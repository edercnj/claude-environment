# Dead Letter Queue (DLQ)

## Intent

The Dead Letter Queue captures messages that cannot be processed successfully after all retry attempts are exhausted. Rather than losing failed messages or blocking the processing pipeline, the DLQ provides a safe holding area where problematic messages can be inspected, diagnosed, and manually replayed once the underlying issue is resolved. It is the last line of defense in an event-driven system's error handling chain.

## When to Use

- Event-driven systems with asynchronous message processing
- `architecture.event_driven=true` where at-least-once delivery is configured
- Any message consumer that may encounter unprocessable messages (poison pills)
- Systems where message loss is unacceptable and failed messages must be preserved
- Saga orchestration where failed steps need manual investigation
- Webhook receivers where incoming events may contain unexpected formats

## When NOT to Use

- Synchronous request-response systems where errors are returned directly to the caller
- Messages that are intentionally discarded on failure (telemetry, non-critical metrics)
- When the processing system has no mechanism for manual intervention or replay
- Log-based systems where the original event log is preserved and can be replayed from source

## Structure

```
    Producer ──► Main Queue ──► Consumer
                                   │
                              [Process Message]
                                   │
                          ┌────────┼────────┐
                          │                  │
                       Success            Failure
                          │                  │
                          ▼                  ▼
                       Commit            Retry (N times)
                                             │
                                        ┌────┼────┐
                                        │         │
                                    Recovered  Exhausted
                                        │         │
                                     Commit       ▼
                                          ┌──────────────┐
                                          │  Dead Letter  │
                                          │    Queue      │
                                          │               │
                                          │ [Failed Msg]  │
                                          │ [Error Info]  │
                                          │ [Timestamp]   │
                                          │ [Attempt #]   │
                                          └──────┬───────┘
                                                 │
                                          ┌──────▼───────┐
                                          │  DLQ Monitor  │
                                          │  (Alert +     │
                                          │   Dashboard)  │
                                          └──────────────┘
```

## Implementation Guidelines

### DLQ Message Enrichment

When a message is moved to the DLQ, it MUST carry diagnostic metadata:

| Field | Purpose |
|-------|---------|
| Original message | The complete original message payload |
| Original queue/topic | Where the message was originally consumed from |
| Error message | The exception or error that caused the final failure |
| Stack trace | Full stack trace from the last processing attempt |
| Retry count | Number of attempts made before moving to DLQ |
| First failure time | Timestamp of the first processing attempt |
| Last failure time | Timestamp of the final processing attempt |
| Consumer instance | Identifier of the consumer that last attempted processing |
| Correlation ID | Business correlation ID for tracing |

### Poison Pill Detection

A poison pill is a message that will never be processed successfully regardless of how many times it is retried. Detecting these early prevents wasted retry cycles.

| Detection Strategy | Mechanism |
|-------------------|-----------|
| Schema validation | Validate message format before processing; reject invalid immediately |
| Error classification | Distinguish permanent errors (deserialization, validation) from transient errors |
| Fast-fail on known patterns | If the error type is non-retryable, move to DLQ immediately without retrying |
| Retry threshold | If a message has been redelivered N times (broker-tracked), move to DLQ |

### DLQ Processing Workflow

| Step | Action | Responsibility |
|------|--------|---------------|
| 1. Alert | Notify operations team when DLQ message count exceeds threshold | Automated monitoring |
| 2. Triage | Classify messages by error type; identify root cause | Operations / Development |
| 3. Fix | Deploy fix for the processing logic or data issue | Development |
| 4. Replay | Replay messages from DLQ back to the original queue | Operations (manual or tooling) |
| 5. Verify | Confirm replayed messages are processed successfully | Automated monitoring |
| 6. Purge | Remove successfully replayed messages from DLQ | Automated or manual |

### Replay Guidelines

| Principle | Guideline |
|-----------|-----------|
| Ordering | Replay messages in the order they were added to the DLQ |
| Rate limiting | Replay at a controlled rate to avoid overwhelming the consumer |
| Idempotency | Consumers MUST be idempotent; replayed messages may be duplicates |
| Selective replay | Support replaying by error type, time range, or correlation ID |
| Dry run | Support a validation mode that checks if messages would process successfully without committing |
| Audit trail | Log every replay action with who initiated it and the result |

### Monitoring and Alerting

| Metric | Type | Alert Condition |
|--------|------|-----------------|
| DLQ message count | Gauge | Any messages present (investigate) |
| DLQ ingestion rate | Counter | Messages entering DLQ faster than being resolved |
| DLQ age (oldest message) | Gauge | Oldest message exceeds SLA (e.g., > 1 hour) |
| Replay success rate | Gauge | Replayed messages failing again |
| DLQ by error type | Counter (per type) | New error type appearing |

**Rule:** DLQ messages MUST trigger alerts. A growing DLQ is a symptom of a systemic issue that requires attention. DLQs should normally be empty.

### Retention and Lifecycle

| Aspect | Guideline |
|--------|-----------|
| Retention period | Based on business SLA; typically 7-30 days |
| Archival | After retention period, archive to cold storage before deletion |
| Size limits | Set maximum DLQ size; alert well before the limit |
| Cleanup | Automated purge of messages older than retention period |

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Ignoring the DLQ | Failed messages accumulate unnoticed | Alert on any DLQ message; review daily |
| DLQ without metadata | Cannot diagnose why the message failed | Enrich with error, stack trace, context |
| Automatic replay without fix | Replayed messages fail again, re-entering DLQ | Fix the root cause before replaying |
| No replay tooling | Manual, error-prone replay process | Build or adopt replay tooling with rate limiting |
| DLQ for every error | Transient errors bypass retry | Only DLQ after retries exhausted or on permanent errors |
| No retention policy | DLQ grows unbounded | Set TTL and archival policies |

## Relationship to Other Patterns

- **Retry with Backoff**: Retries are the first line of defense for transient failures; the DLQ is the last resort after retries are exhausted
- **Circuit Breaker**: When a circuit opens, messages may fail processing; these failures contribute to DLQ volume
- **Outbox Pattern**: If the outbox relay cannot publish a message after max retries, it moves the message to a DLQ
- **Saga Pattern**: Failed saga steps that cannot be compensated or retried produce DLQ entries for manual resolution
- **Idempotency**: Replayed messages from the DLQ must be handled idempotently by consumers
- **Event Sourcing**: In event-sourced systems, the original event stream provides an alternative replay mechanism; the DLQ captures projection failures
