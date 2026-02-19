# MongoDB — Migration Patterns

## Overview

MongoDB has **no native migration tool** like Flyway. Schema changes require application-level strategies.

| Approach | Best For | Dependency |
|----------|----------|------------|
| **Mongock** | Java/Kotlin projects, CI/CD pipelines | `io.mongock:mongock-*` |
| **mongosh scripts** | Ops-driven migrations, simple changes | MongoDB Shell |
| **Schema versioning** | Gradual migration, zero-downtime | Application logic |

## Mongock (Java Migration Runner)

### Dependencies

```xml
<!-- Quarkus -->
<dependency>
    <groupId>io.mongock</groupId>
    <artifactId>mongock-quarkus</artifactId>
</dependency>

<!-- Spring Boot -->
<dependency>
    <groupId>io.mongock</groupId>
    <artifactId>mongock-springboot-v3</artifactId>
</dependency>
```

### Changeset Template

```java
@ChangeUnit(id = "001-create-merchants-indexes", order = "001", author = "team")
public class CreateMerchantsIndexes {

    @Execution
    public void execute(MongoDatabase db) {
        var collection = db.getCollection("merchants");
        collection.createIndex(
            Indexes.ascending("mid"),
            new IndexOptions().unique(true).name("uq_merchants_mid")
        );
        collection.createIndex(
            Indexes.ascending("status", "createdAt"),
            new IndexOptions().name("idx_merchants_status_created")
        );
    }

    @RollbackExecution
    public void rollback(MongoDatabase db) {
        var collection = db.getCollection("merchants");
        collection.dropIndex("uq_merchants_mid");
        collection.dropIndex("idx_merchants_status_created");
    }
}
```

### Naming Convention

```
{order}-{description}
001-create-merchants-indexes
002-add-schema-validation-merchants
003-migrate-address-to-embedded
```

### Configuration

```properties
# Quarkus
mongock.migration-scan-package=com.example.migration
mongock.enabled=true

# Spring Boot
mongock.migration-scan-package=com.example.migration
mongock.enabled=true
```

## mongosh Scripts (Versioned)

### Directory Structure

```
db/migrations/
├── V001__create_merchants_indexes.js
├── V002__add_schema_validation.js
├── V003__migrate_address_format.js
└── run-migrations.sh
```

### Script Template

```javascript
// V001__create_merchants_indexes.js
// Description: Create indexes for merchants collection
// Date: 2026-02-18

const version = 1;
const description = "create_merchants_indexes";

if (db.migrations.countDocuments({ version: version }) === 0) {
    db.merchants.createIndex({ mid: 1 }, { unique: true, name: "uq_merchants_mid" });
    db.merchants.createIndex({ status: 1, createdAt: -1 }, { name: "idx_merchants_status_created" });

    db.migrations.insertOne({
        version: version,
        description: description,
        appliedAt: new Date(),
        success: true
    });
    print(`Migration V${String(version).padStart(3, '0')} applied: ${description}`);
} else {
    print(`Migration V${String(version).padStart(3, '0')} already applied, skipping.`);
}
```

### Runner Script

```bash
#!/usr/bin/env bash
set -euo pipefail

MONGO_URI="${MONGO_URI:-mongodb://localhost:27017/mydb}"

for script in db/migrations/V*.js; do
    echo "Running: $script"
    mongosh "$MONGO_URI" --file "$script"
done
echo "All migrations applied."
```

## Schema Versioning Pattern

Add `_schemaVersion` to every document. Transform on read, write back new format.

### Implementation

```java
public record MerchantDocument(
    String id,
    String mid,
    String name,
    Address address,        // New in v2 (was flat fields)
    int _schemaVersion
) {}

public MerchantDocument migrateIfNeeded(Document raw) {
    int version = raw.getInteger("_schemaVersion", 1);
    return switch (version) {
        case 1 -> migrateV1toV2(raw);
        case 2 -> mapV2(raw);
        default -> throw new UnsupportedSchemaVersionException(version);
    };
}
```

### Version Tracking

| Version | Change | Migration Strategy |
|---------|--------|--------------------|
| 1 | Initial schema | — |
| 2 | Address from flat fields to embedded object | Lazy (on read) |
| 3 | Added `tags` array with default `[]` | Default value on read |

## Rules

| Rule | Detail |
|------|--------|
| Idempotent | Every migration MUST be safe to run multiple times |
| Versioned in Git | Migration scripts live alongside application code |
| Tested | Run migrations against test DB before production |
| Rollback plan | Mongock: `@RollbackExecution`; scripts: separate rollback file |
| No data loss | NEVER drop fields without confirming zero usage |
| Index builds | Use `background: true` (< 4.2) or default background (>= 4.2) |
