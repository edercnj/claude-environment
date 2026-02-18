# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Quarkus — Coding Patterns

> Extends: `core/01-clean-code.md`, `core/02-solid-principles.md`

## Java 21 — Mandatory Features

| Feature                   | Usage                                      |
| ------------------------- | ------------------------------------------ |
| Records                   | DTOs, Value Objects, Events, Responses    |
| Sealed Interfaces         | Decision strategies, transaction types     |
| Pattern Matching (switch) | Routing, type-based decisions              |
| Text Blocks               | Complex SQL queries, log templates         |
| Optional                  | Search returns (NEVER return null)         |
| var                       | Local variables with obvious type          |

## Anti-Patterns (FORBIDDEN)

- Lombok (Quarkus has its own facilities)
- Return `null` — use `Optional<T>` or empty collection
- Magic numbers/strings — use constants or enums
- `System.out.println` — use `java.util.logging` or SLF4J via Quarkus
- Field injection with `@Inject` on private fields without constructor — prefer constructor injection
- Blocking Vert.x event loop with long synchronous operations
- Mutable state in CDI beans `@ApplicationScoped`
- Using reflection directly in code that runs on native (use `@RegisterForReflection`)
- Heavy static initialization (static blocks with I/O, connections) — incompatible with native
- Dynamic proxy without prior registration — incompatible with GraalVM

## CDI (Contexts and Dependency Injection)

```java
// CORRECT — Constructor Injection (signature on one line)
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

// WRONG — Field Injection without constructor
@ApplicationScoped
public class TransactionService {
    @Inject
    TransactionRepository repository;
}
```

## Panache — Repository Pattern

```java
@ApplicationScoped
public class MerchantRepository implements PanacheRepository<MerchantEntity> {
    public Optional<MerchantEntity> findByMid(String mid) {
        return find("mid", mid).firstResultOptional();
    }
}
```

## REST Endpoints (RESTEasy Reactive)

```java
@Path("/api/v1/merchants")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class MerchantResource {

    @GET
    public List<MerchantResponse> list() { ... }

    @POST
    @Transactional
    public Response create(CreateMerchantRequest request) { ... }
}
```

## Naming Conventions

| Element         | Convention                                 | Example                        |
| --------------- | ------------------------------------------ | ------------------------------ |
| Class           | PascalCase                                 | `TransactionHandler`           |
| Interface       | PascalCase (no I prefix)                   | `AuthorizationEngine`          |
| Method          | camelCase, verb                            | `processTransaction()`         |
| Variable        | camelCase                                  | `responseCode`                 |
| Constant        | UPPER_SNAKE                               | `MAX_TIMEOUT_SECONDS`          |
| Enum            | PascalCase (type), UPPER_SNAKE (values)   | `TransactionType.DEBIT_SALE`   |
| Package         | lowercase                                 | `com.example.domain`           |
| Entity          | PascalCase + Entity suffix                | `TransactionEntity`            |
| Repository      | PascalCase + Repository suffix            | `TransactionRepository`        |
| Resource (REST) | PascalCase + Resource suffix              | `MerchantResource`             |
| DTO Request     | PascalCase + Request suffix               | `CreateMerchantRequest`        |
| DTO Response    | PascalCase + Response suffix              | `MerchantResponse`             |

## Formatting

- Indentation: **4 spaces** (no tabs)
- Maximum width: **120 characters** per line
- Braces: **K&R style** (opening brace on same line)
- Imports: no wildcard (`*`), organized: java -> jakarta -> com.{project} -> others

### Method Signature — ONE LINE

Method signatures MUST fit on a single line, including all parameters.
Only break into multiple lines if exceeding 120 characters.

```java
// GOOD — signature on one line
private byte[] routeMessage(String mti, IsoMessage isoMessage, byte[] rawMessage, ConnectionContext context) {
    return switch (mti) {
        case MTI_ECHO_REQUEST -> handleEchoRequest(isoMessage, rawMessage, context);
        case MTI_DEBIT_REQUEST -> handleDebitRequest(isoMessage, rawMessage, context);
        default -> {
            LOG.warnf("Unsupported MTI: %s from connection %s", mti, context.connectionId());
            yield buildErrorResponse(RESPONSE_CODE_INVALID_TRANSACTION);
        }
    };
}

// BAD — unnecessary parameter break
private byte[] routeMessage(
        String mti,
        IsoMessage isoMessage,
        byte[] rawMessage,
        ConnectionContext context) {
```

## Mapper Pattern (Static Utility Classes)

Mappers convert between layers of hexagonal architecture. Two types:

### DTO Mappers (Inbound REST Adapter)

Location: `adapter.inbound.rest.mapper`

