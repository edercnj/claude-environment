---
name: database-patterns
description: "Database conventions: schema naming, migration patterns, indexing rules, query optimization, connection pool configuration. Uses {{DB_TYPE}}, {{DB_MIGRATION}} placeholders. Condition: database != none."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Database Patterns

## Purpose

Provides database conventions for schema design, migration management, indexing strategies, query optimization, and connection pool configuration. All patterns are {{DB_TYPE}}-aware and use {{DB_MIGRATION}} for schema versioning.

## Condition

This knowledge pack is only relevant when `database != "none"` in the project configuration.

---

## 1. Schema Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Schema | lowercase, project name | `simulator`, `billing` |
| Table | snake_case, plural | `transactions`, `merchants` |
| Column | snake_case | `response_code`, `created_at` |
| Index | `idx_{table}_{columns}` | `idx_transactions_stan_date` |
| Unique constraint | `uq_{table}_{column}` | `uq_merchants_mid` |
| Foreign key | `fk_{table}_{ref}` | `fk_terminals_merchant_id` |
| Check constraint | `ck_{table}_{rule}` | `ck_transactions_amount_positive` |
| Sequence | `{table}_id_seq` | `transactions_id_seq` |

---

## 2. Standard Data Types

### PostgreSQL ({{DB_TYPE}} = postgresql)

| Data | Type | Justification |
|------|------|---------------|
| Primary key | `BIGSERIAL PRIMARY KEY` | 64-bit auto-increment |
| Monetary values | `BIGINT` (cents) | Avoids floating-point precision issues |
| Timestamps | `TIMESTAMP WITH TIME ZONE` | Always timezone-aware |
| Short identifiers | `VARCHAR(N)` | Fixed max length, enforced at DB level |
| Status / enums | `VARCHAR(20)` | Readable, extensible without migration |
| Boolean flags | `BOOLEAN NOT NULL DEFAULT FALSE` | Explicit, no null ambiguity |
| Raw binary | `BYTEA` | For opaque blobs (raw messages, files) |
| Flexible structure | `JSONB` | For semi-structured data, indexable |
| Free text | `TEXT` | Only for truly unbounded content |

### MySQL ({{DB_TYPE}} = mysql)

| Data | Type | Justification |
|------|------|---------------|
| Primary key | `BIGINT AUTO_INCREMENT PRIMARY KEY` | 64-bit auto-increment |
| Monetary values | `BIGINT` (cents) | Same principle as PostgreSQL |
| Timestamps | `TIMESTAMP DEFAULT CURRENT_TIMESTAMP` | UTC by default in MySQL |
| Short identifiers | `VARCHAR(N)` | With `CHARACTER SET utf8mb4` |
| Raw binary | `BLOB` / `LONGBLOB` | For opaque blobs |
| Flexible structure | `JSON` | Native JSON type (MySQL 5.7+) |

---

## 3. Mandatory Columns

Every table MUST include:

```sql
id BIGSERIAL PRIMARY KEY,              -- or BIGINT AUTO_INCREMENT for MySQL
-- ... domain columns ...
created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
```

---

## 4. Migration Patterns

### {{DB_MIGRATION}} = flyway

**Naming:** `V{version}__{description}.sql` (two underscores)

```sql
-- V{N}__{description}.sql
-- Description: [what this migration does]
-- Story: STORY-NNN

BEGIN;

CREATE TABLE IF NOT EXISTS {{schema}}.{{table_name}} (
    id BIGSERIAL PRIMARY KEY,
    -- domain columns
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_{{table_name}}_column
    ON {{schema}}.{{table_name}} (column);

COMMIT;
```

**Location:** `src/main/resources/db/migration/`

### {{DB_MIGRATION}} = liquibase

**Naming:** `changelog-{NNN}-{description}.xml` or `.yaml`

```yaml
databaseChangeLog:
  - changeSet:
      id: NNN-create-{{table_name}}
      author: developer
      changes:
        - createTable:
            tableName: {{table_name}}
            schemaName: {{schema}}
            columns:
              - column:
                  name: id
                  type: BIGSERIAL
                  autoIncrement: true
                  constraints:
                    primaryKey: true
              # ... domain columns
              - column:
                  name: created_at
                  type: TIMESTAMP WITH TIME ZONE
                  defaultValueComputed: NOW()
                  constraints:
                    nullable: false
```

**Location:** `src/main/resources/db/changelog/`

### Migration Rules (All Tools)

- NEVER alter a migration already applied in production
- ALWAYS use idempotent operations (`IF NOT EXISTS`, `IF EXISTS`)
- ALWAYS wrap DDL in transactions where supported
- ALWAYS document which story created the migration
- One migration per logical change

---

## 5. Indexing Rules

### When to Create Indexes

