# Adapter Pattern (External Service Integration)

## Intent

The Adapter pattern provides a bridge between an application's internal interfaces and external services that have incompatible APIs, protocols, or data formats. In the context of service integration, the adapter encapsulates all communication details -- protocol handling, data format translation, error mapping, authentication, and resilience wrappers -- behind a clean interface that the application can consume without knowledge of the external system's peculiarities. This isolation makes external dependencies replaceable, testable, and maintainable.

## When to Use

- Integrating with any external service (third-party APIs, partner systems, payment processors, messaging platforms)
- When the external service's API contract differs from the internal domain model
- When the external service uses a different protocol than the application (REST vs gRPC, SOAP vs REST)
- When resilience patterns (circuit breaker, retry, timeout) must wrap external calls consistently
- Whenever the application should remain functional if the external service changes its API

## When NOT to Use

- Internal service-to-service calls within the same organization where contracts are aligned and co-owned
- When the external service's model matches the domain model exactly (though this is rare in practice)
- Trivial integrations that are unlikely to change (e.g., writing to standard output)
- When a higher-level pattern (Anti-Corruption Layer, BFF) already provides the necessary translation

## Structure

```
    ┌──────────────────────────────────────────────────────┐
    │                  Application                          │
    │                                                       │
    │  Domain Layer                                         │
    │  ┌─────────────────┐                                  │
    │  │  Outbound Port   │  (Interface defined by domain)  │
    │  │  e.g., Payment   │                                 │
    │  │  Gateway         │                                 │
    │  └────────┬─────────┘                                 │
    │           │                                           │
    │  Adapter Layer                                        │
    │  ┌────────▼──────────────────────────────────────┐    │
    │  │              Adapter Implementation             │   │
    │  │                                                │   │
    │  │  ┌──────────────┐  ┌──────────────────────┐   │   │
    │  │  │  Translator   │  │  Protocol Client     │   │   │
    │  │  │  (Format Map) │  │  (HTTP, gRPC, SOAP)  │   │   │
    │  │  └──────────────┘  └──────────────────────┘   │   │
    │  │  ┌──────────────┐  ┌──────────────────────┐   │   │
    │  │  │  Error Mapper │  │  Auth Handler        │   │   │
    │  │  └──────────────┘  └──────────────────────┘   │   │
    │  │  ┌──────────────┐  ┌──────────────────────┐   │   │
    │  │  │  Retry/CB    │  │  Request/Response Log │   │   │
    │  │  └──────────────┘  └──────────────────────┘   │   │
    │  └────────────────────────────────────────────────┘   │
    │           │                                           │
    └───────────┼───────────────────────────────────────────┘
                │
                ▼
    ┌──────────────────────┐
    │   External Service    │
    │   (Third-party API)   │
    └──────────────────────┘
```

## Implementation Guidelines

### Adapter Components

| Component | Responsibility |
|-----------|---------------|
| Port interface | Defined in the domain; describes what the application needs, not how it gets it |
| Protocol client | Manages HTTP connections, gRPC channels, SOAP clients, or TCP sockets |
| Request translator | Converts domain objects into the external service's request format |
| Response translator | Converts external responses into domain objects |
| Error mapper | Translates external errors (HTTP status codes, error payloads) into domain exceptions |
| Authentication handler | Manages API keys, OAuth tokens, mutual TLS, or other auth mechanisms |
| Resilience wrapper | Applies circuit breaker, retry, timeout, and bulkhead around external calls |

### Format Translation Principles

| Principle | Guideline |
|-----------|-----------|
| Domain-driven interface | The port interface uses domain types; the adapter handles all format conversion |
| No external types in domain | External DTOs, enums, and error codes MUST NOT leak past the adapter |
| Mapping completeness | Map all fields the domain needs; explicitly ignore irrelevant external fields |
| Default handling | Define sensible defaults for optional external fields that the domain requires |
| Validation | Validate external response data before translating to domain types |

