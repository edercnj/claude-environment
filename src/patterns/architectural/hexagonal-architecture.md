# Hexagonal Architecture (Ports & Adapters)

## Intent

Hexagonal Architecture isolates the business domain from all external concerns -- frameworks, databases, messaging systems, and user interfaces -- by establishing strict dependency boundaries through ports (abstractions) and adapters (implementations). This ensures the core business logic remains testable, portable, and independent of infrastructure decisions, allowing teams to defer or replace technology choices without rewriting domain logic.

## When to Use

- Any project where long-term maintainability and testability are priorities
- Systems that must integrate with multiple external protocols (REST, gRPC, TCP, messaging)
- Applications expected to outlive their current infrastructure choices
- Applicable to all `architecture.style` values: monolith, modular-monolith, microservice
- When domain complexity justifies the structural overhead
- Projects where multiple teams contribute to the same codebase

## When NOT to Use

- Throwaway prototypes or proof-of-concept projects with a lifespan under three months
- CRUD-only applications with no meaningful business logic
- Scripts, CLI tools, or single-purpose utilities
- When the entire team is unfamiliar with the pattern and there is no time for onboarding

## Structure

```
                    ┌──────────────────────────────────────────┐
                    │            Inbound Adapters               │
                    │  REST  │  gRPC  │  TCP  │  CLI  │  MQ    │
                    └────┬───┴────┬───┴───┬───┴───┬───┴────┬───┘
                         │        │       │       │        │
                    ═════╪════════╪═══════╪═══════╪════════╪═════
                         │   Inbound Ports (Interfaces)    │
                    ┌────▼────────▼───────▼───────▼────────▼───┐
                    │                                           │
                    │             APPLICATION LAYER             │
                    │         (Use Cases / Orchestration)       │
                    │                                           │
                    ├───────────────────────────────────────────┤
                    │                                           │
                    │              DOMAIN CORE                  │
                    │   Models │ Rules │ Engines │ Value Objs   │
                    │                                           │
                    └────┬────────┬───────┬───────┬────────┬───┘
                         │   Outbound Ports (Interfaces)   │
                    ═════╪════════╪═══════╪═══════╪════════╪═════
                         │        │       │       │        │
                    ┌────▼───┬────▼──┬────▼──┬────▼───┬────▼───┐
                    │   DB   │ Cache │ Queue │ Logger │ ExtAPI │
                    │            Outbound Adapters              │
                    └───────────────────────────────────────────┘
```

## Implementation Guidelines

### The Dependency Rule

All source-level dependencies MUST point inward toward the domain. The domain layer has zero knowledge of the adapter layer. The application layer orchestrates domain operations through ports but never references adapter implementations directly.

| Layer | Permitted Dependencies |
|-------|----------------------|
| Domain (models, rules, engines) | Standard library only; no framework, no infrastructure |
| Domain (ports) | Domain models only |
| Application (use cases) | Domain models, domain ports, domain engines |
| Inbound Adapters | Application layer, domain ports, framework libraries |
| Outbound Adapters | Domain ports, domain models, infrastructure libraries |
| Configuration | Framework configuration, dependency injection wiring |

### Port Design Principles

**Inbound Ports** define what the application offers to the outside world. They are interfaces that use cases implement. Each inbound port represents a distinct capability: processing a command, answering a query, or handling an event.

**Outbound Ports** define what the application needs from the outside world. They are interfaces the domain declares and outbound adapters implement. Each outbound port represents a dependency: persistence, messaging, external service calls, logging.

| Port Aspect | Guideline |
|-------------|-----------|
| Granularity | One port per bounded concern; avoid god-interfaces |
| Naming | Name after the capability, not the technology (PersistencePort, not DatabasePort) |
| Return types | Domain types only; never framework-specific types |
| Exceptions | Domain-defined exceptions only; adapters translate infrastructure exceptions |

### Adapter Design Principles

Adapters translate between the external world and the domain. Each adapter belongs to exactly one port. Adapters are replaceable; swapping an adapter MUST NOT require changes to the domain or application layer.

### The Mapper Pattern

Mappers are the translation mechanism between layers. Two distinct categories exist:

- **DTO Mappers** (inbound side): Convert external request/response formats into domain models and back. Masking, formatting, and protocol-specific concerns live here.
- **Entity Mappers** (outbound side): Convert domain models into persistence entities and back. ORM annotations, column mappings, and storage-specific concerns live here.

Mappers MUST be stateless. They MUST NOT contain business logic. They exist purely for structural translation.

### Thread-Safety Requirements

| Classification | Lifecycle | Constraint |
|---------------|-----------|------------|
| Stateless services | Singleton | No mutable instance fields |
| Request handlers | Request-scoped | Scoped to a single request lifecycle |
| Domain models / DTOs | Immutable | Thread-safe by construction |
| ORM entities | Transaction-scoped | Never shared across threads or transactions |

### Package Structure

Organize packages by architectural layer first, then by concern within each layer. The domain package has zero imports from adapter or framework packages. The adapter package is organized by direction (inbound/outbound) and then by technology.

## Relationship to Other Patterns

- **Summarized in**: `core/05-architecture-principles.md` provides the condensed reference for daily use
- **Modular Monolith**: Each module within a modular monolith applies hexagonal architecture internally, with module boundaries acting as additional isolation
- **CQRS**: Naturally fits within hexagonal architecture -- command and query ports become distinct inbound ports
- **Repository Pattern**: Repositories are the canonical outbound adapter for persistence, implementing outbound ports defined in the domain
- **Anti-Corruption Layer**: When integrating with external systems, the outbound adapter acts as an anti-corruption layer, preventing external models from leaking into the domain
- **Adapter Pattern**: Every outbound adapter is fundamentally an application of the adapter pattern, translating between domain interfaces and external protocols
