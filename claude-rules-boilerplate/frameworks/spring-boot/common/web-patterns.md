# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot — REST Web Patterns

> Extends the base API design and architecture rules. All naming conventions, hexagonal architecture, and RFC 7807 error handling apply.

## Controller Structure

```java
@RestController
@RequestMapping("/api/v1/merchants")
public class MerchantController {

    private final MerchantService merchantService;

    public MerchantController(MerchantService merchantService) {
        this.merchantService = merchantService;
    }

    @GetMapping
    public PaginatedResponse<MerchantResponse> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int limit) {
        var result = merchantService.listMerchants(page, limit);
        var responses = result.getContent().stream()
            .map(MerchantDtoMapper::toResponse)
            .toList();
        return PaginatedResponse.of(responses, page, limit, result.getTotalElements());
    }

    @GetMapping("/{id}")
    public MerchantResponse getById(@PathVariable Long id) {
        var merchant = merchantService.findById(id);
        return MerchantDtoMapper.toResponse(merchant);
    }

    @PostMapping
    public ResponseEntity<MerchantResponse> create(@Valid @RequestBody CreateMerchantRequest request) {
        var merchant = merchantService.createMerchant(request);
        var response = MerchantDtoMapper.toResponse(merchant);
        var location = URI.create("/api/v1/merchants/" + merchant.id());
        return ResponseEntity.created(location).body(response);
    }

    @PutMapping("/{id}")
    public MerchantResponse update(@PathVariable Long id, @Valid @RequestBody UpdateMerchantRequest request) {
        var merchant = merchantService.updateMerchant(id, request);
        return MerchantDtoMapper.toResponse(merchant);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        merchantService.deactivateMerchant(id);
        return ResponseEntity.noContent().build();
    }
}
```

## HTTP Method Mapping

| Annotation | HTTP Method | Typical Status |
|-----------|-------------|---------------|
| `@GetMapping` | GET | 200 OK |
| `@PostMapping` | POST | 201 Created |
| `@PutMapping` | PUT | 200 OK |
| `@DeleteMapping` | DELETE | 204 No Content |
| `@PatchMapping` | PATCH | 200 OK |

## Request DTOs as Records with Bean Validation

```java
@Schema(description = "Request for merchant creation")
public record CreateMerchantRequest(

    @NotBlank
    @Size(max = 15)
    @Schema(description = "Merchant Identifier (MID)", example = "123456789012345", maxLength = 15)
    String mid,

    @NotBlank
    @Size(max = 100)
    @Schema(description = "Merchant legal name", example = "Test Store LTDA", maxLength = 100)
    String name,

    @NotBlank
    @Size(max = 100)
    @Schema(description = "Merchant trade name", example = "TestStore", maxLength = 100)
    String tradeName,

    @NotBlank
    @Size(min = 11, max = 14)
    @Pattern(regexp = "\\d{11,14}")
    @Schema(description = "CPF (11 digits) or CNPJ (14 digits)", example = "12345678000190")
    String document,

    @NotBlank
    @Size(min = 4, max = 4)
    @Pattern(regexp = "\\d{4}")
    @Schema(description = "Merchant Category Code", example = "5411")
    String mcc
) {}

@Schema(description = "Request for merchant update")
public record UpdateMerchantRequest(

    @NotBlank
    @Size(max = 100)
    @Schema(description = "Merchant legal name", example = "Updated Store LTDA")
    String name,

    @Size(max = 100)
    @Schema(description = "Merchant trade name", example = "UpdatedStore")
    String tradeName,

    @NotBlank
    @Size(min = 4, max = 4)
    @Pattern(regexp = "\\d{4}")
    @Schema(description = "Merchant Category Code", example = "5411")
    String mcc
) {}
```

## Response DTOs as Records

```java
@Schema(description = "Merchant response")
public record MerchantResponse(

    @Schema(description = "Internal ID", example = "1")
    Long id,

    @Schema(description = "Merchant Identifier", example = "123456789012345")
    String mid,

    @Schema(description = "Merchant legal name", example = "Test Store LTDA")
    String name,

    @Schema(description = "Masked document", example = "123****90")
    String documentMasked,

    @Schema(description = "Merchant Category Code", example = "5411")
    String mcc,

    @Schema(description = "Current status", example = "ACTIVE")
    String status,

    @Schema(description = "Creation timestamp")
    OffsetDateTime createdAt,

    @Schema(description = "Last update timestamp")
    OffsetDateTime updatedAt
) {}
```

## ResponseEntity for Full Control

Use `ResponseEntity<T>` when you need to control status codes and headers:

