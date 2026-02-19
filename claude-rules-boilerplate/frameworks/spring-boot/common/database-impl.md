# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot — Database Patterns

> Extends the base database design rules. All naming conventions, Flyway practices, index strategies, and data security requirements apply.

## PostgreSQL Data Types

| Data | PostgreSQL Type | JPA Type | Justification |
|------|-----------------|----------|---------------|
| ID | `BIGSERIAL PRIMARY KEY` | `Long` with `@GeneratedValue(IDENTITY)` | 64-bit auto-increment |
| Monetary values | `BIGINT` (cents) | `Long` | Avoids floating-point issues |
| Timestamps | `TIMESTAMP WITH TIME ZONE` | `OffsetDateTime` | Always with timezone |
| Masked PAN | `VARCHAR(19)` | `String` | First 6 + last 4 + asterisks |
| MTI | `VARCHAR(4)` | `String` | Supports 1987/1993 (4 digits) and 2021 (3 digits) |
| Response Code | `VARCHAR(2)` | `String` | ISO 8583 standard |
| STAN | `VARCHAR(6)` | `String` | Systems Trace Audit Number |
| Status/Enums | `VARCHAR(20)` | `@Enumerated(STRING)` | Readable, extensible |
| Raw ISO data | `BYTEA` | `byte[]` | Complete ISO message |
| Parsed fields | `JSONB` | `String` or `Map` | Flexible for different ISO versions |
| Documents (CNPJ) | `VARCHAR(14)` | `String` | No formatting |
| Boolean flags | `BOOLEAN NOT NULL DEFAULT FALSE` | `boolean` | Explicit |

## Mandatory Columns in ALL Tables

```sql
id BIGSERIAL PRIMARY KEY,
-- ... specific columns ...
created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
```

JPA mapping with Spring Data JPA Auditing:

```java
@Entity
@Table(name = "transactions", schema = "simulator")
@EntityListeners(AuditingEntityListener.class)
public class TransactionEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "mti", nullable = false, length = 4)
    private String mti;

    @Column(name = "stan", nullable = false, length = 6)
    private String stan;

    @Column(name = "masked_pan", length = 19)
    private String maskedPan;

    @Column(name = "amount_cents", nullable = false)
    private Long amountCents;

    @Column(name = "response_code", nullable = false, length = 2)
    private String responseCode;

    @Column(name = "merchant_id")
    private Long merchantId;

    @Column(name = "terminal_id", length = 8)
    private String terminalId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private TransactionStatus status;

    @Column(name = "iso_version", length = 4)
    private String isoVersion;

    @Column(name = "raw_message")
    private byte[] rawMessage;

    @Column(name = "local_date_time", length = 12)
    private String localDateTime;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected TransactionEntity() {}

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getMti() { return mti; }
    public void setMti(String mti) { this.mti = mti; }
    public String getStan() { return stan; }
    public void setStan(String stan) { this.stan = stan; }
    public String getMaskedPan() { return maskedPan; }
    public void setMaskedPan(String maskedPan) { this.maskedPan = maskedPan; }
    public Long getAmountCents() { return amountCents; }
    public void setAmountCents(Long amountCents) { this.amountCents = amountCents; }
    public String getResponseCode() { return responseCode; }
    public void setResponseCode(String responseCode) { this.responseCode = responseCode; }
    public Long getMerchantId() { return merchantId; }
    public void setMerchantId(Long merchantId) { this.merchantId = merchantId; }
    public String getTerminalId() { return terminalId; }
    public void setTerminalId(String terminalId) { this.terminalId = terminalId; }
    public TransactionStatus getStatus() { return status; }
    public void setStatus(TransactionStatus status) { this.status = status; }
    public String getIsoVersion() { return isoVersion; }
    public void setIsoVersion(String isoVersion) { this.isoVersion = isoVersion; }
    public byte[] getRawMessage() { return rawMessage; }
    public void setRawMessage(byte[] rawMessage) { this.rawMessage = rawMessage; }
    public String getLocalDateTime() { return localDateTime; }
    public void setLocalDateTime(String localDateTime) { this.localDateTime = localDateTime; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
}
```

### Enable JPA Auditing

```java
@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig {
}
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
-- V1__create_merchants_table.sql
-- Story: STORY-009
-- Description: Creates the merchants table

BEGIN;

CREATE SCHEMA IF NOT EXISTS simulator;

CREATE TABLE IF NOT EXISTS simulator.merchants (
    id BIGSERIAL PRIMARY KEY,
    mid VARCHAR(15) NOT NULL,
    legal_name VARCHAR(100) NOT NULL,
    trade_name VARCHAR(100),
    document VARCHAR(14) NOT NULL,
    mcc VARCHAR(4) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    timeout_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_merchants_mid
    ON simulator.merchants (mid);

COMMIT;
```

