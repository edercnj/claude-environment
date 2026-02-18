# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Quarkus — REST API Patterns

> Extends: `core/06-api-design-principles.md`

## Technology Stack

- **RESTEasy Reactive** (JAX-RS) via Quarkus
- **Jackson** for JSON serialization
- **MicroProfile OpenAPI** for documentation (auto-generated)
- **Bean Validation** (Jakarta) for request validation

## Request/Response DTOs (Records)

All REST DTOs MUST be Java records with `@RegisterForReflection`:

```java
@RegisterForReflection
@Schema(description = "Request for merchant creation")
public record CreateMerchantRequest(
    @NotBlank @Size(max = 15)
    @Schema(description = "Merchant Identifier (MID)", example = "123456789012345", maxLength = 15)
    String mid,

    @NotBlank @Size(max = 100)
    @Schema(description = "Merchant legal name", example = "Test Store LTDA", maxLength = 100)
    String name,

    @NotBlank @Size(min = 11, max = 14) @Pattern(regexp = "\\d{11,14}")
    @Schema(description = "Tax identification number (11 or 14 digits)", example = "12345678000190")
    String document,

    @NotBlank @Size(min = 4, max = 4) @Pattern(regexp = "\\d{4}")
    @Schema(description = "Merchant Category Code", example = "5411")
    String mcc
) {}
```

```java
@RegisterForReflection
@Schema(description = "Merchant response")
public record MerchantResponse(
    Long id,
    String mid,
    String name,
    String documentMasked,
    String mcc,
    boolean timeoutEnabled,
    String status,
    OffsetDateTime createdAt
) {}
```

### OpenAPI @Schema Rules

- `@Schema` on **class** with `description`
- `@Schema` on **each field** with `description` and `example`
- Nested records ALSO must have `@Schema` on class and fields
- `example` should contain realistic and valid value
- Do not use `@Schema` on internal fields that do not appear in the API

## ProblemDetail — RFC 7807

```java
@RegisterForReflection
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ProblemDetail(
    String type, String title, int status, String detail,
    String instance, Map<String, Object> extensions
) {
    public static ProblemDetail notFound(String detail, String instance) {
        return new ProblemDetail("/errors/not-found", "Not Found", 404, detail, instance, null);
    }

    public static ProblemDetail conflict(String detail, String instance, Map<String, Object> extensions) {
        return new ProblemDetail("/errors/conflict", "Conflict", 409, detail, instance, extensions);
    }

    public static ProblemDetail badRequest(String detail, String instance) {
        return new ProblemDetail("/errors/bad-request", "Bad Request", 400, detail, instance, null);
    }

    public static ProblemDetail validationError(String detail, String instance, Map<String, List<String>> violations) {
        return new ProblemDetail("/errors/validation-error", "Validation Error", 400, detail, instance,
            Map.of("violations", violations));
    }

    public static ProblemDetail internalError(String detail, String instance) {
        return new ProblemDetail("/errors/internal-error", "Internal Server Error", 500, detail, instance, null);
    }

    public static ProblemDetail tooManyRequests(String detail, String instance) {
        return new ProblemDetail("/errors/too-many-requests", "Too Many Requests", 429, detail, instance, null);
    }

    public static ProblemDetail serviceUnavailable(String detail, String instance) {
        return new ProblemDetail("/errors/service-unavailable", "Service Unavailable", 503, detail, instance, null);
    }
}
```

**Rules:**
- Each new error type (status code) MUST have a corresponding factory method
- NEVER construct `ProblemDetail` directly with `new` — use factory methods
- The `type` field follows the pattern `/errors/{error-slug}`

## PaginatedResponse<T>

```java
@RegisterForReflection
@JsonInclude(JsonInclude.Include.NON_NULL)
public record PaginatedResponse<T>(
    List<T> data,
    PaginationInfo pagination
) {
    @RegisterForReflection
    public record PaginationInfo(int page, int limit, long total, int totalPages) {}

    public static <T> PaginatedResponse<T> of(List<T> data, int page, int limit, long total) {
        int totalPages = (int) Math.ceil((double) total / limit);
        return new PaginatedResponse<>(data, new PaginationInfo(page, limit, total, totalPages));
    }
}
```

