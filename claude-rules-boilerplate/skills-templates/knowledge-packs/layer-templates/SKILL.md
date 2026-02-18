---
name: layer-templates
description: "Reference code templates for each hexagonal architecture layer. Provides consistent patterns for domain model, ports, DTOs, mappers, entities, repositories, use cases, REST resources, exception mappers, migrations, and configuration. Uses {{LANGUAGE}}, {{FRAMEWORK}} placeholders."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Layer Templates (Hexagonal Architecture)

## Purpose

Provides copy-and-adapt code templates for every hexagonal architecture layer. Agents use these templates to produce structurally consistent code across a project, regardless of the specific domain entity being implemented.

## Template Catalog

| Layer | Component | Package Location |
|-------|-----------|-----------------|
| Domain Model | Record / Sealed Interface / Enum | `domain/model/` |
| Port Inbound | Interface (domain types only) | `domain/port/inbound/` |
| Port Outbound | Interface (Optional returns) | `domain/port/outbound/` |
| DTO Request | Validated input record | `adapter/inbound/rest/dto/` |
| DTO Response | Immutable output record | `adapter/inbound/rest/dto/` |
| DTO Mapper | Static utility class | `adapter/inbound/rest/mapper/` |
| Entity | ORM-managed persistence class | `adapter/outbound/persistence/entity/` |
| Entity Mapper | Static utility class | `adapter/outbound/persistence/mapper/` |
| Repository | Data access abstraction | `adapter/outbound/persistence/repository/` |
| Use Case | Application orchestration | `application/` |
| REST Resource | HTTP endpoint handler | `adapter/inbound/rest/` |
| Exception Mapper | Error-to-response converter | `adapter/inbound/rest/` |
| Migration | Database schema change | `db/migration/` |
| Configuration | Typed config mapping | `config/` |

---

## 1. Domain Model

Pure domain record. Zero framework dependencies. Only JDK types.

```
// {{LANGUAGE}} — domain/model/{{EntityName}}.{{EXT}}
// Record for immutable value, class for aggregate root with behavior

public record {{EntityName}}(
    Long id,
    String name,
    String identifier,        // unique business key
    {{EntityName}}Status status,
    OffsetDateTime createdAt,
    OffsetDateTime updatedAt
) {}

// Enum for domain states
public enum {{EntityName}}Status {
    ACTIVE, INACTIVE, SUSPENDED
}
```

**Rules:**
- ZERO imports from framework packages (no `jakarta.*`, no `org.springframework.*`)
- Immutable by default (records preferred)
- Sealed interfaces for type hierarchies with exhaustive pattern matching

---

## 2. Port Inbound

Interface defining what the application offers to the outside world.

```
// domain/port/inbound/{{EntityName}}ManagementPort.{{EXT}}

public interface {{EntityName}}ManagementPort {
    {{EntityName}} create({{EntityName}} entity);
    Optional<{{EntityName}}> findById(Long id);
    Optional<{{EntityName}}> findByIdentifier(String identifier);
    List<{{EntityName}}> listAll(int page, int limit);
    {{EntityName}} update(Long id, {{EntityName}} updated);
    void deactivate(Long id);
    long count();
}
```

**Rules:**
- Domain types only (no DTOs, no entities)
- `Optional<T>` for single lookups, never null
- Empty collection for list operations, never null

---

## 3. Port Outbound

Interface defining what the domain needs from infrastructure.

```
// domain/port/outbound/{{EntityName}}PersistencePort.{{EXT}}

public interface {{EntityName}}PersistencePort {
    void save({{EntityName}} entity);
    Optional<{{EntityName}}> findById(Long id);
    Optional<{{EntityName}}> findByIdentifier(String identifier);
    List<{{EntityName}}> findAll(int page, int limit);
    void update({{EntityName}} entity);
    long count();
}
```

**Rules:**
- Commands (`save`, `update`) return void — follow CQS
- Queries return `Optional<T>` or `List<T>`, never null

---

## 4. DTO Request

Validated input from external clients.

```
// adapter/inbound/rest/dto/Create{{EntityName}}Request.{{EXT}}
// {{FRAMEWORK}}-specific: @RegisterForReflection (Quarkus) or none (Spring)

public record Create{{EntityName}}Request(
    @NotBlank @Size(max = 15) String identifier,
    @NotBlank @Size(max = 100) String name,
    @NotBlank String category
) {}
```

**Notes:**
- Bean Validation annotations are standard (`jakarta.validation`)
- {{FRAMEWORK}} may require additional annotations for native/AOT builds
- OpenAPI `@Schema` annotations recommended for documentation