```java
// 201 Created with Location header
@PostMapping
public ResponseEntity<MerchantResponse> create(@Valid @RequestBody CreateMerchantRequest request) {
    var merchant = merchantService.createMerchant(request);
    var response = MerchantDtoMapper.toResponse(merchant);
    return ResponseEntity
        .created(URI.create("/api/v1/merchants/" + merchant.id()))
        .body(response);
}

// 204 No Content
@DeleteMapping("/{id}")
public ResponseEntity<Void> delete(@PathVariable Long id) {
    merchantService.deactivateMerchant(id);
    return ResponseEntity.noContent().build();
}

// 200 OK with custom headers
@GetMapping("/{id}")
public ResponseEntity<MerchantResponse> getById(@PathVariable Long id) {
    var merchant = merchantService.findById(id);
    return ResponseEntity.ok()
        .header("X-Request-Id", UUID.randomUUID().toString())
        .body(MerchantDtoMapper.toResponse(merchant));
}
```

When the return is always 200, you can omit `ResponseEntity`:

```java
// Implicit 200 OK
@GetMapping("/{id}")
public MerchantResponse getById(@PathVariable Long id) {
    return MerchantDtoMapper.toResponse(merchantService.findById(id));
}
```

## ProblemDetail (RFC 7807) — Spring-Native

Spring 6+ has built-in `ProblemDetail`. Use a custom record for consistency:

```java
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ProblemDetail(
    String type,
    String title,
    int status,
    String detail,
    String instance,
    Map<String, Object> extensions
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

## @ControllerAdvice — Global Exception Handling

### Domain Exception Handler (Pattern Matching Switch)

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<ProblemDetail> handleDomainExceptions(RuntimeException exception, HttpServletRequest request) {
        var path = request.getRequestURI();
        var problemDetail = switch (exception) {
            case MerchantNotFoundException e -> ProblemDetail.notFound(
                "Merchant not found: " + e.getIdentifier(), path);
            case MerchantAlreadyExistsException e -> ProblemDetail.conflict(
                "Merchant with MID '%s' already exists".formatted(e.getMid()),
                path, Map.of("existingMid", e.getMid()));
            case TerminalNotFoundException e -> ProblemDetail.notFound(
                "Terminal not found: " + e.getIdentifier(), path);
            case TerminalAlreadyExistsException e -> ProblemDetail.conflict(
                "Terminal with TID '%s' already exists".formatted(e.getTid()),
                path, Map.of("existingTid", e.getTid()));
            case InvalidDocumentException e -> ProblemDetail.badRequest(
                e.getMessage(), path);
            default -> {
                LOG.error("Unexpected error on {}: {}", path, exception.getMessage(), exception);
                yield ProblemDetail.internalError("Internal processing error", path);
            }
        };
        return ResponseEntity.status(problemDetail.status()).body(problemDetail);
    }
}
```

### Bean Validation Handler (MethodArgumentNotValidException)

```java
@RestControllerAdvice
public class ValidationExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ProblemDetail> handleValidationErrors(MethodArgumentNotValidException exception, HttpServletRequest request) {
        var violations = exception.getBindingResult().getFieldErrors().stream()
            .collect(Collectors.groupingBy(
                FieldError::getField,
                Collectors.mapping(FieldError::getDefaultMessage, Collectors.toList())
            ));
        var problemDetail = ProblemDetail.validationError(
            "Validation failed", request.getRequestURI(), violations);
        return ResponseEntity.badRequest().body(problemDetail);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ProblemDetail> handleConstraintViolations(ConstraintViolationException exception, HttpServletRequest request) {
        var violations = exception.getConstraintViolations().stream()
            .collect(Collectors.groupingBy(
                v -> extractFieldName(v.getPropertyPath()),
                Collectors.mapping(ConstraintViolation::getMessage, Collectors.toList())
            ));
        var problemDetail = ProblemDetail.validationError(
            "Validation failed", request.getRequestURI(), violations);
        return ResponseEntity.badRequest().body(problemDetail);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ProblemDetail> handleMalformedJson(HttpMessageNotReadableException exception, HttpServletRequest request) {
        var problemDetail = ProblemDetail.badRequest(
            "Malformed JSON request body", request.getRequestURI());
        return ResponseEntity.badRequest().body(problemDetail);
    }

    private String extractFieldName(Path propertyPath) {
        String path = propertyPath.toString();
        int lastDot = path.lastIndexOf('.');
        return lastDot >= 0 ? path.substring(lastDot + 1) : path;
    }
}
```

### Exception Handler Rules

| Rule | Detail |
|------|--------|
| Pattern matching | Use Java 21 switch expressions in exception handlers |
| Default case | MUST log at ERROR level, return 500 generic |
| Stack traces | NEVER expose in production responses |
| New exceptions | MUST have corresponding `case` in the handler |
| Validation | Group violations by field name |
| Rate limit | Return 429 with `Retry-After` header |
| Circuit open | Return 503 with `Retry-After` header |

## springdoc-openapi Annotations

