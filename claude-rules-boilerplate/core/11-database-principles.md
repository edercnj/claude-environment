# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 11 — Database Principles

## Principles
- **Versioned migrations:** All schema changes through migration tool
- **Repository pattern:** Centralized data access via repositories
- **Separate schema/database:** Application tables in their own namespace
- **Conventions over configuration:** Consistent naming across all tables

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Table | snake_case, plural | `transactions`, `merchants` |
| Column | snake_case | `response_code`, `created_at` |
| Index | `idx_{table}_{columns}` | `idx_transactions_stan_date` |
| UNIQUE Constraint | `uq_{table}_{column}` | `uq_merchants_mid` |
| Foreign Key | `fk_{table}_{ref}` | `fk_terminals_merchant_id` |
| Check | `ck_{table}_{rule}` | `ck_transactions_amount_positive` |
| Sequence | `{table}_id_seq` | `transactions_id_seq` |

## Standard Data Types (Principles)

| Data | Recommended Type | Justification |
|------|-----------------|---------------|
| Primary Key | Auto-incrementing 64-bit integer | Scalable, globally unique |
| Monetary values | Integer (cents) | Avoids floating-point precision issues |
| Timestamps | Timestamp with timezone | Always with timezone for correctness |
| Status / Enums | String (varchar) | Readable, extensible, portable |
| Boolean flags | Boolean with explicit default | No ambiguity |
| Raw binary data | Binary / blob type | For opaque payloads |
| Structured data | JSON type | For flexible schemas |

> **Customize:** Map these principles to your database's specific types (e.g., `BIGSERIAL` for PostgreSQL, `BIGINT AUTO_INCREMENT` for MySQL, `ObjectId` for MongoDB).

## Mandatory Columns in ALL Tables

```sql
id {AUTO_INCREMENT_TYPE} PRIMARY KEY,
-- ... specific columns ...
created_at {TIMESTAMP_TYPE} NOT NULL DEFAULT {NOW_FUNCTION},
updated_at {TIMESTAMP_TYPE} NOT NULL DEFAULT {NOW_FUNCTION}
```

Every table MUST have: primary key, `created_at`, and `updated_at`.

## Migration Rules

### Naming

```
V{version}__{description}.{ext}
```

Examples:
- `V1__create_transaction_table.sql`
- `V2__create_merchant_terminal_tables.sql`
- `V3__add_index_transactions_stan.sql`

### Rules

- Always wrapped in transactions (`BEGIN; ... COMMIT;`)
- Use `IF NOT EXISTS` / `IF EXISTS` for idempotence
- NEVER modify a migration already applied in production — create a new migration
- One migration per logical change
- Comment at top: ticket/story reference, author, description

### Template

```sql
-- V{N}__{description}.sql
-- Story: {TICKET}
-- Description: {what this migration does}

BEGIN;

CREATE TABLE IF NOT EXISTS {schema}.{table_name} (
    id {AUTO_INCREMENT_TYPE} PRIMARY KEY,
    -- columns
    created_at {TIMESTAMP_TYPE} NOT NULL DEFAULT {NOW},
    updated_at {TIMESTAMP_TYPE} NOT NULL DEFAULT {NOW}
);

CREATE INDEX IF NOT EXISTS idx_{table}_{column}
    ON {schema}.{table_name} ({column});

COMMIT;
```

## Index Rules

1. **ALWAYS** create indexes for columns used in WHERE, JOIN, ORDER BY
2. **Composite indexes:** order matters — most selective column first
3. **Partial indexes** when query filters by status (e.g., `WHERE status = 'ACTIVE'`)
4. **NEVER** index low-cardinality columns alone (e.g., boolean with 50/50 distribution)
5. Validate with EXPLAIN ANALYZE on critical queries

## Data Security

- Sensitive identifiers: store ONLY masked or encrypted
- Passwords / secrets: NEVER persist in plain text
- Binary secrets (encryption keys, tokens): NEVER persist
- Audit data: store raw payloads in binary format for forensics
- Database credentials: managed by secrets manager, NEVER in code

## Connection Pool

| Parameter | Guideline |
|-----------|-----------|
| Min connections | 5 (warm pool) |
| Max connections | 20 (per instance, adjust for replicas) |
| Acquire timeout | 3-5 seconds |
| Idle timeout | 10 minutes |

**Rule:** Max connections per instance * number of replicas MUST NOT exceed database max_connections.

## Anti-Patterns (FORBIDDEN)

- `FLOAT` or `DOUBLE` for monetary values — use integer cents
- `TEXT` without limit for known fields — use bounded strings
- Composite primary keys — use auto-increment + UNIQUE constraint
- Cascading deletes in production — use soft delete (status = 'DELETED')
- `SELECT *` in application queries — list columns explicitly
- Store full sensitive identifiers — ALWAYS mask before persisting
- Modify applied migrations — create new migrations
- Migrations without transactions — always wrap in BEGIN/COMMIT
- Skip index creation for query patterns — every WHERE/JOIN needs an index
- Database credentials in source code or configuration files
