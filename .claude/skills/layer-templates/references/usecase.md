# Template: Use Case (Application Layer)

## Pattern

```java
package com.bifrost.simulator.application;

import com.bifrost.simulator.domain.model.Merchant;
import com.bifrost.simulator.domain.model.MerchantStatus;
import com.bifrost.simulator.domain.port.outbound.MerchantPersistencePort;
import com.bifrost.simulator.domain.exception.MerchantAlreadyExistsException;
import com.bifrost.simulator.domain.exception.MerchantNotFoundException;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.Optional;
import org.jboss.logging.Logger;

@ApplicationScoped
public class ManageMerchantUseCase {

    private static final Logger LOG = Logger.getLogger(ManageMerchantUseCase.class);

    private final MerchantPersistencePort persistencePort;

    @Inject
    public ManageMerchantUseCase(MerchantPersistencePort persistencePort) {
        this.persistencePort = persistencePort;
    }

    @Transactional
    public Merchant create(Merchant merchant) {
        if (persistencePort.existsByMid(merchant.mid())) {
            throw new MerchantAlreadyExistsException(merchant.mid());
        }
        return persistencePort.save(merchant);
    }

    public Optional<Merchant> findById(Long id) {
        return persistencePort.findById(id);
    }

    public List<Merchant> list(int page, int limit) {
        return persistencePort.list(page, limit);
    }

    public long count() {
        return persistencePort.count();
    }

    @Transactional
    public Merchant update(Long id, Merchant updated) {
        var existing = persistencePort.findById(id)
            .orElseThrow(() -> new MerchantNotFoundException(id.toString()));
        return persistencePort.save(mergeFields(existing, updated));
    }

    @Transactional
    public void deactivate(Long id) {
        var merchant = persistencePort.findById(id)
            .orElseThrow(() -> new MerchantNotFoundException(id.toString()));
        persistencePort.updateStatus(id, MerchantStatus.INACTIVE);
        LOG.infof("Merchant deactivated: mid=%s", merchant.mid());
    }

    private Merchant mergeFields(Merchant existing, Merchant updated) {
        return new Merchant(
            existing.id(),
            existing.mid(),
            updated.legalName() != null ? updated.legalName() : existing.legalName(),
            updated.tradeName() != null ? updated.tradeName() : existing.tradeName(),
            existing.document(),
            updated.mccs() != null ? updated.mccs() : existing.mccs(),
            updated.configuration() != null ? updated.configuration() : existing.configuration(),
            existing.status(),
            existing.createdAt(),
            null
        );
    }
}
```

## CHANGE THESE

- **Class name**: `{Action}{Entity}UseCase` (e.g., `ManageMerchantUseCase`, `AuthorizeDebitUseCase`)
- **Dependencies**: Inject outbound ports (interfaces, not implementations)
- **Methods**: One public method per use case operation
- **Business logic**: Orchestrate domain objects and ports

## Critical Rules (memorize)

1. `@ApplicationScoped` — stateless singleton
2. Constructor injection with `@Inject`
3. Depends on PORTS (interfaces), not adapters (implementations)
4. `@Transactional` on write operations
5. Methods <= 25 lines, one level of abstraction

## Checklist

- [ ] `@ApplicationScoped`
- [ ] Constructor injection (not field injection)
- [ ] Depends on port interfaces only
- [ ] `@Transactional` on create/update/delete
- [ ] `Optional<T>` for find operations
- [ ] Rich exceptions with context for not-found cases
- [ ] Logger present for significant operations
- [ ] Class <= 250 lines
