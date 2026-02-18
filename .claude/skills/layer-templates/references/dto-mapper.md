# Template: DTO Mapper (Inbound REST)

## Pattern

```java
package com.bifrost.simulator.adapter.inbound.rest.mapper;

import com.bifrost.simulator.adapter.inbound.rest.dto.CreateMerchantRequest;
import com.bifrost.simulator.adapter.inbound.rest.dto.MerchantResponse;
import com.bifrost.simulator.domain.model.Merchant;
import com.bifrost.simulator.domain.model.MerchantConfiguration;
import com.bifrost.simulator.domain.model.MerchantStatus;
import java.util.List;

public final class MerchantDtoMapper {

    private MerchantDtoMapper() {}

    public static Merchant toDomain(CreateMerchantRequest request) {
        return new Merchant(
            null,
            request.mid(),
            request.name(),
            request.tradeName(),
            request.document(),
            List.of(request.mcc()),
            new MerchantConfiguration(false, 0),
            MerchantStatus.ACTIVE,
            null,
            null
        );
    }

    public static MerchantResponse toResponse(Merchant merchant) {
        return new MerchantResponse(
            merchant.id(),
            merchant.mid(),
            merchant.legalName(),
            maskDocument(merchant.document()),
            merchant.mccs(),
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

## CHANGE THESE

- **Class name**: `{Entity}DtoMapper`
- **toDomain()**: Map request record fields to domain record constructor
- **toResponse()**: Map domain record to response record (MASK sensitive data)
- **Masking methods**: Add for PAN, document, or other sensitive fields

## Critical Rules (memorize)

1. `final class` + `private` constructor + `static` methods
2. Masking logic lives in the mapper that EXPOSES data externally
3. PAN mask: first 6 + `****` + last 4
4. Document mask: first 3 + `****` + last 2
5. Located in `adapter.inbound.rest.mapper`

## Checklist

- [ ] `final class`
- [ ] `private` constructor
- [ ] All methods `static`
- [ ] `toDomain()` and `toResponse()` methods present
- [ ] Sensitive data masked in `toResponse()` (document, PAN)
- [ ] No CDI annotations
