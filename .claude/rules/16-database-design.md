# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 16 — Database Design

## Principles
- **PostgreSQL 16+** as the only database
- **Flyway** for versioned migrations
- **Panache Repository Pattern** for data access
- **Separate schema:** all tables in the `simulator` schema

## Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Table | snake_case, plural | `transactions`, `merchants` |
| Column | snake_case | `response_code`, `created_at` |
| Index | `idx_{table}_{columns}` | `idx_transactions_stan_date` |
| UNIQUE Constraint | `uq_{table}_{column}` | `uq_merchants_mid` |
| Foreign Key | `fk_{table}_{ref}` | `fk_terminals_merchant_id` |
| Check | `ck_{table}_{rule}` | `ck_transactions_amount_positive` |
| Sequence | `{table}_id_seq` | `transactions_id_seq` (auto with BIGSERIAL) |

## Standard Data Types
| Data | PostgreSQL Type | Justification |
|------|-----------------|---------------|
| ID | `BIGSERIAL PRIMARY KEY` | 64-bit auto-increment |
| Monetary values | `BIGINT` (cents) | Avoids floating-point issues |
| Timestamps | `TIMESTAMP WITH TIME ZONE` | Always with timezone |
| Masked PAN | `VARCHAR(19)` | First 6 + last 4 + asterisks |
| MTI | `VARCHAR(4)` | Supports 1987/1993 (4 digits) and 2021 (3 digits) |
| Response Code | `VARCHAR(2)` | ISO 8583 standard |
| STAN | `VARCHAR(6)` | Systems Trace Audit Number |
| Status/Enums | `VARCHAR(20)` | Readable, extensible |
| Raw ISO data | `BYTEA` | Complete ISO message |
| Parsed fields | `JSONB` | Flexible for different ISO versions |
| Documents (CNPJ) | `VARCHAR(14)` | No formatting |
| Boolean flags | `BOOLEAN NOT NULL DEFAULT FALSE` | Explicit |

## Mandatory Columns in ALL Tables
```sql
id BIGSERIAL PRIMARY KEY,
-- ... specific columns ...
created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
```

## Index Rules
1. **ALWAYS** create indexes for columns used in WHERE, JOIN, ORDER BY
2. **Composite indexes:** order matters — most selective column first
3. **Partial indexes** when query filters by status: `WHERE status = 'ACTIVE'`
4. **NEVER** index low-cardinality columns alone (e.g., boolean)
5. Validate with `EXPLAIN ANALYZE` on critical queries

### Mandatory Indexes
```sql
-- Transactions: lookup by STAN + date (reversal matching)
CREATE INDEX idx_transactions_stan_date ON simulator.transactions (stan, local_date_time, terminal_id);

-- Transactions: filter by merchant
CREATE INDEX idx_transactions_merchant ON simulator.transactions (merchant_id, created_at DESC);

-- Transactions: filter by response code (dashboard)
CREATE INDEX idx_transactions_rc ON simulator.transactions (response_code, created_at DESC);

-- Merchants: lookup by MID (unique)
CREATE UNIQUE INDEX uq_merchants_mid ON simulator.merchants (mid);

-- Terminals: lookup by TID (unique)
CREATE UNIQUE INDEX uq_terminals_tid ON simulator.terminals (tid);
```

## Flyway Migrations

### Rules
- Naming: `V{N}__{description}.sql` (two underscores)
- Always wrapped in `BEGIN; ... COMMIT;`
- Use `IF NOT EXISTS` for idempotence
- NEVER alter a migration already applied in production
- One migration per logical change
- Comment at top: Story, author, description

### Template
```sql
-- V{N}__{description}.sql
-- Story: STORY-NNN
-- Description: [what this migration does]

BEGIN;

CREATE TABLE IF NOT EXISTS simulator.table_name (
    id BIGSERIAL PRIMARY KEY,
    -- columns
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_table_column
    ON simulator.table_name (column);

COMMIT;
```

## Data Security
- PAN: store ONLY masked (123456****1234)
- PIN Block: NEVER persist
- CVV/CVC: NEVER persist
- Track Data: NEVER persist
- Raw ISO message: store in BYTEA (for debug/audit)
- Database credentials: Kubernetes Secrets, NEVER in code

## Anti-Patterns
- ❌ `FLOAT` or `DECIMAL` for monetary values → use `BIGINT` (cents)
- ❌ `TEXT` without limit for known fields → use `VARCHAR(N)`
- ❌ Composite primary keys → use BIGSERIAL + UNIQUE constraint
- ❌ Cascading deletes in production → use soft delete (status = 'DELETED')
- ❌ Queries with `SELECT *` → list columns explicitly
- ❌ Store full PAN → ALWAYS mask before persisting
