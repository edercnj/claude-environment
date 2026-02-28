# Modular Monolith

## Intent

The Modular Monolith structures a single deployable unit into well-defined, loosely coupled modules with explicit boundaries, enforced dependency rules, and clear internal APIs. It captures the architectural discipline of microservices -- bounded contexts, independent data ownership, explicit contracts -- without incurring the operational complexity of distributed systems. It also provides a natural migration path toward microservices when scaling demands justify the transition.

## When to Use

- `architecture.style=modular-monolith` in the project configuration
- Teams that need strong module boundaries but are not ready for distributed system overhead
- Projects in early stages where the domain boundaries are still being discovered
- Organizations that want a clear migration path to microservices in the future
- Systems where deployment simplicity and transactional consistency are priorities
- Teams smaller than five engineers, where operating multiple services is impractical

## When NOT to Use

- When independent scaling of components is an immediate, proven need
- When different modules require fundamentally different technology stacks
- When organizational structure already maps to independent service teams
- Trivial applications with no meaningful module boundaries
- When the team has strong microservice experience and infrastructure is already in place

## Structure

```
    ┌───────────────────── Single Deployable Unit ─────────────────────┐
    │                                                                   │
    │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
    │  │  Module A    │  │  Module B    │  │  Module C    │             │
    │  │             │  │             │  │             │              │
    │  │ Public API   │  │ Public API   │  │ Public API   │             │
    │  │ (Interface)  │◄─┤ (Interface)  │◄─┤ (Interface)  │             │
    │  │             │  │             │  │             │              │
    │  │ Domain       │  │ Domain       │  │ Domain       │             │
    │  │ Application  │  │ Application  │  │ Application  │             │
    │  │ Adapters     │  │ Adapters     │  │ Adapters     │             │
    │  │             │  │             │  │             │              │
    │  │ [Schema A]   │  │ [Schema B]   │  │ [Schema C]   │             │
    │  └─────────────┘  └─────────────┘  └─────────────┘              │
    │         │                │                │                       │
    │         ▼                ▼                ▼                       │
    │  ┌──────────────────────────────────────────────┐                │
    │  │          Shared Kernel (minimal)              │                │
    │  │  Common types, cross-cutting concerns          │                │
    │  └──────────────────────────────────────────────┘                │
    │                                                                   │
    └───────────────────────────────────────────────────────────────────┘
```

## Implementation Guidelines

### Module Boundary Rules

| Rule | Constraint |
|------|-----------|
| Data ownership | Each module owns its database schema; no cross-module table access |
| API surface | Modules communicate ONLY through their public API interfaces |
| Direct references | Module internals (domain models, entities, repositories) are NEVER exposed |
| Package visibility | Use language-level access control to enforce boundaries (module systems, package-private) |
| Dependency direction | Modules may depend on the Shared Kernel; modules MUST NOT have circular dependencies |

### Module Internal Structure

Each module follows hexagonal architecture internally:

```
module-{name}/
├── api/                  # Public API (interfaces + DTOs exposed to other modules)
│   ├── {Module}Service   # Interface other modules call
│   └── dto/              # Shared DTOs for inter-module communication
├── domain/               # Domain core (private to module)
│   ├── model/
│   ├── port/
│   └── engine/
├── application/          # Use cases (private to module)
├── adapter/              # Infrastructure (private to module)
│   ├── inbound/
│   └── outbound/
└── config/               # Module-specific configuration
```

### Inter-Module Communication

| Mechanism | Consistency | Coupling | Use When |
|-----------|------------|---------|----------|
| Direct method call via public API | Strong (same transaction) | Medium | Operations requiring immediate consistency |
| In-process domain events | Eventual (async listener) | Low | Notifications, side effects, projections |
| Shared message bus (in-memory) | Eventual | Very low | Decoupled workflows, future microservice migration |

**Rules:**
- Prefer domain events over direct calls for cross-module side effects
- Direct calls are acceptable for queries and operations requiring transactional consistency
- NEVER pass internal domain models across module boundaries; use DTOs from the public API

### Shared Kernel Guidelines

The Shared Kernel contains ONLY code that genuinely belongs to multiple modules:

| Permitted | Forbidden |
|-----------|-----------|
| Common value types (Money, Email, Address) | Business logic |
| Cross-cutting concerns (logging, metrics interfaces) | Domain entities |
| Shared event base types | Module-specific DTOs |
| Common exception types | Repository interfaces |

**Rule:** The Shared Kernel MUST be minimal. If only two modules use a type, consider duplication over sharing. Shared Kernel changes affect all modules.

### Data Isolation

- Each module has its own database schema (same database, separate schemas)
- Cross-module data access goes through the owning module's public API, NEVER through direct SQL
- Each module manages its own migrations independently
- Foreign keys across module schemas are FORBIDDEN; use soft references (IDs only)

### Migration Path to Microservices

| Step | Action | Validation |
|------|--------|------------|
| 1. Identify candidate | High traffic module, independent scaling need | Metrics confirm bottleneck |
| 2. Verify boundaries | Module has no shared-transaction dependencies | All cross-module calls are async or API-based |
| 3. Extract data store | Move module schema to separate database | Module still functions with remote DB |
| 4. Replace in-process calls | Swap direct calls for network calls (HTTP/gRPC) | All integration tests pass |
| 5. Deploy independently | Module becomes a standalone service | Monitor latency, error rates |

**Rule:** A module is ready for extraction when it communicates with other modules exclusively through its public API and domain events, with no shared transactions.

## Relationship to Other Patterns

- **Hexagonal Architecture**: Each module applies hexagonal architecture internally; the module boundary adds another layer of isolation
- **CQRS**: Modules can independently adopt CQRS for their internal read/write separation
- **Event Sourcing**: Individual modules may use event sourcing while others use traditional persistence
- **Anti-Corruption Layer**: Module public APIs act as anti-corruption layers, preventing internal model leakage
- **Strangler Fig**: When migrating a legacy monolith, the modular monolith is often the intermediate step before full microservice extraction