```sql
-- V2__create_terminals_table.sql
-- Story: STORY-009
-- Description: Creates the terminals table

BEGIN;

CREATE TABLE IF NOT EXISTS simulator.terminals (
    id BIGSERIAL PRIMARY KEY,
    tid VARCHAR(8) NOT NULL,
    merchant_id BIGINT NOT NULL,
    model VARCHAR(50),
    serial_number VARCHAR(50),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    timeout_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    timeout_seconds INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_terminals_merchant_id FOREIGN KEY (merchant_id)
        REFERENCES simulator.merchants(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_terminals_tid
    ON simulator.terminals (tid);

CREATE INDEX IF NOT EXISTS idx_terminals_merchant_id
    ON simulator.terminals (merchant_id);

COMMIT;
```

```sql
-- V3__create_transactions_table.sql
-- Story: STORY-001
-- Description: Creates the transactions table

BEGIN;

CREATE TABLE IF NOT EXISTS simulator.transactions (
    id BIGSERIAL PRIMARY KEY,
    mti VARCHAR(4) NOT NULL,
    stan VARCHAR(6) NOT NULL,
    masked_pan VARCHAR(19),
    amount_cents BIGINT NOT NULL,
    response_code VARCHAR(2) NOT NULL,
    merchant_id BIGINT,
    terminal_id VARCHAR(8),
    status VARCHAR(20) NOT NULL,
    iso_version VARCHAR(4),
    raw_message BYTEA,
    local_date_time VARCHAR(12),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_transactions_amount_positive CHECK (amount_cents >= 0)
);

CREATE INDEX IF NOT EXISTS idx_transactions_stan_date
    ON simulator.transactions (stan, local_date_time, terminal_id);

CREATE INDEX IF NOT EXISTS idx_transactions_merchant
    ON simulator.transactions (merchant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_rc
    ON simulator.transactions (response_code, created_at DESC);

COMMIT;
```

### Flyway Configuration (application.yml)

```yaml
spring:
  flyway:
    enabled: true
    schemas:
      - simulator
    locations:
      - classpath:db/migration
    baseline-on-migrate: false
    validate-on-migrate: true
```

## Spring Data JPA Repository

```java
public interface TransactionJpaRepository extends JpaRepository<TransactionEntity, Long> {

    Optional<TransactionEntity> findByStanAndLocalDateTime(String stan, String localDateTime);

    Page<TransactionEntity> findByMerchantId(Long merchantId, Pageable pageable);

    Page<TransactionEntity> findByResponseCode(String responseCode, Pageable pageable);

    @Query("""
        SELECT t FROM TransactionEntity t
        WHERE t.merchantId = :merchantId
          AND t.createdAt >= :since
        ORDER BY t.createdAt DESC
        """)
    List<TransactionEntity> findRecentByMerchant(@Param("merchantId") Long merchantId, @Param("since") OffsetDateTime since);

    long countByMerchantIdAndResponseCode(Long merchantId, String responseCode);

    boolean existsByStanAndLocalDateTime(String stan, String localDateTime);
}

public interface MerchantJpaRepository extends JpaRepository<MerchantEntity, Long> {

    Optional<MerchantEntity> findByMid(String mid);

    boolean existsByMid(String mid);

    List<MerchantEntity> findByStatusOrderByCreatedAtDesc(MerchantStatus status);

    long countByStatus(MerchantStatus status);
}

public interface TerminalJpaRepository extends JpaRepository<TerminalEntity, Long> {

    Optional<TerminalEntity> findByTid(String tid);

    boolean existsByTid(String tid);

    List<TerminalEntity> findByMerchantIdOrderByCreatedAtDesc(Long merchantId);

    Page<TerminalEntity> findByMerchantId(Long merchantId, Pageable pageable);
}
```

## Entity Mapper Pattern

Static utility classes convert between domain models and JPA entities:

