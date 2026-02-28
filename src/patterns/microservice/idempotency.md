# Idempotency

## Intent

Idempotency ensures that performing the same operation multiple times produces the same result as performing it once. In distributed systems where network failures, retries, and message redelivery are inevitable, idempotency is the fundamental mechanism that prevents duplicate processing, double charges, duplicate records, and data corruption. Without idempotency, every retry is a risk.

## When to Use

- `architecture.style=microservice` and `event_driven=true` systems where retries are expected
- Any API endpoint that modifies state (POST, PUT, PATCH, DELETE)
- Message consumers in at-least-once delivery systems (Kafka, RabbitMQ, SQS)
- Saga steps and compensation actions that may be retried
- Payment processing, order creation, or any operation where duplication has business impact
- Webhook receivers that may receive the same event multiple times

## When NOT to Use

- Read-only (GET) operations that are naturally idempotent
- Operations where duplication is harmless (e.g., updating a record to the same value)
- Internal function calls within a single process with no retry mechanism
- When the operation is already idempotent by nature (e.g., PUT replacing the entire resource)

## Structure

```
    Client                    Service                    Store
      │                         │                          │
      │── Request + Key ──────►│                          │
      │                         │── Check Key Exists? ───►│
      │                         │◄── No (first time) ─────│
      │                         │                          │
      │                         │── Process Operation ────►│
      │                         │── Store Key + Result ───►│
      │                         │◄── Confirm ──────────────│
      │◄── Response ────────────│                          │
      │                         │                          │
      │── Same Request + Key ──►│                          │
      │                         │── Check Key Exists? ───►│
      │                         │◄── Yes (duplicate) ─────│
      │                         │── Load Stored Result ───►│
      │◄── Same Response ──────│                          │
```

## Implementation Guidelines

### Idempotency Key Design

| Aspect | Guideline |
|--------|-----------|
| Generation | Client generates a unique key per logical operation (UUID, ULID) |
| Transmission | Passed via a dedicated header (e.g., Idempotency-Key) or message attribute |
| Scope | One key per distinct business intent; retries use the same key |
| Format | UUID v4, ULID, or a deterministic hash of operation parameters |
| Uniqueness | Keys MUST be globally unique within the retention window |

### Deduplication Strategies

| Strategy | Mechanism | Best For |
|----------|-----------|----------|
| **Key-based lookup** | Store idempotency key in a dedicated table; check before processing | API requests |
| **Natural key** | Use business-meaningful identifiers (order ID + operation) | Domain operations |
| **Message ID** | Use the message broker's delivery ID | Event consumers |
| **Content hash** | Hash the request body; treat identical content as duplicate | Webhook receivers |
| **Database constraint** | Unique constraint on business key prevents duplicate inserts | Write operations |

### Storage for Idempotency State

| Storage | TTL | Consistency | Use Case |
|---------|-----|-------------|----------|
| Relational DB (same as business data) | Days to weeks | Strong (same transaction) | Critical operations (payments) |
| Redis / Cache | Hours to days | Eventual | High-throughput API deduplication |
| In-memory (local) | Minutes | None (single instance) | Development or single-instance services |

**Rule:** For critical operations, store the idempotency key in the SAME transaction as the business data change. This ensures atomicity: the operation is recorded as processed if and only if the business change commits.

### Request Lifecycle with Idempotency

| State | Meaning | Response to Duplicate |
|-------|---------|----------------------|
| Not found | First request with this key | Process normally |
| In progress | Another request with this key is currently being processed | Return 409 Conflict or wait |
| Completed | Request was already processed successfully | Return stored response |
| Failed | Previous attempt with this key failed | Allow retry (reprocess) |

### Exactly-Once Semantics

True exactly-once processing is achieved by combining:

| Component | Role |
|-----------|------|
| At-least-once delivery | Message broker guarantees the message is delivered (possibly more than once) |
| Consumer idempotency | Consumer deduplicates based on message ID or idempotency key |
| Result: Exactly-once processing | Each message is processed exactly once, despite possible redelivery |

### Retry Safety Guidelines

| Principle | Detail |
|-----------|--------|
| Same key on retry | Retries MUST use the same idempotency key as the original request |
| Fingerprint validation | On duplicate key, optionally verify the request body matches the original |
| Mismatch handling | If key matches but body differs, return 422 Unprocessable Entity |
| TTL on keys | Idempotency records MUST expire; retention period matches the business retry window |
| Cleanup | Purge expired idempotency records periodically |

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Server-generated idempotency keys | Client cannot retry with the same key | Client generates keys |
| No TTL on idempotency records | Unbounded storage growth | Set expiration aligned with retry window |
| Check-then-act without locking | Race condition: two requests pass the check | Atomic check-and-insert (INSERT IF NOT EXISTS) |
| Idempotency only at the API layer | Internal event consumers still process duplicates | Apply at every boundary |
| Ignoring partial failures | Operation partially completed; retry completes the rest differently | Use transactions or compensation |

## Relationship to Other Patterns

- **Outbox Pattern**: The outbox guarantees at-least-once event delivery; consumers MUST be idempotent to handle redelivery
- **Saga Pattern**: Every saga step and compensation action MUST be idempotent to handle retries during orchestration
- **Retry with Backoff**: Retries are safe only when the target operation is idempotent
- **Event Sourcing**: Event handlers and projections MUST be idempotent since events may be replayed
- **Dead Letter Queue**: Messages that fail even with idempotent retry go to the DLQ for investigation
