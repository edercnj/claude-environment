---
name: spring-patterns
description: "Spring Boot-specific patterns: Spring DI, @ConfigurationProperties, Spring Data JPA, @RestController, @ControllerAdvice, Spring AOT. Internal reference for agents producing Spring Boot code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Spring Boot Patterns

## Purpose

Provides Spring Boot-specific implementation patterns that supplement the generic layer templates. Agents reference this pack when generating code for a Java 21 + Spring Boot project.

---

## 1. Spring Dependency Injection

### Constructor Injection (Mandatory)

```java
@Service
public class TransactionService {
    private final TransactionRepository repository;
    private final AuthorizationEngine engine;

    // Single constructor = implicit @Autowired (no annotation needed)
    public TransactionService(TransactionRepository repository, AuthorizationEngine engine) {
        this.repository = repository;
        this.engine = engine;
    }
}
```

### Bean Scope Selection

| Scope | Annotation | When |
|-------|-----------|------|
| Singleton (default) | `@Service`, `@Component`, `@Repository` | Stateless services |
| Request | `@RequestScope` | Per-request state (rare) |
| Prototype | `@Scope("prototype")` | New instance per injection |

### FORBIDDEN

- Field injection (`@Autowired` on fields)
- Mutable state in singleton beans
- `@Setter` on entities with business invariants

### Lombok Policy

Lombok is ALLOWED but optional. When used:
- Prefer `@RequiredArgsConstructor` for constructor injection
- NEVER use Lombok on Records
- NEVER use `@Data` (encourages mutability)

```java
// With Lombok
@Service
@RequiredArgsConstructor
public class TransactionService {
    private final TransactionRepository repository;
    private final AuthorizationEngine engine;
}
```

---

## 2. @ConfigurationProperties

Use `@ConfigurationProperties` for groups of 3+ properties with common prefix.

```java
@ConfigurationProperties(prefix = "app.feature")
public record FeatureConfig(
    @DefaultValue("true") boolean enabled,
    @DefaultValue("100") int maxItems,
    @DefaultValue("30") int timeoutSeconds,
    NestedConfig nested
) {
    public record NestedConfig(
        @DefaultValue("5") int retries
    ) {}
}
```

### Enable in Application

```java
@SpringBootApplication
@ConfigurationPropertiesScan
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

### Usage

```java
@Service
public class FeatureService {
    private final FeatureConfig config;

    public FeatureService(FeatureConfig config) {
        this.config = config;
    }

    public void process() {
        if (config.enabled()) {
            int max = config.maxItems();
            // ...
        }
    }
}
```

### Corresponding Properties

```properties
app.feature.enabled=true
app.feature.max-items=100
app.feature.timeout-seconds=30
app.feature.nested.retries=5
```

### When NOT to Use

For 1-2 isolated properties, use `@Value`:

```java
@Value("${app.socket.port:8583}")
private int port;
```

---

## 3. Spring Data JPA

### Repository Interface

```java
public interface MerchantRepository extends JpaRepository<MerchantEntity, Long> {

    Optional<MerchantEntity> findByMid(String mid);

    Page<MerchantEntity> findByStatus(String status, Pageable pageable);

    long countByStatus(String status);

    @Query("SELECT m FROM MerchantEntity m WHERE m.status = :status ORDER BY m.createdAt DESC")
    List<MerchantEntity> findActiveOrderByCreatedAt(@Param("status") String status);

    boolean existsByMid(String mid);
}
```

### Common Operations

```java
// Save
repository.save(entity);

// Find by ID (Optional)
Optional<Entity> e = repository.findById(id);

// Paginated query
Page<Entity> page = repository.findAll(PageRequest.of(0, 20, Sort.by("createdAt").descending()));

// Count
long total = repository.count();

// Delete
repository.deleteById(id);

// Exists check (efficient)
boolean exists = repository.existsByMid("123");
```

### Entity Pattern

```java
@Entity
@Table(name = "merchants", schema = "simulator")
public class MerchantEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "mid", nullable = false, unique = true, length = 15)
    private String mid;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    // Getters and setters required (Spring Data uses reflection)
    // Or use Lombok: @Getter @Setter @NoArgsConstructor

    @PrePersist
    void prePersist() { createdAt = updatedAt = OffsetDateTime.now(); }

    @PreUpdate
    void preUpdate() { updatedAt = OffsetDateTime.now(); }
}
```

---

## 4. @RestController

```java
@RestController
@RequestMapping("/api/v1/merchants")
public class MerchantController {

    private final MerchantManagementPort service;

    public MerchantController(MerchantManagementPort service) {
        this.service = service;
    }