```java
public final class TransactionEntityMapper {

    private TransactionEntityMapper() {}

    public static TransactionEntity toEntity(Transaction transaction) {
        var entity = new TransactionEntity();
        entity.setMti(transaction.mti());
        entity.setStan(transaction.stan());
        entity.setMaskedPan(transaction.maskedPan());
        entity.setAmountCents(transaction.amountCents());
        entity.setResponseCode(transaction.responseCode());
        entity.setMerchantId(transaction.merchantId());
        entity.setTerminalId(transaction.terminalId());
        entity.setStatus(transaction.status());
        entity.setIsoVersion(transaction.isoVersion());
        entity.setRawMessage(transaction.rawMessage());
        entity.setLocalDateTime(transaction.localDateTime());
        return entity;
    }

    public static Transaction toDomain(TransactionEntity entity) {
        return new Transaction(
            entity.getId(),
            entity.getMti(),
            entity.getStan(),
            entity.getMaskedPan(),
            entity.getAmountCents(),
            entity.getResponseCode(),
            entity.getMerchantId(),
            entity.getTerminalId(),
            entity.getStatus(),
            entity.getIsoVersion(),
            entity.getRawMessage(),
            entity.getLocalDateTime(),
            entity.getCreatedAt(),
            entity.getUpdatedAt()
        );
    }
}
```

## HikariCP Connection Pool

Spring Boot uses HikariCP by default. Configuration:

```yaml
spring:
  datasource:
    hikari:
      minimum-idle: 5
      maximum-pool-size: 20
      connection-timeout: 5000
      idle-timeout: 300000
      max-lifetime: 1800000
      leak-detection-threshold: 60000
      pool-name: simulator-pool
```

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| minimum-idle | 2 | 5 | 5 |
| maximum-pool-size | 5 | 15 | 20 |
| connection-timeout | 10000 | 5000 | 5000 |
| idle-timeout | 600000 | 300000 | 300000 |
| leak-detection-threshold | 30000 | 60000 | 60000 |

## H2 MODE=PostgreSQL for Tests

```yaml
# application-test.yml
spring:
  datasource:
    url: jdbc:h2:mem:testdb;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH
    username: sa
    password:
    driver-class-name: org.h2.Driver

  jpa:
    hibernate:
      ddl-auto: create-drop
    properties:
      hibernate:
        default_schema: simulator

  flyway:
    enabled: false
```

### H2 PostgreSQL Mode Limitations

| Supported | Not Supported |
|-----------|---------------|
| Basic SQL syntax | `JSONB` operators (`->`, `->>`) |
| `VARCHAR`, `BIGINT`, `BOOLEAN` | PostgreSQL arrays |
| `TIMESTAMP WITH TIME ZONE` | `BYTEA` (partial) |
| `SERIAL` / `BIGSERIAL` | Full-text search |
| Standard indexes | Partial indexes |
| Foreign keys | Materialized views |

For features not supported by H2, use Testcontainers with real PostgreSQL.

## Index Rules

1. **ALWAYS** create indexes for columns used in WHERE, JOIN, ORDER BY
2. **Composite indexes:** most selective column first
3. **Partial indexes** when filtering by status: `WHERE status = 'ACTIVE'`
4. **NEVER** index low-cardinality columns alone (e.g., boolean)
5. Validate with `EXPLAIN ANALYZE` on critical queries (use Testcontainers)

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

-- Terminals: filter by merchant
CREATE INDEX idx_terminals_merchant_id ON simulator.terminals (merchant_id);
```

## Data Security

| Data | Persist? | How |
|------|----------|-----|
| PAN | Masked only | `411111****1111` |
| PIN Block | NEVER | -- |
| CVV/CVC | NEVER | -- |
| Track Data | NEVER | -- |
| Raw ISO message | Yes | `BYTEA` (for audit) |
| Amount | Yes | `BIGINT` (cents) |
| STAN | Yes | `VARCHAR(6)` |
| Response Code | Yes | `VARCHAR(2)` |

## Anti-Patterns (FORBIDDEN)

```sql
-- FORBIDDEN: FLOAT for monetary values
amount FLOAT  -- Use BIGINT (cents)

-- FORBIDDEN: TEXT without limit
description TEXT  -- Use VARCHAR(N) for known fields

-- FORBIDDEN: Composite primary keys
PRIMARY KEY (merchant_id, terminal_id)  -- Use BIGSERIAL + UNIQUE constraint

-- FORBIDDEN: Cascading deletes in production
ON DELETE CASCADE  -- Use soft delete (status = 'DELETED')

-- FORBIDDEN: SELECT *
SELECT * FROM simulator.transactions  -- List columns explicitly

-- FORBIDDEN: Store full PAN
pan VARCHAR(19)  -- Store masked only: masked_pan VARCHAR(19)

-- FORBIDDEN: Altering applied migrations
-- V1__create_merchants.sql (already applied) -- Create V4__alter_merchants.sql instead

-- FORBIDDEN: Missing BEGIN/COMMIT in migrations
CREATE TABLE ...;  -- Wrap in BEGIN; ... COMMIT;

-- FORBIDDEN: spring.jpa.hibernate.ddl-auto=update in production
-- Use Flyway migrations exclusively
```