### Protocol Bridging

| Scenario | Adapter Handles |
|----------|----------------|
| REST to gRPC | HTTP client on external side; gRPC service interface on internal side |
| REST to SOAP | HTTP/JSON externally; SOAP/XML translation in adapter |
| Async to Sync | Message queue consumer externally; synchronous port interface internally |
| Sync to Async | Synchronous port call; adapter publishes to external event system |
| Binary to structured | Raw binary protocol; adapter deserializes to domain structures |

### Resilience Wrapping

Every external service call through an adapter MUST be wrapped with resilience patterns:

| Pattern | Purpose | Configuration |
|---------|---------|---------------|
| Timeout | Prevent waiting indefinitely for external response | Connection: 3-5s, Read: 5-10s |
| Circuit breaker | Stop calling a failing external service | Per external service instance |
| Retry | Recover from transient external failures | Only for idempotent operations; with backoff and jitter |
| Bulkhead | Limit concurrent calls to external service | Based on external service's rate limits |
| Fallback | Provide degraded response when external service is unavailable | Cache, default, or error |

### Authentication Handling

| Auth Type | Adapter Responsibility |
|-----------|----------------------|
| API key | Attach key to headers; rotate keys without domain changes |
| OAuth2 client credentials | Manage token lifecycle (obtain, cache, refresh) transparently |
| Mutual TLS | Configure certificates; handle renewal |
| HMAC signing | Sign requests per the external service's specification |
| Custom auth | Implement the vendor's authentication flow |

**Rule:** Authentication details are entirely within the adapter. The domain MUST NOT know how authentication with the external service works.

### Error Handling Strategy

| External Error | Adapter Action | Domain Receives |
|---------------|---------------|-----------------|
| HTTP 400 (client error) | Log, translate | Domain-specific validation exception |
| HTTP 401/403 (auth) | Re-authenticate; retry once | Auth failure exception (if retry fails) |
| HTTP 404 (not found) | Translate | Domain-specific not-found exception |
| HTTP 429 (rate limit) | Respect Retry-After; queue or reject | Rate limit exception |
| HTTP 500/503 (server error) | Trigger retry/circuit breaker | Service unavailable exception |
| Network error | Trigger retry/circuit breaker | Connection failure exception |
| Unexpected response format | Log full response; translate to error | Integration exception |

### Testing Strategy

| Test Type | Purpose | Approach |
|-----------|---------|----------|
| Unit tests | Verify translation logic | Test translators with known inputs and expected outputs |
| Contract tests | Verify adapter against external API contract | Use consumer-driven contracts or recorded responses |
| Integration tests | Verify real communication | Call sandbox/staging external environments |
| Resilience tests | Verify circuit breaker, retry, timeout behavior | Simulate failures with mocks or chaos tools |

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Exposing external DTOs to domain | Domain polluted with external concerns | Translate at the adapter boundary |
| No resilience wrapping | Single external failure cascades through the system | Wrap every external call with timeout, circuit breaker, retry |
| Hardcoded external URLs | Cannot switch environments or migrate | Externalize configuration |
| Auth credentials in adapter code | Security risk | Use secrets management; inject credentials |
| Single adapter for multiple services | Changes to one external service break integration with another | One adapter per external service |

## Relationship to Other Patterns

- **Hexagonal Architecture**: Adapters are the outer ring; they implement outbound ports defined in the domain layer
- **Anti-Corruption Layer**: The ACL is a specialized adapter focused on protecting the domain model from external model pollution
- **Circuit Breaker**: Wraps the adapter's external calls to detect and prevent cascading failures
- **Retry with Backoff**: Applied inside the adapter for transient external failures on idempotent operations
- **Backend for Frontend**: BFFs are client-facing adapters that aggregate and shape data from multiple backend services
- **Outbox Pattern**: When the adapter needs to reliably publish events after an external call, the outbox ensures consistency
