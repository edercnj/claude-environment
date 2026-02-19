# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 06 — API Design Principles

## Principles
- **RESTful** conventions for HTTP APIs
- **JSON** as default serialization format
- **OpenAPI 3.0** for documentation (auto-generated when possible)
- **Versioning** in URL: `/api/v1/`

## URL Structure

```
/api/v1/{resource}              → collection
/api/v1/{resource}/{id}         → specific resource
/api/v1/{resource}/{id}/{sub}   → sub-resource
```

Use nouns for resources, HTTP methods for actions:
- `GET /api/v1/merchants` — list
- `POST /api/v1/merchants` — create
- `GET /api/v1/merchants/{id}` — get by ID
- `PUT /api/v1/merchants/{id}` — update
- `DELETE /api/v1/merchants/{id}` — deactivate (soft delete)

## Status Codes

| Operation | Success | Common Errors |
|-----------|---------|---------------|
| GET list | 200 OK | 400 Bad Request (invalid filter) |
| GET item | 200 OK | 404 Not Found |
| POST | 201 Created (with Location header) | 400 Validation, 409 Conflict (duplicate) |
| PUT | 200 OK | 400 Validation, 404 Not Found |
| DELETE | 204 No Content | 404 Not Found |
| Rate Limited | — | 429 Too Many Requests + `Retry-After` |
| Service Degraded | — | 503 Service Unavailable + `Retry-After` |

## Standardized Error Response (RFC 7807)

All error responses follow the Problem Details format:

```json
{
  "type": "/errors/merchant-already-exists",
  "title": "Merchant Already Exists",
  "status": 409,
  "detail": "A merchant with ID '123456789012345' already exists",
  "instance": "/api/v1/merchants",
  "extensions": {
    "existingId": "123456789012345"
  }
}
```

### ProblemDetail Structure

| Field | Type | Description |
|-------|------|-------------|
| type | string | Error type URI (e.g., `/errors/{error-slug}`) |
| title | string | Human-readable title |
| status | int | HTTP status code |
| detail | string | Detailed description of the specific occurrence |
| instance | string | URI of the request that caused the error |
| extensions | object | Additional fields for debugging (optional) |

### Factory Methods Pattern

Centralize error creation through factory methods:

```
ProblemDetail.notFound(detail, instance)
ProblemDetail.conflict(detail, instance, extensions)
ProblemDetail.badRequest(detail, instance)
ProblemDetail.validationError(detail, instance, violations)
ProblemDetail.internalError(detail, instance)
ProblemDetail.tooManyRequests(detail, instance)
ProblemDetail.serviceUnavailable(detail, instance)
```

**Rule:** NEVER construct ProblemDetail directly — use factory methods. Each new error type MUST have a corresponding factory method.

## Pagination

All list endpoints MUST be paginated.

```json
{
  "data": [...],
  "pagination": {
    "page": 0,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}
```

Query params: `?page=0&limit=20&sort=createdAt,desc`

**Rules:**
- `page` is **0-based** internally
- Default `limit`: 20
- Maximum `limit`: 100
- Always include `total` and `totalPages`

## Filters

Use query parameters for filtering collections:

```
GET /api/v1/transactions?type=debit&status=approved&from=2026-02-01&to=2026-02-15&limit=50
```

## JSON Serialization Rules

| Rule | Standard |
|------|----------|
| Dates | ISO 8601 (`2026-02-16T14:30:00Z`) |
| Field names | camelCase in JSON |
| Nulls | Omit null fields |
| Enums | Serialize as string (`"APPROVED"`, not `0`) |
| Monetary values | Use integer cents or string with explicit precision |

## Input Validation

All request DTOs MUST have validation annotations/rules:

```
CreateMerchantRequest:
    mid: required, max 15 chars
    name: required, max 100 chars
    document: required, pattern "\\d{11,14}"
    mcc: required, exactly 4 digits
```

Validation errors return 400 with field-level detail:

```json
{
  "type": "/errors/validation-error",
  "title": "Validation Error",
  "status": 400,
  "detail": "Validation failed",
  "instance": "/api/v1/merchants",
  "extensions": {
    "violations": {
      "mid": ["must not be blank"],
      "document": ["must match pattern \\d{11,14}"]
    }
  }
}
```

## Exception Mapping

### Dual Mapper Pattern

Two complementary exception mappers:

1. **Domain Exception Mapper** — Maps domain exceptions to RFC 7807 responses using pattern matching
   - Each domain exception has a corresponding case
   - Default case logs at ERROR and returns 500 generic (never expose stack traces)

2. **Validation Exception Mapper** — Extracts field-level violations from validation framework
   - Groups violations by field name
   - Returns 400 with structured violation details

## API Documentation

All request/response DTOs MUST have documentation annotations:
- Description on class level
- Description + example on each field
- Nested objects also documented

## Security

- Authentication: API Key via header or OAuth2 / JWT
- Sensitive data: NEVER expose in responses (mask or omit)
- Rate limiting: per API key or per IP
- CORS: configure explicitly if frontend clients exist

## Protocol-Specific Conventions

This rule covers universal API design principles. For detailed, protocol-specific conventions see:

- **REST:** `protocols/rest/rest-conventions.md` — cursor/offset pagination, HATEOAS, versioning strategies, bulk operations, partial updates (JSON Merge Patch / JSON Patch)
- **REST (OpenAPI):** `protocols/rest/openapi-conventions.md` — schema organization, $ref reuse, security schemes, operation IDs
- **gRPC:** `protocols/grpc/grpc-conventions.md` — Proto3 style guide, streaming patterns, deadline propagation, error model
- **GraphQL:** `protocols/graphql/graphql-conventions.md` — schema design, DataLoader, Relay pagination, complexity analysis
- **WebSocket:** `protocols/websocket/websocket-conventions.md` — message framing, heartbeat, reconnection, connection draining
- **Event-Driven:** `protocols/event-driven/event-conventions.md` — CloudEvents, schema registry, event versioning

## Anti-Patterns (FORBIDDEN)

- Verbs in URL (`/api/v1/createMerchant`) — use nouns + HTTP verb
- Return 200 for errors with `{ "error": true }` — use HTTP status codes
- Expose ORM entities directly — ALWAYS use DTOs
- Return lists without pagination — ALWAYS paginate
- Ignore Content-Type — ALWAYS validate `application/json`
- Construct error responses inline — use factory methods
- Exception mapper without logging the `default` case
- Stack traces in production error responses
- DTOs without documentation annotations
