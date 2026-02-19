# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# PostgreSQL — Types and Conventions

> PostgreSQL-specific type mappings, naming conventions, and extensions.

## Version Matrix

| Version | Release  | Key Features                                                         |
| ------- | -------- | -------------------------------------------------------------------- |
| 14      | Sep 2021 | Multirange types, `SEARCH` REINDEX concurrency, JSON subscripting    |
| 15      | Oct 2022 | `MERGE` statement, `SECURITY INVOKER` views, JSON logging, `UNIQUE NULLS NOT DISTINCT` |
| 16      | Sep 2023 | Logical replication from standbys, `pg_stat_io`, `ANY_VALUE()`, bulk loading improvements |
| 17      | Sep 2024 | Incremental backup, `RETURNING` for `MERGE`, `MAINTAIN` privilege, JSON table functions |

**Recommendation:** Use PostgreSQL 16+ for new projects. Version 15+ is minimum for `MERGE` support.

## Type Mapping

| Use Case             | PostgreSQL Type           | Size           | Notes                                        |
| -------------------- | ------------------------- | -------------- | -------------------------------------------- |
| Primary key          | `BIGSERIAL`               | 8 bytes        | Auto-increment 64-bit integer                |
| UUID primary key     | `UUID`                    | 16 bytes       | Use `gen_random_uuid()` (PG 13+)            |
| Monetary values      | `BIGINT`                  | 8 bytes        | Store in cents — avoids floating-point issues |
| Precise decimals     | `NUMERIC(p,s)`            | Variable       | Exact arithmetic, slower than BIGINT          |
| Timestamps           | `TIMESTAMPTZ`             | 8 bytes        | **Always** use timezone-aware variant         |
| Short strings        | `VARCHAR(N)`              | Variable       | Use when max length is known and meaningful   |
| Long/unbounded text  | `TEXT`                    | Variable       | No performance difference vs VARCHAR in PG    |
| Boolean flags        | `BOOLEAN NOT NULL DEFAULT FALSE` | 1 byte  | Never allow NULL on booleans                 |
| JSON documents       | `JSONB`                   | Variable       | Binary format, indexable, preferred over JSON |
| Binary data          | `BYTEA`                   | Variable       | Raw bytes (files, encrypted data, ISO msgs)  |
| Enums in DB          | `VARCHAR(20-50)`          | Variable       | Readable, extensible — avoid `CREATE TYPE`   |
| IP addresses         | `INET`                    | 7 or 19 bytes  | Native IP type with operators                |
| Arrays               | `TYPE[]`                  | Variable       | Use sparingly — prefer junction tables       |

### Types to Avoid

| Type                | Problem                             | Use Instead            |
| ------------------- | ----------------------------------- | ---------------------- |
| `FLOAT` / `REAL`    | Rounding errors for money           | `BIGINT` or `NUMERIC`  |
| `SERIAL` (32-bit)   | Overflow at ~2 billion rows         | `BIGSERIAL`            |
| `TIMESTAMP`         | No timezone — ambiguous             | `TIMESTAMPTZ`          |
| `JSON`              | Stored as text, no indexing         | `JSONB`                |
| `CHAR(N)`           | Right-pads with spaces              | `VARCHAR(N)` or `TEXT` |
| `MONEY`             | Locale-dependent, limited precision | `BIGINT` (cents)       |
| `CREATE TYPE enum`  | Hard to modify, migration headaches | `VARCHAR` + CHECK      |

## Naming Conventions

| Element          | Convention           | Example                         |
| ---------------- | -------------------- | ------------------------------- |
| Schema           | lowercase            | `{{DB_TYPE}}`                   |
| Table            | snake_case, plural   | `transactions`, `merchants`     |
| Column           | snake_case           | `response_code`, `created_at`   |
| Primary key      | `id`                 | `id BIGSERIAL PRIMARY KEY`      |
| Foreign key col  | `{table_singular}_id`| `merchant_id`                   |
| Index            | `idx_{table}_{cols}` | `idx_transactions_stan_date`    |
| Unique constraint| `uq_{table}_{col}`   | `uq_merchants_mid`             |
| Foreign key      | `fk_{table}_{ref}`   | `fk_terminals_merchant_id`     |
| Check constraint | `ck_{table}_{rule}`  | `ck_transactions_amount_positive` |
| Sequence         | `{table}_id_seq`     | Auto-created with `BIGSERIAL`   |

