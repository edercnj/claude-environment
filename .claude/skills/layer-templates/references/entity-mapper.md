# Template: Entity Mapper

## Pattern

```java
package com.bifrost.simulator.adapter.outbound.persistence.mapper;

import com.bifrost.simulator.adapter.outbound.persistence.entity.MerchantEntity;
import com.bifrost.simulator.domain.model.Merchant;
import com.bifrost.simulator.domain.model.MerchantStatus;
import java.time.OffsetDateTime;

public final class MerchantEntityMapper {

    private MerchantEntityMapper() {}

    public static MerchantEntity toEntity(Merchant merchant) {
        var entity = new MerchantEntity();
        entity.setMid(merchant.mid());
        entity.setLegalName(merchant.legalName());
        entity.setTradeName(merchant.tradeName());
        entity.setDocument(merchant.document());
        entity.setMcc(merchant.mccs().getFirst());
        entity.setStatus(merchant.status().name());
        entity.setForceTimeout(merchant.configuration().forceTimeout());
        entity.setTimeoutSeconds(merchant.configuration().timeoutSeconds());
        entity.setCreatedAt(OffsetDateTime.now());
        entity.setUpdatedAt(OffsetDateTime.now());
        return entity;
    }

    public static Merchant toDomain(MerchantEntity entity) {
        return new Merchant(
            entity.getId(),
            entity.getMid(),
            entity.getLegalName(),
            entity.getTradeName(),
            entity.getDocument(),
            java.util.List.of(entity.getMcc()),
            new com.bifrost.simulator.domain.model.MerchantConfiguration(
                entity.isForceTimeout(),
                entity.getTimeoutSeconds() != null ? entity.getTimeoutSeconds() : 0),
            MerchantStatus.valueOf(entity.getStatus()),
            entity.getCreatedAt(),
            entity.getUpdatedAt()
        );
    }
}
```

## CHANGE THESE

- **Class name**: `{Entity}EntityMapper`
- **toEntity()**: Map domain record fields to entity setters
- **toDomain()**: Map entity getters to domain record constructor
- **Null handling**: Check nullable fields before mapping

## Critical Rules (memorize)

1. `final class` + `private` constructor + `static` methods
2. NO `@ApplicationScoped` — not a CDI bean
3. NO `@RegisterForReflection` — not serialized
4. NO MapStruct — incompatible with native build
5. Located in `adapter.outbound.persistence.mapper`

## Checklist

- [ ] `final class`
- [ ] `private` constructor
- [ ] All methods `static`
- [ ] `toEntity()` and `toDomain()` methods present
- [ ] Null checks on optional fields
- [ ] No CDI annotations
- [ ] No MapStruct
