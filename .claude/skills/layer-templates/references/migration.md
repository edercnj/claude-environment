# Template: Flyway Migration

## Pattern

```sql
-- V1__create_merchants_table.sql
-- Story: STORY-009
-- Description: Create merchants table for merchant management

BEGIN;

CREATE TABLE IF NOT EXISTS simulator.merchants (
    id              BIGSERIAL PRIMARY KEY,
    mid             VARCHAR(15) NOT NULL,
    legal_name      VARCHAR(100) NOT NULL,
    trade_name      VARCHAR(100) NOT NULL,
    document        VARCHAR(14) NOT NULL,
    mcc             VARCHAR(4) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    force_timeout   BOOLEAN NOT NULL DEFAULT FALSE,
    timeout_seconds INTEGER,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_merchants_mid
    ON simulator.merchants (mid);

CREATE INDEX IF NOT EXISTS idx_merchants_status
    ON simulator.merchants (status)
    WHERE status = 'ACTIVE';

COMMIT;
```

## CHANGE THESE

- **File name**: `V{N}__{description}.sql` (two underscores, next version number)
- **Story reference**: Update to current STORY-NNN
- **Table name**: Plural, snake_case in `simulator` schema
- **Columns**: Match the Architect's plan and Rule 16 types
- **Indexes**: Add per query patterns from the plan

## Critical Rules (memorize)

1. ALWAYS `BEGIN;` ... `COMMIT;` (explicit transaction)
2. ALWAYS `IF NOT EXISTS` for idempotency
3. Schema is ALWAYS `simulator.*`
4. Monetary values: `BIGINT` (cents) — NEVER `DECIMAL`/`FLOAT`
5. Timestamps: `TIMESTAMP WITH TIME ZONE` with `DEFAULT NOW()`

## Type Reference

| Data | PostgreSQL Type |
|------|----------------|
| ID | `BIGSERIAL PRIMARY KEY` |
| Money | `BIGINT` (cents) |
| Timestamps | `TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()` |
| PAN (masked) | `VARCHAR(19)` |
| MTI | `VARCHAR(4)` |
| Response Code | `VARCHAR(2)` |
| STAN | `VARCHAR(6)` |
| Status | `VARCHAR(20)` |
| Boolean | `BOOLEAN NOT NULL DEFAULT FALSE` |

## Checklist

- [ ] File name: `V{N}__{description}.sql`
- [ ] Comment header with Story and Description
- [ ] `BEGIN;` at start, `COMMIT;` at end
- [ ] `IF NOT EXISTS` on CREATE TABLE and CREATE INDEX
- [ ] Schema `simulator.*`
- [ ] `created_at` and `updated_at` columns present
- [ ] `BIGINT` for monetary values (not DECIMAL)
- [ ] Appropriate indexes created
