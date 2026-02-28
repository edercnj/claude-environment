# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# PostgreSQL — Migration Patterns

> Migration strategies and tooling for PostgreSQL. DDL is fully transactional in PostgreSQL, enabling safe rollback on error.

## Flyway (Recommended for SQL-First Teams)

### File Naming Convention

| Type        | Pattern                        | Example                               |
| ----------- | ------------------------------ | ------------------------------------- |
| Versioned   | `V{N}__{description}.sql`     | `V1__create_merchants_table.sql`      |
| Repeatable  | `R__{description}.sql`        | `R__refresh_materialized_views.sql`   |
| Undo (paid) | `U{N}__{description}.sql`     | `U1__drop_merchants_table.sql`        |

> **Note:** Double underscore `__` between version and description is mandatory.

### Migration Location

```
src/main/resources/db/migration/
├── V1__create_merchants_table.sql
├── V2__create_terminals_table.sql
├── V3__create_transactions_table.sql
├── V4__add_timeout_configuration.sql
└── R__update_statistics_view.sql
```

### Template Migration (Flyway)

```sql
-- V{N}__{description}.sql
-- Story: STORY-NNN
-- Description: Brief description of what this migration does

BEGIN;

CREATE TABLE IF NOT EXISTS {{DB_TYPE}}.table_name (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_table_name_status
    ON {{DB_TYPE}}.table_name (status);

COMMIT;
```

**Key advantage:** PostgreSQL supports transactional DDL, so `BEGIN;...COMMIT;` ensures the entire migration succeeds or rolls back atomically. This is NOT possible in MySQL or Oracle.

### Flyway Configuration ({{FRAMEWORK}})

| Framework | Configuration Key                           | Default Value                  |
| --------- | ------------------------------------------- | ------------------------------ |
| Quarkus   | `quarkus.flyway.migrate-at-start`           | `false`                        |
| Quarkus   | `quarkus.flyway.default-schema`             | —                              |
| Quarkus   | `quarkus.flyway.locations`                  | `db/migration`                 |
| Spring    | `spring.flyway.enabled`                     | `true`                         |
| Spring    | `spring.flyway.schemas`                     | —                              |
| Spring    | `spring.flyway.locations`                   | `classpath:db/migration`       |

## Liquibase (Alternative — Multi-DB or Rollback Needed)

### Changeset Format (YAML)

```yaml
databaseChangeLog:
  - changeSet:
      id: 1
      author: developer
      changes:
        - createTable:
            schemaName: {{DB_TYPE}}
            tableName: merchants
            columns:
              - column:
                  name: id
                  type: BIGSERIAL
                  constraints:
                    primaryKey: true
              - column:
                  name: mid
                  type: VARCHAR(15)
                  constraints:
                    nullable: false
                    unique: true
              - column:
                  name: created_at
                  type: TIMESTAMPTZ
                  defaultValueComputed: NOW()
                  constraints:
                    nullable: false
      rollback:
        - dropTable:
            schemaName: {{DB_TYPE}}
            tableName: merchants
```

### Changeset Format (SQL)

```sql
--changeset developer:1
--comment: Create merchants table
CREATE TABLE {{DB_TYPE}}.merchants (
    id         BIGSERIAL PRIMARY KEY,
    mid        VARCHAR(15) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
--rollback DROP TABLE IF EXISTS {{DB_TYPE}}.merchants;
```

## Rollback Patterns

### Strategy by Change Type

| Change Type          | Rollback Strategy                          | Reversible? |
| -------------------- | ------------------------------------------ | ----------- |
| `CREATE TABLE`       | `DROP TABLE IF EXISTS`                     | Yes         |
| `ADD COLUMN`         | `ALTER TABLE ... DROP COLUMN`              | Yes*        |
| `DROP COLUMN`        | **Not reversible** (data lost)             | No          |
| `CREATE INDEX`       | `DROP INDEX IF EXISTS`                     | Yes         |
| `ALTER COLUMN TYPE`  | `ALTER COLUMN ... TYPE old_type`           | Risky       |
| `INSERT seed data`   | `DELETE WHERE condition`                   | Yes         |
| `DROP TABLE`         | **Not reversible** (data lost)             | No          |

> *Dropping a column loses data. For reversible column removal, use a two-phase approach: (1) stop writing, (2) drop in next release.

### Safe Column Removal (Two-Phase)

```sql
-- Phase 1: Migration N — Mark column as unused (deploy, wait for all code to stop using it)
-- No SQL needed, just code changes

-- Phase 2: Migration N+1 — Drop column (next release)
BEGIN;
ALTER TABLE {{DB_TYPE}}.merchants DROP COLUMN IF EXISTS legacy_field;
COMMIT;
```

### Safe Column Rename (Three-Phase)

```sql
-- Phase 1: Add new column, backfill
BEGIN;
ALTER TABLE {{DB_TYPE}}.merchants ADD COLUMN IF NOT EXISTS trade_name VARCHAR(100);
UPDATE {{DB_TYPE}}.merchants SET trade_name = fantasy_name WHERE trade_name IS NULL;
COMMIT;

-- Phase 2: Code reads from both, writes to both (deploy)
-- Phase 3: Drop old column (next release)
BEGIN;
ALTER TABLE {{DB_TYPE}}.merchants DROP COLUMN IF EXISTS fantasy_name;
COMMIT;
```

## Concurrent Index Creation

For large tables, create indexes without locking writes:

```sql
-- DO NOT wrap in BEGIN/COMMIT — CONCURRENTLY cannot run inside a transaction
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transactions_merchant
    ON {{DB_TYPE}}.transactions (merchant_id, created_at DESC);
```

> `CREATE INDEX CONCURRENTLY` cannot be inside a `BEGIN;...COMMIT;` block. This is a Flyway migration that must NOT be wrapped in a transaction. In Flyway, disable transaction per migration by naming it normally and adding a comment or using callbacks.

## Best Practices

| Rule                                     | Rationale                                          |
| ---------------------------------------- | -------------------------------------------------- |
| Always use `IF NOT EXISTS` / `IF EXISTS` | Idempotent migrations, safe re-runs                |
| Wrap DDL in `BEGIN;...COMMIT;`           | Atomic migration (PostgreSQL supports this)        |
| One logical change per migration         | Easier to review, debug, and rollback              |
| Never modify an applied migration        | Breaks Flyway/Liquibase checksum validation        |
| Comment with story/ticket reference      | Traceability from migration to requirement         |
| Test migrations on empty database        | Validates full migration chain                     |
| Test migrations on production clone      | Catches data-dependent issues                      |
| Separate DDL and DML migrations          | DDL locks tables; DML can be batched               |
| Use `CONCURRENTLY` for large table indexes | Avoids write locks during index creation          |
| Always add `created_at` and `updated_at` | Standard audit columns on every table              |

## Anti-Patterns (FORBIDDEN)

| Anti-Pattern                            | Problem                                          |
| --------------------------------------- | ------------------------------------------------ |
| Modifying applied migration             | Checksum mismatch, broken state                  |
| DDL without `IF NOT EXISTS`             | Fails on re-run or partial apply                 |
| Missing `BEGIN;...COMMIT;`              | Non-atomic migration (though PG auto-wraps)      |
| `CREATE INDEX` on large table (blocking)| Locks writes for minutes/hours                   |
| Multiple unrelated changes in one file  | Hard to debug, impossible to partial rollback     |
| Using `{{DB_MIGRATION}}` auto-generation for production | `drop-and-create` destroys data    |
| Seed data in versioned migrations       | Runs once, hard to update                        |
| No schema prefix on table names         | Tables land in `public`, namespace pollution     |
