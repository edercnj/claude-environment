# Template: REST Resource

## Pattern

```java
package com.bifrost.simulator.adapter.inbound.rest;

import com.bifrost.simulator.adapter.inbound.rest.dto.CreateMerchantRequest;
import com.bifrost.simulator.adapter.inbound.rest.dto.MerchantResponse;
import com.bifrost.simulator.adapter.inbound.rest.dto.PaginatedResponse;
import com.bifrost.simulator.adapter.inbound.rest.mapper.MerchantDtoMapper;
import com.bifrost.simulator.application.ManageMerchantUseCase;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.net.URI;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Path("/api/v1/merchants")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Merchants", description = "Merchant management endpoints")
public class MerchantResource {

    private final ManageMerchantUseCase useCase;

    @Inject
    public MerchantResource(ManageMerchantUseCase useCase) {
        this.useCase = useCase;
    }

    @GET
    @Operation(summary = "List merchants with pagination")
    public PaginatedResponse<MerchantResponse> list(
            @QueryParam("page") @DefaultValue("0") int page,
            @QueryParam("limit") @DefaultValue("20") int limit) {
        var merchants = useCase.list(page, limit);
        var total = useCase.count();
        var responses = merchants.stream().map(MerchantDtoMapper::toResponse).toList();
        return PaginatedResponse.of(responses, page, limit, total);
    }

    @GET
    @Path("/{id}")
    @Operation(summary = "Get merchant by ID")
    public MerchantResponse getById(@PathParam("id") Long id) {
        var merchant = useCase.findById(id)
            .orElseThrow(() -> new com.bifrost.simulator.domain.exception.MerchantNotFoundException(id.toString()));
        return MerchantDtoMapper.toResponse(merchant);
    }

    @POST
    @Operation(summary = "Create a new merchant")
    public Response create(@Valid CreateMerchantRequest request) {
        var merchant = MerchantDtoMapper.toDomain(request);
        var created = useCase.create(merchant);
        var response = MerchantDtoMapper.toResponse(created);
        return Response.created(URI.create("/api/v1/merchants/" + created.id()))
            .entity(response)
            .build();
    }

    @PUT
    @Path("/{id}")
    @Operation(summary = "Update an existing merchant")
    public MerchantResponse update(@PathParam("id") Long id, @Valid CreateMerchantRequest request) {
        var merchant = MerchantDtoMapper.toDomain(request);
        var updated = useCase.update(id, merchant);
        return MerchantDtoMapper.toResponse(updated);
    }

    @DELETE
    @Path("/{id}")
    @Operation(summary = "Deactivate a merchant (soft delete)")
    public Response delete(@PathParam("id") Long id) {
        useCase.deactivate(id);
        return Response.noContent().build();
    }
}
```

## CHANGE THESE

- **@Path**: `/api/v1/{resource}` (plural noun)
- **@Tag**: Resource name and description
- **Class name**: `{Entity}Resource`
- **Use case**: Inject the appropriate use case
- **DTO mapper**: Use the appropriate DTO mapper
- **Endpoints**: Match the Architect's plan (CRUD + custom)

## Critical Rules (memorize)

1. `@Valid` on request body parameters (triggers Bean Validation)
2. POST returns `Response.created(URI)` with 201 + Location header
3. DELETE returns `Response.noContent()` with 204
4. Pagination via `PaginatedResponse.of()` factory
5. Constructor injection with `@Inject`

## Checklist

- [ ] `@Path("/api/v1/{resource}")` with plural noun
- [ ] `@Produces` and `@Consumes` for JSON
- [ ] `@Tag` for OpenAPI grouping
- [ ] `@Operation` on each endpoint
- [ ] `@Valid` on request body params
- [ ] POST returns 201 with Location header
- [ ] DELETE returns 204
- [ ] Constructor injection
- [ ] Uses DTO mapper (never exposes domain directly)
