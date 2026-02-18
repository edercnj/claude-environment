# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 02 — Java 21 + Quarkus Code Patterns

## Java 21 — Mandatory Features

| Feature                   | Usage                                      |
| ------------------------- | ------------------------------------------ |
| Records                   | DTOs, Value Objects, Events, Responses    |
| Sealed Interfaces         | Decision strategies, transaction types     |
| Pattern Matching (switch) | MTI routing, type-based decisions          |
| Text Blocks               | Complex SQL queries, log templates         |
| Optional                  | Search returns (NEVER return null)         |
| var                       | Local variables with obvious type          |

## Anti-Patterns (FORBIDDEN)

- ❌ Lombok (Quarkus has its own facilities)
- ❌ Return `null` — use `Optional<T>` or empty collection
- ❌ Magic numbers/strings — use constants or enums
- ❌ `System.out.println` — use `java.util.logging` or SLF4J via Quarkus
- ❌ Field injection with `@Inject` on private fields without constructor — prefer constructor injection
- ❌ Blocking Vert.x event loop with long synchronous operations
- ❌ Mutable state in CDI beans `@ApplicationScoped`
- ❌ Using reflection directly in code that runs on native (use `@RegisterForReflection`)
- ❌ Heavy static initialization (static blocks with I/O, connections) — incompatible with native
- ❌ Dynamic proxy without prior registration — incompatible with GraalVM

## Quarkus — Mandatory Patterns

### CDI (Contexts and Dependency Injection)

```java
// ✅ CORRECT — Constructor Injection (signature on one line)
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

// ❌ WRONG — Field Injection without constructor
@ApplicationScoped
public class TransactionService {
    @Inject
    TransactionRepository repository;
}
```

### Panache — Repository Pattern

```java
// ✅ CORRECT — Repository Pattern with Panache
@ApplicationScoped
public class MerchantRepository implements PanacheRepository<MerchantEntity> {
    public Optional<MerchantEntity> findByMid(String mid) {
        return find("mid", mid).firstResultOptional();
    }
}
```

### REST Endpoints

```java
// ✅ CORRECT — RESTEasy Reactive
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
| Package         | lowercase                                 | `com.bifrost.simulator.domain` |
| Entity          | PascalCase + Entity suffix                | `TransactionEntity`            |
| Repository      | PascalCase + Repository suffix            | `TransactionRepository`        |
| Resource (REST) | PascalCase + Resource suffix              | `MerchantResource`             |
| DTO Request     | PascalCase + Request suffix               | `CreateMerchantRequest`        |
| DTO Response    | PascalCase + Response suffix              | `MerchantResponse`             |

## Formatting

- Indentation: **4 spaces** (no tabs)
- Maximum width: **120 characters** per line (relaxed from 100 for Quarkus)
- Braces: **K&R style** (opening brace on same line)
- Imports: no wildcard (`*`), organized (java → jakarta → com.bifrost → others)

### Method Signature — ONE LINE

Method signatures MUST fit on a single line, including all parameters.
Only break into multiple lines if exceeding 120 characters.

```java
// ✅ GOOD — signature on one line
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

