# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# gRPC & Proto3 Conventions

## Package Naming

| Rule | Convention | Example |
|------|-----------|---------|
| Format | Reverse domain + service + version | `com.company.payments.v1` |
| Version suffix | Always include major version | `v1`, `v2` |
| Lowercase only | No uppercase in package names | `com.company.order_service.v1` |
| Word separation | Underscores for multi-word segments | `payment_gateway`, not `paymentGateway` |

Each `.proto` file MUST declare its package. Files in the same logical service MUST share the same package prefix.

## Service Naming

| Rule | Convention |
|------|-----------|
| Case | PascalCase |
| Suffix | Always end with `Service` |
| Scope | One service per bounded context |
| File | One service definition per `.proto` file |

Examples: `OrderService`, `PaymentGatewayService`, `NotificationService`

NEVER combine unrelated RPCs in a single service. If a service exceeds 10 RPC methods, evaluate splitting by subdomain.

## Message Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Messages | PascalCase | `CreateOrderRequest`, `OrderResponse` |
| Request messages | Suffix with `Request` | `GetOrderRequest`, `ListOrdersRequest` |
| Response messages | Suffix with `Response` | `GetOrderResponse`, `ListOrdersResponse` |
| Wrapper messages | Describe content | `OrderDetails`, `PaymentSummary` |
| Nested messages | PascalCase, scoped to parent | `Order.LineItem` |

Every RPC MUST have its own dedicated Request and Response message type. NEVER reuse a single message across multiple RPCs even if the fields are identical today -- they will diverge.

## Field Naming

| Rule | Convention | Example |
|------|-----------|---------|
| Case | snake_case | `order_id`, `created_at`, `line_items` |
| Boolean prefix | Use `is_`, `has_`, `can_`, `should_` | `is_active`, `has_discount` |
| ID fields | Suffix with `_id` | `customer_id`, `order_id` |
| Timestamp fields | Suffix with `_at` or `_time` | `created_at`, `expiry_time` |
| Duration fields | Suffix with unit or use `google.protobuf.Duration` | `timeout_seconds` or Duration type |

Field numbers 1-15 use 1 byte on the wire; reserve these for frequently populated fields. Field numbers 16-2047 use 2 bytes.

## Enum Conventions

| Rule | Convention |
|------|-----------|
| Enum name | PascalCase |
| Values | UPPER_SNAKE_CASE |
| Zero value | MUST be `UNSPECIFIED` and represent unknown/default |
| Prefix | All values prefixed with enum name |

Example structure:
- `OrderStatus` enum values: `ORDER_STATUS_UNSPECIFIED = 0`, `ORDER_STATUS_PENDING = 1`, `ORDER_STATUS_APPROVED = 2`, `ORDER_STATUS_REJECTED = 3`

**Rules:**
- The zero value MUST always be `_UNSPECIFIED` and MUST NOT carry business meaning
- NEVER reuse numeric values (even after deprecation; use `reserved` instead)
- Prefix all values with the enum type name to avoid namespace collisions
- New values MUST be added at the end (after the highest existing number)

## Oneof Usage Guidelines

| Use When | Avoid When |
|----------|------------|
| Exactly one of several fields must be set | Fields are independently optional |
| Polymorphic payloads (payment by card vs bank) | All fields can coexist |
| Mutually exclusive configuration options | Default behavior is acceptable |

**Rules:**
- Oneof fields MUST NOT be `repeated`
- Oneof fields MUST NOT be `map`
- Always handle the "none set" case in application code
- Document which oneof variant is expected for each use case

## Repeated vs Map Field Choices

| Use `repeated` When | Use `map` When |
|---------------------|----------------|
| Order matters | Lookup by key is primary access pattern |
| Duplicates are possible/valid | Keys are unique identifiers |
| Elements are complex messages | Values are simple or messages keyed by string/int |
| Pagination or streaming of elements | Metadata, labels, or configuration key-value pairs |

**Map constraints:**
- Keys MUST be string or integer types (not float, bytes, or enum)
- Maps are unordered; do not depend on iteration order
- NEVER use map when order is significant

## Streaming Patterns

| Pattern | Direction | Use Cases |
|---------|-----------|-----------|
| Unary | Request -> Response | Standard CRUD, simple queries |
| Server streaming | Request -> stream Response | Real-time feeds, large result sets, event subscriptions |
| Client streaming | stream Request -> Response | File upload, batch ingestion, telemetry reporting |
| Bidirectional streaming | stream Request <-> stream Response | Chat, collaborative editing, real-time sync |