---

## 5. DTO Response

Immutable output returned to clients. Sensitive data masked.

```
// adapter/inbound/rest/dto/{{EntityName}}Response.{{EXT}}

public record {{EntityName}}Response(
    Long id,
    String identifier,
    String name,
    String status,
    OffsetDateTime createdAt
) {}
```

**Rules:**
- Never expose internal IDs if they leak implementation details
- Mask sensitive fields (documents, PANs) before returning
- Omit null fields in JSON serialization

---

## 6. DTO Mapper

Static utility converting between REST DTOs and domain models.

```
// adapter/inbound/rest/mapper/{{EntityName}}DtoMapper.{{EXT}}

public final class {{EntityName}}DtoMapper {

    private {{EntityName}}DtoMapper() {}

    public static {{EntityName}} toDomain(Create{{EntityName}}Request request) {
        return new {{EntityName}}(
            null,
            request.name(),
            request.identifier(),
            {{EntityName}}Status.ACTIVE,
            null, null
        );
    }

    public static {{EntityName}}Response toResponse({{EntityName}} domain) {
        return new {{EntityName}}Response(
            domain.id(),
            domain.identifier(),
            domain.name(),
            domain.status().name(),
            domain.createdAt()
        );
    }
}
```

**Rules:**
- `final class` + private constructor + static methods
- NOT a DI bean (no `@ApplicationScoped` / `@Component`)
- Masking logic for sensitive data lives here (output mapper)

---

## 7. Entity

ORM-managed persistence class. Framework-specific annotations apply.

```
// adapter/outbound/persistence/entity/{{EntityName}}Entity.{{EXT}}
// {{FRAMEWORK}}-specific: extends PanacheEntity (Quarkus) or plain @Entity (Spring)

@Entity
@Table(name = "{{table_name}}", schema = "{{schema}}")
public class {{EntityName}}Entity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "identifier", nullable = false, unique = true, length = 15)
    private String identifier;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "status", nullable = false, length = 20)
    private String status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    // Getters, setters, lifecycle callbacks
    @PrePersist
    void prePersist() { createdAt = updatedAt = OffsetDateTime.now(); }

    @PreUpdate
    void preUpdate() { updatedAt = OffsetDateTime.now(); }
}
```

**Rules:**
- NEVER expose entities outside the persistence adapter
- Mandatory columns: `id`, `created_at`, `updated_at`
- No business logic in entities

---

## 8. Entity Mapper

Static utility converting between domain models and JPA entities.

```
// adapter/outbound/persistence/mapper/{{EntityName}}EntityMapper.{{EXT}}

public final class {{EntityName}}EntityMapper {

    private {{EntityName}}EntityMapper() {}

    public static {{EntityName}}Entity toEntity({{EntityName}} domain) {
        var entity = new {{EntityName}}Entity();
        entity.setIdentifier(domain.identifier());
        entity.setName(domain.name());
        entity.setStatus(domain.status().name());
        return entity;
    }

    public static {{EntityName}} toDomain({{EntityName}}Entity entity) {
        return new {{EntityName}}(
            entity.getId(),
            entity.getName(),
            entity.getIdentifier(),
            {{EntityName}}Status.valueOf(entity.getStatus()),
            entity.getCreatedAt(),
            entity.getUpdatedAt()
        );
    }
}
```

---

## 9. Repository

Data access. {{FRAMEWORK}}-specific implementation.

```
// adapter/outbound/persistence/repository/{{EntityName}}Repository.{{EXT}}
// Quarkus: implements PanacheRepository<E>
// Spring: extends JpaRepository<E, Long>

public class {{EntityName}}Repository {

    public Optional<{{EntityName}}Entity> findByIdentifier(String identifier) {
        // Framework-specific query
    }

    public List<{{EntityName}}Entity> findByStatus(String status, int page, int limit) {
        // Framework-specific pagination
    }
}
```

---

## 10. Use Case

Application-layer orchestration. Calls ports, never adapters directly.

```
// application/Manage{{EntityName}}UseCase.{{EXT}}

public class Manage{{EntityName}}UseCase implements {{EntityName}}ManagementPort {

    private final {{EntityName}}PersistencePort persistence;

    // Constructor injection ({{FRAMEWORK}}-specific annotation)
    public Manage{{EntityName}}UseCase({{EntityName}}PersistencePort persistence) {
        this.persistence = persistence;
    }

    public {{EntityName}} create({{EntityName}} entity) {
        persistence.findByIdentifier(entity.identifier()).ifPresent(existing -> {
            throw new {{EntityName}}AlreadyExistsException(entity.identifier());
        });
        persistence.save(entity);
        return persistence.findByIdentifier(entity.identifier()).orElseThrow();
    }

    public Optional<{{EntityName}}> findById(Long id) {
        return persistence.findById(id);
    }
}
```

