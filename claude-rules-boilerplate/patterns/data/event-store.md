# Event Store

## Intent

The Event Store is a specialized persistence mechanism designed for event-sourced systems. It stores an ordered, immutable sequence of domain events that represent every state change in the system. Unlike traditional databases that store current state, the event store captures the complete history of state transitions, enabling state reconstruction at any point in time, complete audit trails, and multiple read model projections from a single source of truth.

## When to Use

- Systems implementing event sourcing where events are the primary persistence model
- When a complete, immutable audit trail of all state changes is a business requirement
- Applications that need temporal queries (state at any point in time)
- Systems that build multiple read models (projections) from the same event stream
- Domains where regulatory compliance requires provable, tamper-evident history

## When NOT to Use

- Applications using traditional CRUD persistence where current state is sufficient
- Systems that do not benefit from historical state reconstruction
- When the team lacks experience with event sourcing and event-driven architecture
- Simple applications where the overhead of event storage and projection management is unjustified
- Systems with extreme write throughput (millions of events per second per aggregate) without partitioning capability

## Structure

```
    ┌─────────────────────────────────────────────────────────┐
    │                      Event Store                         │
    │                                                          │
    │  Stream: Order-12345                                     │
    │  ┌──────┬──────────────────┬─────────┬────────┬───────┐ │
    │  │ Pos  │ Event Type       │ Payload │ Version│ Time  │ │
    │  ├──────┼──────────────────┼─────────┼────────┼───────┤ │
    │  │  1   │ OrderCreated     │ {...}   │   1    │ T1    │ │
    │  │  2   │ ItemAdded        │ {...}   │   2    │ T2    │ │
    │  │  3   │ ItemAdded        │ {...}   │   3    │ T3    │ │
    │  │  4   │ PaymentReceived  │ {...}   │   4    │ T4    │ │
    │  │  5   │ OrderShipped     │ {...}   │   5    │ T5    │ │
    │  └──────┴──────────────────┴─────────┴────────┴───────┘ │
    │                                                          │
    │  Snapshot: Order-12345 (at version 100)                  │
    │  ┌──────────────────────────────────────────────┐       │
    │  │ Aggregate state as of event 100              │       │
    │  │ (only events 101+ need replaying)            │       │
    │  └──────────────────────────────────────────────┘       │
    │                                                          │
    │  Global Position Index (for projections):                │
    │  ┌──────┬──────────┬──────────────────┬────────┐        │
    │  │ GPos │ Stream   │ Event Type       │ Time   │        │
    │  ├──────┼──────────┼──────────────────┼────────┤        │
    │  │  1   │ Order-1  │ OrderCreated     │ T1     │        │
    │  │  2   │ User-5   │ UserRegistered   │ T2     │        │
    │  │  3   │ Order-1  │ ItemAdded        │ T3     │        │
    │  │  ...                                        │        │
    │  └─────────────────────────────────────────────┘        │
    └─────────────────────────────────────────────────────────┘
```

## Implementation Guidelines

### Event Record Structure

| Field | Purpose | Constraint |
|-------|---------|-----------|
| stream_id | Identifies the aggregate instance (e.g., Order-12345) | NOT NULL, indexed |
| stream_position | Ordinal position within the stream | NOT NULL, sequential per stream |
| global_position | Monotonically increasing position across all streams | NOT NULL, unique, sequential |
| event_type | Fully qualified event type name | NOT NULL |
| payload | Serialized event data (JSON or binary) | NOT NULL |
| metadata | Correlation ID, causation ID, user context | NOT NULL |
| schema_version | Version of the event payload schema | NOT NULL |
| created_at | Timestamp of event creation | NOT NULL |

### Storage Requirements

| Requirement | Description |
|-------------|-------------|
| Append-only | Events are NEVER updated or deleted once written |
| Stream ordering | Events within a stream maintain strict insertion order |
| Global ordering | A global position enables ordered consumption across all streams |
| Optimistic concurrency | Appending checks expected stream version; rejects on mismatch |
| Durability | Committed events MUST survive process and hardware failures |
| Immutability | No UPDATE or DELETE operations on event records (enforced at application and/or DB level) |

### Snapshot Strategy

Snapshots accelerate aggregate loading by capturing materialized state at a point in time.

| Aspect | Guideline |
|--------|-----------|
| Trigger | Create a snapshot every N events (e.g., every 50-200) |
| Storage | Store snapshots in a separate table or alongside event streams |
| Loading | Load snapshot + replay only events after the snapshot's version |
| Rebuilding | Snapshots are disposable; always rebuildable from the event stream |
| Versioning | Track snapshot schema version; stale versions trigger full replay |
| Cleanup | Keep only the latest snapshot per stream; purge older ones |

### Projection Design

| Principle | Guideline |
|-----------|-----------|
| Disposability | Projections can be deleted and rebuilt entirely from the event store |
| Position tracking | Each projection tracks the last global position it has processed |
| Idempotency | Processing the same event twice MUST produce the same result |
| Isolation | Each projection runs independently; one projection failure does not affect others |
| Multiple projections | Different read models can consume the same events for different purposes |
| Rebuild support | The system MUST support rebuilding any projection from position zero |

### Event Versioning and Evolution

| Strategy | Mechanism | When to Use |
|----------|-----------|-------------|
| Upcasting | Transform old event format to new format on read | Non-breaking changes; adding optional fields |
| Weak schema | Add fields with defaults; ignore unknown fields | Forward-compatible changes |
| New event type | Introduce a new event alongside the old one | Fundamentally different semantics |
| Stream migration | Create a new stream with transformed events | Last resort; expensive and complex |

**Rule:** NEVER modify stored events. All evolution strategies work at the read or projection layer, leaving the stored events immutable.

### Performance Considerations

| Concern | Mitigation |
|---------|------------|
| Long event streams | Snapshots every N events; limit replay to snapshot + tail |
| High write throughput | Batch appends; partition streams across storage nodes |
| Projection lag | Monitor lag metrics; scale projection consumers |
| Storage growth | Archive old streams to cold storage; keep event store lean |
| Query by event type | Maintain indexes on event_type and global_position |

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Updating events | Destroys audit trail and breaks projections | Events are immutable; use new events or upcasting |
| Large events | Slow reads, high storage cost | Keep events focused; reference external data by ID |
| Events without metadata | Cannot correlate or trace | Always include correlation ID, causation ID, timestamp |
| No global position | Cannot build cross-stream projections | Include a monotonically increasing global position |
| Snapshot as source of truth | Snapshots can be stale or corrupt | Events are the source of truth; snapshots are optimization |
| Unbounded stream replay | Startup takes minutes or hours | Implement snapshots; monitor stream lengths |

## Relationship to Other Patterns

- **Event Sourcing**: The event store is the persistence layer for event sourcing; see `patterns/architectural/event-sourcing.md` for the complete pattern
- **CQRS**: The event store is the write store; projections built from events populate the read stores
- **Outbox Pattern**: In some designs, the event store itself serves as the outbox, with a relay process publishing events to external consumers
- **Saga Pattern**: Saga state changes can be stored as events in the event store, providing a complete history of saga execution
- **Repository Pattern**: In event-sourced systems, the repository loads aggregates by reading and replaying events from the event store, rather than querying a relational table
