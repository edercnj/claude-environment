# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# API Gateway Pattern

## Purpose
The API Gateway is a single entry point that sits between external clients and backend services. It encapsulates internal system architecture and provides a unified API tailored to each client type. Every rule below is **mandatory** — not aspirational.

## Gateway Responsibilities

### GW-01: Request Routing

**Path-based routing:**
- Route `/api/v1/users/**` to the Users service, `/api/v1/orders/**` to the Orders service
- Version prefixes (`/v1/`, `/v2/`) route to different service deployments
- Strip gateway-specific prefixes before forwarding (e.g., `/api/v1/users/123` becomes `/users/123` at the backend)

**Header-based routing:**
- Route based on `Accept` header (e.g., `application/vnd.company.v2+json` to v2 backend)
- Route based on custom headers (e.g., `X-Client-Type: mobile` to mobile-optimized backend)
- A/B testing headers route to canary deployments

**Query-param-based routing:**
- Feature flag parameters (e.g., `?beta=true`) route to experimental backends
- Use sparingly — prefer header-based routing for cleanliness

**Rules:**
- Routing configuration MUST be declarative (YAML/JSON), not embedded in application code
- Default route MUST return `404` with a structured error body, never expose internal topology
- Health-check endpoints (`/health`, `/ready`) MUST NOT be routed to backends — the gateway itself responds

### GW-02: Authentication

**Token validation (JWT / OAuth2):**
- Validate JWT signature, expiration (`exp`), issuer (`iss`), and audience (`aud`) at the gateway
- Extract claims and inject them as headers to backend services (e.g., `X-User-Id`, `X-Tenant-Id`)
- NEVER forward raw tokens to backends unless the backend explicitly requires them for downstream calls
- Token refresh is the client's responsibility — the gateway only validates

**API key validation:**
- API keys identify the calling application, not the user
- Validate against a fast lookup (in-memory cache backed by a key store)
- Rate-limit and usage-plan enforcement is tied to the API key
- API keys MUST be sent in headers (`X-API-Key`), never in query parameters (they leak in logs and referrer headers)

**Rules:**
- Authentication MUST happen before any routing or transformation logic
- Failed authentication returns `401 Unauthorized` with a structured error body — no internal details
- Public endpoints (e.g., `/health`, `/docs`) MUST be explicitly allowlisted to skip authentication

### GW-03: Rate Limiting

**Per-client limiting:**
- Identify client by API key, JWT subject, or IP address (in that priority order)
- Default: 100 requests/minute per client (configurable per plan)

**Per-endpoint limiting:**
- Write endpoints (`POST`, `PUT`, `DELETE`) get stricter limits than read endpoints (`GET`)
- Expensive endpoints (e.g., `/reports/generate`) get dedicated low limits

**Global limiting:**
- Protect the gateway itself from total overload regardless of individual client limits
- Global limit MUST be higher than the sum of expected peak per-client traffic

**Rules:**
- Return `429 Too Many Requests` with `Retry-After` header (seconds until the window resets)
- Use sliding window or token bucket algorithm — fixed window causes thundering herd at window boundaries
- Rate limit state MUST be stored in a shared store (Redis) for multi-instance gateways

### GW-04: Request/Response Transformation

**Header injection:**
- Add correlation/trace headers (`X-Request-Id`, `X-Trace-Id`) if not present
- Add internal routing headers (`X-Upstream-Service`, `X-Gateway-Region`)
- Strip sensitive client headers that backends should not trust (e.g., `X-Forwarded-For` spoofing)

**Body rewriting:**
- Transform between client-facing API schema and internal service schema when they diverge
- Aggregate responses from multiple backend calls into a single client response (API composition)
- Redact sensitive fields from responses (e.g., internal IDs, debug metadata in production)

**Rules:**
- Transformation logic MUST be lightweight — heavy transformations belong in a BFF or dedicated service
- NEVER modify request bodies without explicit configuration — pass-through is the default
- Response transformations MUST NOT break streaming responses (chunked transfer encoding)

### GW-05: Load Balancing

**Algorithms:**

| Algorithm | Use When |
|-----------|----------|
| Round-robin | Backend instances are homogeneous and stateless |
| Weighted round-robin | Instances have different capacities (e.g., mixed instance sizes) |
| Least connections | Request duration varies significantly across endpoints |
| Consistent hashing | Session affinity needed (use `X-User-Id` or similar as hash key) |

**Rules:**
- Health checks MUST be active (periodic probes), not just passive (failure counting)
- Unhealthy backends MUST be removed from the pool within one health check interval
- Recovery MUST be gradual — restored backends receive a fraction of traffic before full inclusion

### GW-06: Circuit Breaking

- Open the circuit after **5 consecutive failures** or **50% error rate** in a 30-second window (configurable)
- Half-open state: allow **1 probe request** every 10 seconds to test recovery
- Closed state: resume normal traffic after **3 consecutive successful probes**
- Return `503 Service Unavailable` with `Retry-After` header when the circuit is open
- Circuit state MUST be per-backend-service, not global — one failing service must not block others

### GW-07: Caching

**Response caching for GET requests:**
- Cache key: method + path + sorted query parameters + relevant headers (e.g., `Accept`, `Authorization`)
- Respect `Cache-Control` headers from backends (`max-age`, `no-cache`, `no-store`)
- Default TTL: 60 seconds for cacheable responses without explicit `Cache-Control`

