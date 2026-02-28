# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot — Spring Data JPA Patterns

> Extends: `core/11-database-principles.md`
> All naming conventions, hexagonal architecture, and Clean Code rules apply.

## Repository Interface

Spring Data JPA uses **interface-based** repositories. Extend `JpaRepository<Entity, ID>` for full CRUD + pagination:

```java
public interface MerchantJpaRepository extends JpaRepository<MerchantEntity, Long> {

    Optional<MerchantEntity> findByMid(String mid);

    List<MerchantEntity> findByStatusOrderByCreatedAtDesc(MerchantStatus status);

    boolean existsByMid(String mid);

    long countByStatus(MerchantStatus status);
}
```

### Repository Hierarchy

| Interface | Provides |
|-----------|----------|
| `Repository<T, ID>` | Marker interface |
| `CrudRepository<T, ID>` | Basic CRUD (save, findById, delete, etc.) |
| `ListCrudRepository<T, ID>` | CRUD returning `List` instead of `Iterable` |
| `PagingAndSortingRepository<T, ID>` | Pagination and sorting |
| `JpaRepository<T, ID>` | All above + flush, saveAll, batch operations |

**Standard:** Always use `JpaRepository` unless there is a specific reason to restrict.

## Derived Query Methods

Spring Data derives queries from method names:

```java
public interface TransactionJpaRepository extends JpaRepository<TransactionEntity, Long> {

    // Simple field match
    Optional<TransactionEntity> findByStanAndLocalDateTime(String stan, String localDateTime);

    // Multiple conditions
    List<TransactionEntity> findByMerchantIdAndResponseCodeOrderByCreatedAtDesc(Long merchantId, String responseCode);

    // IN clause
    List<TransactionEntity> findByResponseCodeIn(Collection<String> responseCodes);

    // Date range
    List<TransactionEntity> findByCreatedAtBetween(OffsetDateTime from, OffsetDateTime to);

    // LIKE
    List<TransactionEntity> findByMaskedPanStartingWith(String panPrefix);

    // Count
    long countByMerchantIdAndResponseCode(Long merchantId, String responseCode);

    // Exists
    boolean existsByStanAndLocalDateTime(String stan, String localDateTime);

    // Delete (returns count)
    long deleteByStatusAndCreatedAtBefore(String status, OffsetDateTime before);
}
```

### Naming Convention for Derived Queries

| Keyword | Example | SQL Equivalent |
|---------|---------|---------------|
| `findBy` | `findByMid(String mid)` | `WHERE mid = ?` |
| `And` | `findByMidAndStatus(...)` | `WHERE mid = ? AND status = ?` |
| `Or` | `findByMidOrTid(...)` | `WHERE mid = ? OR tid = ?` |
| `Between` | `findByCreatedAtBetween(...)` | `WHERE created_at BETWEEN ? AND ?` |
| `LessThan` | `findByAmountLessThan(...)` | `WHERE amount < ?` |
| `GreaterThanEqual` | `findByAmountGreaterThanEqual(...)` | `WHERE amount >= ?` |
| `IsNull` | `findByDeletedAtIsNull()` | `WHERE deleted_at IS NULL` |
| `In` | `findByStatusIn(Collection)` | `WHERE status IN (?)` |
| `OrderBy...Desc` | `findByStatusOrderByCreatedAtDesc(...)` | `ORDER BY created_at DESC` |
| `Top` / `First` | `findTop10ByStatus(...)` | `LIMIT 10` |

## @Query for Custom Queries

Use `@Query` for complex queries that cannot be expressed via method names:

```java
public interface TransactionJpaRepository extends JpaRepository<TransactionEntity, Long> {

    // JPQL query
    @Query("SELECT t FROM TransactionEntity t WHERE t.merchantId = :merchantId AND t.createdAt >= :since ORDER BY t.createdAt DESC")
    List<TransactionEntity> findRecentByMerchant(@Param("merchantId") Long merchantId, @Param("since") OffsetDateTime since);

    // Native SQL query
    @Query(value = """
        SELECT response_code, COUNT(*) as total, SUM(amount_cents) as total_amount
        FROM simulator.transactions
        WHERE merchant_id = :merchantId
          AND created_at >= :since
        GROUP BY response_code
        ORDER BY total DESC
        """, nativeQuery = true)
    List<Object[]> findTransactionSummary(@Param("merchantId") Long merchantId, @Param("since") OffsetDateTime since);

    // JPQL with pagination
    @Query("SELECT t FROM TransactionEntity t WHERE t.responseCode = :rc")
    Page<TransactionEntity> findByResponseCodePaged(@Param("rc") String responseCode, Pageable pageable);

    // Update query
    @Modifying
    @Query("UPDATE MerchantEntity m SET m.status = :status, m.updatedAt = CURRENT_TIMESTAMP WHERE m.id = :id")
    int updateStatus(@Param("id") Long id, @Param("status") MerchantStatus status);
}
```

