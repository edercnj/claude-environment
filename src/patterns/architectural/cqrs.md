# Command Query Responsibility Segregation (CQRS)

## Intent

CQRS addresses the fundamental tension between optimizing data models for writing (consistency, normalization, validation) and optimizing them for reading (denormalization, aggregation, speed). By separating the command (write) path from the query (read) path into distinct models -- and optionally distinct data stores -- each side can be independently optimized, scaled, and evolved without compromising the other.

## When to Use

- Read and write workloads have significantly different performance characteristics or scaling needs
- The domain model is complex and read-optimized views diverge substantially from the write model
- Multiple read representations of the same data are needed (dashboards, reports, search)
- Most relevant for `architecture.style=microservice` and `architecture.style=modular-monolith`
- Systems where eventual consistency on reads is acceptable
- High-throughput systems where read/write ratios exceed 10:1

## When NOT to Use

- Simple CRUD applications with no meaningful difference between read and write models
- Systems requiring strong consistency on every read immediately after a write
- Small teams without experience managing dual models and synchronization
- `architecture.style=monolith` with a simple domain and low traffic
- When the added complexity of maintaining two models outweighs the scaling benefit

## Structure

```
    ┌─────────────────┐                    ┌─────────────────┐
    │   Command Side   │                    │   Query Side     │
    │                  │                    │                  │
    │  Command DTO     │                    │  Query Request   │
    │       │          │                    │       │          │
    │       ▼          │                    │       ▼          │
    │  Command Handler │                    │  Query Handler   │
    │       │          │                    │       │          │
    │       ▼          │                    │       ▼          │
    │  Domain Model    │                    │  Read Model      │
    │  (Aggregates)    │                    │  (Projections)   │
    │       │          │                    │       │          │
    │       ▼          │    Sync/Async      │       ▼          │
    │  Write Store     │───────────────────►│  Read Store      │
    │  (Normalized)    │   (Events/CDC)     │  (Denormalized)  │
    └─────────────────┘                    └─────────────────┘
```

### Separation Levels

| Level | Write Store | Read Store | Sync Mechanism | Complexity |
|-------|------------|------------|----------------|------------|
| Logical | Same DB, same schema | Same DB, views/materialized views | Database-level | Low |
| Schema | Same DB, separate tables | Same DB, read-optimized tables | Triggers or app-level | Medium |
| Physical | Separate database | Separate database (or search engine) | Events, CDC, or messaging | High |

## Implementation Guidelines

### Command Side Principles

- Commands represent intent: they describe what the user wants to happen, not how
- Each command has exactly one handler; commands are never broadcast
- Command handlers validate, enforce invariants, and persist through the write model
- The write model is normalized, optimized for consistency and integrity
- Command handlers return only success/failure and identifiers -- never full read models
- Commands MUST be idempotent or carry idempotency keys

### Query Side Principles

- Queries are inherently idempotent and side-effect free
- Read models are denormalized, pre-computed, and optimized for specific query patterns
- Multiple read models can exist for the same data (one per consumer need)
- Read handlers MUST NOT modify state
- Query results may be eventually consistent with the write model

### Synchronization Guidelines

| Mechanism | Consistency | Latency | Reliability |
|-----------|------------|---------|-------------|
| Synchronous (same transaction) | Strong | Low | High (but coupled) |
| Domain events (async in-process) | Eventual (milliseconds) | Low | Medium |
| Message broker (async cross-process) | Eventual (seconds) | Medium | High (with outbox) |
| Change Data Capture (CDC) | Eventual (seconds) | Medium | High |

### Consistency Boundaries

- Define explicit SLAs for read model staleness (e.g., "read model reflects writes within 2 seconds")
- Implement version tracking so consumers can detect stale reads
- For operations requiring read-after-write consistency, route reads to the write store
- Design the UI to accommodate eventual consistency (optimistic updates, pending states)

### Model Evolution

- Command and query models evolve independently; a change to the write schema does not mandate an immediate change to every read model
- Projection rebuilding MUST be supported: the ability to reconstruct any read model from the event or change log
- Version read models so consumers can migrate gradually

## Relationship to Other Patterns

- **Event Sourcing**: Frequently paired with CQRS; the event log becomes the write model, and projections become the read models
- **Hexagonal Architecture**: Commands and queries map naturally to distinct inbound ports
- **Repository Pattern**: The write side uses traditional repositories; the read side uses specialized query repositories or direct read-optimized access
- **Saga Pattern**: Long-running business processes coordinate multiple commands across services
- **Outbox Pattern**: Ensures reliable synchronization between the write store and read store via transactional event publishing
- **Event Store**: When combined with event sourcing, the event store replaces the traditional write database
