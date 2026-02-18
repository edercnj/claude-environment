# Template: Inbound Port (Interface)

## Pattern

```java
package com.bifrost.simulator.domain.port.inbound;

import com.bifrost.simulator.domain.model.Transaction;
import com.bifrost.simulator.domain.model.TransactionResult;

public interface AuthorizationPort {

    TransactionResult authorizeDebit(Transaction transaction);

    TransactionResult authorizeCredit(Transaction transaction);
}
```

## CHANGE THESE

- **Interface name**: `{Capability}Port` — describes what the domain offers
- **Methods**: One per use case the domain supports
- **Parameter/return types**: Domain models only (never DTOs, never entities)

## Critical Rules (memorize)

1. Inbound ports define what the domain CAN DO (offered services)
2. Only domain types in signatures (Records from `domain.model`)
3. No framework annotations (`@ApplicationScoped`, `@Inject`, etc.)
4. Interface — no implementation here
5. Located in `domain.port.inbound`

## Checklist

- [ ] Package is `domain.port.inbound`
- [ ] Interface (not class)
- [ ] Only JDK + domain model imports
- [ ] No framework annotations
- [ ] Method names describe domain operations (verbs)
