# Backend for Frontend (BFF)

## Intent

The Backend for Frontend pattern creates a dedicated backend service tailored to the needs of a specific client type (web, mobile, CLI, third-party). Instead of forcing all clients to consume a single generic API -- which inevitably becomes a compromise that serves no client well -- each BFF aggregates, transforms, and shapes responses specifically for its client. This eliminates over-fetching, under-fetching, and client-side orchestration complexity while keeping backend services focused on domain logic rather than presentation concerns.

## When to Use

- `architecture.style=microservice` with multiple client types (web SPA, native mobile, CLI, partner API)
- When different clients need significantly different response shapes, fields, or aggregation from the same backend services
- When mobile clients need optimized, minimal payloads compared to feature-rich web responses
- When client teams want to iterate independently on their API contracts without coordinating with backend teams
- Systems where client-side orchestration of multiple microservices creates latency and complexity

## When NOT to Use

- Single-client applications where a single API is sufficient
- When all clients consume the same data in the same shape (a shared API gateway suffices)
- Small systems with one or two backend services where aggregation is trivial
- When the team cannot maintain multiple BFF services (operational overhead)
- When GraphQL or similar query languages solve the response-shaping problem adequately

## Structure

```
    ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
    │  Web    │   │ Mobile  │   │   CLI   │   │ Partner │
    │  SPA    │   │  App    │   │  Tool   │   │   API   │
    └────┬────┘   └────┬────┘   └────┬────┘   └────┬────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
    ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
    │ Web BFF │   │Mobile   │   │ CLI BFF │   │Partner  │
    │         │   │  BFF    │   │         │   │  BFF    │
    │ Full    │   │Minimal  │   │Structured│  │Stable   │
    │ payload │   │ payload │   │  output  │   │contract │
    └────┬────┘   └────┬────┘   └────┬────┘   └────┬────┘
         │              │              │              │
         └──────────────┼──────────────┼──────────────┘
                        │              │
                        ▼              ▼
              ┌──────────────────────────────────┐
              │        Backend Microservices       │
              │                                    │
              │  ┌────────┐ ┌────────┐ ┌────────┐│
              │  │Order   │ │User    │ │Catalog ││
              │  │Service │ │Service │ │Service ││
              │  └────────┘ └────────┘ └────────┘│
              └──────────────────────────────────┘
```

## Implementation Guidelines

### BFF Responsibilities

| Responsibility | Description |
|---------------|-------------|
| Response shaping | Select and transform fields for the specific client |
| Aggregation | Compose data from multiple backend services into a single response |
| Protocol translation | Adapt between client protocol (REST, GraphQL) and backend protocols (gRPC, events) |
| Pagination adaptation | Translate between client pagination expectations and backend pagination models |
| Error translation | Map backend errors into client-appropriate error formats and messages |
| Client-specific caching | Cache responses tailored to the client's access patterns |

### What a BFF Must NOT Do

| Forbidden | Rationale |
|-----------|-----------|
| Domain business logic | Business rules belong in backend services; BFF is presentation-layer only |
| Direct database access | BFF calls backend services; it does not own data |
| Data mutation logic | Write operations are forwarded to backend services; BFF does not process them |
| Shared state between BFFs | Each BFF is independent; sharing state re-creates the monolithic API problem |
| Authentication decisions | BFF validates tokens and forwards identity; authorization is in backend services |

### Per-Client Optimization

| Client Type | BFF Optimization |
|-------------|-----------------|
| Web SPA | Rich payloads, full entity details, pagination with counts, hypermedia links |
| Mobile native | Minimal payloads, compressed images, offline-friendly structures, delta updates |
| CLI tool | Structured output (JSON/YAML), machine-parseable errors, progress indicators |
| Partner/Third-party | Stable versioned API, backward-compatible, comprehensive documentation |

### Aggregation Guidelines

| Principle | Guideline |
|-----------|-----------|
| Parallel calls | Call independent backend services in parallel; aggregate results |
| Timeout per service | Each backend call has its own timeout; return partial data if non-critical services are slow |
| Fallback for non-critical data | If a secondary service fails, return the response without that data (with a flag indicating incompleteness) |
| Circuit breakers | Wrap each backend call in a circuit breaker to prevent cascading failures |
| No deep orchestration | BFFs aggregate (fan-out/fan-in); they do not orchestrate multi-step workflows |

### Versioning and Evolution

| Aspect | Guideline |
|--------|-----------|
| Owned by client team | The BFF is maintained by (or closely with) the team that owns the client |
| Independent deployment | Each BFF deploys independently from backend services and other BFFs |
| Contract evolution | BFF API contract evolves at the client's pace, not the backend's pace |
| Backend changes | Backend API changes are absorbed by the BFF; the client contract remains stable |
| Deprecation | BFF versions are retired when the corresponding client version is sunset |

### Operational Considerations

| Concern | Guideline |
|---------|-----------|
| Performance | BFFs add one network hop; minimize overhead with caching and parallel calls |
| Monitoring | Monitor BFF-specific metrics: aggregation latency, per-backend-call latency, error rates |
| Scaling | Scale each BFF independently based on its client's traffic patterns |
| Security | BFF validates authentication tokens; passes identity to backends; terminates client-facing TLS |
| Logging | Correlate BFF requests with backend service calls using a shared trace/correlation ID |

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Shared BFF for all clients | Becomes a monolithic API; compromises for every client | One BFF per client type |
| Business logic in BFF | BFF becomes a hidden domain service | Keep BFF as a thin translation and aggregation layer |
| BFF calling other BFFs | Circular dependencies, layered complexity | BFFs call backend services only |
| No BFF ownership | BFF drifts without clear responsibility | Client team owns and maintains their BFF |
| Over-aggregation | BFF composes 10+ backend calls per request | Rethink backend API boundaries; consider backend aggregation service |

## Relationship to Other Patterns

- **API Gateway**: The gateway routes to BFFs; BFFs route to backend services. Gateway handles cross-cutting concerns (auth, rate limiting); BFFs handle client-specific shaping
- **Anti-Corruption Layer**: BFFs act as ACLs between the client's expected model and the backend services' domain models
- **Circuit Breaker**: Each BFF-to-backend call should be wrapped in a circuit breaker for resilience
- **Adapter Pattern**: BFFs are adapters that translate between client expectations and backend service contracts
- **CQRS**: BFFs naturally align with the query side; they aggregate read models from multiple services for client consumption
