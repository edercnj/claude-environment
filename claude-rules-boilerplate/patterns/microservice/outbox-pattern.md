# Outbox Pattern

## Intent

The Outbox pattern solves the dual-write problem: when a service must both update its database and publish an event, these two operations cannot be performed atomically without a distributed transaction. The outbox pattern writes the event to an "outbox" table within the same local database transaction as the business data change, then a separate process reads from the outbox table and publishes to the message broker. This guarantees that events are published if and only if the business transaction commits.

## When to Use

- `architecture.style=microservice` with `event_driven=true`
- Any service that must reliably publish events after a state change
- When at-least-once event delivery is required (with consumer-side idempotency)
- Systems where losing an event means data inconsistency across services
- Saga step execution where event publication failure would corrupt the saga
- Whenever a database write and a message publish must be logically atomic

## When NOT to Use

- Single-service applications with no event consumers
- When the messaging system supports transactional producers natively (and you accept the coupling)
- Fire-and-forget notifications where occasional loss is acceptable
- Systems using event sourcing, where the event store IS the source of truth and can be tailed directly

## Structure

```
    ┌─────────────────────────────────────────────────┐
    │                   Service                        │
    │                                                  │
    │   Business Logic                                 │
    │        │                                         │
    │        ▼                                         │
    │   ┌──────────── Single Transaction ────────────┐ │
    │   │                                            │ │
    │   │   1. Write to Business Tables              │ │
    │   │   2. Write to Outbox Table                 │ │
    │   │                                            │ │
    │   └────────────────────────────────────────────┘ │
    │                                                  │
    │   Outbox Table                                   │
    │   ┌────────┬───────┬─────────┬────────┬───────┐ │
    │   │   id   │ type  │ payload │ status │ time  │ │
    │   ├────────┼───────┼─────────┼────────┼───────┤ │
    │   │  uuid  │ event │  json   │ PENDING│  ts   │ │
    │   └────────┴───────┴─────────┴────────┴───────┘ │
    │                    │                             │
    └────────────────────┼─────────────────────────────┘
                         │
              ┌──────────▼──────────┐
              │   Relay Process     │
              │  (Polling or CDC)   │
              └──────────┬──────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │   Message Broker    │
              │  (Kafka, RabbitMQ)  │
              └─────────────────────┘
```

## Implementation Guidelines

### Outbox Table Design

| Column | Purpose | Constraint |
|--------|---------|-----------|
| id | Unique event identifier | Primary key, UUID or ULID |
| aggregate_type | Type of the entity that changed | NOT NULL, indexed |
| aggregate_id | ID of the specific entity instance | NOT NULL, indexed |
| event_type | Name of the domain event | NOT NULL |
| payload | Serialized event data | NOT NULL, JSON |
| created_at | Timestamp of the event creation | NOT NULL, indexed for ordering |
| status | Processing status (PENDING, PUBLISHED, FAILED) | NOT NULL, indexed |
| retry_count | Number of publication attempts | NOT NULL, default 0 |
| published_at | Timestamp when successfully published | Nullable |

### Relay Strategies

| Strategy | Mechanism | Latency | Complexity | Reliability |
|----------|-----------|---------|------------|-------------|
| **Polling** | Periodic query on outbox table | Seconds (poll interval) | Low | High |
| **CDC (Change Data Capture)** | Database transaction log tailing | Milliseconds | Medium | Very high |
| **Transaction log mining** | Read DB WAL/binlog directly | Milliseconds | High | Very high |

### Polling Relay Guidelines

- Poll at a fixed interval (e.g., every 1-5 seconds) for PENDING records
- Process in batches ordered by created_at to maintain ordering
- Use SELECT FOR UPDATE SKIP LOCKED (or equivalent) to allow multiple relay instances
- Mark records as PUBLISHED after successful broker acknowledgment
- Delete or archive published records periodically to prevent table growth

### CDC Relay Guidelines

- Tail the database transaction log for changes to the outbox table
- Maintains strict ordering as events are captured in commit order
- No polling overhead; near-real-time event publishing
- Requires infrastructure support (Debezium, DynamoDB Streams, etc.)
- The relay process MUST track its position in the transaction log for crash recovery

### Delivery Guarantees

| Guarantee | Mechanism |
|-----------|-----------|
| At-least-once delivery | Outbox + relay ensures events are published; consumers MUST be idempotent |
| Ordering per aggregate | Events for the same aggregate_id are published in created_at order |
| No data loss | Event persisted in same transaction as business data; relay retries on failure |
| Duplicate detection | Consumers use the event id for deduplication |

### Housekeeping

| Task | Frequency | Action |
|------|-----------|--------|
| Purge published events | Daily or weekly | Delete or archive records where status = PUBLISHED and age > retention period |
| Retry failed events | Continuous (with backoff) | Increment retry_count; move to dead letter after max retries |
| Monitor outbox lag | Continuous | Alert when PENDING records exceed age threshold |
| Table size monitoring | Daily | Alert when outbox table exceeds expected size |

## Relationship to Other Patterns

- **Saga Pattern**: Each saga step uses the outbox pattern to reliably publish its completion or failure events
- **Event Sourcing**: In event-sourced systems, the event store can serve as the outbox, eliminating the need for a separate outbox table
- **Idempotency**: Since the outbox guarantees at-least-once delivery, all consumers MUST implement idempotent event handling
- **Dead Letter Queue**: Events that fail to publish after maximum retries are moved to a dead letter queue for manual intervention
- **CQRS**: The outbox ensures read model projections receive every event, maintaining consistency between command and query sides