| Scenario | Action |
|----------|--------|
| Column in WHERE clause (frequently queried) | Single-column index |
| Multiple columns in WHERE (AND) | Composite index (most selective first) |
| Column in ORDER BY | Index matching sort order |
| Foreign key column | Index (mandatory for JOIN performance) |
| Unique business key | UNIQUE index or constraint |
| Low-cardinality column alone (boolean, status) | DO NOT index alone |
| Column with status filter | Partial index: `WHERE status = 'ACTIVE'` |

### Composite Index Ordering

Place the most selective column first:

```sql
-- GOOD: merchant_id is more selective than status
CREATE INDEX idx_transactions_merchant_status
    ON {{schema}}.transactions (merchant_id, status);

-- BAD: status has low cardinality, poor selectivity
CREATE INDEX idx_transactions_status_merchant
    ON {{schema}}.transactions (status, merchant_id);
```

### Partial Indexes (PostgreSQL)

```sql
-- Index only active records (smaller, faster)
CREATE INDEX idx_merchants_active
    ON {{schema}}.merchants (mid) WHERE status = 'ACTIVE';
```

### Validation

Always validate indexes with query plans:

```sql
EXPLAIN ANALYZE SELECT * FROM {{schema}}.transactions
    WHERE merchant_id = '123456789012345' AND status = 'PROCESSED';
```

---

## 6. Query Optimization

### Mandatory Practices

- NEVER use `SELECT *` in production queries -- list columns explicitly
- ALWAYS use parameterized queries (prevent SQL injection)
- ALWAYS paginate list queries (never return unbounded results)
- Use `COUNT(*)` instead of fetching all rows to count
- Prefer `EXISTS` over `COUNT` for existence checks

### Pagination Pattern

```sql
-- Offset-based (simple, sufficient for most cases)
SELECT id, identifier, name, status, created_at
FROM {{schema}}.{{table_name}}
WHERE status = 'ACTIVE'
ORDER BY created_at DESC
LIMIT :limit OFFSET :offset;

-- Keyset-based (better for large datasets)
SELECT id, identifier, name, status, created_at
FROM {{schema}}.{{table_name}}
WHERE status = 'ACTIVE' AND created_at < :last_created_at
ORDER BY created_at DESC
LIMIT :limit;
```

---

## 7. Connection Pool Configuration

### PostgreSQL Pool Settings

```properties
# Minimum connections kept warm
{{prefix}}.datasource.jdbc.min-size=5

# Maximum concurrent connections
{{prefix}}.datasource.jdbc.max-size=20

# Timeout waiting for a connection from pool
{{prefix}}.datasource.jdbc.acquisition-timeout=5S

# How long an idle connection stays in pool
{{prefix}}.datasource.jdbc.idle-removal-interval=15M

# Statement timeout (prevents runaway queries)
{{prefix}}.hibernate-orm.jdbc.statement-timeout=30
```

### Pool Sizing Formula

```
max_pool_size = (core_count * 2) + effective_spindle_count
```

For most applications: start with 10-20, tune based on load.

### Per-Environment Sizing

| Environment | min-size | max-size | Notes |
|-------------|----------|----------|-------|
| Dev/Test | 2 | 5 | Minimal, fast startup |
| Staging | 5 | 15 | Mirrors production ratio |
| Production | 5 | 20 | Tuned to workload |

---

## 8. Test Database Strategy

| Scenario | Database | Configuration |
|----------|----------|---------------|
| Unit tests / fast integration | H2 in {{DB_TYPE}} mode | In-memory, schema auto-generated |
| Migration validation | Real {{DB_TYPE}} (Testcontainers) | Validates actual DDL compatibility |
| Performance / EXPLAIN ANALYZE | Real {{DB_TYPE}} (Testcontainers) | Realistic query plans |

### H2 PostgreSQL Mode Example

```properties
datasource.db-kind=h2
datasource.jdbc.url=jdbc:h2:mem:testdb;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH
datasource.username=sa
datasource.password=
hibernate-orm.database.generation=drop-and-create
flyway.enabled=false
```

---

## 9. Data Security at Database Level

| Data | Storage Rule |
|------|-------------|
| Passwords | Hashed (bcrypt/argon2), NEVER plaintext |
| PAN / Card numbers | Masked (first 6 + last 4) or tokenized |
| PIN blocks, CVV | NEVER persist |
| Documents (SSN, tax ID) | Encrypt at rest or mask |
| API keys | Hashed, NEVER plaintext |

---

## Anti-Patterns

- `FLOAT` or `DECIMAL` for monetary values -- use `BIGINT` (cents)
- `TEXT` without reason for bounded fields -- use `VARCHAR(N)`
- Composite primary keys -- use surrogate `BIGSERIAL` + UNIQUE constraint
- Cascading deletes in production -- use soft delete (`status = 'DELETED'`)
- `SELECT *` in any production query
- Storing full sensitive data (PAN, PIN) unmasked
- Migrations that modify already-applied scripts
- Missing indexes on foreign key columns