**Guidelines:**
- Prefer unary RPCs for simple operations; do not over-use streaming
- Server streaming: send an initial metadata frame for client to validate before data flows
- Client streaming: respond with summary/acknowledgment after stream completes
- Bidirectional: define clear message sequencing protocol; document who sends first
- All streaming RPCs MUST handle cancellation gracefully
- Set maximum message size per stream; reject streams that exceed limits

## Deadline Propagation

- Every RPC call MUST set a deadline (timeout)
- Deadlines propagate automatically across service boundaries in gRPC
- Parent deadline MUST be shorter than or equal to the sum of child deadlines
- Recommended defaults: internal service calls 5s, external-facing 30s, batch operations 120s
- NEVER use infinite deadlines; always set an upper bound
- Check `context.Err()` / equivalent at each processing stage; abort early if deadline exceeded
- Log deadline violations with upstream service identity for capacity planning

## Error Model

### Standard Error Codes

| Code | Name | When to Use |
|------|------|-------------|
| 0 | OK | Success |
| 1 | CANCELLED | Client cancelled the request |
| 2 | UNKNOWN | Unknown error (catch-all; avoid) |
| 3 | INVALID_ARGUMENT | Client sent invalid data (validation) |
| 4 | DEADLINE_EXCEEDED | Operation timed out |
| 5 | NOT_FOUND | Resource does not exist |
| 6 | ALREADY_EXISTS | Duplicate creation attempt |
| 7 | PERMISSION_DENIED | Authenticated but not authorized |
| 8 | RESOURCE_EXHAUSTED | Rate limit or quota exceeded |
| 9 | FAILED_PRECONDITION | System not in required state |
| 10 | ABORTED | Concurrency conflict (retry may succeed) |
| 12 | UNIMPLEMENTED | RPC not implemented |
| 13 | INTERNAL | Internal server error (do not expose details) |
| 14 | UNAVAILABLE | Service temporarily unavailable (retry with backoff) |
| 16 | UNAUTHENTICATED | Missing or invalid authentication |

### Rich Error Details

Use `google.rpc.Status` with `details` field containing well-known types:
- `google.rpc.BadRequest` -- field-level validation violations
- `google.rpc.RetryInfo` -- minimum retry delay
- `google.rpc.DebugInfo` -- internal debug context (NEVER in production)
- `google.rpc.ErrorInfo` -- machine-readable error reason and metadata

NEVER expose internal error messages or stack traces through gRPC error details in production.

## Reflection API

| Environment | Enable Reflection? | Reasoning |
|-------------|:-----------------:|-----------|
| Local development | Yes | Enables tools like `grpcurl`, `grpcui` |
| Staging/testing | Yes | Facilitates integration testing |
| Production | No | Security risk; exposes service contract |

When reflection is disabled, provide the compiled `.proto` files or a proto registry for consumers.

## Health Check Protocol

All gRPC services MUST implement the `grpc.health.v1.Health` service.

**Requirements:**
- Return `SERVING` when the service and its critical dependencies are healthy
- Return `NOT_SERVING` when the service cannot process requests
- Support per-service health checks (empty service name = overall health)
- Integrate with load balancer health probes and Kubernetes readiness checks
- Health check MUST NOT have heavy dependencies (no database queries; use cached status)
- Response time for health checks MUST be under 100ms

## Anti-Patterns (FORBIDDEN)

- Missing `UNSPECIFIED` zero value in enums -- the zero value MUST always exist and mean "unknown"
- Reusing Request/Response messages across different RPCs -- each RPC gets its own pair
- Field numbers that skip values without `reserved` declarations
- Streaming RPCs without cancellation handling
- RPCs without deadlines -- every call MUST have a timeout
- Using `google.protobuf.Struct` or `google.protobuf.Any` as a lazy alternative to proper schema design
- Exposing reflection in production
- Health check endpoints that perform expensive operations
- Returning `UNKNOWN` error code for errors that have a specific code
- Mixing business logic error details with transport-level errors
- Proto files without package declaration
- Services with more than 10 RPCs that should be split
- Using `float`/`double` for monetary values -- use `int64` cents or `string` with explicit precision
