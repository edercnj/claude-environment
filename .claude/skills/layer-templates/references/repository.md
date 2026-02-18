# Template: Repository (Panache)

## Pattern

```java
package com.bifrost.simulator.adapter.outbound.persistence.repository;

import com.bifrost.simulator.adapter.outbound.persistence.entity.MerchantEntity;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.Optional;

@ApplicationScoped
public class MerchantRepository implements PanacheRepository<MerchantEntity> {

    public Optional<MerchantEntity> findByMid(String mid) {
        return find("mid", mid).firstResultOptional();
    }

    public boolean existsByMid(String mid) {
        return count("mid", mid) > 0;
    }

    public long countByStatus(String status) {
        return count("status", status);
    }
}
```

## CHANGE THESE

- **Class name**: `{Entity}Repository`
- **Entity type parameter**: `PanacheRepository<{Entity}Entity>`
- **Query methods**: Add domain-specific finders per the Architect's plan
- **Return types**: `Optional<T>` for single results, `List<T>` for collections

## Critical Rules (memorize)

1. `@ApplicationScoped` — CDI singleton
2. `implements PanacheRepository<{Entity}Entity>`
3. Queries return `Optional` for single results — NEVER null
4. Use Panache query methods: `find()`, `count()`, `list()`
5. Parameterized queries only — NEVER string concatenation in queries

## Checklist

- [ ] `@ApplicationScoped`
- [ ] `implements PanacheRepository<XxxEntity>`
- [ ] All single-result finders return `Optional<T>`
- [ ] Parameterized queries (no SQL injection risk)
- [ ] Located in `adapter.outbound.persistence.repository`
