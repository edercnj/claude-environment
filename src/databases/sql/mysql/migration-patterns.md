# MySQL / MariaDB — Migration Patterns

## CRITICAL: DDL Is Implicit Commit

Like Oracle, MySQL performs an **implicit COMMIT** before and after DDL statements. `START TRANSACTION; ... COMMIT;` wrapping does NOT provide atomicity for DDL.

```sql
-- This does NOT rollback CREATE TABLE on failure:
START TRANSACTION;
CREATE TABLE foo (...);  -- IMPLICIT COMMIT
CREATE TABLE bar (...);  -- If this fails, foo already exists
COMMIT;
```

**DML** (INSERT, UPDATE, DELETE) IS transactional within InnoDB. Wrap DML-only migrations in transactions.

## Migration Tool Support

| Feature | Flyway | Liquibase |
|---------|--------|-----------|
| MySQL support | Via `flyway-mysql` add-on | Built-in |
| MariaDB support | Via `flyway-mysql` (shared) | Built-in |
| DDL transactions | No (MySQL limitation) | No (MySQL limitation) |
| DML transactions | Yes | Yes |
| Rollback | Manual (undo scripts) | Auto-generated for many ops |
| Recommendation | Standard choice | When rollback automation needed |

## MANDATORY: Character Set and Collation

Every CREATE TABLE MUST include `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`. Omitting this risks inheriting `utf8mb3` or `latin1` defaults.

## Template Migration — Flyway

```sql
-- V{N}__{description}.sql
-- Story: {TICKET}
-- Description: {what this migration does}
-- NOTE: DDL is implicit commit in MySQL. Each statement commits independently.

CREATE TABLE IF NOT EXISTS app_schema.table_name (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    col1 VARCHAR(100) NOT NULL,
    col2 BIGINT,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_table_col1
    ON app_schema.table_name (col1);

CREATE UNIQUE INDEX uq_table_col2
    ON app_schema.table_name (col2);
```

## ON UPDATE CURRENT_TIMESTAMP

MySQL natively supports automatic `updated_at` — no trigger needed:

```sql
updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
```

| Database | Auto-update Mechanism |
|----------|----------------------|
| MySQL | `ON UPDATE CURRENT_TIMESTAMP` (column definition) |
| MariaDB | `ON UPDATE CURRENT_TIMESTAMP` (same syntax) |
| PostgreSQL | Trigger required |
| Oracle | Trigger required |

## DML Migration (Transactional)

```sql
-- V{N}__{description}.sql
-- DML migrations CAN be wrapped in transactions

START TRANSACTION;

INSERT INTO app_schema.config (key_name, value)
VALUES ('feature.timeout', 'true')
ON DUPLICATE KEY UPDATE value = VALUES(value);

UPDATE app_schema.merchants
SET status = 'ACTIVE'
WHERE status IS NULL;

COMMIT;
```

## ALTER TABLE Patterns

### Add Column

```sql
-- V{N}__add_column_to_table.sql
ALTER TABLE app_schema.merchants
    ADD COLUMN trade_name VARCHAR(100) NULL AFTER name;
```

### Add Index (Non-blocking in MySQL 8.0+)

```sql
-- V{N}__add_index_transactions.sql
-- MySQL 8.0+ supports ALGORITHM=INPLACE for many index operations
ALTER TABLE app_schema.transactions
    ADD INDEX idx_transactions_merchant (merchant_id, created_at DESC),
    ALGORITHM=INPLACE, LOCK=NONE;
```

### Modify Column

```sql
-- V{N}__modify_column_size.sql
ALTER TABLE app_schema.merchants
    MODIFY COLUMN name VARCHAR(200) NOT NULL;
```

## MariaDB-Specific Features

| Feature | Syntax |
|---------|--------|
| Sequences (alternative to AUTO_INCREMENT) | `CREATE SEQUENCE seq_name START 1 INCREMENT 1;` |
| System versioning | `ALTER TABLE t ADD SYSTEM VERSIONING;` |
| INVISIBLE columns | `ALTER TABLE t ADD COLUMN hidden INT INVISIBLE;` |

## Best Practices

| Practice | Detail |
|----------|--------|
| Always `ENGINE=InnoDB` | Explicit in every CREATE TABLE |
| Always `utf8mb4` | Both CHARSET and COLLATE |
| One DDL per migration | Avoids partial-apply states |
| `IF NOT EXISTS` / `IF EXISTS` | Idempotent migrations |
| `DATETIME(6)` over `TIMESTAMP` | Avoids 2038 limit, microsecond precision |
| `ON UPDATE CURRENT_TIMESTAMP(6)` | Auto-update `updated_at` |
| Schema-qualify tables | `app_schema.table_name` |
| NEVER modify applied migrations | Create corrective migration |
| `ALGORITHM=INPLACE, LOCK=NONE` | For online DDL when possible (8.0+) |
| Test on both MySQL and MariaDB | If supporting both — subtle differences exist |

## Anti-Patterns

- Missing `DEFAULT CHARSET=utf8mb4` — inherits wrong default
- Mixing DDL and DML in same migration expecting atomicity
- `ALTER TABLE` without `ALGORITHM`/`LOCK` on large tables (causes lock)