**Cache invalidation strategy:**
- Purge on `POST`/`PUT`/`DELETE` to the same resource path
- Support explicit purge via admin API or webhook from backend services
- Use `ETag` and `If-None-Match` for conditional requests to reduce bandwidth

**Rules:**
- NEVER cache responses with `Set-Cookie` headers
- NEVER cache responses to authenticated requests unless the backend explicitly opts in via `Cache-Control: public`
- Cache storage: use an in-memory store (local) for single-instance or a distributed cache (Redis) for multi-instance

### GW-08: CORS (Cross-Origin Resource Sharing)

- Centralize CORS configuration at the gateway — backends MUST NOT set CORS headers
- Allowlist specific origins — NEVER use `Access-Control-Allow-Origin: *` in production
- Pre-flight (`OPTIONS`) responses MUST be cached (`Access-Control-Max-Age: 86400`)
- Expose only necessary headers via `Access-Control-Expose-Headers`

```
# Example CORS configuration
allowed_origins:
  - "https://app.example.com"
  - "https://admin.example.com"
allowed_methods: ["GET", "POST", "PUT", "DELETE", "PATCH"]
allowed_headers: ["Authorization", "Content-Type", "X-Request-Id"]
expose_headers: ["X-Request-Id", "X-Trace-Id"]
max_age: 86400
allow_credentials: true
```

### GW-09: Request Validation

- Validate request schema (JSON Schema, OpenAPI spec) at the gateway before forwarding
- Reject malformed requests with `400 Bad Request` and a structured validation error body
- Validate `Content-Type` header matches the expected payload format
- Enforce maximum request body size (default: 1 MB, configurable per endpoint)
- Sanitize inputs: strip null bytes, enforce UTF-8 encoding

**Rules:**
- Schema validation at the gateway is for structural correctness only — business validation belongs in the backend
- Validation schemas MUST be versioned alongside the API specification
- NEVER silently drop invalid fields — either reject or pass through, based on explicit policy

### GW-10: Logging & Observability

**Access logs:**
- Log every request: timestamp, method, path, status code, latency, client IP, request ID
- Log format MUST be structured (JSON) for machine parsing
- NEVER log request/response bodies by default — enable only for specific endpoints in debug mode

**Request tracing:**
- Inject `X-Request-Id` (UUID v4) if not present in the incoming request
- Propagate W3C Trace Context headers (`traceparent`, `tracestate`) to backends
- Include gateway processing time as a span in the distributed trace

**Metrics:**
- Expose request count, error rate, and latency percentiles (p50, p95, p99) per route
- Expose circuit breaker state changes as events
- Expose rate limit hits as a counter per client/endpoint

## Gateway Patterns

### Edge Gateway

**Single entry point for all external traffic.**

```
[Internet] --> [Edge Gateway] --> [Service A]
                              --> [Service B]
                              --> [Service C]
```

- Most common pattern — suitable for most microservice architectures
- Handles all cross-cutting concerns (auth, rate limiting, logging) in one place
- Risk: single point of failure — mitigate with horizontal scaling and multi-AZ deployment
- Risk: deployment bottleneck — mitigate with declarative configuration and zero-downtime reloads

### Backend for Frontend (BFF)

**Per-client gateway — each client type gets its own gateway.**

```
[Mobile App]  --> [Mobile BFF]  --> [Service A, B]
[Web App]     --> [Web BFF]     --> [Service A, C]
[Partner API] --> [Partner BFF] --> [Service B, C]
```

- Use when different clients need fundamentally different API shapes or aggregation logic
- Each BFF is owned by the client team, not the platform team
- BFF contains client-specific transformation and aggregation — NOT business logic
- Do not let BFFs diverge into independent backends — shared logic stays in the underlying services

### Micro Gateway (Service Mesh Ingress)

**Per-service or per-team gateway.**

```
[Edge Gateway] --> [Team A Gateway] --> [Team A Services]
               --> [Team B Gateway] --> [Team B Services]
```

- Use when teams need independent release cycles for their API surface
- Each micro gateway handles team-specific routing and policies
- The edge gateway handles global concerns (TLS termination, global rate limits, DDoS protection)
- Common in service mesh architectures where each namespace has its own ingress

## When NOT to Use a Gateway

| Scenario | Alternative |
|----------|-------------|
| Internal service-to-service communication | Service mesh sidecar (Envoy, Linkerd) or direct calls with client-side load balancing |
| Simple single-service deployment | Direct exposure via load balancer (ALB/NLB) — a gateway adds unnecessary latency and complexity |
| Gateway becomes a deployment bottleneck | Split into BFF or micro gateway pattern |
| Team cannot maintain gateway infrastructure | Use a managed API gateway service (AWS API Gateway, GCP API Gateway) |

## Anti-Patterns (FORBIDDEN)

- Business logic in the gateway — the gateway routes and transforms, it does NOT make business decisions
- Monolithic gateway configuration — use modular, per-service route files merged at deploy time
- Synchronous calls between gateway plugins — plugins execute in a pipeline, each stage is independent
- Caching authenticated user-specific responses without cache key isolation — leads to data leaks
- Logging full request/response bodies in production — performance and privacy disaster
- Hardcoded backend URLs — use service discovery or DNS-based resolution
- Gateway as the only layer of security — defense in depth requires backends to validate too
