# API Gateway

## Intent

The API Gateway provides a single entry point for all client requests in a microservice architecture. It handles cross-cutting concerns -- routing, authentication, rate limiting, load balancing, and response aggregation -- at the edge, shielding internal services from direct client exposure. This decouples clients from the internal service topology, enabling services to be refactored, split, or merged without impacting consumers.

## When to Use

- `architecture.style=microservice` where clients need a unified API surface
- Systems with multiple client types (web, mobile, CLI) that require different response shapes
- When cross-cutting concerns (auth, rate limiting, logging) must be applied consistently at the edge
- APIs exposed to external consumers who should not know the internal service topology
- When request aggregation is needed to reduce client-side round trips

## When NOT to Use

- Monolithic applications with a single API surface
- Internal service-to-service communication (use service mesh or direct calls instead)
- When a simple reverse proxy or load balancer is sufficient
- Systems with only one or two services where the gateway adds unnecessary indirection
- When the team cannot maintain the gateway as a critical infrastructure component

## Structure

```
    Clients
    ┌──────┐  ┌──────┐  ┌──────┐
    │ Web  │  │Mobile│  │ CLI  │
    └──┬───┘  └──┬───┘  └──┬───┘
       │         │         │
       ▼         ▼         ▼
    ┌─────────────────────────────────────────┐
    │              API Gateway                 │
    │                                          │
    │  ┌──────────┐  ┌───────────┐  ┌───────┐│
    │  │  Auth     │  │Rate Limit │  │Logging││
    │  └──────────┘  └───────────┘  └───────┘│
    │  ┌──────────┐  ┌───────────┐  ┌───────┐│
    │  │  Routing  │  │Aggregation│  │ Cache ││
    │  └──────────┘  └───────────┘  └───────┘│
    │  ┌──────────────────────────────────────┐│
    │  │  Protocol Translation (REST/gRPC)    ││
    │  └──────────────────────────────────────┘│
    └──────┬──────────┬──────────┬─────────────┘
           │          │          │
           ▼          ▼          ▼
      ┌────────┐ ┌────────┐ ┌────────┐
      │Service │ │Service │ │Service │
      │   A    │ │   B    │ │   C    │
      └────────┘ └────────┘ └────────┘
```

## Implementation Guidelines

### Core Responsibilities

| Responsibility | Description |
|---------------|-------------|
| Request routing | Route requests to the appropriate backend service based on path, headers, or method |
| Authentication | Verify identity tokens (JWT, OAuth2) at the edge before forwarding |
| Authorization | Enforce coarse-grained access control (fine-grained stays in services) |
| Rate limiting | Protect backend services with per-client, per-endpoint, and global limits |
| Request/response transformation | Translate protocols, reshape payloads, add/remove headers |
| Aggregation | Compose responses from multiple backend services into a single client response |
| Load balancing | Distribute traffic across service instances |
| Caching | Cache responses for idempotent GET requests at the edge |

### Routing Principles

- Route based on URL path prefix, HTTP method, and headers
- Version APIs at the gateway level (path-based: /v1/, /v2/ or header-based)
- Support canary routing for gradual rollouts (route a percentage of traffic to new versions)
- Maintain a routing table that maps external paths to internal service endpoints
- Gateway routing configuration MUST be version-controlled and reviewed

### Authentication at the Edge

| Aspect | Guideline |
|--------|-----------|
| Token validation | Validate JWT/OAuth2 tokens at the gateway; reject invalid tokens before they reach services |
| Token propagation | Forward validated identity context (user ID, roles, tenant) to backend services via headers |
| Service identity | Backend services trust the gateway's forwarded identity; mutual TLS between gateway and services |
| Public endpoints | Explicitly whitelist unauthenticated endpoints; deny by default |

### Rate Limiting at the Edge

| Scope | Strategy | Purpose |
|-------|----------|---------|
| Per API key | Token bucket | Prevent single consumer from monopolizing resources |
| Per endpoint | Fixed window | Protect expensive operations |
| Global | Sliding window | Overall system protection |

### Aggregation Guidelines

- Aggregation requests to multiple backend services should execute in parallel
- Define timeouts per backend call; return partial results if non-critical services are slow
- Implement circuit breakers for each backend service the gateway calls
- Avoid deep business logic in the aggregation layer; it should be structural composition only

### Gateway Anti-Patterns

| Anti-Pattern | Problem | Alternative |
|-------------|---------|-------------|
| Business logic in gateway | Gateway becomes a monolith | Keep logic in services |
| Single gateway for all concerns | Single point of failure and bottleneck | Use BFF pattern for client-specific needs |
| No health checks for backends | Gateway routes to dead services | Integrate with service discovery and health checks |
| Unbounded aggregation | Gateway timeouts on complex compositions | Limit aggregation depth; use async patterns |
| Gateway as service mesh | Conflating edge and internal concerns | Use service mesh for service-to-service |

### Operational Guidelines

- The gateway is a critical path component; it MUST be highly available (multi-instance, multi-zone)
- Gateway configuration changes MUST go through the same review process as code changes
- Monitor gateway latency independently from backend latency to detect gateway-introduced overhead
- Implement circuit breakers within the gateway for each backend service
- Support graceful degradation: if a non-critical backend is down, serve partial responses

## Relationship to Other Patterns

- **Backend for Frontend (BFF)**: Specialized gateways per client type; the API gateway may route to BFFs rather than directly to services
- **Service Discovery**: The gateway must resolve service locations dynamically; integrate with service registry or DNS
- **Circuit Breaker**: Each backend call from the gateway should be wrapped in a circuit breaker
- **Rate Limiting**: The gateway is the primary enforcement point for rate limiting (see `core/09-resilience-principles.md`)
- **Bulkhead**: Isolate gateway resources per backend service to prevent one slow service from affecting all routes
