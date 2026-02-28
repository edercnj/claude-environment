# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Event-Driven Architecture Conventions

## CloudEvents Envelope Standard

All events MUST use the CloudEvents specification (v1.0) as the envelope format. This is non-negotiable for interoperability.

### Required Attributes

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `specversion` | String | CloudEvents spec version | `1.0` |
| `id` | String (UUID) | Unique event identifier | `550e8400-e29b-41d4-a716-446655440000` |
| `source` | URI | Event producer identifier | `/services/order-service` |
| `type` | String | Event type (see naming below) | `com.company.orders.OrderCreated` |
| `time` | Timestamp (RFC 3339) | Event creation time in UTC | `2026-02-19T14:30:00Z` |
| `datacontenttype` | String | Payload content type | `application/json` |

### Recommended Extension Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `subject` | String | Entity the event is about | `/orders/12345` |
| `correlationid` | String (UUID) | Trace correlation across services |
| `causationid` | String (UUID) | ID of the event that caused this event |
| `dataschema` | URI | Schema reference for the data payload |
| `partitionkey` | String | Key used for ordering/partitioning |

## Event Naming

### Convention: Reverse Domain + Past Tense

| Pattern | Format | Example |
|---------|--------|---------|
| Full qualified type | `com.company.{domain}.{EventName}` | `com.company.orders.OrderCreated` |
| Event name | PascalCase, past tense | `OrderCreated`, `PaymentProcessed` |
| Domain | Lowercase bounded context | `orders`, `payments`, `inventory` |

### Naming Rules

| Rule | Correct | Incorrect |
|------|---------|-----------|
| Past tense (something happened) | `OrderCreated` | `CreateOrder`, `OrderCreate` |
| Noun + past participle | `PaymentProcessed` | `ProcessPayment` |
| Specific, not generic | `OrderShipped` | `EntityUpdated` |
| No CRUD verbs | `InventoryReserved` | `InventoryUpdated` |
| Domain-scoped | `com.company.orders.OrderCancelled` | `OrderCancelled` (missing domain) |

**Commands vs Events:** Commands are imperative (`CreateOrder`), events are facts (`OrderCreated`). Events describe something that already happened. NEVER name an event as a command.

## Schema Registry

### Supported Formats

| Format | When to Use | Tradeoffs |
|--------|-------------|-----------|
| JSON Schema | Default for JSON payloads; broadest tooling support | Verbose, no binary encoding |
| Avro | High-throughput systems with schema evolution needs | Compact binary, requires registry, less readable |
| Protobuf | When gRPC is already in the stack | Compact binary, strong typing, steeper learning curve |

### Registry Requirements

- ALL event schemas MUST be registered before producing events
- Schema registry MUST enforce compatibility checks on registration
- Producer MUST embed schema ID or version in the event (header or envelope attribute)
- Consumer MUST validate payload against the registered schema
- Schema registry MUST be highly available (treat as critical infrastructure)

## Event Versioning

### Additive Changes Only (Non-Breaking)

| Change | Safe? | Notes |
|--------|:-----:|-------|
| Add optional field | Yes | Consumers ignore unknown fields |
| Add new event type | Yes | No existing consumers subscribe to it |
| Add optional extension attribute | Yes | Consumers ignore unknown attributes |
| Widen a numeric type (int32 -> int64) | Yes | Backward compatible in most formats |

### Breaking Changes Require New Event Type

| Change | Action Required |
|--------|----------------|
| Remove a field | Create new event type (e.g., `OrderCreatedV2`) |
| Rename a field | Create new event type |
| Change a field type | Create new event type |
| Change the semantic meaning of a field | Create new event type |
| Change from required to optional | Create new event type |

**Versioning strategy:**
- Suffix with version when breaking: `com.company.orders.OrderCreatedV2`
- Produce both old and new events during migration (dual-write)
- Set sunset date for the old event type (minimum 90 days)
- Monitor consumer subscriptions; remove old event after all consumers migrate

## Ordering Guarantees

### Partition Key Strategy

| Entity Type | Partition Key | Ordering Guarantee |
|-------------|---------------|-------------------|
| Per-entity ordering | Entity ID (e.g., `orderId`) | All events for one entity arrive in order |
| Per-tenant ordering | Tenant ID | All events for one tenant arrive in order |
| Per-aggregate ordering | Aggregate root ID | All events for one aggregate arrive in order |
| Global ordering | None (single partition) | Total order; severely limits throughput |

**Rules:**
- Choose the partition key based on the smallest scope that requires ordering
- NEVER use global ordering unless the domain absolutely requires it (throughput bottleneck)
- Document the partition key for every event type
- Consumers MUST handle out-of-order events when processing across partitions
- Include a monotonic sequence number per entity for consumer-side reordering if needed

