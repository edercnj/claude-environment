# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java — Coding Conventions

> Common conventions for all Java versions. Version-specific features are in separate version files.

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
| Controller      | PascalCase + Controller suffix            | `MerchantController`           |
| DTO Request     | PascalCase + Request suffix               | `CreateMerchantRequest`        |
| DTO Response    | PascalCase + Response suffix              | `MerchantResponse`             |
| Service         | PascalCase + Service suffix               | `TransactionService`           |

## Anti-Patterns (FORBIDDEN in any Java version)

- ❌ Return `null` — use `Optional<T>` or empty collection
- ❌ `System.out.println` — use SLF4J or framework logging
- ❌ Magic numbers/strings — use constants or enums
- ❌ Field injection without constructor — prefer constructor injection
- ❌ Mutable state in singleton beans
- ❌ Boolean flag as method parameter — create two distinct methods
- ❌ `String` concatenation with `+` in error messages — use `String.formatted()` (17+) or `String.format()`

## Constructor Injection (Universal)

Prefer constructor injection over field injection. Works with any DI framework (CDI, Spring, Guice).

```java
// ✅ CORRECT — Constructor injection
public class TransactionService {
    private final TransactionRepository repository;
    private final AuthorizationEngine engine;

    public TransactionService(TransactionRepository repository, AuthorizationEngine engine) {
        this.repository = repository;
        this.engine = engine;
    }
}

// ❌ WRONG — Field injection
public class TransactionService {
    @Inject
    TransactionRepository repository;
}
```

## Formatting

- Indentation: **4 spaces** (no tabs)
- Maximum width: **120 characters** per line
- Braces: **K&R style** (opening brace on same line)
- Imports: no wildcard (`*`), organized: java → jakarta/javax → com.{project} → others

### Method Signature — ONE LINE

Method signatures MUST fit on a single line, including all parameters.
Only break into multiple lines if exceeding 120 characters.

```java
// ✅ GOOD — signature on one line
private byte[] routeMessage(String mti, IsoMessage isoMessage, byte[] rawMessage, ConnectionContext context) {
    // ...
}

// ❌ BAD — unnecessary parameter break
private byte[] routeMessage(
        String mti,
        IsoMessage isoMessage,
        byte[] rawMessage,
        ConnectionContext context) {
```

## Mapper Pattern (Static Utility Classes)

Mappers convert between layers of architecture. Structure: `final class` + `private` constructor + `static` methods.

```java
public final class MerchantDtoMapper {

    private MerchantDtoMapper() {}

    public static Merchant toDomain(CreateMerchantRequest request) {
        return new Merchant(request.mid(), request.name(), request.document());
    }

    public static MerchantResponse toResponse(Merchant merchant) {
        return new MerchantResponse(merchant.id(), merchant.mid(), merchant.name(),
            maskDocument(merchant.document()));
    }

    private static String maskDocument(String document) {
        if (document == null || document.length() < 5) return "****";
        return document.substring(0, 3) + "****" + document.substring(document.length() - 2);
    }
}
```

### Mapper Rules

| Rule         | Detail |
|--------------|--------|
| Structure    | `final class` + `private` constructor + `static` methods |
| CDI/Spring   | NOT a managed bean — not needed |
| MapStruct    | **FORBIDDEN** unless explicitly required by project config |
| Masking      | Masking logic lives in mapper that **exposes** data externally |
| Null safety  | Check nulls on optional fields before mapping |
| Location     | DTO Mapper in inbound adapter, Entity Mapper in outbound adapter |

> **Exception:** Mappers needing injected dependencies MAY be managed beans with constructor injection and instance methods.

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
```

### Domain Exception Rules

| Rule            | Detail |
|-----------------|--------|
| Inheritance     | Extends `RuntimeException` (unchecked) — NEVER checked exceptions |
| Context         | Private field with value that caused error |
| Getter          | Getter for context field — used by ExceptionMapper |
| Message         | `String.formatted()` (Java 15+) or `String.format()` (older) — NEVER `+` concatenation |
| Sensitive data  | Mask in exception message |
| Location        | `domain.model` or `domain.exception` package |
| Naming          | `{Entity}{Problem}Exception` — e.g., `MerchantNotFoundException` |

## Clean Code Rules (CC-01 to CC-10)

### CC-01: Names That Reveal Intent

- Names should reveal intent: `elapsedTimeInMs` not `d`
- Avoid misinformation: don't use `accountList` if not a `List`
- Meaningful distinctions: `source` / `destination` not `a1` / `a2`
- Pronounceable names: `createdAt` not `crtdTmst`
- Searchable names: named constants, not literal values
- No Hungarian prefixes: `name` not `strName`
- Verbs for methods: `processTransaction()`, `extractAmount()`
- Nouns for classes: `TransactionHandler`, `MerchantRepository`

### CC-02: Functions Do ONE Thing

- Maximum **25 lines** per method
- Maximum **4 parameters** (if more → create a Record/class as parameter)
- One level of abstraction per function (Stepdown Rule)
- ❌ FORBIDDEN `boolean` flag as parameter — create two distinct methods
- ❌ FORBIDDEN hidden side effects

### CC-03: Single Responsibility

- Maximum **250 lines** per class
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

If you copy code → extract method or utility class.

### CC-06: Rich Error Handling

- NEVER return `null` — use `Optional<T>` or empty collection
- NEVER pass `null` as argument
- Prefer unchecked exceptions (RuntimeException)
- Catch at the right level

### CC-07: Self-Documenting Code

- Javadoc ONLY when it adds real value
- FORBIDDEN Javadoc boilerplate that repeats method name
- Inline comments ONLY for non-obvious business logic

### CC-08: Vertical Formatting

| Where                                         | Blank line? |
| --------------------------------------------- | ----------- |
| Between constants and fields                  | ✅ Yes      |
| Between fields and constructor                | ✅ Yes      |
| Between constructor and public methods        | ✅ Yes      |
| Between methods                               | ✅ Always   |
| Within method: between logical blocks         | ✅ Yes      |
| Within method: related lines                  | ❌ No       |
| After class opening `{`                       | ❌ No       |
| Before closing `}`                            | ❌ No       |

**Ordering within class (Newspaper Rule):**
1. Constants (`private static final`)
2. Logger
3. Instance fields (`private final`)
4. Constructor(s)
5. Public methods
6. Package-private methods
7. Private methods (in order called by public methods)

### CC-09: Law of Demeter

```java
// ❌ BAD — train wreck
var mcc = transaction.getMerchant().getTerminal().getMcc();

// ✅ GOOD — ask directly
var mcc = transaction.getMerchantMcc();
```

### CC-10: Class Organization

- Classes should be small — measured by responsibilities
- High cohesion: methods use most fields
- If a method subset uses only a field subset → extract class

## SOLID Principles (Java)

### SRP — Single Responsibility
Each class has ONE reason to change.

### OCP — Open/Closed
New behavior = new class, NEVER modify existing handlers. Use interfaces with Strategy pattern.

### LSP — Liskov Substitution
Every implementation must be substitutable without breaking callers.

### ISP — Interface Segregation
Small, focused interfaces. Prefer many small interfaces over one large interface.

### DIP — Dependency Inversion
- Domain NEVER depends on infrastructure
- Use interfaces (ports), not concrete implementations
