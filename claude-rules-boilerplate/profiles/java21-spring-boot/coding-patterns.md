# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Spring Boot — Coding Patterns

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

- Return `null` — use `Optional<T>` or empty collection
- Magic numbers/strings — use constants or enums
- `System.out.println` — use SLF4J (`LoggerFactory.getLogger()`)
- Field injection with `@Autowired` on fields — prefer constructor injection (implicit single-constructor)
- Mutable state in singleton beans (`@Service`, `@Component`)
- Using reflection directly in code that runs on native (use `@RegisterReflectionForBinding`)
- Heavy static initialization (static blocks with I/O, connections) — incompatible with native
- Dynamic proxy without prior registration — incompatible with GraalVM

### Lombok Policy

Lombok is **ALLOWED but optional** in Spring Boot projects (unlike Quarkus where it is FORBIDDEN). When used:
- Prefer `@Getter`, `@RequiredArgsConstructor`, `@Builder` — avoid `@Data` (mutable)
- NEVER use Lombok on Records — Records already provide accessors, equals, hashCode, toString
- NEVER use `@Setter` on entities with business invariants — use explicit methods
- If the team decides NOT to use Lombok, follow the same manual patterns as Quarkus

## Spring Dependency Injection

```java
// CORRECT — Constructor Injection (implicit, no @Autowired needed with single constructor)
@Service
public class TransactionService {
    private final TransactionRepository repository;
    private final AuthorizationEngine engine;

    public TransactionService(TransactionRepository repository, AuthorizationEngine engine) {
        this.repository = repository;
        this.engine = engine;
    }
}

// WRONG — Field Injection
@Service
public class TransactionService {
    @Autowired
    private TransactionRepository repository;
}
```

**Rules:**
- With a single constructor, Spring auto-injects without `@Autowired`
- With multiple constructors, annotate the injection constructor with `@Autowired`
- ALWAYS use `private final` fields for injected dependencies
- Stereotype annotations: `@Service` (business logic), `@Repository` (data access), `@Component` (generic), `@RestController` (REST endpoints)

## Spring Data JPA — Repository Pattern

```java
public interface MerchantRepository extends JpaRepository<MerchantEntity, Long> {

    Optional<MerchantEntity> findByMid(String mid);

    boolean existsByMid(String mid);

    @Query("SELECT m FROM MerchantEntity m WHERE m.status = :status")
    List<MerchantEntity> findAllByStatus(@Param("status") MerchantStatus status);
}
```

**Rules:**
- Extend `JpaRepository<Entity, Long>` for full CRUD + pagination
- Use derived query methods for simple queries (`findByMid`, `existsByTid`)
- Use `@Query` with JPQL for complex queries
- NEVER use native queries unless PostgreSQL-specific features are required
- Return `Optional<T>` for single-result queries, `List<T>` for collections

## REST Endpoints (Spring MVC)

```java
@RestController
@RequestMapping("/api/v1/merchants")
public class MerchantController {

    private final MerchantService merchantService;

    public MerchantController(MerchantService merchantService) {
        this.merchantService = merchantService;
    }

    @GetMapping
    public ResponseEntity<PaginatedResponse<MerchantResponse>> list(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int limit) {
        // ...
    }

    @PostMapping
    public ResponseEntity<MerchantResponse> create(@Valid @RequestBody CreateMerchantRequest request) {
        var merchant = merchantService.create(request);
        var response = MerchantDtoMapper.toResponse(merchant);
        var location = URI.create("/api/v1/merchants/" + merchant.id());
        return ResponseEntity.created(location).body(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<MerchantResponse> findById(@PathVariable Long id) {
        // ...
    }
}
```

### WebFlux Endpoints (Reactive Alternative)

```java
@RestController
@RequestMapping("/api/v1/merchants")
public class MerchantController {

    private final MerchantService merchantService;

    public MerchantController(MerchantService merchantService) {
        this.merchantService = merchantService;
    }

    @GetMapping
    public Flux<MerchantResponse> list() { ... }

    @PostMapping
    public Mono<ResponseEntity<MerchantResponse>> create(@Valid @RequestBody CreateMerchantRequest request) { ... }
}
```