## Optional Returns

Single-entity lookups MUST return `Optional<T>`. NEVER return `null`.

```java
public interface MerchantJpaRepository extends JpaRepository<MerchantEntity, Long> {

    // CORRECT — Optional return
    Optional<MerchantEntity> findByMid(String mid);

    // Spring Data's findById already returns Optional
    // Optional<MerchantEntity> findById(Long id);  -- inherited
}

// Usage in service
@Service
public class MerchantService {

    private final MerchantJpaRepository repository;

    public MerchantService(MerchantJpaRepository repository) {
        this.repository = repository;
    }

    public Merchant findByMid(String mid) {
        return repository.findByMid(mid)
            .map(MerchantEntityMapper::toDomain)
            .orElseThrow(() -> new MerchantNotFoundException(mid));
    }
}
```

## Pagination with Page<T> and Pageable

```java
// Repository
public interface TransactionJpaRepository extends JpaRepository<TransactionEntity, Long> {

    Page<TransactionEntity> findByMerchantId(Long merchantId, Pageable pageable);

    Page<TransactionEntity> findByResponseCode(String responseCode, Pageable pageable);
}

// Service
@Service
public class TransactionService {

    private final TransactionJpaRepository repository;

    public TransactionService(TransactionJpaRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public Page<Transaction> listByMerchant(Long merchantId, int page, int size) {
        var pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        return repository.findByMerchantId(merchantId, pageable)
            .map(TransactionEntityMapper::toDomain);
    }
}

// Controller
@RestController
@RequestMapping("/api/v1/transactions")
public class TransactionController {

    private final TransactionService service;

    public TransactionController(TransactionService service) {
        this.service = service;
    }

    @GetMapping
    public PaginatedResponse<TransactionResponse> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int limit,
            @RequestParam(required = false) Long merchantId) {
        var result = service.listByMerchant(merchantId, page, limit);
        var responses = result.getContent().stream()
            .map(TransactionDtoMapper::toResponse)
            .toList();
        return PaginatedResponse.of(responses, page, limit, result.getTotalElements());
    }
}
```

## JPA Entity with Auditing

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

    @Column(name = "trade_name", length = 100)
    private String tradeName;

    @Column(name = "document", nullable = false, length = 14)
    private String document;

    @Column(name = "mcc", nullable = false, length = 4)
    private String mcc;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private MerchantStatus status;

    @Column(name = "timeout_enabled", nullable = false)
    private boolean timeoutEnabled;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    // Default constructor required by JPA
    protected MerchantEntity() {}

    // Getters and setters (or Lombok @Getter/@Setter)
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getMid() { return mid; }
    public void setMid(String mid) { this.mid = mid; }
    public String getLegalName() { return legalName; }
    public void setLegalName(String legalName) { this.legalName = legalName; }
    public String getTradeName() { return tradeName; }
    public void setTradeName(String tradeName) { this.tradeName = tradeName; }
    public String getDocument() { return document; }
    public void setDocument(String document) { this.document = document; }
    public String getMcc() { return mcc; }
    public void setMcc(String mcc) { this.mcc = mcc; }
    public MerchantStatus getStatus() { return status; }
    public void setStatus(MerchantStatus status) { this.status = status; }
    public boolean isTimeoutEnabled() { return timeoutEnabled; }
    public void setTimeoutEnabled(boolean timeoutEnabled) { this.timeoutEnabled = timeoutEnabled; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
}
```

### Enable JPA Auditing

```java
@Configuration
@EnableJpaAuditing
public class JpaConfig {

    @Bean
    public AuditorAware<String> auditorProvider() {
        return () -> Optional.of("system");
    }
}
```

## Entity Mapper Pattern

Mappers convert between domain models and JPA entities. They are **static utility classes**, NOT Spring beans.

```java
public final class MerchantEntityMapper {

    private MerchantEntityMapper() {}

