# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# REST API Conventions

> Extends: `core/06-api-design-principles.md` (summary). This file is the authoritative reference for REST conventions.

## Resource Naming

| Rule | Convention | Example |
|------|-----------|---------|
| Collection resources | Plural nouns | `/orders`, `/customers`, `/invoices` |
| Multi-word resources | kebab-case | `/payment-methods`, `/line-items` |
| Singleton resources | Singular noun | `/cart`, `/profile` (per-user context) |
| Sub-resources | Nested under parent | `/orders/{id}/line-items` |
| Resource identifiers | Opaque strings or UUIDs | `/orders/550e8400-e29b-41d4` |
| Maximum nesting depth | 2 levels | `/customers/{id}/orders/{orderId}` |

**Naming constraints:**
- NEVER use verbs in URIs (`/createOrder` is forbidden; use `POST /orders`)
- NEVER use CRUD prefixes (`/getUsers` is forbidden; use `GET /users`)
- NEVER expose internal implementation (`/db/table/row` is forbidden)
- Use lowercase only in path segments

## HTTP Methods Mapping

| Method | Semantics | Idempotent | Safe | Request Body | Typical Success |
|--------|-----------|:----------:|:----:|:------------:|:---------------:|
| GET | Read resource(s) | Yes | Yes | No | 200 OK |
| POST | Create resource / trigger action | No | No | Yes | 201 Created |
| PUT | Full replace of resource | Yes | No | Yes | 200 OK |
| PATCH | Partial update of resource | No* | No | Yes | 200 OK |
| DELETE | Remove resource | Yes | No | No | 204 No Content |
| HEAD | Metadata only (same as GET, no body) | Yes | Yes | No | 200 OK |
| OPTIONS | Supported methods / CORS preflight | Yes | Yes | No | 204 No Content |

*PATCH is idempotent only when using JSON Merge Patch with the same payload repeatedly.

## Status Codes (Comprehensive)

### Success (2xx)

| Code | Meaning | When to Use |
|------|---------|-------------|
| 200 OK | Request succeeded | GET, PUT, PATCH returning updated resource |
| 201 Created | Resource created | POST; MUST include `Location` header |
| 202 Accepted | Async processing started | Long-running operations; return task/job URI |
| 204 No Content | Success with no body | DELETE; PUT/PATCH when not returning resource |

### Redirection (3xx)

| Code | Meaning | When to Use |
|------|---------|-------------|
| 301 Moved Permanently | Resource URI changed permanently | API version sunset with new URI |
| 304 Not Modified | Cached response is still valid | Conditional GET with ETag/If-None-Match |

### Client Errors (4xx)

| Code | Meaning | When to Use |
|------|---------|-------------|
| 400 Bad Request | Malformed or invalid input | Validation failures, malformed JSON |
| 401 Unauthorized | Authentication required or failed | Missing or invalid credentials |
| 403 Forbidden | Authenticated but not authorized | Insufficient permissions |
| 404 Not Found | Resource does not exist | Unknown ID or URI |
| 405 Method Not Allowed | HTTP method not supported | PUT on a read-only resource |
| 406 Not Acceptable | Cannot produce requested format | Unsupported Accept header |
| 409 Conflict | State conflict | Duplicate creation, concurrent edit collision |
| 410 Gone | Resource permanently deleted | Distinguishes from 404 for hard-deleted resources |
| 412 Precondition Failed | Conditional update failed | Optimistic locking with If-Match / ETag |
| 415 Unsupported Media Type | Wrong Content-Type | Sending XML when only JSON is accepted |
| 422 Unprocessable Entity | Semantic validation failure | Well-formed but business-rule-invalid request |
| 429 Too Many Requests | Rate limit exceeded | MUST include `Retry-After` header |

### Server Errors (5xx)

| Code | Meaning | When to Use |
|------|---------|-------------|
| 500 Internal Server Error | Unexpected failure | Unhandled exceptions (never expose details) |
| 502 Bad Gateway | Upstream service failure | Downstream dependency returned invalid response |
| 503 Service Unavailable | Temporarily overloaded | MUST include `Retry-After` header |
| 504 Gateway Timeout | Upstream timeout | Downstream dependency did not respond in time |

## RFC 7807 Error Format (Problem Details)

All error responses MUST use `application/problem+json` content type.

**Required fields:**

| Field | Type | Description |
|-------|------|-------------|
| type | URI | Machine-readable error type identifier (e.g., `/errors/validation-error`) |
| title | string | Short human-readable summary of the problem type |
| status | integer | HTTP status code (duplicated for convenience in logs) |
| detail | string | Human-readable explanation specific to this occurrence |
| instance | URI | URI that identifies the specific request (for correlation) |

**Optional extension fields:** Include additional context relevant to debugging (e.g., `violations`, `retryAfter`, `conflictingResource`). NEVER include stack traces or internal system details in production.

## Pagination

### Cursor-Based Pagination (Preferred for Large/Real-Time Data)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cursor` | Opaque token pointing to position in dataset | (none = start) |
| `limit` | Maximum items to return | 20 |

Response includes `next_cursor` (null when no more results). Use cursor-based when: data changes frequently, dataset is large (100k+ rows), consistent ordering is required, or deep pagination is expected.