**Usage in Resource:**
```java
@GET
public PaginatedResponse<MerchantResponse> list(
        @QueryParam("page") @DefaultValue("0") int page,
        @QueryParam("limit") @DefaultValue("20") int limit) {
    var merchants = service.listMerchants(page, limit);
    var total = service.countMerchants();
    var responses = merchants.stream().map(MerchantDtoMapper::toResponse).toList();
    return PaginatedResponse.of(responses, page, limit, total);
}
```

**Rules:**
- `page` is **0-based** internally (Panache standard)
- ALWAYS use factory method `PaginatedResponse.of()` to create instances
- `PaginationInfo` is a nested record — MUST have `@RegisterForReflection` separately

## ExceptionMapper — Dual Pattern

### SimulatorExceptionMapper — Domain Exceptions

Maps domain exceptions to RFC 7807 responses using **pattern matching switch** (Java 21):

```java
@Provider
public class SimulatorExceptionMapper implements ExceptionMapper<RuntimeException> {

    @Context
    UriInfo uriInfo;

    @Override
    public Response toResponse(RuntimeException exception) {
        var problemDetail = switch (exception) {
            case MerchantNotFoundException e -> ProblemDetail.notFound(
                "Merchant not found: " + e.getIdentifier(), uriInfo.getPath());
            case MerchantAlreadyExistsException e -> ProblemDetail.conflict(
                "Merchant with ID '%s' already exists".formatted(e.getIdentifier()),
                uriInfo.getPath(), Map.of("existingId", e.getIdentifier()));
            case TerminalNotFoundException e -> ProblemDetail.notFound(
                "Terminal not found: " + e.getIdentifier(), uriInfo.getPath());
            case TerminalAlreadyExistsException e -> ProblemDetail.conflict(
                "Terminal with ID '%s' already exists".formatted(e.getIdentifier()),
                uriInfo.getPath(), Map.of("existingId", e.getIdentifier()));
            case InvalidDocumentException e -> ProblemDetail.badRequest(
                e.getMessage(), uriInfo.getPath());
            default -> {
                LOG.errorf("Unexpected error on %s: %s", uriInfo.getPath(), exception.getMessage());
                yield ProblemDetail.internalError("Internal processing error", uriInfo.getPath());
            }
        };
        return Response.status(problemDetail.status()).entity(problemDetail).build();
    }
}
```

### ConstraintViolationExceptionMapper — Bean Validation

```java
@Provider
public class ConstraintViolationExceptionMapper implements ExceptionMapper<ConstraintViolationException> {

    @Context
    UriInfo uriInfo;

    @Override
    public Response toResponse(ConstraintViolationException exception) {
        var violations = exception.getConstraintViolations().stream()
            .collect(Collectors.groupingBy(
                v -> extractFieldName(v.getPropertyPath()),
                Collectors.mapping(ConstraintViolation::getMessage, Collectors.toList())
            ));
        var problemDetail = ProblemDetail.validationError(
            "Validation failed", uriInfo.getPath(), violations);
        return Response.status(400).entity(problemDetail).build();
    }
}
```

### ExceptionMapper Rules

- ALWAYS use pattern matching switch (Java 21) in domain exception mapper
- Each new domain exception MUST have a corresponding `case`
- The `default` MUST log at ERROR level and return 500 generic (never expose stack trace)
- `ConstraintViolationExceptionMapper` groups violations by field for easier frontend display

## Anti-Patterns

- Verbs in URL (`/api/v1/createMerchant`) — use nouns + HTTP verb
- Return 200 for errors with `{ "error": true }` — use HTTP status codes
- Expose JPA Entity directly — ALWAYS use DTOs (Records)
- Return lists without pagination — ALWAYS paginate
- Ignore Content-Type — ALWAYS validate `application/json`
- Construct `ProblemDetail` directly with `new` — use factory methods
- ExceptionMapper without log in `default` — unexpected errors must be logged
- REST DTOs without `@Schema` — incomplete OpenAPI documentation
