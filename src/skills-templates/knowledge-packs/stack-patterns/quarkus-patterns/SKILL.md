---
name: quarkus-patterns
description: "Quarkus-specific patterns: CDI, @ConfigMapping, Panache Repository, RESTEasy Reactive, native build constraints, @RegisterForReflection. Internal reference for agents producing Quarkus code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Quarkus Patterns

## Purpose

Provides Quarkus-specific implementation patterns that supplement the generic layer templates. Agents reference this pack when generating code for a Java 21 + Quarkus project.

---

## 1. CDI (Contexts and Dependency Injection)

### Constructor Injection (Mandatory)

```java
@ApplicationScoped
public class TransactionService {
    private final TransactionRepository repository;
    private final AuthorizationEngine engine;

    @Inject
    public TransactionService(TransactionRepository repository, AuthorizationEngine engine) {
        this.repository = repository;
        this.engine = engine;
    }
}
```

### CDI Scope Selection

| Scope | When | Thread Safety |
|-------|------|---------------|
| `@ApplicationScoped` | Stateless services, repositories, handlers | Must be thread-safe (no mutable fields) |
| `@RequestScoped` | Per-request state (rare) | Safe within single request |
| `@Dependent` | Utility beans, short-lived | New instance per injection point |

### FORBIDDEN

- Field injection (`@Inject` on private field without constructor)
- Mutable state in `@ApplicationScoped` beans
- `@Singleton` without CDI awareness (use `@ApplicationScoped`)

---

## 2. @ConfigMapping (SmallRye)

Use `@ConfigMapping` for groups of 3+ properties with a common prefix.

```java
@ConfigMapping(prefix = "app.feature")
public interface FeatureConfig {

    @WithDefault("true")
    boolean enabled();

    @WithDefault("100")
    int maxItems();

    @WithDefault("30")
    int timeoutSeconds();

    NestedConfig nested();

    interface NestedConfig {
        @WithDefault("5")
        int retries();
    }
}
```

### Usage

```java
@ApplicationScoped
public class FeatureService {
    private final FeatureConfig config;

    @Inject
    public FeatureService(FeatureConfig config) {
        this.config = config;
    }

    public void process() {
        if (config.enabled()) {
            int max = config.maxItems();
            int retries = config.nested().retries();
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

For 1-2 isolated properties, use `@ConfigProperty`:

```java
@ConfigProperty(name = "app.socket.port", defaultValue = "8583")
int port;
```

---

## 3. Panache Repository Pattern

```java
@ApplicationScoped
public class MerchantRepository implements PanacheRepository<MerchantEntity> {

    public Optional<MerchantEntity> findByMid(String mid) {
        return find("mid", mid).firstResultOptional();
    }

    public List<MerchantEntity> findByStatus(String status, int page, int limit) {
        return find("status", Sort.descending("createdAt"), status)
            .page(page, limit)
            .list();
    }

    public long countByStatus(String status) {
        return count("status", status);
    }
}
```

### Common Operations

```java
// Persist
repository.persist(entity);

// Find by ID (Optional)
Optional<Entity> e = repository.findByIdOptional(id);

// Paginated query
List<Entity> page = repository.find("status", "ACTIVE")
    .page(0, 20).list();

// Count
long total = repository.count();

// Delete
repository.deleteById(id);
```

### Entity Pattern (Panache)

Quarkus Panache entities can use public fields (no getters/setters needed):

```java
@Entity
@Table(name = "merchants", schema = "simulator")
public class MerchantEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @Column(name = "mid", nullable = false, unique = true, length = 15)
    public String mid;

    @Column(name = "name", nullable = false, length = 100)
    public String name;

    @Column(name = "created_at", nullable = false, updatable = false)
    public OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    public OffsetDateTime updatedAt;

    @PrePersist
    void prePersist() { createdAt = updatedAt = OffsetDateTime.now(); }

    @PreUpdate
    void preUpdate() { updatedAt = OffsetDateTime.now(); }
}
```

---

## 4. RESTEasy Reactive

```java
@Path("/api/v1/merchants")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class MerchantResource {

    private final MerchantManagementPort service;

    @Inject
    public MerchantResource(MerchantManagementPort service) {
        this.service = service;
    }

    @GET
    public PaginatedResponse<MerchantResponse> list(
            @QueryParam("page") @DefaultValue("0") int page,
            @QueryParam("limit") @DefaultValue("20") int limit) {
        var merchants = service.listAll(page, limit);
        var total = service.count();
        var responses = merchants.stream().map(MerchantDtoMapper::toResponse).toList();
        return PaginatedResponse.of(responses, page, limit, total);
    }

    @POST
    @Transactional
    public Response create(@Valid CreateMerchantRequest request) {
        var domain = MerchantDtoMapper.toDomain(request);
        var created = service.create(domain);
        return Response.status(201).entity(MerchantDtoMapper.toResponse(created)).build();
    }

    @GET
    @Path("/{id}")
    public MerchantResponse findById(@PathParam("id") Long id) {
        return service.findById(id)
            .map(MerchantDtoMapper::toResponse)
            .orElseThrow(() -> new MerchantNotFoundException(String.valueOf(id)));
    }

    @DELETE
    @Path("/{id}")
    @Transactional
    public Response delete(@PathParam("id") Long id) {
        service.deactivate(id);
        return Response.noContent().build();
    }
}
```

### Exception Mapper

```java
@Provider
public class SimulatorExceptionMapper implements ExceptionMapper<RuntimeException> {