All REST DTOs MUST have `@Schema` annotations:

```java
@Schema(description = "Terminal response")
public record TerminalResponse(

    @Schema(description = "Terminal Identifier", example = "TERM0001")
    String tid,

    @Schema(description = "Associated merchant ID", example = "1")
    Long merchantId,

    @Schema(description = "Terminal model", example = "PAX-A920")
    String model,

    @Schema(description = "Current status", example = "ACTIVE")
    String status,

    @Schema(description = "Whether timeout simulation is enabled", example = "false")
    boolean timeoutEnabled
) {}
```

### OpenAPI Configuration

```java
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("Authorizer Simulator API")
                .version("1.0.0")
                .description("REST API for managing merchants, terminals, and viewing transactions"))
            .addSecurityItem(new SecurityRequirement().addList("ApiKey"))
            .components(new Components()
                .addSecuritySchemes("ApiKey",
                    new SecurityScheme()
                        .type(SecurityScheme.Type.APIKEY)
                        .in(SecurityScheme.In.HEADER)
                        .name("X-API-Key")));
    }
}
```

## Sub-Resources

Terminals are sub-resources of merchants:

```java
@RestController
@RequestMapping("/api/v1/merchants/{merchantId}/terminals")
public class MerchantTerminalController {

    private final TerminalService terminalService;

    public MerchantTerminalController(TerminalService terminalService) {
        this.terminalService = terminalService;
    }

    @GetMapping
    public PaginatedResponse<TerminalResponse> listByMerchant(
            @PathVariable Long merchantId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int limit) {
        var result = terminalService.listByMerchant(merchantId, page, limit);
        var responses = result.getContent().stream()
            .map(TerminalDtoMapper::toResponse)
            .toList();
        return PaginatedResponse.of(responses, page, limit, result.getTotalElements());
    }

    @PostMapping
    public ResponseEntity<TerminalResponse> create(
            @PathVariable Long merchantId,
            @Valid @RequestBody CreateTerminalRequest request) {
        var terminal = terminalService.createTerminal(merchantId, request);
        var response = TerminalDtoMapper.toResponse(terminal);
        return ResponseEntity.created(URI.create("/api/v1/terminals/" + terminal.tid())).body(response);
    }
}

// Direct terminal access
@RestController
@RequestMapping("/api/v1/terminals")
public class TerminalController {

    private final TerminalService terminalService;

    public TerminalController(TerminalService terminalService) {
        this.terminalService = terminalService;
    }

    @GetMapping("/{tid}")
    public TerminalResponse getByTid(@PathVariable String tid) {
        return TerminalDtoMapper.toResponse(terminalService.findByTid(tid));
    }

    @PutMapping("/{tid}")
    public TerminalResponse update(@PathVariable String tid, @Valid @RequestBody UpdateTerminalRequest request) {
        return TerminalDtoMapper.toResponse(terminalService.updateTerminal(tid, request));
    }
}
```

## JSON Serialization Configuration

```java
@Configuration
public class JacksonConfig {

    @Bean
    public Jackson2ObjectMapperBuilderCustomizer jsonCustomizer() {
        return builder -> builder
            .serializationInclusion(JsonInclude.Include.NON_NULL)
            .featuresToDisable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
            .modules(new JavaTimeModule());
    }
}
```

## Anti-Patterns (FORBIDDEN)

```java
// FORBIDDEN — Verbs in URL
@PostMapping("/createMerchant")  // Use POST /api/v1/merchants
public MerchantResponse createMerchant(...) { ... }

// FORBIDDEN — 200 for errors
@PostMapping
public ResponseEntity<Map<String, Object>> create(@RequestBody CreateMerchantRequest request) {
    try {
        var merchant = service.create(request);
        return ResponseEntity.ok(Map.of("success", true, "data", merchant));
    } catch (Exception e) {
        return ResponseEntity.ok(Map.of("success", false, "error", e.getMessage()));  // Wrong!
    }
}

// FORBIDDEN — Exposing JPA Entity directly
@GetMapping("/{id}")
public MerchantEntity getById(@PathVariable Long id) {
    return repository.findById(id).orElseThrow();
}

// FORBIDDEN — No pagination on list endpoints
@GetMapping
public List<MerchantResponse> listAll() {
    return repository.findAll().stream().map(...).toList();  // No limit!
}

// FORBIDDEN — Constructing ProblemDetail directly
return new ProblemDetail("/errors/not-found", "Not Found", 404, ...);
// Use factory methods: ProblemDetail.notFound(...)

// FORBIDDEN — Exception handler without logging in default
default -> ProblemDetail.internalError("error", path);  // Missing LOG.error(...)

// FORBIDDEN — DTOs without @Schema
public record MerchantResponse(Long id, String mid, String name) {}  // Missing @Schema
```
