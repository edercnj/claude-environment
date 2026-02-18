# Template: DTO Request

## Pattern

```java
package com.bifrost.simulator.adapter.inbound.rest.dto;

import io.quarkus.runtime.annotations.RegisterForReflection;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@RegisterForReflection
@Schema(description = "Request for merchant creation")
public record CreateMerchantRequest(

    @NotBlank @Size(max = 15)
    @Schema(description = "Merchant Identifier (MID)", example = "123456789012345", maxLength = 15)
    String mid,

    @NotBlank @Size(max = 100)
    @Schema(description = "Merchant legal name", example = "Test Store LTDA", maxLength = 100)
    String name,

    @NotBlank @Size(max = 100)
    @Schema(description = "Merchant trade name", example = "TestStore", maxLength = 100)
    String tradeName,

    @NotBlank @Size(min = 11, max = 14) @Pattern(regexp = "\\d{11,14}")
    @Schema(description = "CPF (11 digits) or CNPJ (14 digits)", example = "12345678000190")
    String document,

    @NotBlank @Size(min = 4, max = 4) @Pattern(regexp = "\\d{4}")
    @Schema(description = "Merchant Category Code", example = "5411")
    String mcc
) {}
```

## CHANGE THESE

- **Package**: Keep `adapter.inbound.rest.dto`
- **Class name**: `Create{Entity}Request` or `Update{Entity}Request`
- **@Schema description**: Describe what this request creates/updates
- **Fields**: Replace with the fields from the Architect's plan
- **Validation**: Match constraints from the plan (sizes, patterns, required)
- **@Schema examples**: Use realistic values for the domain

## Critical Rules (memorize)

1. `@RegisterForReflection` is MANDATORY (Quarkus Native)
2. `@Schema` on class AND every field (OpenAPI docs)
3. Bean Validation annotations on every field (`@NotBlank`, `@Size`, `@Pattern`)
4. Record fields are `final` by design — no setters needed
5. Import order: `io.quarkus` -> `jakarta` -> `org.eclipse` (alphabetical within groups)

## Checklist

- [ ] `@RegisterForReflection` present on class
- [ ] `@Schema(description = "...")` on class
- [ ] `@Schema(description, example)` on every field
- [ ] `@NotBlank` on required String fields
- [ ] `@Size` with min/max on bounded fields
- [ ] `@Pattern` on formatted fields (MCC, document, etc.)
- [ ] No Lombok annotations
- [ ] Record (not class)
