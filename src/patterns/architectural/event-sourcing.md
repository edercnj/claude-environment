# Event Sourcing

## Intent

Event Sourcing replaces traditional state-based persistence with an append-only log of domain events. Instead of storing the current state of an entity, the system stores the complete sequence of state-changing events. Current state is derived by replaying events from the log. This provides a complete audit trail, enables temporal queries, supports rebuilding state at any point in time, and naturally decouples write operations from read projections.

## When to Use

- Systems requiring a complete, immutable audit trail (financial, regulatory, compliance)
- When `architecture.event_driven=true` and the domain naturally expresses state changes as events
- Domains where understanding "how we got here" is as important as "where we are now"
- Systems that benefit from temporal queries (state at any point in time)
- When multiple read models (projections) are needed from the same data
- Complex domains with high concurrency where conflict resolution benefits from event granularity

## When NOT to Use

- Simple CRUD applications where current state is the only concern
- Systems where every read requires strong consistency with the latest write
- Teams without experience in eventual consistency and event-driven thinking
- Domains with high-frequency state changes on the same entity (thousands per second per aggregate)
- When regulatory requirements mandate the ability to delete data (right to be forgotten) without crypto-shredding capability

## Structure

```
    Command ──► Aggregate ──► Events ──► Event Store
                                │              │
                                │              │ (append-only)
                                │              │
                                ▼              ▼
                          Event Bus      Event Log
                              │         ┌──────────┐
                    ┌─────────┼─────┐   │ Event 1  │
                    │         │     │   │ Event 2  │
                    ▼         ▼     ▼   │ Event 3  │
               Projection Projection   │   ...    │
                  A         B     C     │ Event N  │
                  │         │     │     └──────────┘
                  ▼         ▼     ▼          │
              Read DB    Search  Cache   Snapshots
                                        (periodic)
```

### Event Lifecycle

```
  Command Received
        │
        ▼
  Load Aggregate (replay events or load snapshot + subsequent events)
        │
        ▼
  Validate Business Rules
        │
        ▼
  Produce New Event(s)
        │
        ▼
  Append to Event Store (with optimistic concurrency check)
        │
        ▼
  Publish to Event Bus (for projections and downstream consumers)
```

## Implementation Guidelines

### Event Design Principles

| Principle | Guideline |
|-----------|-----------|
| Immutability | Events are facts; once stored, they MUST NEVER be modified or deleted |
| Self-description | Each event carries enough context to be understood independently |
| Granularity | One event per meaningful state change; avoid mega-events |
| Naming | Past tense verbs describing what happened: OrderPlaced, PaymentReceived |
| Versioning | Include a schema version; support upcasting from old versions to new |
| Ordering | Events within a stream are strictly ordered; global ordering is optional |

### Event Store Requirements

| Requirement | Description |
|-------------|-------------|
| Append-only | No updates, no deletes on event records |
| Stream identity | Events belong to a stream (typically per aggregate instance) |
| Optimistic concurrency | Reject appends if expected stream version mismatches |
| Ordering guarantee | Events within a stream maintain insertion order |
| Global position | A monotonically increasing position across all streams (for projections) |
| Retention | Events are retained indefinitely unless crypto-shredded |

### Snapshot Strategy

Snapshots accelerate aggregate loading by capturing state at a point in time. Only events after the snapshot need replaying.

| Aspect | Guideline |
|--------|-----------|
| Frequency | Every N events (e.g., every 100) or time-based |
| Storage | Alongside or separate from the event store |
| Invalidation | Snapshots are disposable; always rebuildable from events |
| Versioning | Snapshot schema version must be tracked; stale snapshots trigger full replay |

### Projection Guidelines

- Projections are disposable read models rebuilt entirely from the event log
- Each projection consumes specific event types and maintains its own read-optimized store
- Projections MUST track their last processed event position for resumability
- Projection rebuilds MUST be idempotent
- Design projections for specific query patterns; multiple projections for the same data are normal

### Event Versioning and Evolution

| Strategy | When to Use |
|----------|-------------|
| Upcasting | Transform old event formats to new on read; original events unchanged |
| Weak schema | Add optional fields with defaults; consumers ignore unknown fields |
| New event type | When the semantic meaning changes fundamentally |
| Copy-and-replace | Last resort: create a new stream with transformed events |

### Concurrency and Conflict Resolution

- Use optimistic concurrency on aggregate stream version for writes
- On conflict, reload the aggregate and retry the command
- For high-contention aggregates, consider functional conflict resolution: merge non-conflicting events automatically

## Relationship to Other Patterns

- **CQRS**: The natural companion; event sourcing provides the write model, projections provide read models
- **Event Store**: The persistence mechanism specifically designed for event sourcing (see `patterns/data/event-store.md`)
- **Saga Pattern**: Sagas coordinate multi-aggregate or multi-service operations using the events produced by event-sourced aggregates
- **Outbox Pattern**: Ensures events are reliably published to external consumers alongside event store persistence
- **Idempotency**: Event handlers and projections MUST be idempotent since events may be replayed during recovery or projection rebuilds