**Rules:**
- Use Spring MVC for blocking/traditional apps, WebFlux for reactive
- NEVER mix MVC and WebFlux in the same module
- `@Valid` on `@RequestBody` for Bean Validation
- Return `ResponseEntity<T>` for explicit status codes and headers

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
| Controller      | PascalCase + Controller suffix            | `MerchantController`           |
| Service         | PascalCase + Service suffix               | `MerchantService`              |
| DTO Request     | PascalCase + Request suffix               | `CreateMerchantRequest`        |
| DTO Response    | PascalCase + Response suffix              | `MerchantResponse`             |
| Config Props    | PascalCase + Properties suffix            | `SimulatorProperties`          |

## Formatting

- Indentation: **4 spaces** (no tabs)
- Maximum width: **120 characters** per line
- Braces: **K&R style** (opening brace on same line)
- Imports: no wildcard (`*`), organized: java -> jakarta -> org.springframework -> com.{project} -> others

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
            log.warn("Unsupported MTI: {} from connection {}", mti, context.connectionId());
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

Mappers convert between layers. Two types:

### DTO Mappers (Inbound REST Layer)

Location: `adapter.inbound.rest.mapper` (or `web.mapper`)

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

### Entity Mappers (Outbound Persistence Layer)

Location: `adapter.outbound.persistence.mapper` (or `repository.mapper`)

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
| Spring       | WITHOUT `@Component` — not a Spring bean |
| MapStruct    | **ALLOWED** (unlike Quarkus native). Still prefer manual mappers for simplicity |
| Masking      | Masking logic (document, sensitive fields) lives in mapper that **exposes** data externally |
| Null safety  | Check nulls on optional fields (address, configuration) before mapping |
| Location     | DTO Mapper in REST/web layer, Entity Mapper in persistence layer |

> **Exception:** Mappers needing injected dependencies (e.g., `ObjectMapper` for JSON) MAY be `@Component` with constructor injection. In that case, use instance methods instead of `static`.

> **MapStruct Note:** MapStruct is compatible with Spring Boot and GraalVM native. If used, annotate mappers with `@Mapper(componentModel = "spring")` for DI integration. However, manual mappers are preferred for transparency and simplicity.

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
| Getter          | Getter for context field — used by `@ControllerAdvice` |
| Message         | `String.formatted()` — NEVER string concatenation with `+` |
| Sensitive data  | Mask in exception message (document, sensitive fields) |
| Location        | `domain.model` or `domain.exception` package |
| Naming          | `{Entity}{Problem}Exception` — e.g., `MerchantNotFoundException`, `TerminalAlreadyExistsException` |

## Global Exception Handling (@ControllerAdvice)

Spring Boot uses `@ControllerAdvice` instead of JAX-RS `ExceptionMapper`:

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(MerchantNotFoundException.class)
    public ResponseEntity<ProblemDetail> handleMerchantNotFound(MerchantNotFoundException ex, HttpServletRequest request) {
        var problem = ProblemDetail.notFound(
            "Merchant not found: " + ex.getIdentifier(), request.getRequestURI());
        return ResponseEntity.status(404).body(problem);
    }

    @ExceptionHandler(MerchantAlreadyExistsException.class)
    public ResponseEntity<ProblemDetail> handleMerchantConflict(MerchantAlreadyExistsException ex, HttpServletRequest request) {
        var problem = ProblemDetail.conflict(
            "Merchant with MID '%s' already exists".formatted(ex.getMid()),
            request.getRequestURI(), Map.of("existingMid", ex.getMid()));
        return ResponseEntity.status(409).body(problem);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ProblemDetail> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        var violations = ex.getBindingResult().getFieldErrors().stream()
            .collect(Collectors.groupingBy(
                FieldError::getField,
                Collectors.mapping(FieldError::getDefaultMessage, Collectors.toList())
            ));
        var problem = ProblemDetail.validationError("Validation failed", request.getRequestURI(), violations);
        return ResponseEntity.status(400).body(problem);
    }

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<ProblemDetail> handleUnexpected(RuntimeException ex, HttpServletRequest request) {
        log.error("Unexpected error on {}: {}", request.getRequestURI(), ex.getMessage(), ex);
        var problem = ProblemDetail.internalError("Internal processing error", request.getRequestURI());
        return ResponseEntity.status(500).body(problem);
    }
}
```