    @Context
    UriInfo uriInfo;

    @Override
    public Response toResponse(RuntimeException exception) {
        var problem = switch (exception) {
            case MerchantNotFoundException e -> ProblemDetail.notFound(e.getMessage(), uriInfo.getPath());
            case MerchantAlreadyExistsException e -> ProblemDetail.conflict(
                e.getMessage(), uriInfo.getPath(), Map.of("mid", e.getMid()));
            default -> {
                LOG.errorf("Unexpected error on %s: %s", uriInfo.getPath(), exception.getMessage());
                yield ProblemDetail.internalError("Internal processing error", uriInfo.getPath());
            }
        };
        return Response.status(problem.status()).entity(problem).build();
    }
}
```

---

## 5. @RegisterForReflection (Native Build)

Mandatory on ALL records serialized/deserialized by Jackson:

```java
// Requests
@RegisterForReflection
public record CreateMerchantRequest(
    @NotBlank @Size(max = 15) String mid,
    @NotBlank @Size(max = 100) String name
) {}

// Responses
@RegisterForReflection
public record MerchantResponse(Long id, String mid, String name) {}

// Error responses
@RegisterForReflection
public record ProblemDetail(String type, String title, int status, String detail) {}

// Nested records
@RegisterForReflection
public record PaginatedResponse<T>(List<T> data, PaginationInfo pagination) {
    @RegisterForReflection
    public record PaginationInfo(int page, int limit, long total, int totalPages) {}
}

// Enums deserialized via Jackson
@RegisterForReflection
public enum TransactionStatus { PENDING, APPROVED, DENIED }
```

### Where NOT Required

- JPA Entities (Hibernate/Panache auto-registers)
- Internal domain models never passing through Jackson
- Mapper classes, utility classes

---

## 6. Native Build Constraints

| Allowed | Forbidden |
|---------|-----------|
| CDI (`@ApplicationScoped`, `@Inject`) | Reflection without `@RegisterForReflection` |
| Records (natively supported) | Dynamic `Class.forName()` |
| Sealed interfaces | Dynamic proxies without config |
| Jackson with `@RegisterForReflection` | Static initialization with I/O |
| Panache repositories | Runtime classloading |

### Build Commands

```bash
# Dev (JVM, hot reload)
mvn quarkus:dev

# Test (JVM)
mvn verify

# Native (container build, no local GraalVM needed)
mvn package -Dnative -Dquarkus.native.container-build=true
```

---

## 7. Configuration Profiles

| File | Purpose |
|------|---------|
| `application.properties` | Base shared (all profiles) |
| `application-dev.properties` | Local dev overrides |
| `application-test.properties` | Test overrides (H2, random ports) |
| `application-prod.properties` | Production overrides (JSON logs, OTel) |

### Override Priority (highest to lowest)

1. Environment variable (`SIMULATOR_SOCKET_PORT=9583`)
2. System property (`-Dsimulator.socket.port=9583`)
3. Profile properties (`application-{profile}.properties`)
4. Base properties (`application.properties`)
5. `@WithDefault` annotation in `@ConfigMapping`

---

## 8. Health Checks

```java
@Liveness
@ApplicationScoped
public class AppLivenessCheck implements HealthCheck {
    @Override
    public HealthCheckResponse call() {
        return HealthCheckResponse.up("alive");
    }
}

@Readiness
@ApplicationScoped
public class DatabaseReadinessCheck implements HealthCheck {
    private final DataSource dataSource;

    @Inject
    public DatabaseReadinessCheck(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public HealthCheckResponse call() {
        try (var conn = dataSource.getConnection()) {
            return HealthCheckResponse.up("database");
        } catch (SQLException e) {
            return HealthCheckResponse.down("database");
        }
    }
}
```

### Endpoints

| Path | Purpose |
|------|---------|
| `/q/health/live` | Liveness (app running) |
| `/q/health/ready` | Readiness (dependencies OK) |
| `/q/health/started` | Startup (init complete) |

---

## Anti-Patterns (Quarkus-Specific)

- Lombok (Quarkus CDI does not need it; records replace DTOs)
- `@Inject` on private fields without constructor
- Blocking the Vert.x event loop with synchronous I/O
- Mutable state in `@ApplicationScoped` beans
- Missing `@RegisterForReflection` on Jackson-serialized records
- Heavy static initializers (incompatible with native)
- `@ConfigProperty` for groups of 3+ related properties
- MapStruct (incompatible with native without extra config)