**Rules:**
- One use case per aggregate or bounded context
- Depends on ports (interfaces), never on adapters (implementations)
- Throws domain exceptions for business rule violations

---

## 11. REST Resource

HTTP endpoint. {{FRAMEWORK}}-specific annotations.

```
// adapter/inbound/rest/{{EntityName}}Resource.{{EXT}}

@Path("/api/v1/{{resource_path}}")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class {{EntityName}}Resource {

    private final {{EntityName}}ManagementPort service;

    public {{EntityName}}Resource({{EntityName}}ManagementPort service) {
        this.service = service;
    }

    @GET
    public PaginatedResponse<{{EntityName}}Response> list(@QueryParam("page") int page, @QueryParam("limit") int limit) {
        var items = service.listAll(page, limit).stream().map({{EntityName}}DtoMapper::toResponse).toList();
        return PaginatedResponse.of(items, page, limit, service.count());
    }

    @POST
    public Response create(@Valid Create{{EntityName}}Request request) {
        var domain = {{EntityName}}DtoMapper.toDomain(request);
        var created = service.create(domain);
        var response = {{EntityName}}DtoMapper.toResponse(created);
        return Response.status(201).entity(response).build();
    }

    @GET @Path("/{id}")
    public {{EntityName}}Response findById(@PathParam("id") Long id) {
        return service.findById(id).map({{EntityName}}DtoMapper::toResponse)
            .orElseThrow(() -> new {{EntityName}}NotFoundException(String.valueOf(id)));
    }
}
```

---

## 12. Exception Mapper

Converts domain exceptions to RFC 7807 ProblemDetail responses.

```
// adapter/inbound/rest/SimulatorExceptionMapper.{{EXT}}

public class SimulatorExceptionMapper {

    public Response toResponse(RuntimeException exception) {
        var problem = switch (exception) {
            case {{EntityName}}NotFoundException e -> ProblemDetail.notFound(e.getMessage(), path);
            case {{EntityName}}AlreadyExistsException e -> ProblemDetail.conflict(e.getMessage(), path, Map.of());
            default -> ProblemDetail.internalError("Internal processing error", path);
        };
        return Response.status(problem.status()).entity(problem).build();
    }
}
```

**Rules:**
- Pattern matching switch ({{LANGUAGE}} 21+ / equivalent)
- Each new domain exception MUST have a corresponding case
- Default case logs at ERROR and returns 500 (never exposes stack trace)

---

## 13. Migration

Database schema change script.

```sql
-- V{N}__create_{{table_name}}_table.sql
-- Description: Create {{table_name}} table
-- Story: STORY-NNN

BEGIN;

CREATE TABLE IF NOT EXISTS {{schema}}.{{table_name}} (
    id BIGSERIAL PRIMARY KEY,
    identifier VARCHAR(15) NOT NULL,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_{{table_name}}_identifier UNIQUE (identifier)
);

CREATE INDEX IF NOT EXISTS idx_{{table_name}}_identifier ON {{schema}}.{{table_name}} (identifier);
CREATE INDEX IF NOT EXISTS idx_{{table_name}}_status ON {{schema}}.{{table_name}} (status);

COMMIT;
```

---

## 14. Configuration

Typed configuration mapping. {{FRAMEWORK}}-specific.

```
// config/{{EntityName}}Config.{{EXT}}
// Quarkus: @ConfigMapping(prefix = "app.{{entity}}")
// Spring: @ConfigurationProperties(prefix = "app.{{entity}}")

public interface {{EntityName}}Config {
    @WithDefault("100")
    int maxItems();

    @WithDefault("true")
    boolean enabled();
}
```

---

## Checklist for Any New Entity

1. Domain model record created in `domain/model/`
2. Inbound port interface in `domain/port/inbound/`
3. Outbound port interface in `domain/port/outbound/`
4. Request/Response DTOs in `adapter/inbound/rest/dto/`
5. DTO mapper in `adapter/inbound/rest/mapper/`
6. JPA entity in `adapter/outbound/persistence/entity/`
7. Entity mapper in `adapter/outbound/persistence/mapper/`
8. Repository in `adapter/outbound/persistence/repository/`
9. Use case in `application/`
10. REST resource in `adapter/inbound/rest/`
11. Exception cases added to exception mapper
12. Flyway migration created
13. Tests for each layer
