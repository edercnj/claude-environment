---
name: database-patterns
description: "Database conventions for {{DB_TYPE}} + {{CACHE_TYPE}}: schema design, migrations ({{DB_MIGRATION}}), indexing, query optimization, caching patterns. References loaded from references/ based on project config."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Database Patterns

## Purpose

Provides database conventions for schema design, migration management, indexing strategies, query optimization, and caching patterns. All patterns are {{DB_TYPE}}-aware and use {{DB_MIGRATION}} for schema versioning. Cache patterns use {{CACHE_TYPE}}.

## Condition

This knowledge pack is relevant when `database != "none"` or `cache != "none"`.

## How to Use

This skill contains reference files specific to your project's database and cache stack. Read the relevant files from the `references/` directory within this skill's folder.

### Database References

**SQL databases (postgresql, oracle, mysql):**
- `references/sql-principles.md` — Universal SQL principles (DDL transactions, ACID, locking)
- `references/types-and-conventions.md` — Data types and naming for {{DB_TYPE}}
- `references/migration-patterns.md` — Migration patterns for {{DB_TYPE}} with {{DB_MIGRATION}}
- `references/query-optimization.md` — Query optimization for {{DB_TYPE}}

**NoSQL databases (mongodb, cassandra):**
- `references/nosql-principles.md` — Universal NoSQL principles (CAP, query-driven modeling)
- `references/modeling-patterns.md` — Data modeling for {{DB_TYPE}}
- `references/migration-patterns.md` — Schema evolution for {{DB_TYPE}}
- `references/query-optimization.md` — Query optimization for {{DB_TYPE}}

### Cache References

- `references/cache-principles.md` — Universal cache patterns (Cache-Aside, TTL, key naming)
- `references/{{CACHE_TYPE}}-patterns.md` — Specific patterns for {{CACHE_TYPE}}

### Cross-Reference

- `references/version-matrix.md` — Version compatibility table for all databases and caches

---

## Universal Rules (Always Apply)

### 1. Schema Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Schema/Database | lowercase, project name | `simulator`, `billing` |
| Table/Collection | snake_case, plural | `transactions`, `merchants` |
| Column/Field | snake_case | `response_code`, `created_at` |
| Index | `idx_{table}_{columns}` | `idx_transactions_stan_date` |
| Unique constraint | `uq_{table}_{column}` | `uq_merchants_mid` |
| Foreign key | `fk_{table}_{ref}` | `fk_terminals_merchant_id` |
| Check constraint | `ck_{table}_{rule}` | `ck_transactions_amount_positive` |

### 2. Mandatory Columns (SQL)

Every table MUST include:

```sql
id BIGSERIAL PRIMARY KEY,              -- or BIGINT AUTO_INCREMENT for MySQL
-- ... domain columns ...
created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
```

### 3. Data Security

| Data | Storage Rule |
|------|-------------|
| Passwords | Hashed (bcrypt/argon2), NEVER plaintext |
| PAN / Card numbers | Masked (first 6 + last 4) or tokenized |
| PIN blocks, CVV | NEVER persist |
| Documents (SSN, tax ID) | Encrypt at rest or mask |
| API keys | Hashed, NEVER plaintext |

### 4. Query Best Practices

- NEVER use `SELECT *` in production queries — list columns explicitly
- ALWAYS use parameterized queries (prevent SQL injection)
- ALWAYS paginate list queries (never return unbounded results)
- Prefer `EXISTS` over `COUNT` for existence checks

### 5. Connection Pool Sizing

| Environment | min-size | max-size | Notes |
|-------------|----------|----------|-------|
| Dev/Test | 2 | 5 | Minimal, fast startup |
| Staging | 5 | 15 | Mirrors production ratio |
| Production | 5 | 20 | Tuned to workload |

### 6. Cache Key Naming (when cache enabled)

```
{service}:{entity}:{id}
{service}:{entity}:{id}:{field}
{service}:{query}:{hash}
```

Always include TTL. Never cache sensitive data (PAN, PIN, credentials).

---

## Anti-Patterns

- `FLOAT` or `DECIMAL` for monetary values — use `BIGINT` (cents)
- `TEXT` without reason for bounded fields — use `VARCHAR(N)`
- Composite primary keys — use surrogate `BIGSERIAL` + UNIQUE constraint
- Cascading deletes in production — use soft delete (`status = 'DELETED'`)
- `SELECT *` in any production query
- Storing full sensitive data (PAN, PIN) unmasked
- Migrations that modify already-applied scripts
- Missing indexes on foreign key columns
- Cache without TTL — causes unbounded memory growth
- Storing sensitive data in cache
