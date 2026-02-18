# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Spring Boot — Database Patterns

> Extends: `core/11-database-principles.md`

## Technology Stack

- **PostgreSQL 16+** as production database
- **Spring Data JPA** (`JpaRepository`) for data access
- **Flyway** for versioned migrations
- **HikariCP** for connection pooling (Spring Boot default)
- **H2 MODE=PostgreSQL** for test profile

## PostgreSQL-Specific Data Types

| Data | PostgreSQL Type | Justification |
|------|-----------------|---------------|
| ID | `BIGSERIAL PRIMARY KEY` | 64-bit auto-increment |
| Monetary values | `BIGINT` (cents) | Avoids floating-point issues |
| Timestamps | `TIMESTAMP WITH TIME ZONE` | Always with timezone |
| Masked identifier | `VARCHAR(19)` | First few + last few chars + asterisks |
| Operation type | `VARCHAR(20)` | Categorizes the operation |
| Status code | `VARCHAR(10)` | Operation result status |
| Status/Enums | `VARCHAR(20)` | Readable, extensible |
| Raw binary data | `BYTEA` | Complete raw payload |
| Parsed fields | `JSONB` | Flexible structured data |
| Tax ID | `VARCHAR(14)` | No formatting |
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

## Spring Data JPA Repository Pattern

```java
public interface MerchantRepository extends JpaRepository<MerchantEntity, Long> {

    Optional<MerchantEntity> findByMid(String mid);

    boolean existsByMid(String mid);

    Page<MerchantEntity> findAllByStatus(MerchantStatus status, Pageable pageable);

    @Query("SELECT m FROM MerchantEntity m WHERE m.mid = :mid AND m.status = 'ACTIVE'")
    Optional<MerchantEntity> findActiveMerchantByMid(@Param("mid") String mid);

    @Query(value = "SELECT * FROM simulator.merchants WHERE document = :document", nativeQuery = true)
    Optional<MerchantEntity> findByDocumentNative(@Param("document") String document);
}
```

### Repository Rules

- Extend `JpaRepository<Entity, Long>` (replaces Panache `PanacheRepository`)
- Use Spring Data derived query methods when possible: `findByMid`, `existsByTid`
- Use `@Query` with JPQL for complex queries
- Use `@Query(nativeQuery = true)` only when PostgreSQL-specific features are needed
- Return `Optional<T>` for single-entity queries — NEVER return `null`
- Use `Page<T>` and `Pageable` for paginated results

## JPA Entity Pattern

```java
@Entity
@Table(name = "merchants", schema = "simulator")
@EntityListeners(AuditingEntityListener.class)
public class MerchantEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "mid", nullable = false, length = 15, unique = true)
    private String mid;

    @Column(name = "legal_name", nullable = false, length = 100)
    private String legalName;

    @Column(name = "document", nullable = false, length = 14)
    private String document;

    @Column(name = "mcc", nullable = false, length = 4)
    private String mcc;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private MerchantStatus status;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    // Getters and setters (no Lombok)
}
```

### JPA Auditing Setup

```java
@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig {
}
```

### Entity Rules

- `@EntityListeners(AuditingEntityListener.class)` on all entities for automatic timestamp management
- `@CreatedDate` for `created_at`, `@LastModifiedDate` for `updated_at`
- `@EnableJpaAuditing` in a `@Configuration` class
- `@GeneratedValue(strategy = GenerationType.IDENTITY)` for PostgreSQL BIGSERIAL
- `@Enumerated(EnumType.STRING)` for enum columns — NEVER `EnumType.ORDINAL`

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
- NOT a Spring bean (`@Service`/`@Component`) — not needed
- NEVER expose JPA Entities outside the persistence adapter

## Transactional Boundaries

```java
@Service
public class MerchantService {

    private final MerchantRepository repository;

    public MerchantService(MerchantRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public Merchant create(CreateMerchantRequest request) {
        if (repository.existsByMid(request.mid())) {
            throw new MerchantAlreadyExistsException(request.mid());
        }
        var entity = MerchantEntityMapper.toEntity(MerchantDtoMapper.toDomain(request));
        var saved = repository.save(entity);
        return MerchantEntityMapper.toDomain(saved);
    }

    @Transactional(readOnly = true)
    public Optional<Merchant> findByMid(String mid) {
        return repository.findByMid(mid).map(MerchantEntityMapper::toDomain);
    }
}
```

**Rules:**
- `@Transactional` on **service methods**, not on repository or controller
- `@Transactional(readOnly = true)` for read-only operations (performance hint)
- NEVER use `@Transactional` on private methods (Spring proxy limitation)

## Connection Pool Configuration (HikariCP)

```yaml
# application.yml
spring:
  datasource:
    url: ${DB_URL:jdbc:postgresql://localhost:5432/myapp}
    username: ${DB_USER:simulator}
    password: ${DB_PASSWORD:simulator}
    driver-class-name: org.postgresql.Driver
    hikari:
      minimum-idle: 5
      maximum-pool-size: 20
      connection-timeout: 5000
      idle-timeout: 300000
      max-lifetime: 600000
      pool-name: SimulatorPool

  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
    hibernate:
      ddl-auto: none
    properties:
      hibernate:
        default_schema: simulator
        format_sql: false
    open-in-view: false

  flyway:
    enabled: true
    schemas: simulator
    locations: classpath:db/migration
```

### Configuration Rules

- `spring.jpa.open-in-view=false` — ALWAYS disable OSIV (anti-pattern)
- `spring.jpa.hibernate.ddl-auto=none` in production — use Flyway
- `spring.datasource.hikari.*` for connection pool tuning

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
    database-platform: org.hibernate.dialect.H2Dialect
    hibernate:
      ddl-auto: create-drop
    properties:
      hibernate:
        default_schema: simulator

  flyway:
    enabled: false
```

### When to Use H2 vs Testcontainers

| Scenario | Database |
|----------|----------|
| Repository unit tests | H2 (default) |
| REST API tests (`@SpringBootTest`) | H2 (default) |
| Flyway migrations validation | Testcontainers (real PostgreSQL) |
| Queries with PostgreSQL-exclusive features | Testcontainers (real PostgreSQL) |
| Performance/volume (EXPLAIN ANALYZE) | Testcontainers (real PostgreSQL) |

## Index Rules

```sql
-- Transactions: lookup by STAN + date (reversal matching)
CREATE INDEX idx_transactions_stan_date ON simulator.transactions (stan, local_date_time, terminal_id);

-- Transactions: filter by merchant
CREATE INDEX idx_transactions_merchant ON simulator.transactions (merchant_id, created_at DESC);

-- Merchants: lookup by client_id (unique)
CREATE UNIQUE INDEX uq_merchants_mid ON simulator.merchants (mid);

-- Terminals: lookup by device_id (unique)
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
- Store full sensitive identifiers — ALWAYS mask before persisting
- `spring.jpa.hibernate.ddl-auto=update` in production — use Flyway
- `spring.jpa.open-in-view=true` — causes lazy loading issues and N+1 queries
- `@Transactional` on controller methods — keep transactional boundaries in service layer
- Lombok `@Data` on entities — write getters/setters explicitly
