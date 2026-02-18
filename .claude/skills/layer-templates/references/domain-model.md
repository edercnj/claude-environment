# Template: Domain Model (Records, Enums, Sealed Interfaces)

## Pattern — Record (Value Object / Domain Entity)

```java
package com.bifrost.simulator.domain.model;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Optional;

public record Transaction(
    Long id,
    String stan,
    String mti,
    BigDecimal amount,
    String responseCode,
    String maskedPan,
    String terminalId,
    String merchantId,
    TransactionType type,
    TransactionStatus status,
    OffsetDateTime createdAt,
    OffsetDateTime updatedAt
) {
    public boolean isApproved() {
        return "00".equals(responseCode);
    }

    public Optional<String> merchantMcc() {
        return Optional.ofNullable(merchantId).map(id -> id.substring(0, 4));
    }
}
```

## Pattern — Enum

```java
package com.bifrost.simulator.domain.model;

public enum TransactionStatus {
    PENDING,
    APPROVED,
    DENIED,
    REVERSED,
    ERROR
}
```

## Pattern — Sealed Interface (Strategy)

```java
package com.bifrost.simulator.domain.model;

public sealed interface TransactionHandler permits
    DebitSaleHandler,
    ReversalHandler,
    EchoTestHandler {

    boolean supports(String mti, String processingCode);
    TransactionResult process(IsoMessage request);
}
```

## CHANGE THESE

- **Record fields**: Replace with domain fields from the Architect's plan
- **Enum values**: Replace with domain-specific values (UPPER_SNAKE_CASE)
- **Sealed permits**: List all concrete implementations

## Critical Rules (memorize)

1. Domain models have ZERO external dependencies (only JDK + b8583)
2. NO `jakarta.*`, `io.quarkus.*`, or adapter imports
3. NO `@RegisterForReflection` (domain models are not serialized via Jackson)
4. Use `Optional` for nullable query results
5. Enums use UPPER_SNAKE_CASE values, PascalCase type name

## Checklist

- [ ] Package is `domain.model`
- [ ] No external framework imports
- [ ] Record (immutable by design)
- [ ] Enum values in UPPER_SNAKE_CASE
- [ ] Sealed interface lists all `permits`
- [ ] No null returns — use Optional