    @GetMapping
    public PaginatedResponse<MerchantResponse> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int limit) {
        var merchants = service.listAll(page, limit);
        var total = service.count();
        var responses = merchants.stream().map(MerchantDtoMapper::toResponse).toList();
        return PaginatedResponse.of(responses, page, limit, total);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public MerchantResponse create(@Valid @RequestBody CreateMerchantRequest request) {
        var domain = MerchantDtoMapper.toDomain(request);
        var created = service.create(domain);
        return MerchantDtoMapper.toResponse(created);
    }

    @GetMapping("/{id}")
    public MerchantResponse findById(@PathVariable Long id) {
        return service.findById(id)
            .map(MerchantDtoMapper::toResponse)
            .orElseThrow(() -> new MerchantNotFoundException(String.valueOf(id)));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        service.deactivate(id);
    }
}
```

---

## 5. @ControllerAdvice (Exception Handling)

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(MerchantNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ProblemDetail handleNotFound(MerchantNotFoundException ex, HttpServletRequest request) {
        return ProblemDetail.notFound(ex.getMessage(), request.getRequestURI());
    }

    @ExceptionHandler(MerchantAlreadyExistsException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ProblemDetail handleConflict(MerchantAlreadyExistsException ex, HttpServletRequest request) {
        return ProblemDetail.conflict(ex.getMessage(), request.getRequestURI(), Map.of("mid", ex.getMid()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        var violations = ex.getBindingResult().getFieldErrors().stream()
            .collect(Collectors.groupingBy(
                FieldError::getField,
                Collectors.mapping(FieldError::getDefaultMessage, Collectors.toList())
            ));
        return ProblemDetail.validationError("Validation failed", request.getRequestURI(), violations);
    }

    @ExceptionHandler(RuntimeException.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ProblemDetail handleUnexpected(RuntimeException ex, HttpServletRequest request) {
        LOG.error("Unexpected error on {}: {}", request.getRequestURI(), ex.getMessage(), ex);
        return ProblemDetail.internalError("Internal processing error", request.getRequestURI());
    }
}
```

### Key Differences from Quarkus

| Aspect | Quarkus | Spring Boot |
|--------|---------|-------------|
| Handler | `ExceptionMapper<T>` with `@Provider` | `@RestControllerAdvice` with `@ExceptionHandler` |
| Path access | `@Context UriInfo` | `HttpServletRequest` parameter |
| Pattern matching | Used in single mapper class | Separate `@ExceptionHandler` per type |

---

## 6. Spring AOT (Native Build)

### @RegisterReflectionForBinding

Equivalent of Quarkus `@RegisterForReflection`:

```java
// On DTOs serialized by Jackson
@RegisterReflectionForBinding
public record CreateMerchantRequest(
    @NotBlank @Size(max = 15) String mid,
    @NotBlank @Size(max = 100) String name
) {}

@RegisterReflectionForBinding
public record MerchantResponse(Long id, String mid, String name) {}
```

### Runtime Hints (for complex cases)

```java
@ImportRuntimeHints(ApplicationRuntimeHints.class)
@SpringBootApplication
public class Application { }

public class ApplicationRuntimeHints implements RuntimeHintsRegistrar {
    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        hints.reflection().registerType(ProblemDetail.class,
            MemberCategory.DECLARED_FIELDS, MemberCategory.INVOKE_DECLARED_CONSTRUCTORS);
    }
}
```

### Build Commands

```bash
# Dev (JVM)
mvn spring-boot:run

# Test
mvn verify

# Native (GraalVM)
mvn -Pnative native:compile

# Native via Buildpacks (no local GraalVM needed)
mvn spring-boot:build-image -Pnative
```

---

## 7. Configuration Profiles

| File | Purpose |
|------|---------|
| `application.properties` | Base shared (all profiles) |
| `application-dev.properties` | Local dev overrides |
| `application-test.properties` | Test overrides |
| `application-prod.properties` | Production overrides |

### Activation

```bash
# Via env var
SPRING_PROFILES_ACTIVE=dev mvn spring-boot:run

# Via command line
mvn spring-boot:run -Dspring.profiles.active=dev
```

---

## 8. Health Checks (Actuator)

### Configuration

```properties
management.endpoints.web.exposure.include=health,info,metrics
management.endpoint.health.show-details=when_authorized
```

### Custom Health Indicator

```java
@Component
public class DatabaseHealthIndicator implements HealthIndicator {
    private final DataSource dataSource;

    public DatabaseHealthIndicator(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public Health health() {
        try (var conn = dataSource.getConnection()) {
            return Health.up().withDetail("database", "connected").build();
        } catch (SQLException e) {
            return Health.down().withException(e).build();
        }
    }
}
```

### Endpoints

| Path | Purpose |
|------|---------|
| `/actuator/health/liveness` | Liveness (app running) |
| `/actuator/health/readiness` | Readiness (dependencies OK) |
| `/actuator/health` | Overall health |

---

## 9. Transaction Management

```java
@Service
@Transactional(readOnly = true)
public class MerchantService {

    @Transactional
    public Merchant create(Merchant merchant) {
        // Write operation — overrides class-level readOnly
    }

    public Optional<Merchant> findById(Long id) {
        // Read-only — uses class-level setting
    }
}
```

---

## Anti-Patterns (Spring-Specific)

- `@Autowired` on fields (use constructor injection)
- `@Data` on entities (encourages mutability, breaks JPA)
- Missing `@Transactional` on write operations
- `@ConfigurationProperties` without `@ConfigurationPropertiesScan`
- Using Spring-specific types in domain layer (violates hexagonal)
- `@Component` scan across all packages (slow startup)
- Missing `@RegisterReflectionForBinding` on Jackson DTOs (native build failure)
- Circular dependencies (redesign with events or interfaces)
