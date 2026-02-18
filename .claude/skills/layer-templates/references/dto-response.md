# Template: DTO Response

## Pattern

```java
package com.bifrost.simulator.adapter.inbound.rest.dto;

import io.quarkus.runtime.annotations.RegisterForReflection;
import java.time.OffsetDateTime;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@RegisterForReflection
@Schema(description = "Merchant response with masked sensitive data")
public record MerchantResponse(

    @Schema(description = "Internal identifier", example = "1")
    Long id,

    @Schema(description = "Merchant Identifier (MID)", example = "123456789012345")
    String mid,

    @Schema(description = "Merchant legal name", example = "Test Store LTDA")
    String legalName,

    @Schema(description = "Masked document (CPF/CNPJ)", example = "123****90")
    String documentMasked,

    @Schema(description = "Merchant Category Codes", example = "[\"5411\"]")
    List<String> mccs,

    @Schema(description = "Merchant status", example = "ACTIVE")
    String status,

    @Schema(description = "Creation timestamp", example = "2026-01-15T10:30:00Z")
    OffsetDateTime createdAt,

    @Schema(description = "Last update timestamp", example = "2026-01-15T10:30:00Z")
    OffsetDateTime updatedAt
) {}
```

## CHANGE THESE

- **Class name**: `{Entity}Response`
- **@Schema description**: Describe what this response represents
- **Fields**: Replace with response fields from the Architect's plan
- **Sensitive fields**: Use masked variants (e.g., `documentMasked`, not `document`)
- **@Schema examples**: Use realistic masked/safe values

## Critical Rules (memorize)

1. `@RegisterForReflection` is MANDATORY (Quarkus Native)
2. `@Schema` on class AND every field
3. NEVER expose: full PAN, PIN, CVV, track data, card expiry
4. Document/PAN fields must be pre-masked by the mapper
5. Use `OffsetDateTime` for timestamps (ISO 8601)

## Checklist

- [ ] `@RegisterForReflection` present
- [ ] `@Schema` on class and all fields
- [ ] No sensitive data exposed (PAN masked, no PIN/CVV)
- [ ] Timestamps as `OffsetDateTime`
- [ ] Record (not class)
- [ ] No validation annotations (responses don't need validation)