    public static MerchantEntity toEntity(Merchant merchant) {
        var entity = new MerchantEntity();
        entity.setMid(merchant.mid());
        entity.setLegalName(merchant.legalName());
        entity.setTradeName(merchant.tradeName());
        entity.setDocument(merchant.document());
        entity.setMcc(merchant.mcc());
        entity.setStatus(merchant.status());
        entity.setTimeoutEnabled(merchant.timeoutEnabled());
        return entity;
    }

    public static Merchant toDomain(MerchantEntity entity) {
        return new Merchant(
            entity.getId(),
            entity.getMid(),
            entity.getLegalName(),
            entity.getTradeName(),
            entity.getDocument(),
            entity.getMcc(),
            entity.getStatus(),
            entity.isTimeoutEnabled(),
            entity.getCreatedAt(),
            entity.getUpdatedAt()
        );
    }
}
```

**Mapper Rules:**

| Rule | Detail |
|------|--------|
| Structure | `final class` + `private` constructor + `static` methods |
| Spring | NOT a Spring bean — no `@Component` |
| MapStruct | Allowed in Spring Boot (unlike Quarkus native) but optional |
| Null safety | Check nulls on optional fields before mapping |
| Location | `adapter.outbound.persistence.mapper` package |

## @Transactional Boundaries

Transactions belong at the **service layer**, never at the controller or repository.

```java
// CORRECT — @Transactional at service layer
@Service
public class MerchantService {

    private final MerchantJpaRepository repository;

    public MerchantService(MerchantJpaRepository repository) {
        this.repository = repository;
    }

    // Write operation — default @Transactional
    @Transactional
    public Merchant createMerchant(CreateMerchantRequest request) {
        if (repository.existsByMid(request.mid())) {
            throw new MerchantAlreadyExistsException(request.mid());
        }
        var entity = MerchantEntityMapper.toEntity(MerchantDtoMapper.toDomain(request));
        var saved = repository.save(entity);
        return MerchantEntityMapper.toDomain(saved);
    }

    // Read operation — readOnly for optimization
    @Transactional(readOnly = true)
    public Merchant findByMid(String mid) {
        return repository.findByMid(mid)
            .map(MerchantEntityMapper::toDomain)
            .orElseThrow(() -> new MerchantNotFoundException(mid));
    }

    // Read operation — readOnly
    @Transactional(readOnly = true)
    public Page<Merchant> listMerchants(int page, int size) {
        var pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        return repository.findAll(pageable).map(MerchantEntityMapper::toDomain);
    }
}
```

### @Transactional Rules

| Rule | Detail |
|------|--------|
| Write operations | `@Transactional` (default: read-write) |
| Read operations | `@Transactional(readOnly = true)` |
| Controller | NEVER `@Transactional` |
| Repository | NEVER `@Transactional` (inherited from Spring Data) |
| Propagation | Default `REQUIRED` unless justified |
| Rollback | Default on unchecked exceptions; add `rollbackFor` for checked |

## Anti-Patterns (FORBIDDEN)

```java
// FORBIDDEN — Exposing JPA Entity in REST response
@GetMapping("/{id}")
public MerchantEntity getMerchant(@PathVariable Long id) {
    return repository.findById(id).orElseThrow();  // Entity leaks to API
}

// FORBIDDEN — N+1 queries (lazy loading in loop)
@Transactional(readOnly = true)
public List<MerchantResponse> listWithTerminals() {
    var merchants = merchantRepository.findAll();
    return merchants.stream()
        .map(m -> new MerchantResponse(m.getId(), m.getMid(), m.getTerminals().size()))  // N+1!
        .toList();
}
// FIX: Use @EntityGraph or JOIN FETCH query

// FORBIDDEN — @Transactional on controller
@RestController
@Transactional  // Wrong layer!
public class MerchantController { ... }

// FORBIDDEN — Returning null instead of Optional
public MerchantEntity findByMid(String mid) {
    return repository.findByMid(mid).orElse(null);  // Return Optional or throw
}

// FORBIDDEN — SELECT * (implicit in findAll without projection)
// Use @Query with explicit columns for large tables
@Query("SELECT new com.example.MerchantSummary(m.id, m.mid, m.status) FROM MerchantEntity m")
List<MerchantSummary> findAllSummaries();

// FORBIDDEN — save() inside a loop without batching
for (var entity : entities) {
    repository.save(entity);  // N individual INSERTs
}
// FIX: repository.saveAll(entities);  // Batch INSERT
```
