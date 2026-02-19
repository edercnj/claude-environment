# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 11 — Version-Specific Features

> Extends: `languages/java/common/coding-conventions.md`

## Available Features

| Feature    | Usage                                | Since  |
| ---------- | ------------------------------------ | ------ |
| var        | Local variables with obvious type    | Java 10 |
| Optional   | Search returns (NEVER return null)   | Java 8  |
| Stream API | Collection processing                | Java 8  |
| HttpClient | HTTP/2 client (java.net.http)       | Java 11 |

## NOT Available in Java 11

| Feature | Available Since | Alternative |
|---------|----------------|-------------|
| Records | Java 16 | Immutable classes or Lombok |
| Sealed Interfaces | Java 17 | Interface + Strategy pattern |
| Text Blocks | Java 13 | String concatenation or `String.format()` |
| Pattern Matching (instanceof) | Java 16 | Explicit `instanceof` + cast |
| Pattern Matching (switch) | Java 21 | `if-else` chains or visitor pattern |
| Virtual Threads | Java 21 | Thread pools, reactive |

## DTO Pattern (without Records)

Since Records are not available in Java 11, use immutable classes:

```java
// Option A: Manual immutable class (preferred in Quarkus)
public final class MerchantResponse {
    private final Long id;
    private final String mid;
    private final String name;

    public MerchantResponse(Long id, String mid, String name) {
        this.id = id;
        this.mid = mid;
        this.name = name;
    }

    public Long getId() { return id; }
    public String getMid() { return mid; }
    public String getName() { return name; }

    // equals, hashCode, toString should be implemented
}

// Option B: Lombok (if allowed by framework — e.g., Spring Boot)
@Value
public class MerchantResponse {
    Long id;
    String mid;
    String name;
}
```

## Handler Pattern (without Sealed Interfaces)

Use interface + enum or Strategy pattern:

```java
public interface TransactionHandler {
    boolean supports(String mti, String processingCode);
    TransactionResult process(IsoMessage request);
}

// Implementations are open — cannot enforce exhaustiveness like sealed
public class DebitSaleHandler implements TransactionHandler { ... }
public class ReversalHandler implements TransactionHandler { ... }
```

## Error Messages (without String.formatted)

```java
// ✅ GOOD (Java 11) — String.format()
throw new MerchantNotFoundException(
    String.format("Merchant not found: %s", identifier));

// ❌ BAD — string concatenation
throw new MerchantNotFoundException("Merchant not found: " + identifier);
```

## SQL Queries (without Text Blocks)

```java
// Java 11 — no text blocks, use string concatenation
private static final String FIND_BY_MERCHANT =
    "SELECT t.id, t.mti, t.stan, t.response_code " +
    "FROM simulator.transactions t " +
    "WHERE t.merchant_id = :merchantId " +
    "ORDER BY t.created_at DESC";
```
