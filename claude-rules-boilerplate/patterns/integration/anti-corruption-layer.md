# Anti-Corruption Layer (ACL)

## Intent

The Anti-Corruption Layer protects a bounded context's domain model from being polluted by the models, conventions, and assumptions of external systems or legacy contexts. It acts as a translation boundary that converts external concepts into the local domain's language and structures, preventing foreign models from leaking inward. Without an ACL, teams gradually compromise their domain model to accommodate external systems, leading to a tangled, inconsistent model that serves no context well.

## When to Use

- When integrating with legacy systems whose models differ significantly from the local domain
- When `architecture.domain_driven=true` and bounded context integrity must be preserved
- Integrating with third-party APIs, partner systems, or vendor platforms
- During migration (Strangler Fig) where old and new systems coexist
- When multiple teams own different bounded contexts with divergent models
- Whenever an external system's model would distort or complicate the local domain model

## When NOT to Use

- When the external system's model aligns closely with the local domain (shared kernel is sufficient)
- Internal communication within the same bounded context
- Trivial integrations where a simple mapping function suffices and there is no model divergence
- When the team owns both sides and can align the models directly

## Structure

```
    ┌──────────────────────────┐        ┌──────────────────────────┐
    │    Local Bounded Context  │        │   External System         │
    │                           │        │                           │
    │   Domain Model            │        │   Foreign Model           │
    │   (clean, consistent)     │        │   (legacy, different)     │
    │                           │        │                           │
    │   Domain Service          │        │   External API            │
    │        │                  │        │        │                  │
    │        ▼                  │        │        │                  │
    │   ACL Port (Interface)    │        │        │                  │
    │                           │        │        │                  │
    └───────────┬──────────────┘        └────────┼──────────────────┘
                │                                 │
                │         ┌───────────────┐       │
                └────────►│     ACL        │◄─────┘
                          │               │
                          │  Translator   │
                          │  Adapter      │
                          │  Facade       │
                          │               │
                          └───────────────┘

    Data Flow:
    External Model ──► ACL Translator ──► Domain Model
    Domain Model   ──► ACL Translator ──► External Model
```

## Implementation Guidelines

### ACL Components

| Component | Responsibility |
|-----------|---------------|
| Translator | Converts between external and domain models (structural mapping) |
| Adapter | Handles protocol and communication concerns (HTTP, gRPC, TCP) |
| Facade | Provides a simplified interface to complex external system interactions |
| Exception mapper | Converts external errors/exceptions into domain-defined exceptions |
| Validator | Validates external data meets domain invariants before translation |

### Translation Principles

| Principle | Guideline |
|-----------|-----------|
| Domain-first | The local domain model dictates the shape of the translation; never bend the domain to match the external model |
| Complete mapping | Every external concept used by the domain MUST be translated; no external types cross the boundary |
| Null safety | Handle missing or null fields from external systems gracefully; apply defaults or reject |
| Validation | Validate translated data against domain invariants; reject invalid external data at the boundary |
| Lossy translation | Not all external fields need mapping; translate only what the domain requires |

### Boundary Rules

| Rule | Detail |
|------|--------|
| No leakage inward | External DTOs, entities, and enums MUST NOT appear in the domain layer |
| No domain leakage outward | Domain models MUST NOT be sent to external systems; translate to external format |
| Interface in domain | The ACL interface (port) lives in the domain layer; the implementation lives in the adapter layer |
| One ACL per external system | Each external integration has its own ACL; do not share translators across systems |
| Version isolation | External API version changes are absorbed by the ACL; the domain remains stable |

### Handling External Model Changes

| Scenario | ACL Response | Domain Impact |
|----------|-------------|---------------|
| External field renamed | Update translator mapping | None |
| External field added | Ignore or map if domain-relevant | None or minimal |
| External field removed | Handle absence gracefully (default, error) | None |
| External API version change | Create new translator version; old one remains until deprecated | None |
| External model restructured | Rewrite translator; domain stays stable | None |

### Error Handling at the Boundary

| External Error | ACL Translation | Domain Receives |
|---------------|----------------|-----------------|
| HTTP 404 Not Found | Translate to domain "entity not found" | Domain-specific NotFoundException |
| HTTP 503 Unavailable | Translate to "service unavailable" | Domain-specific ServiceUnavailableException |
| Validation error from external | Translate to domain validation failure | Domain-specific ValidationException |
| Unexpected response format | Log, translate to system error | Domain-specific IntegrationException |
| Timeout | Translate to timeout domain error | Domain-specific TimeoutException |

### Testing Strategy

| Test Type | Scope | Purpose |
|-----------|-------|---------|
| Unit tests | Translator logic in isolation | Verify mapping correctness for all field combinations |
| Contract tests | ACL against external API contract | Detect external API changes early |
| Integration tests | ACL with real or simulated external system | Verify end-to-end translation |
| Null/edge case tests | Missing fields, unexpected values | Ensure robustness against external data quality |

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Passing external DTOs into domain | Domain polluted with external concepts | Always translate at the ACL boundary |
| Shared translator across contexts | Changes to one integration break another | One ACL per external system |
| Business logic in the ACL | ACL becomes a hidden domain service | ACL only translates; logic stays in domain |
| No ACL ("just call the API") | External model gradually leaks into domain | Always use an ACL for external integrations |
| Bidirectional coupling | ACL depends on domain AND domain depends on ACL types | Domain depends only on the ACL port interface |

## Relationship to Other Patterns

- **Hexagonal Architecture**: The ACL is implemented as an outbound adapter, behind an outbound port defined in the domain
- **Adapter Pattern**: The ACL is a specialized application of the adapter pattern, focused on domain model protection
- **Modular Monolith**: Module public APIs act as lightweight ACLs between modules within the same deployment
- **Strangler Fig**: During migration, the ACL translates between legacy and new system models, enabling gradual replacement
- **Backend for Frontend**: BFFs may incorporate ACL-like translation to protect the frontend's model from backend complexity
