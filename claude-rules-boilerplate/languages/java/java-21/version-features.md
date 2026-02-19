# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 — Version-Specific Features

> Extends: `languages/java/common/coding-conventions.md`

## Mandatory Features

| Feature                   | Usage                                      | Since  |
| ------------------------- | ------------------------------------------ | ------ |
| Records                   | DTOs, Value Objects, Events, Responses    | Java 16 |
| Sealed Interfaces         | Decision strategies, handler hierarchies  | Java 17 |
| Pattern Matching (switch) | Routing, type-based decisions              | Java 21 |
| Text Blocks               | Complex SQL queries, log templates, JSON   | Java 13 |
| Optional                  | Search returns (NEVER return null)         | Java 8  |
| var                       | Local variables with obvious type          | Java 10 |

## Records — Mandatory for DTOs

Records MUST be used for all data transfer objects, value objects, and responses.

```java
// ✅ GOOD (Java 21)
public record MerchantResponse(Long id, String mid, String name, String status) {}

// ❌ BAD (Java 21) — unnecessary class when Record suffices
public class MerchantResponse {
    private final Long id;
    private final String mid;
    // ... boilerplate
}
```

## Sealed Interfaces — Mandatory for Strategies

```java
public sealed interface TransactionHandler permits
    DebitSaleHandler, CreditSaleHandler, ReversalHandler, EchoTestHandler {

    boolean supports(String mti, String processingCode);
    TransactionResult process(IsoMessage request);
}
```

## Pattern Matching Switch — Mandatory for Routing

```java
var problemDetail = switch (exception) {
    case MerchantNotFoundException e -> ProblemDetail.notFound(e.getMessage(), path);
    case DuplicateException e -> ProblemDetail.conflict(e.getMessage(), path);
    case ValidationException e -> ProblemDetail.badRequest(e.getMessage(), path);
    default -> {
        LOG.error("Unexpected error", exception);
        yield ProblemDetail.internalError("Internal error", path);
    }
};
```

## Text Blocks

```java
var query = """
    SELECT t.id, t.mti, t.stan, t.response_code
    FROM simulator.transactions t
    WHERE t.merchant_id = :merchantId
      AND t.created_at >= :startDate
    ORDER BY t.created_at DESC
    """;
```

## Virtual Threads (Java 21)

Consider virtual threads for I/O-bound operations. Framework support required:
- Quarkus 3.17+ supports virtual threads natively
- Spring Boot 3.2+ supports virtual threads via configuration

**Note:** Virtual threads are NOT a replacement for reactive programming. Use them for blocking I/O operations only.

## Sequenced Collections (Java 21)

```java
SequencedCollection<String> list = new ArrayList<>();
list.addFirst("first");
list.addLast("last");
String first = list.getFirst();
String last = list.getLast();
```
