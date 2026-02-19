# Cassandra — Migration Patterns

## Overview

Cassandra has **no native migration framework** like Flyway. Schema changes require versioned CQL scripts or dedicated tools.

| Approach | Best For | Dependency |
|----------|----------|------------|
| **CQL scripts + shell runner** | Simple projects, ops-driven | `cqlsh` only |
| **Cognitor** (cassandra-migration) | Java projects, CI/CD pipelines | `org.cognitor.cassandra:cassandra-migration` |
| **Manual with schema agreement** | Critical production changes | DBA-supervised |

## CQL Scripts — Versioned Approach

### Directory Structure

```
db/cassandra/
├── V001__create_keyspace.cql
├── V002__create_transactions_by_merchant.cql
├── V003__create_transactions_by_stan.cql
├── V004__add_ttl_policy.cql
├── migrations_metadata.cql
└── run-migrations.sh
```

### Keyspace Template

```sql
-- V001__create_keyspace.cql
-- Description: Create application keyspace

CREATE KEYSPACE IF NOT EXISTS simulator
WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'datacenter1': 3
}
AND durable_writes = true;
```

### Table Template

```sql
-- V002__create_transactions_by_merchant.cql
-- Description: Transactions partitioned by merchant with daily bucketing

CREATE TABLE IF NOT EXISTS simulator.transactions_by_merchant (
    merchant_id TEXT,
    tx_date     DATE,
    created_at  TIMESTAMP,
    stan        TEXT,
    amount      BIGINT,
    mti         TEXT,
    response_code TEXT,
    pan_masked  TEXT,
    raw_message BLOB,
    PRIMARY KEY ((merchant_id, tx_date), created_at)
) WITH CLUSTERING ORDER BY (created_at DESC)
   AND default_time_to_live = 7776000   -- 90 days
   AND compaction = {
       'class': 'TimeWindowCompactionStrategy',
       'compaction_window_unit': 'DAYS',
       'compaction_window_size': 1
   };
```

### Runner Script

```bash
#!/usr/bin/env bash
set -euo pipefail

CQLSH_HOST="${CQLSH_HOST:-localhost}"
CQLSH_PORT="${CQLSH_PORT:-9042}"
KEYSPACE="${KEYSPACE:-simulator}"

# Create migration tracking table
cqlsh "$CQLSH_HOST" "$CQLSH_PORT" -e "
CREATE TABLE IF NOT EXISTS ${KEYSPACE}.schema_migrations (
    version     INT PRIMARY KEY,
    description TEXT,
    applied_at  TIMESTAMP,
    checksum    TEXT
);"

for script in db/cassandra/V*.cql; do
    version=$(basename "$script" | grep -oP '(?<=V)\d+')
    version_int=$((10#$version))

    applied=$(cqlsh "$CQLSH_HOST" "$CQLSH_PORT" -e \
        "SELECT version FROM ${KEYSPACE}.schema_migrations WHERE version = ${version_int};" \
        | grep -c "${version_int}" || true)

    if [ "$applied" -eq 0 ]; then
        echo "Applying: $script"
        cqlsh "$CQLSH_HOST" "$CQLSH_PORT" -f "$script"
        checksum=$(sha256sum "$script" | awk '{print $1}')
        cqlsh "$CQLSH_HOST" "$CQLSH_PORT" -e \
            "INSERT INTO ${KEYSPACE}.schema_migrations (version, description, applied_at, checksum)
             VALUES (${version_int}, '$(basename "$script")', toTimestamp(now()), '${checksum}');"
        echo "Applied: $script"
    else
        echo "Skipping (already applied): $script"
    fi
done
echo "All migrations complete."
```

## Cognitor (Java Migration Tool)

### Dependency

```xml
<dependency>
    <groupId>org.cognitor.cassandra</groupId>
    <artifactId>cassandra-migration</artifactId>
    <version>${cassandra-migration.version}</version>
</dependency>
```

### Configuration

```java
@ApplicationScoped
public class CassandraMigrationRunner {

    @Inject
    CqlSession session;

    void onStart(@Observes StartupEvent ev) {
        var db = new Database(session, new MigrationConfiguration()
            .withKeyspaceName("simulator"));
        var migration = new MigrationTask(db, new MigrationRepository("db/cassandra"));
        migration.migrate();
    }
}
```

Scripts placed in `src/main/resources/db/cassandra/` with naming: `001_description.cql`.

## Schema Agreement Check

Before applying DDL changes, verify all nodes agree on the current schema.

```java
boolean schemaAgreed = session.checkSchemaAgreement();
if (!schemaAgreed) {
    throw new IllegalStateException("Schema not in agreement — abort migration");
}
```

```bash
# Via nodetool
nodetool describecluster | grep "Schema versions"
# All nodes must show same schema version hash
```

## Rules

| Rule | Detail |
|------|--------|
| Idempotent | Use `IF NOT EXISTS` on all CREATE statements |
| No ALTER abuse | Prefer new table over complex ALTER; Cassandra does not support column renames |
| Schema agreement | Verify agreement before and after DDL |
| One change per file | Each CQL file = one logical change |
| Version tracked | Store applied versions in `schema_migrations` table |
| Test first | Apply to test cluster before production |
| No DROP in prod | Mark tables as deprecated; drop only after confirmed zero reads |
| Compaction strategy | Choose strategy at creation time (TWCS for time-series, LCS for read-heavy) |