// ❌ BAD — unnecessary parameter break
private byte[] routeMessage(
        String mti,
        IsoMessage isoMessage,
        byte[] rawMessage,
        ConnectionContext context) {
```

### Clean and Concise Code — No Noise

- ❌ **FORBIDDEN** obvious comments that repeat what the code already says
- ❌ **FORBIDDEN** empty boilerplate Javadoc (`@param name the name`, `@return the result`)
- ✅ Self-documenting code: clear names eliminate comments
- ✅ Comments ONLY when explaining the **why**, never the **what**

```java
// ❌ BAD — comment that repeats the code
/** Returns the response code. */
public String getResponseCode() { return responseCode; }

// ❌ BAD — Javadoc boilerplate with no value
/**
 * Process the transaction.
 * @param request the request
 * @return the result
 */
public TransactionResult process(IsoMessage request) { ... }

// ✅ GOOD — no comment, the name explains everything
public TransactionResult processDebitTransaction(IsoMessage request) { ... }

// ✅ GOOD — comment explains non-obvious business rule
// Cents .00 to .50 = approved, .51+ maps to specific RC (RULE-001)
var responseCode = centsDecisionEngine.decide(amount);
```

## Clean Code (CC-01 to CC-07)

### CC-01: Names That Reveal Intent

```java
// ✅ GOOD
TransactionResult authorizeTransaction(IsoMessage request)
// ❌ BAD
Object process(Object msg)
```

**Naming Rules (Clean Code Ch. 2):**

- Names should reveal intent: `elapsedTimeInMs` not `d`
- Avoid misinformation: don't use `accountList` if not a `List` — use `accounts` or `accountGroup`
- Meaningful distinctions: `source` / `destination` not `a1` / `a2`
- Pronounceable names: `createdAt` not `crtdTmst`
- Searchable names: named constants, not literal values scattered in code
- No Hungarian prefixes: `name` not `strName`, `count` not `iCount`
- No mental mapping: `merchant` not `m`, `transaction` not `t` (except short lambdas with obvious context)
- Verbs for methods: `processTransaction()`, `extractAmount()`, `buildResponse()`
- Nouns for classes: `TransactionHandler`, `CentsDecisionEngine`, `MerchantRepository`

### CC-02: Functions Do ONE Thing

- Maximum **25 lines** per method (relaxed from 20 to include CDI boilerplate)
- Maximum **4 parameters** (relaxed from 3 to include injections)
- If more needed → create a Record as parameter
- **One level of abstraction per function** (Stepdown Rule): read the method top-to-bottom as a narrative
- ❌ **FORBIDDEN** `boolean` flag as parameter — create two distinct methods
- ❌ **FORBIDDEN** hidden side effects: method `validateTransaction()` MUST NOT persist

```java
// ✅ GOOD — one level of abstraction, reads as narrative
public TransactionResult authorizeDebitTransaction(IsoMessage request) {
    var amount = extractAmount(request);
    var responseCode = centsDecisionEngine.decide(amount);
    var transaction = buildTransaction(request, responseCode);
    persistencePort.save(transaction);
    return buildResponse(request, responseCode, transaction);
}

// ❌ BAD — mixes abstraction levels
public TransactionResult authorizeDebitTransaction(IsoMessage request) {
    byte[] field4 = request.getField(4);
    String amountStr = new String(field4, StandardCharsets.US_ASCII);
    var amount = new BigDecimal(amountStr).movePointLeft(2);
    // ... 30 lines mixing low-level parsing with business logic
}

// ❌ BAD — flag argument
public void processTransaction(IsoMessage msg, boolean isReversal) { ... }
// ✅ GOOD — separate methods
public void processDebitSale(IsoMessage msg) { ... }
public void processReversal(IsoMessage msg) { ... }
```

### CC-03: Single Responsibility

- Maximum **250 lines** per class (relaxed from 200 for Entities with JPA annotations)
- One class = one reason to change

### CC-04: No Magic Values

```java
// ✅ GOOD
private static final String RESPONSE_APPROVED = "00";
private static final int TIMEOUT_SECONDS = 35;
// ❌ BAD
if (responseCode.equals("00")) ...
Thread.sleep(35000);
```

### CC-05: DRY (Don't Repeat Yourself)

- If you copy code → extract method or utility class

### CC-06: Rich Error Handling

```java
// ✅ GOOD — Exception with context
throw new TransactionProcessingException(
    "Failed to authorize transaction",
    Map.of("mti", mti, "stan", stan, "mid", merchantId)
);
```

- NEVER return `null` — use `Optional<T>` or empty collection
- NEVER pass `null` as argument — use overload or Optional
- Prefer unchecked exceptions (RuntimeException) — checked exceptions pollute the signature
- Catch at the right level: capture exceptions where you can handle them, not where it's convenient
- For resilience patterns (`@CircuitBreaker`, `@Retry`, `@Timeout`, `@Bulkhead`, `@Fallback`), follow **Rule 24 — Application Resilience**

### CC-07: Self-Documenting Code

- Javadoc ONLY when it adds real value (public port interfaces, complex business rules)
- **FORBIDDEN** Javadoc boilerplate that repeats method name or parameters
- Inline comments ONLY for non-obvious business logic (e.g., cents rule)
- If method name already explains what it does → do NOT add Javadoc

### CC-08: Vertical Formatting (Clean Code Ch. 5)

**Blank lines separate CONCEPTS. No blank lines group RELATED items.**

```java
// ✅ GOOD — blank lines between different concepts
@ApplicationScoped
public class DebitAuthorizationHandler {

    private static final Logger LOG = Logger.getLogger(DebitAuthorizationHandler.class);
    private static final String MTI_DEBIT_RESPONSE = "1210";

    private final CentsDecisionEngine decisionEngine;
    private final PersistencePort persistencePort;

    @Inject
    public DebitAuthorizationHandler(CentsDecisionEngine decisionEngine, PersistencePort persistencePort) {
        this.decisionEngine = decisionEngine;
        this.persistencePort = persistencePort;
    }

    public TransactionResult process(IsoMessage request) {
        var amount = extractAmount(request);
        var responseCode = decisionEngine.decide(amount);

        var transaction = buildTransaction(request, responseCode);
        persistencePort.save(transaction);

        return buildResponse(request, responseCode, transaction);
    }

    private BigDecimal extractAmount(IsoMessage request) {
        // ...
    }

    private Transaction buildTransaction(IsoMessage request, String responseCode) {
        // ...
    }

    private TransactionResult buildResponse(IsoMessage request, String responseCode, Transaction tx) {
        // ...
    }
}
```

**Vertical spacing rules:**

| Where                                         | Blank line? | Reason                              |
| --------------------------------------------- | ----------- | ----------------------------------- |
| Between constants and fields                  | ✅ Yes      | Separates configuration from state  |
| Between fields and constructor                | ✅ Yes      | Separates state from initialization |
| Between constructor and public methods        | ✅ Yes      | Separates init from behavior        |
| Between methods                               | ✅ Always   | Each method is a concept            |
| Within method: between logical blocks         | ✅ Yes      | Separates processing stages         |
| Within method: related lines                  | ❌ No       | Maintains visual cohesion            |
| Between import groups                         | ✅ Yes      | java → jakarta → com.bifrost        |
| After class opening `{`                       | ❌ No       | Blank line right after `{` is noise |
| Before closing `}`                            | ❌ No       | Blank line before `}` is noise      |

**Ordering within class (Newspaper Rule):**

1. Constants (`private static final`)
2. Logger
3. Instance fields (`private final`)
4. Constructor(s)
5. Public methods (class API)
6. Package-private methods
7. Private methods (in order called by public methods)

### CC-09: Law of Demeter (Don't Talk to Strangers)

```java
// ❌ BAD — train wreck, couples 3 objects
var mcc = transaction.getMerchant().getTerminal().getMcc();

// ✅ GOOD — ask directly from who knows
var mcc = transaction.getMerchantMcc();
```

### CC-10: Class Organization (Clean Code Ch. 10)

- Classes should be **small** — measured by responsibilities, not lines
- High cohesion: methods use most fields of the class
- If a method subset uses only a field subset → extract class
- Prefer many small classes to few large classes

## SOLID

### SRP — Single Responsibility

Each class has ONE reason to change:

- `SocketServer` → manages TCP connections
- `MessageRouter` → routes by MTI
- `DebitAuthorizationHandler` → processes debit
- `CentsDecisionEngine` → decides RC by cents

### OCP — Open/Closed

New transaction type = new Handler class, NEVER modifies existing handlers.
Use `sealed interface TransactionHandler` with `permits`.

### LSP — Liskov Substitution

Every `TransactionHandler` must be substitutable without breaking `MessageRouter`.

### ISP — Interface Segregation

Small, focused interfaces:

- `TransactionHandler` → processTransaction()
- `Persistable` → persist(), find()
- `HealthCheckable` → healthCheck()

### DIP — Dependency Inversion

- Domain NEVER depends on infrastructure
- Use CDI `@Inject` with interfaces, not concrete implementations

## Mapper Pattern (Static Utility Classes)

Mappers convert between layers of hexagonal architecture. Two types exist:

### DTO Mappers (Inbound REST Adapter)

Location: `adapter.inbound.rest.mapper`
Responsibility: Convert between REST DTOs (request/response) and domain models.

```java
// ✅ CORRECT — final class + private constructor + static methods
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
            maskDocument(merchant.document()),  // Masking in output mapper
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
Responsibility: Convert between domain models and JPA Entities.

```java
// ✅ CORRECT — final class + private constructor + static methods
public final class MerchantEntityMapper {

    private MerchantEntityMapper() {}

    public static MerchantEntity toEntity(Merchant merchant) {
        var entity = new MerchantEntity();
        entity.setMid(merchant.mid());
        entity.setLegalName(merchant.legalName());
        entity.setDocument(merchant.document());
        entity.setMccs(String.join(",", merchant.mccs()));
        // ...
        return entity;
    }

    public static Merchant toDomain(MerchantEntity entity) {
        return new Merchant(
            entity.getId(),
            entity.getMid(),
            entity.getLegalName(),
            entity.getDocument(),
            Arrays.asList(entity.getMccs().split(",")),
            // ...
        );
    }
}
```

**Mapper Rules:**

| Rule         | Detail |
|--------------|--------|
| Structure    | `final class` + `private` constructor + `static` methods |
| CDI          | WITHOUT `@ApplicationScoped` — not a CDI bean |
| Reflection   | WITHOUT `@RegisterForReflection` — not serialized |
| MapStruct    | **FORBIDDEN** — incompatible with native build without extra config |
| Masking      | Masking logic (document, PAN) lives in mapper that **exposes** data externally |
| Null safety  | Check nulls on optional fields (address, configuration) before mapping |
| Location     | DTO Mapper in `adapter.inbound.rest.mapper`, Entity Mapper in `adapter.outbound.persistence.mapper` |

> **Exception:** Mappers needing injected dependencies (e.g., `ObjectMapper` for JSON) MAY be `@ApplicationScoped` with constructor injection. In that case, use instance methods instead of `static`.

## Domain Exception with Context

Domain exceptions follow a consistent pattern:

```java
// ✅ CORRECT — RuntimeException + context + getter + String.formatted()
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

// ✅ CORRECT — Masking sensitive data in message
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

**Domain Exception Rules:**

| Rule            | Detail |
|-----------------|--------|
| Inheritance     | Extends `RuntimeException` (unchecked) — NEVER checked exceptions |
| Context         | Private field with value that caused error (mid, tid, identifier) |
| Getter          | Getter for context field — used by ExceptionMapper |
| Message         | `String.formatted()` — NEVER string concatenation with `+` |
| Sensitive data  | Mask in exception message (document, PAN) |
| Location        | `domain.model` or `domain.exception` package |
| Naming          | `{Entity}{Problem}Exception` — e.g: `MerchantNotFoundException`, `TerminalAlreadyExistsException` |

## @RegisterForReflection in REST DTOs

**Mandatory** on ALL records used in REST serialization/deserialization (Jackson):

```java
// ✅ Mandatory on requests
@RegisterForReflection
public record CreateMerchantRequest(...) {}

// ✅ Mandatory on responses
@RegisterForReflection
public record MerchantResponse(...) {}

// ✅ Mandatory on error responses
@RegisterForReflection
public record ProblemDetail(...) {}

// ✅ Mandatory on generic wrappers
@RegisterForReflection
public record PaginatedResponse<T>(...) {
    @RegisterForReflection
    public record PaginationInfo(...) {}  // Nested record ALSO needs it
}

// ✅ Mandatory on nested records in request/response
@RegisterForReflection
public record AddressRequest(...) {}
```

**Where it's mandatory:**
- REST requests (records with `@NotBlank`, `@Size`, etc.)
- REST responses (records returned by endpoints)
- ProblemDetail and error variants
- PaginatedResponse and PaginationInfo
- Nested records used within requests/responses
- Enums deserialized via Jackson

**Where it's NOT necessary:**
- JPA Entities (Hibernate/Panache registers automatically)
- Internal domain models that never pass through Jackson
- Mappers and utility classes (not serialized)

## Quarkus Native — Mandatory Restrictions

The project uses **Quarkus Native Build** (GraalVM/Mandrel) for production. This imposes additional code restrictions:

### Native Compatibility

| Allowed                                            | Forbidden                               |
| -------------------------------------------------- | --------------------------------------- |
| CDI (`@ApplicationScoped`, `@Inject`)              | Reflection without `@RegisterForReflection` |
| Records (natively supported)                       | Dynamic `Class.forName()`               |
| Sealed interfaces (natively supported)             | Dynamic proxies without config          |
| Jackson serialization (with `@RegisterForReflection`) | Static initialization with I/O          |
| Panache repositories                               | Dynamic classloading at runtime         |
| Vert.x handlers                                    | `java.lang.reflect.Proxy` without registry |

### Mandatory Annotations for Native

```java
// ✅ DTOs to be serialized via Jackson (REST API)
@RegisterForReflection
public record MerchantResponse(String mid, String name, String status) {}

// ✅ JPA Entities (Hibernate registers automatically via Panache)
// Does NOT need @RegisterForReflection if using Panache

// ✅ Enums used in deserialization
@RegisterForReflection
public enum TransactionStatus { PENDING, APPROVED, DENIED, REVERSED }
```

### Build Profiles

```properties
# Dev (JVM mode — hot reload)
mvn quarkus:dev

# Test (JVM mode — Testcontainers)
mvn verify

# Production (Native — GraalVM/Mandrel)
mvn package -Dnative -Dquarkus.native.container-build=true
```

### Performance Targets (Native)

| Metric                | Target     |
| --------------------- | ---------- |
| Startup time          | < 100ms    |
| RSS Memory (idle)     | < 128MB    |
| First request latency | < 50ms     |
| Throughput (ISO 8583) | > 1000 TPS |

## Clean Code — Extended Reference

The project strictly follows **Clean Code** principles (Robert C. Martin). Rules CC-01 to CC-07 above are MANDATORY, but follow expanded guidelines:

### Clean Functions

```java
// ✅ GOOD — Small function, does ONE thing, descriptive name
public TransactionResult authorizeDebitTransaction(IsoMessage request) {
    var amount = extractAmount(request);
    var responseCode = centsDecisionEngine.decide(amount);
    var transaction = buildTransaction(request, responseCode);
    persistencePort.save(transaction);
    return buildResponse(request, responseCode, transaction);
}

// ❌ BAD — Function does many things, generic name
public Object process(Object msg) {
    // 50 lines of code mixing parsing, validation, persistence and response
}
```

### Error Handling as First-Class Citizen

```java
// ✅ GOOD — Rich exception hierarchy, complete context
public sealed interface SimulatorException permits
    TransactionProcessingException,
    MessageParsingException,
    MerchantNotFoundException,
    TimeoutSimulationException {

    String message();
    Map<String, Object> context();
}

// ✅ GOOD — Each exception carries sufficient context for debugging
throw new TransactionProcessingException(
    "Cents rule returned denial",
    Map.of("mti", "1200", "amount", "100.51", "rc", "51", "stan", "123456")
);
```

### Command-Query Separation (CQS)

```java
// ✅ GOOD — Commands don't return, queries don't modify state
void persistTransaction(Transaction tx);                     // Command
Optional<Transaction> findByStanAndDate(String stan, String date); // Query

// ❌ BAD — Mixes command and query
Transaction saveAndReturn(Transaction tx); // Command that returns = ambiguous
```

## SOLID — Extended Reference with Project Examples

### SRP — Single Responsibility (Concrete Examples)

```java
// ✅ Each class has ONE reason to change
class TcpServer { }                    // Reason: network protocol changes
class MessageFrameDecoder { }          // Reason: framing protocol changes
class MessageRouter { }                // Reason: routing rules change
class CentsDecisionEngine { }          // Reason: cents rule changes
class TransactionRepository { }        // Reason: database schema changes
class MerchantResource { }             // Reason: REST API contract changes

// ❌ BAD — Class does everything (God Class)
class TransactionManager {
    void receiveFromSocket() { }       // Network
    void parseIsoMessage() { }         // Parsing
    void validateMcc() { }             // Business
    void saveToDatabase() { }          // Persistence
    void buildResponse() { }           // Serialization
}
```

### OCP — Open/Closed (Strategy Pattern for Handlers)

```java
// ✅ New transaction type = NEW class, ZERO changes to existing
public sealed interface TransactionHandler permits
    DebitSaleHandler,
    CreditSaleHandler,
    ReversalHandler,
    PreAuthHandler,
    EchoTestHandler,
    VoucherHandler,
    TransportHandler {

    boolean supports(String mti, String processingCode);
    TransactionResult process(IsoMessage request);
}

// ✅ Router uses polymorphism, NEVER switch/if-else on MTI
@ApplicationScoped
public class MessageRouter {
    private final List<TransactionHandler> handlers;

    public TransactionResult route(IsoMessage message) {
        return handlers.stream()
            .filter(h -> h.supports(message.getMti(), message.getProcessingCode()))
            .findFirst()
            .orElseThrow(() -> new UnsupportedTransactionException(message.getMti()))
            .process(message);
    }
}
```

### DIP — Dependency Inversion (Ports & Adapters in Practice)

```java
// ✅ Domain defines PORT (interface)
// domain/port/outbound/PersistencePort.java
public interface PersistencePort {
    void save(Transaction transaction);
    Optional<Transaction> findByStanAndDate(String stan, String date);
}

// ✅ Adapter IMPLEMENTS the port
// adapter/outbound/persistence/PostgresPersistenceAdapter.java
@ApplicationScoped
public class PostgresPersistenceAdapter implements PersistencePort {
    private final TransactionRepository repository;
    private final TransactionEntityMapper mapper;
    // ...
}

// ✅ Application uses the PORT, not the adapter
// application/AuthorizeTransactionUseCase.java
@ApplicationScoped
public class AuthorizeTransactionUseCase {
    private final PersistencePort persistence; // Interface, not PostgresAdapter
    // ...
}
```
