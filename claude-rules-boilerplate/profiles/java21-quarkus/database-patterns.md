# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Quarkus — Database Patterns

> Extends: `core/11-database-principles.md`

## Technology Stack

- **PostgreSQL 16+** as production database
- **Hibernate ORM with Panache** for data access
- **Flyway** for versioned migrations
- **H2 MODE=PostgreSQL** for test profile

## PostgreSQL-Specific Data Types

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
| Raw binary data | `BYTEA` | Complete ISO message |
| Parsed fields | `JSONB` | Flexible for different versions |
| Documents (CNPJ) | `VARCHAR(14)` | No formatting |
| Boolean flags | `BOOLEAN NOT NULL DEFAULT FALSE` | Explicit |

## Mandatory Columns in ALL Tables

```sql
id BIGSERIAL PRIMARY KEY,
-- ... specific columns ...
created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
```

## Flyway Migrations

### Naming

```
V{N}__{description}.sql
```

Two underscores between version and description. Location: `src/main/resources/db/migration/`

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

### Migration Rules

- Always wrapped in `BEGIN; ... COMMIT;`
- Use `IF NOT EXISTS` for idempotence
- NEVER modify a migration already applied in production — create a new migration
- One migration per logical change
- Comment at top: Story, author, description

## Panache Repository Pattern

```java
@ApplicationScoped
public class MerchantRepository implements PanacheRepository<MerchantEntity> {

    public Optional<MerchantEntity> findByMid(String mid) {
        return find("mid", mid).firstResultOptional();
    }

    public List<MerchantEntity> listPaged(int page, int limit) {
        return findAll(Sort.by("createdAt").descending())
            .page(Page.of(page, limit))
            .list();
    }

    public long countAll() {
        return count();
    }
}
```

## Entity Mapper Pattern

Location: `adapter.outbound.persistence.mapper`

```java
public final class TransactionEntityMapper {

    private TransactionEntityMapper() {}

    public static TransactionEntity toEntity(Transaction transaction) {
        var entity = new TransactionEntity();
        entity.setMti(transaction.mti());
        entity.setStan(transaction.stan());
        entity.setResponseCode(transaction.responseCode());
        entity.setAmountCents(transaction.amountCents());
        entity.setMerchantId(transaction.merchantId());
        entity.setTerminalId(transaction.terminalId());
        return entity;
    }

    public static Transaction toDomain(TransactionEntity entity) {
        return new Transaction(
            entity.getId(),
            entity.getMti(),
            entity.getStan(),
            entity.getResponseCode(),
            entity.getAmountCents(),
            entity.getMerchantId(),
            entity.getTerminalId(),
            entity.getCreatedAt()
        );
    }
}
```

**Rules:**
- `final class` + `private` constructor + `static` methods
- NOT a CDI bean (`@ApplicationScoped`) — not needed
- WITHOUT `@RegisterForReflection` — not serialized by Jackson
- NEVER expose JPA Entities outside the persistence adapter

## Connection Pool Configuration

```properties
quarkus.datasource.jdbc.min-size=5
quarkus.datasource.jdbc.max-size=20
quarkus.datasource.jdbc.acquisition-timeout=5S
```

## H2 MODE=PostgreSQL for Tests

```properties
# application-test.properties
quarkus.datasource.db-kind=h2
quarkus.datasource.jdbc.url=jdbc:h2:mem:testdb;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH
quarkus.datasource.username=sa
quarkus.datasource.password=

quarkus.hibernate-orm.database.generation=drop-and-create
quarkus.hibernate-orm.database.default-schema=simulator
quarkus.flyway.enabled=false
```

## Index Rules

```sql
-- Transactions: lookup by STAN + date (reversal matching)
CREATE INDEX idx_transactions_stan_date ON simulator.transactions (stan, local_date_time, terminal_id);

-- Transactions: filter by merchant
CREATE INDEX idx_transactions_merchant ON simulator.transactions (merchant_id, created_at DESC);

-- Merchants: lookup by MID (unique)
CREATE UNIQUE INDEX uq_merchants_mid ON simulator.merchants (mid);

-- Terminals: lookup by TID (unique)
CREATE UNIQUE INDEX uq_terminals_tid ON simulator.terminals (tid);
```

**Rules:**
1. ALWAYS create indexes for columns used in WHERE, JOIN, ORDER BY
2. Composite indexes: order matters — most selective column first
3. Partial indexes when query filters by status: `WHERE status = 'ACTIVE'`
4. NEVER index low-cardinality columns alone (e.g., boolean)
5. Validate with `EXPLAIN ANALYZE` on critical queries

## Anti-Patterns

- `FLOAT` or `DECIMAL` for monetary values — use `BIGINT` (cents)
- `TEXT` without limit for known fields — use `VARCHAR(N)`
- Composite primary keys — use BIGSERIAL + UNIQUE constraint
- Cascading deletes in production — use soft delete (status = 'DELETED')
- Queries with `SELECT *` — list columns explicitly
- Store full PAN — ALWAYS mask before persisting
- Use `quarkus.hibernate-orm.database.generation=update` in production — use Flyway