### Mandatory Columns (All Tables)

```sql
CREATE TABLE {{DB_TYPE}}.example (
    id         BIGSERIAL PRIMARY KEY,
    -- ... domain columns ...
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Schema Separation

```sql
CREATE SCHEMA IF NOT EXISTS {{DB_TYPE}};
SET search_path TO {{DB_TYPE}}, public;
```

All application tables live in a dedicated schema, never in `public`.

## Useful Extensions

| Extension    | Purpose                                   | Install                             |
| ------------ | ----------------------------------------- | ----------------------------------- |
| `pgcrypto`   | Cryptographic functions, `gen_random_uuid()` | `CREATE EXTENSION IF NOT EXISTS pgcrypto;` |
| `uuid-ossp`  | UUID generation (v1, v4)                  | `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";` |
| `pg_trgm`    | Trigram-based fuzzy text search           | `CREATE EXTENSION IF NOT EXISTS pg_trgm;` |
| `btree_gist` | GiST index on scalar types (exclusion)    | `CREATE EXTENSION IF NOT EXISTS btree_gist;` |
| `pg_stat_statements` | Query performance tracking         | `CREATE EXTENSION IF NOT EXISTS pg_stat_statements;` |

> **Note:** `gen_random_uuid()` is built-in since PostgreSQL 13 — no extension needed.

## Declarative Partitioning (11+)

| Partition Type | Use Case                            | Example                           |
| -------------- | ----------------------------------- | --------------------------------- |
| RANGE          | Time-series data, date-based        | Monthly transaction partitions    |
| LIST           | Categorical data, region/status     | Partition by `status`             |
| HASH           | Even distribution, no natural range | Partition by `merchant_id`        |

```sql
-- Range partitioning by date
CREATE TABLE {{DB_TYPE}}.transactions (
    id          BIGSERIAL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    mti         VARCHAR(4) NOT NULL,
    amount      BIGINT NOT NULL
) PARTITION BY RANGE (created_at);

CREATE TABLE {{DB_TYPE}}.transactions_2026_01
    PARTITION OF {{DB_TYPE}}.transactions
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE {{DB_TYPE}}.transactions_2026_02
    PARTITION OF {{DB_TYPE}}.transactions
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
```

**Rules:**
- Primary key MUST include the partition key
- Indexes are created per partition (automatic in PG 11+)
- Use `pg_partman` extension for automated partition management

## Framework Integration

| Framework               | Dependency                                  | Configuration Key                          |
| ----------------------- | ------------------------------------------- | ------------------------------------------ |
| Quarkus                 | `quarkus-jdbc-postgresql`                   | `quarkus.datasource.db-kind=postgresql`    |
| Spring Boot             | `spring-boot-starter-data-jpa` + `postgresql` | `spring.datasource.url=jdbc:postgresql://` |
| Micronaut               | `micronaut-data-jdbc` + `postgresql`        | `datasources.default.url=jdbc:postgresql://` |
| Django                  | `psycopg2-binary`                           | `DATABASES.default.ENGINE=django.db.backends.postgresql` |
| SQLAlchemy              | `psycopg2-binary`                           | `create_engine("postgresql://...")`        |
| Entity Framework Core   | `Npgsql.EntityFrameworkCore.PostgreSQL`      | `UseNpgsql("...")`                         |
| GORM (Go)               | `gorm.io/driver/postgres`                   | `gorm.Open(postgres.Open("..."))`          |

## Anti-Patterns (PostgreSQL-Specific)

| Anti-Pattern                        | Problem                                | Correct Approach                      |
| ----------------------------------- | -------------------------------------- | ------------------------------------- |
| Tables in `public` schema           | Namespace pollution, security risk     | Use dedicated schema                  |
| `TIMESTAMP` without timezone        | Ambiguous time interpretation          | Always use `TIMESTAMPTZ`              |
| `CREATE TYPE` for enums             | Painful to alter, migration issues     | `VARCHAR` + `CHECK` constraint        |
| Not using `JSONB` over `JSON`       | No indexing, stored as text            | Use `JSONB` for all JSON storage      |
| `SERIAL` instead of `BIGSERIAL`     | 32-bit overflow on large tables        | Default to `BIGSERIAL`                |
| Missing `IF NOT EXISTS` in DDL      | Migration fails on re-run              | Always use `IF NOT EXISTS`            |
