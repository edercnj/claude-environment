# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Spring Boot — REST API Patterns

> Extends: `core/06-api-design-principles.md`

## Technology Stack

- **Spring Web MVC** (`@RestController`) via Spring Boot 3.x
- **Jackson** for JSON serialization
- **springdoc-openapi** for OpenAPI 3.0 documentation (Swagger UI auto-generated)
- **Jakarta Bean Validation** for request validation
- **Spring 6 ProblemDetail** or custom record with factory methods for RFC 7807

## Request/Response DTOs (Records)

All REST DTOs MUST be Java records. No `@RegisterForReflection` needed — Jackson works natively with Spring Boot:

```java
@Schema(description = "Request for merchant creation")
public record CreateMerchantRequest(
    @NotBlank @Size(max = 15)
    @Schema(description = "Merchant identifier (MID)", example = "MID000000000001", maxLength = 15)
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

- `@Schema` annotations come from `io.swagger.v3.oas.annotations.media.Schema` (springdoc-openapi)
- `@Schema` on **class** with `description`
- `@Schema` on **each field** with `description` and `example`
- Nested records ALSO must have `@Schema` on class and fields
- `example` should contain realistic and valid value
- Do not use `@Schema` on internal fields that do not appear in the API

## REST Controller Pattern

```java
@RestController
@RequestMapping("/api/v1/merchants")
@Validated
@Tag(name = "Merchants", description = "Merchant management operations")
public class MerchantController {

    private final MerchantService merchantService;

    public MerchantController(MerchantService merchantService) {
        this.merchantService = merchantService;
    }

    @GetMapping
    public PaginatedResponse<MerchantResponse> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int limit) {
        var merchants = merchantService.listMerchants(page, limit);
        var total = merchantService.countMerchants();
        var responses = merchants.stream().map(MerchantDtoMapper::toResponse).toList();
        return PaginatedResponse.of(responses, page, limit, total);
    }

    @GetMapping("/{id}")
    public MerchantResponse getById(@PathVariable Long id) {
        var merchant = merchantService.findById(id);
        return MerchantDtoMapper.toResponse(merchant);
    }

    @PostMapping
    public ResponseEntity<MerchantResponse> create(@Valid @RequestBody CreateMerchantRequest request) {
        var merchant = merchantService.create(request);
        var response = MerchantDtoMapper.toResponse(merchant);
        var location = URI.create("/api/v1/merchants/" + merchant.id());
        return ResponseEntity.created(location).body(response);
    }

    @PutMapping("/{id}")
    public MerchantResponse update(@PathVariable Long id, @Valid @RequestBody UpdateMerchantRequest request) {
        var merchant = merchantService.update(id, request);
        return MerchantDtoMapper.toResponse(merchant);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        merchantService.deactivate(id);
        return ResponseEntity.noContent().build();
    }
}
```

### Controller Rules

- `@RestController` combines `@Controller` + `@ResponseBody`
- `@RequestMapping("/api/v1/{resource}")` at class level for base path
- `@Validated` on class for method-level validation support
- `@Valid` on `@RequestBody` parameters to trigger Bean Validation
- `ResponseEntity<T>` for explicit status code control (201 Created with Location, 204 No Content)
- Simple returns (no `ResponseEntity`) default to 200 OK
- Constructor injection (no `@Autowired` annotation needed with single constructor)

## ProblemDetail — RFC 7807

Use a custom record with factory methods for consistent error responses:

```java
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
- Alternative: use Spring 6 built-in `org.springframework.http.ProblemDetail` if preferred

## PaginatedResponse<T>

```java
@JsonInclude(JsonInclude.Include.NON_NULL)
public record PaginatedResponse<T>(
    List<T> data,
    PaginationInfo pagination
) {
    public record PaginationInfo(int page, int limit, long total, int totalPages) {}

    public static <T> PaginatedResponse<T> of(List<T> data, int page, int limit, long total) {
        int totalPages = (int) Math.ceil((double) total / limit);
        return new PaginatedResponse<>(data, new PaginationInfo(page, limit, total, totalPages));
    }
}
```

**Rules:**
- `page` is **0-based** internally (Spring Data standard)
- ALWAYS use factory method `PaginatedResponse.of()` to create instances
- Alternative: use Spring Data's `Page<T>` directly if simpler mapping is acceptable

### Spring Data Pageable Integration

```java
@GetMapping
public PaginatedResponse<MerchantResponse> list(@PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
    var page = merchantService.listMerchants(pageable);
    var responses = page.getContent().stream().map(MerchantDtoMapper::toResponse).toList();
    return PaginatedResponse.of(responses, pageable.getPageNumber(), pageable.getPageSize(), page.getTotalElements());
}
```

