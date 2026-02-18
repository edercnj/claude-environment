# Template: Outbound Port (Interface)

## Pattern

```java
package com.bifrost.simulator.domain.port.outbound;

import com.bifrost.simulator.domain.model.Transaction;
import java.util.Optional;

public interface PersistencePort {

    void save(Transaction transaction);

    Optional<Transaction> findByStanAndDate(String stan, String date);

    Optional<Transaction> findById(Long id);
}
```

## CHANGE THESE

- **Interface name**: `{Capability}Port` — describes what the domain needs
- **Methods**: One per external operation the domain requires
- **Return types**: `Optional<T>` for queries, `void` for commands

## Critical Rules (memorize)

1. Outbound ports define what the domain NEEDS (required services)
2. Implemented by adapters (e.g., `PostgresPersistenceAdapter`)
3. Only domain types — never JPA entities, never DTOs
4. Queries return `Optional<T>` — NEVER return null
5. Commands return `void` — Command-Query Separation (CQS)

## Checklist

- [ ] Package is `domain.port.outbound`
- [ ] Interface (not class)
- [ ] Only JDK + domain model imports
- [ ] Queries return `Optional<T>`
- [ ] Commands return `void`
- [ ] No framework annotations
