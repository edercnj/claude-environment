---
name: review-api
description: "Skill: API Design — Reviews REST API design in the ISO 8583 authorizer simulator, covering patterns, DTOs, status codes, security, and compliance with Rule 17."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[STORY-NNN]"
context: fork
agent: general-purpose
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: API Design

## Description

Guide for REST API design in the ISO 8583 authorizer simulator.

## Patterns

### URL Pattern

```
/api/v1/{resource}              → collection (GET list, POST create)
/api/v1/{resource}/{id}         → item (GET, PUT, DELETE)
/api/v1/{resource}/{id}/{sub}   → sub-resource
```

## DTOs as Records

### Request with Validation

```java
@RegisterForReflection
public record CreateMerchantRequest(
    @NotBlank @Size(max = 15) String mid,
    @NotBlank @Size(max = 100) String name,
    @NotBlank @Pattern(regexp = "\\d{11,14}") String document,
    @NotBlank @Size(min = 4, max = 4) String mcc
) {}
```

### Immutable Response

```java
@RegisterForReflection
public record MerchantResponse(
    Long id, String mid, String name, String mcc, String status,
    OffsetDateTime createdAt
) {}
```

## Error Response (RFC 7807)

```java
@RegisterForReflection
public record ProblemDetail(
    String type, String title, int status,
    String detail, String instance
) {}
```

## Resource Pattern

```java
@Path("/api/v1/merchants")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class MerchantResource {

    private final ManageMerchantUseCase useCase;

    @Inject
    public MerchantResource(ManageMerchantUseCase useCase) {
        this.useCase = useCase;
    }

    @GET
    public Response list(@QueryParam("page") @DefaultValue("1") int page,
                         @QueryParam("limit") @DefaultValue("20") int limit) {
        var result = useCase.list(page, limit);
        return Response.ok(result).build();
    }

    @POST
    @Transactional
    public Response create(@Valid CreateMerchantRequest request) {
        var merchant = useCase.create(request);
        return Response.created(URI.create("/api/v1/merchants/" + merchant.id()))
                       .entity(merchant)
                       .build();
    }
}
```

## Pagination

```java
@RegisterForReflection
public record PaginatedResponse<T>(
    List<T> data,
    PaginationInfo pagination
) {
    @RegisterForReflection
    public record PaginationInfo(int page, int limit, long total, int totalPages) {}
}
```

## Swagger/OpenAPI

- Automatic via Quarkus SmallRye OpenAPI
- UI at: `/q/swagger-ui`
- Spec at: `/q/openapi`

## Status Codes

| Operation | Success                            | Common Errors                            |
| --------- | ---------------------------------- | ---------------------------------------- |
| GET list  | 200 OK                             | 400 Bad Request (invalid filter)         |
| GET item  | 200 OK                             | 404 Not Found                            |
| POST      | 201 Created (with Location header) | 400 Validation, 409 Conflict (duplicate) |
| PUT       | 200 OK                             | 400 Validation, 404 Not Found            |
| DELETE    | 204 No Content                     | 404 Not Found                            |

## Input Validation

Always use `@Valid` in Resources:

```java
@POST
public Response create(@Valid CreateMerchantRequest request) {
    // request was automatically validated by Bean Validation
    // Violations return 400 Bad Request automatically via ExceptionHandler
}
```

## Security

- **Sensitive Data:** NEVER expose full PAN in responses
- **Authentication:** API Key via `X-API-Key` header (if needed)
- **CORS:** Configure only for required domains
- **Rate Limiting:** Via Bucket4j per IP/API Key — 429 response with `Retry-After` (see **Rule 24**)

## Project Endpoints

```
# Merchants (Management API)
GET    /api/v1/merchants                    → List merchants (paginated)
POST   /api/v1/merchants                    → Create merchant
GET    /api/v1/merchants/{id}               → Get merchant by ID
PUT    /api/v1/merchants/{id}               → Update merchant
DELETE /api/v1/merchants/{id}               → Deactivate merchant (soft delete)

# Terminals (sub-resource of Merchant)
GET    /api/v1/merchants/{id}/terminals     → List merchant terminals
POST   /api/v1/merchants/{id}/terminals     → Create terminal
GET    /api/v1/terminals/{tid}              → Get terminal by TID
PUT    /api/v1/terminals/{tid}              → Update terminal

# Transactions (read-only, dashboard)
GET    /api/v1/transactions                 → List transactions (filters, paginated)
GET    /api/v1/transactions/{id}            → Transaction detail
GET    /api/v1/transactions/summary         → Summary/totals

# Health & Metrics (Built-in Quarkus)
GET    /q/health                            → Overall health
GET    /q/health/live                       → Liveness probe
GET    /q/health/ready                      → Readiness probe
GET    /q/metrics                           → OpenTelemetry metrics
```

## JSON Serialization

- **Dates:** ISO 8601 format (`2026-02-16T14:30:00Z`)
- **Fields:** camelCase in JSON (snake_case in database)
- **Nulls:** Omit null fields with `@JsonInclude(NON_NULL)`
- **Enums:** Serialize as string (`"APPROVED"`, not `0`)
- **Monetary Values:** Cents as `long` in JSON (e.g., `1050` = 10.50)

## Anti-Patterns

- ❌ Verbs in URL (`/api/v1/createMerchant`) → use nouns + HTTP verb
- ❌ Return 200 for errors with `{ "error": true }` → use HTTP status codes
- ❌ Expose JPA Entity directly → ALWAYS use DTOs (Records)
- ❌ Return lists without pagination → ALWAYS paginate large collections
- ❌ Ignore Content-Type → ALWAYS validate `application/json`
- ❌ Custom headers → use HTTP standards (Accept, Authorization, Content-Type)

## Review Checklist

- [ ] URLs follow RESTful pattern (nouns, no verbs)
- [ ] DTOs are Records with `@RegisterForReflection`
- [ ] Validation via `@Valid` on each Resource POST/PUT
- [ ] Correct status codes (201 for POST, 204 for DELETE)
- [ ] Pagination implemented for lists
- [ ] PAN/sensitive data NEVER in responses
- [ ] Error responses follow RFC 7807 (ProblemDetail)
- [ ] OpenAPI auto-generated (`/q/swagger-ui`)
- [ ] REST Assured tests for each endpoint
- [ ] Rate limiting configured (429 + Retry-After — Rule 24)?
- [ ] Circuit breaker fallback returns 503 (not generic 500 — Rule 24)?
- [ ] ExceptionMapper handles `CircuitBreakerOpenException`, `BulkheadException`, `TimeoutException`?