### Offset-Based Pagination (Simple UI Use Cases)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `page` | 0-based page index | 0 |
| `limit` | Items per page | 20 |

Response includes `total`, `totalPages`. Use offset-based when: UI needs page numbers, dataset is small/stable, or total count is needed.

**Shared constraints:**
- Default `limit`: 20
- Maximum `limit`: 100
- All list endpoints MUST be paginated with no exceptions

## Filtering with Query Parameters

- Use flat query parameters: `?status=active&type=debit`
- Date ranges: `?from=2026-01-01&to=2026-01-31` (ISO 8601)
- Multi-value: `?status=active,pending` (comma-separated) or `?status=active&status=pending` (repeated)
- Partial match: `?name=like:acme` (prefixed operator)
- Range filters: `?amount=gte:1000&amount=lte:5000`
- NEVER use request body for GET filtering

## Sorting Conventions

- Query parameter: `?sort=createdAt,desc` or `?sort=-createdAt` (prefix minus for descending)
- Multiple sort fields: `?sort=status,asc&sort=createdAt,desc`
- Default sort: MUST be documented per endpoint
- Only allow sorting on indexed fields; reject unknown sort fields with 400

## HATEOAS Decision Guide

| Scenario | Use HATEOAS? | Reasoning |
|----------|:------------:|-----------|
| Public API consumed by unknown third parties | Yes | Clients discover capabilities dynamically |
| Internal microservice-to-microservice | No | Services share contracts; links add overhead |
| API with complex state machines | Yes | Links communicate available transitions |
| Simple CRUD API with fixed workflows | No | Overhead outweighs benefit |

When using HATEOAS, include a `_links` object with `rel` and `href` for each available action on the resource.

## Versioning Strategies

| Strategy | Format | Pros | Cons |
|----------|--------|------|------|
| URI path | `/api/v1/orders` | Explicit, easy to route, cache-friendly | URL pollution, harder to sunset |
| Custom header | `Api-Version: 1` | Clean URLs | Easy to forget, not visible in browser |
| Accept header | `Accept: application/vnd.api.v1+json` | Standards-compliant | Complex, poor tooling support |
| Query param | `?version=1` | Simple | Pollutes cache keys, easy to forget |

**Recommendation:** Use URI path versioning (`/api/v1/`) for external APIs. Use header versioning only when URI versioning is impractical (e.g., GraphQL endpoints).

## Content Negotiation

- Requests MUST include `Content-Type: application/json` for bodies
- Responses MUST include `Content-Type: application/json` (or `application/problem+json` for errors)
- Support `Accept` header; return 406 if the requested format is unsupported
- Character encoding: always UTF-8

## Bulk Operations

| Operation | Method | URI | Notes |
|-----------|--------|-----|-------|
| Batch create | POST | `/orders/batch` | Body contains array of resources |
| Batch update | PATCH | `/orders/batch` | Body contains array of partial updates with IDs |
| Batch delete | POST | `/orders/batch-delete` | Body contains array of IDs |

**Constraints:**
- Maximum batch size: 100 items per request (configurable)
- Return individual results per item (success/failure) with overall 200 or 207 Multi-Status
- Batch operations MUST be atomic (all-or-nothing) OR return per-item status; document which strategy is used

## Partial Updates: PATCH Strategies

| Strategy | Content-Type | Behavior | When to Use |
|----------|-------------|----------|-------------|
| JSON Merge Patch | `application/merge-patch+json` | Null removes field; missing fields unchanged | Simple updates, no array manipulation |
| JSON Patch | `application/json-patch+json` | Operations array (add, remove, replace, move, copy, test) | Complex updates, array element manipulation |

**Default recommendation:** JSON Merge Patch for most APIs due to simplicity. Use JSON Patch only when array element operations are required.

## Rate Limiting Headers

All rate-limited endpoints MUST include these response headers:

| Header | Description | Example |
|--------|-------------|---------|
| `X-RateLimit-Limit` | Maximum requests per window | `1000` |
| `X-RateLimit-Remaining` | Requests remaining in current window | `742` |
| `X-RateLimit-Reset` | Unix timestamp when the window resets | `1706140800` |
| `Retry-After` | Seconds to wait (only on 429 responses) | `30` |

Rate limit scope: per API key, per user, or per IP -- document which applies. Use sliding window or token bucket algorithms; fixed windows create thundering herd at reset boundaries.

## Anti-Patterns (FORBIDDEN)

- Verbs in URIs (`/api/v1/createOrder`) -- use HTTP methods with noun resources
- Returning 200 for error conditions with `{ "success": false }` -- use proper HTTP status codes
- Exposing ORM/database entities directly as API responses -- always use DTOs
- Unpaginated list endpoints -- every collection MUST be paginated
- Using POST for idempotent reads -- use GET
- Nested resources deeper than 2 levels (`/a/{id}/b/{id}/c/{id}/d`) -- flatten or use query params
- Inconsistent naming (mixing camelCase and snake_case in URIs)
- Including sensitive data (passwords, tokens, secrets) in query parameters or URIs
- Ignoring `Accept` and `Content-Type` headers
- Returning 500 with stack traces in production
- Designing RPC-style endpoints disguised as REST (`/api/v1/doSomething`)
- Using DELETE with a request body (some proxies/clients drop it)
- Returning different response shapes for the same endpoint based on conditions