## Exception Handling — @ControllerAdvice Pattern

### GlobalExceptionHandler — Domain Exceptions

Maps domain exceptions to RFC 7807 responses using **pattern matching switch** (Java 21):

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<ProblemDetail> handleDomainException(RuntimeException exception, HttpServletRequest request) {
        var problemDetail = switch (exception) {
            case MerchantNotFoundException e -> ProblemDetail.notFound(
                "Merchant not found: " + e.getIdentifier(), request.getRequestURI());
            case MerchantAlreadyExistsException e -> ProblemDetail.conflict(
                "Merchant with ID '%s' already exists".formatted(e.getIdentifier()),
                request.getRequestURI(), Map.of("existingId", e.getIdentifier()));
            case TerminalNotFoundException e -> ProblemDetail.notFound(
                "Terminal not found: " + e.getIdentifier(), request.getRequestURI());
            case TerminalAlreadyExistsException e -> ProblemDetail.conflict(
                "Terminal with ID '%s' already exists".formatted(e.getIdentifier()),
                request.getRequestURI(), Map.of("existingId", e.getIdentifier()));
            case InvalidDocumentException e -> ProblemDetail.badRequest(
                e.getMessage(), request.getRequestURI());
            default -> {
                LOG.error("Unexpected error on {}: {}", request.getRequestURI(), exception.getMessage(), exception);
                yield ProblemDetail.internalError("Internal processing error", request.getRequestURI());
            }
        };
        return ResponseEntity.status(problemDetail.status()).body(problemDetail);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ProblemDetail> handleValidationErrors(MethodArgumentNotValidException exception, HttpServletRequest request) {
        var violations = exception.getBindingResult().getFieldErrors().stream()
            .collect(Collectors.groupingBy(
                FieldError::getField,
                Collectors.mapping(FieldError::getDefaultMessage, Collectors.toList())
            ));
        var problemDetail = ProblemDetail.validationError(
            "Validation failed", request.getRequestURI(), violations);
        return ResponseEntity.status(400).body(problemDetail);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ProblemDetail> handleConstraintViolation(ConstraintViolationException exception, HttpServletRequest request) {
        var violations = exception.getConstraintViolations().stream()
            .collect(Collectors.groupingBy(
                v -> extractFieldName(v.getPropertyPath()),
                Collectors.mapping(ConstraintViolation::getMessage, Collectors.toList())
            ));
        var problemDetail = ProblemDetail.validationError(
            "Validation failed", request.getRequestURI(), violations);
        return ResponseEntity.status(400).body(problemDetail);
    }

    private static String extractFieldName(Path propertyPath) {
        var iterator = propertyPath.iterator();
        String fieldName = "";
        while (iterator.hasNext()) {
            fieldName = iterator.next().getName();
        }
        return fieldName;
    }
}
```

### Exception Handler Rules

- `@RestControllerAdvice` replaces JAX-RS `@Provider` + `ExceptionMapper`
- ALWAYS use pattern matching switch (Java 21) in domain exception handler
- Each new domain exception MUST have a corresponding `case`
- The `default` MUST log at ERROR level and return 500 generic (never expose stack trace)
- `MethodArgumentNotValidException` handles `@Valid` failures on `@RequestBody` (replaces ConstraintViolationExceptionMapper)
- `ConstraintViolationException` handles `@Validated` method-level violations
- Use `HttpServletRequest` to access `request.getRequestURI()` for the `instance` field

## springdoc-openapi Configuration

```yaml
# application.yml
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
    enabled: true  # disable in prod
  default-produces-media-type: application/json
  default-consumes-media-type: application/json
```

### Maven Dependency

```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>${springdoc.version}</version>
</dependency>
```

## Anti-Patterns

- Verbs in URL (`/api/v1/createMerchant`) — use nouns + HTTP verb
- Return 200 for errors with `{ "error": true }` — use HTTP status codes
- Expose JPA Entity directly — ALWAYS use DTOs (Records)
- Return lists without pagination — ALWAYS paginate
- Ignore Content-Type — ALWAYS validate `application/json`
- Construct `ProblemDetail` directly with `new` — use factory methods
- Exception handler without log in `default` — unexpected errors must be logged
- REST DTOs without `@Schema` — incomplete OpenAPI documentation
- `@Autowired` on fields — use constructor injection
- Business logic in controllers — controllers delegate to services only