```java
public final class MerchantDtoMapper {

    private MerchantDtoMapper() {}

    public static Merchant toDomain(CreateMerchantRequest request) {
        return new Merchant(
            request.mid(),
            request.name(),
            request.tradeName(),
            request.document(),
            List.of(request.mcc()),
            mapAddress(request.address()),
            mapConfiguration(request.configuration()),
            MerchantStatus.ACTIVE
        );
    }

    public static MerchantResponse toResponse(Merchant merchant) {
        return new MerchantResponse(
            merchant.id(),
            merchant.mid(),
            merchant.legalName(),
            maskDocument(merchant.document()),
            merchant.mccs(),
            mapAddressResponse(merchant.address()),
            mapConfigurationResponse(merchant.configuration()),
            merchant.status().name(),
            merchant.createdAt(),
            merchant.updatedAt()
        );
    }

    private static String maskDocument(String document) {
        if (document == null || document.length() < 5) return "****";
        return document.substring(0, 3) + "****" + document.substring(document.length() - 2);
    }
}
```

### Entity Mappers (Outbound Persistence Adapter)

Location: `adapter.outbound.persistence.mapper`

```java
public final class MerchantEntityMapper {

    private MerchantEntityMapper() {}

    public static MerchantEntity toEntity(Merchant merchant) {
        var entity = new MerchantEntity();
        entity.setMid(merchant.mid());
        entity.setLegalName(merchant.legalName());
        entity.setDocument(merchant.document());
        entity.setMccs(String.join(",", merchant.mccs()));
        return entity;
    }

    public static Merchant toDomain(MerchantEntity entity) {
        return new Merchant(
            entity.getId(),
            entity.getMid(),
            entity.getLegalName(),
            entity.getDocument(),
            Arrays.asList(entity.getMccs().split(","))
        );
    }
}
```

### Mapper Rules

| Rule         | Detail |
|--------------|--------|
| Structure    | `final class` + `private` constructor + `static` methods |
| CDI          | WITHOUT `@ApplicationScoped` — not a CDI bean |
| Reflection   | WITHOUT `@RegisterForReflection` — not serialized |
| MapStruct    | **FORBIDDEN** — incompatible with native build without extra config |
| Masking      | Masking logic (document, sensitive fields) lives in mapper that **exposes** data externally |
| Null safety  | Check nulls on optional fields (address, configuration) before mapping |
| Location     | DTO Mapper in `adapter.inbound.rest.mapper`, Entity Mapper in `adapter.outbound.persistence.mapper` |

> **Exception:** Mappers needing injected dependencies (e.g., `ObjectMapper` for JSON) MAY be `@ApplicationScoped` with constructor injection. In that case, use instance methods instead of `static`.

## Domain Exception with Context

```java
public class MerchantNotFoundException extends RuntimeException {

    private final String identifier;

    public MerchantNotFoundException(String identifier) {
        super("Merchant not found: %s".formatted(identifier));
        this.identifier = identifier;
    }

    public String getIdentifier() {
        return identifier;
    }
}

// Masking sensitive data in message
public class InvalidDocumentException extends RuntimeException {

    private final String document;

    public InvalidDocumentException(String document) {
        super("Invalid document: %s****%s".formatted(
            document.substring(0, 3),
            document.substring(document.length() - 2)));
        this.document = document;
    }

    public String getDocument() {
        return document;
    }
}
```

### Domain Exception Rules

| Rule            | Detail |
|-----------------|--------|
| Inheritance     | Extends `RuntimeException` (unchecked) — NEVER checked exceptions |
| Context         | Private field with value that caused error (mid, tid, identifier) |
| Getter          | Getter for context field — used by ExceptionMapper |
| Message         | `String.formatted()` — NEVER string concatenation with `+` |
| Sensitive data  | Mask in exception message (document, sensitive fields) |
| Location        | `domain.model` or `domain.exception` package |
| Naming          | `{Entity}{Problem}Exception` — e.g., `MerchantNotFoundException`, `TerminalAlreadyExistsException` |

## @RegisterForReflection in REST DTOs

**Mandatory** on ALL records used in REST serialization/deserialization (Jackson):

```java
// Mandatory on requests
@RegisterForReflection
public record CreateMerchantRequest(...) {}

// Mandatory on responses
@RegisterForReflection
public record MerchantResponse(...) {}

// Mandatory on error responses
@RegisterForReflection
public record ProblemDetail(...) {}

// Mandatory on generic wrappers and nested records
@RegisterForReflection
public record PaginatedResponse<T>(...) {
    @RegisterForReflection
    public record PaginationInfo(...) {}
}
```

**Where it IS mandatory:**
- REST requests (records with `@NotBlank`, `@Size`, etc.)
- REST responses (records returned by endpoints)
- ProblemDetail and error variants
- PaginatedResponse and PaginationInfo
- Nested records used within requests/responses
- Enums deserialized via Jackson

**Where it is NOT necessary:**
- JPA Entities (Hibernate/Panache registers automatically)
- Internal domain models that never pass through Jackson
- Mappers and utility classes (not serialized)