## Consumer Group Patterns

| Pattern | Description | When to Use |
|---------|-------------|-------------|
| Competing consumers | Multiple instances in same group share partitions | Scale processing horizontally |
| Fan-out | Multiple groups each receive all events | Different services process same events independently |
| Single consumer | One instance processes all partitions | Low-volume, ordering-critical |

**Rules:**
- Consumer group ID format: `{service-name}-{purpose}` (e.g., `order-service-projector`, `notification-service-mailer`)
- NEVER share a consumer group across different services
- Each consumer group MUST have its own offset/checkpoint tracking
- Rebalancing strategy: cooperative (preferred) or eager (simpler but causes pauses)

## Exactly-Once vs At-Least-Once

| Delivery | Guarantee | Implementation Cost | When to Use |
|----------|-----------|:-------------------:|-------------|
| At-most-once | Events may be lost | Low | Metrics, non-critical logs |
| At-least-once | Events may be duplicated | Medium | Default for all business events |
| Exactly-once | No loss, no duplicates | High | Financial transactions, inventory |

**At-least-once (recommended default):**
- Producer retries on failure
- Consumer commits offset AFTER successful processing
- Consumer MUST be idempotent (use event ID for deduplication)

**Exactly-once (when required):**
- Use transactional outbox pattern (write event + state in same DB transaction)
- Or use broker-native exactly-once (e.g., Kafka transactions)
- Consumer deduplicates using event ID stored in processed-events table
- Deduplication window: minimum 7 days retention of processed event IDs

## Dead Letter Topic Configuration

| Parameter | Default | Notes |
|-----------|---------|-------|
| DLT name | `{original-topic}.dlt` | Consistent naming convention |
| Maximum retries before DLT | 3 | With exponential backoff between retries |
| Retry delays | 1s, 5s, 30s | Increasing delays per attempt |
| DLT retention | 30 days | Enough time for manual investigation |
| DLT alerting threshold | > 0 messages | Alert immediately on any DLT message |

**Rules:**
- Every consumer MUST have a dead letter topic configured
- DLT messages MUST include: original event, error message, retry count, failure timestamp, consumer group ID
- DLT MUST be monitored; alert on new messages within 5 minutes
- Provide tooling to replay events from DLT back to the original topic
- NEVER silently drop failed events; DLT is mandatory

## Event Replay Capability

| Requirement | Implementation |
|-------------|---------------|
| Replay by time range | Broker retains events for configured retention period |
| Replay by event type | Consumer filters during replay |
| Replay by entity ID | Consumer filters by partition key during replay |
| Replay to new consumer group | Create new group with earliest offset |
| Idempotent replay | Consumer deduplicates by event ID |

**Rules:**
- Event retention MUST be at least 7 days (30 days recommended)
- Replay MUST NOT affect other consumer groups
- Consumers MUST be idempotent to support replay without side effects
- Document the replay procedure for each consumer
- Test replay capability at least quarterly

## Correlation ID Propagation

| Hop | Action |
|-----|--------|
| API Gateway / Entry Point | Generate `correlationId` (UUID) if not present in request headers |
| Service processing | Read `correlationId` from incoming request/event; attach to all outgoing events |
| Event producer | Include `correlationId` as CloudEvents extension attribute |
| Event consumer | Read `correlationId` from event; propagate to downstream calls and events |
| Logging | Include `correlationId` in every log line (structured logging) |

**Rules:**
- `correlationId` MUST be propagated across ALL service boundaries (HTTP, gRPC, events)
- NEVER generate a new `correlationId` mid-chain; always propagate the original
- Use `causationId` to link parent-child event relationships within the same correlation
- Include `correlationId` in distributed tracing spans for end-to-end visibility

## Anti-Patterns (FORBIDDEN)

- Events without CloudEvents envelope -- all events MUST use the standard format
- Command-style event names (`CreateOrder`) -- events are past tense facts (`OrderCreated`)
- Unregistered schemas -- all event schemas MUST be in the schema registry
- Breaking changes to existing event types -- create a new versioned event type
- Consumers without dead letter topic -- failed events MUST NOT be silently dropped
- Consumers that are not idempotent -- at-least-once delivery means duplicates will occur
- Global ordering when per-entity ordering suffices -- global ordering kills throughput
- Sharing consumer groups across different services -- each service owns its group
- Events without correlation ID -- breaks distributed tracing
- Producing events outside of a transaction (dual-write problem) -- use outbox pattern or transactions
- Events with sensitive data (PII, secrets) in the payload without encryption
- Unbounded event payloads -- set maximum payload size (1 MB recommended)
- Events that reference data instead of containing it (thin events) without a documented retrieval contract
