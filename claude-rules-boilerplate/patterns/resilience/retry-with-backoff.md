# Retry with Backoff

## Intent

The Retry with Backoff pattern handles transient failures by automatically re-attempting failed operations with progressively increasing delays between attempts. Transient failures -- network glitches, temporary resource exhaustion, brief service unavailability -- are common in distributed systems and often resolve on their own. Retry with backoff provides automatic recovery from these failures while preventing the system from overwhelming an already struggling dependency through controlled spacing of attempts.

## When to Use

- Operations against external dependencies that experience transient failures (network, database, APIs)
- `architecture.style=microservice` where network calls are frequent and unreliable
- Idempotent operations that are safe to retry without side effects
- Connection establishment where transient rejection is expected under load
- Reference: `core/09-resilience-principles.md` defines retry as a core resilience mechanism

## When NOT to Use

- Non-idempotent operations (INSERT without idempotency key, financial transactions without deduplication)
- Business validation errors (400 Bad Request, authorization failures, constraint violations)
- Permanent failures that will not resolve with time (invalid credentials, missing resource)
- Operations inside an open circuit breaker (retries are suppressed by the circuit)
- When the client's timeout budget does not allow for retry delays

## Structure

```
    Request ──► Attempt 1 ──[fail]──► Wait (base delay)
                                          │
                                          ▼
                    Attempt 2 ──[fail]──► Wait (base * 2 + jitter)
                                              │
                                              ▼
                        Attempt 3 ──[fail]──► Wait (base * 4 + jitter)
                                                  │
                                                  ▼
                            Attempt 4 ──[fail]──► Exhausted ──► Fail / Fallback

    Delay Progression (exponential with jitter):
    ┌────┐   ┌─────────┐   ┌──────────────────┐   ┌─────────────────────────┐
    │ 1s │   │ 2s +jit │   │   4s + jitter    │   │     8s + jitter         │
    └────┘   └─────────┘   └──────────────────┘   └─────────────────────────┘
```

## Implementation Guidelines

### Backoff Strategies

| Strategy | Delay Formula | Use Case |
|----------|--------------|----------|
| Fixed | delay = constant | Simple cases; low concurrency |
| Linear | delay = base * attempt | Gradual increase; moderate concurrency |
| Exponential | delay = base * 2^attempt | Standard choice; scales well under contention |
| Exponential with cap | delay = min(base * 2^attempt, max_delay) | Prevents excessively long waits |
| Decorrelated jitter | delay = random(base, previous_delay * 3) | Best distribution under high concurrency |

### Jitter: Why It Is Mandatory

Without jitter, all clients that failed at the same time will retry at the same time, creating a thundering herd that overwhelms the recovering dependency. Jitter randomizes retry timing to spread the load.

| Jitter Type | Mechanism | Effectiveness |
|-------------|-----------|---------------|
| Full jitter | delay = random(0, base * 2^attempt) | High spread; some retries are immediate |
| Equal jitter | delay = base * 2^attempt / 2 + random(0, base * 2^attempt / 2) | Good spread; minimum wait guaranteed |
| Decorrelated jitter | delay = random(base, previous_delay * 3) | Best overall distribution |

**Rule:** ALWAYS use jitter. Retry without jitter is an anti-pattern that causes synchronized retry storms.

### Configuration Guidelines

| Parameter | Guideline | Rationale |
|-----------|-----------|-----------|
| Max attempts | 3-5 | Enough for transient recovery; not so many that failures take minutes |
| Base delay | 100ms-1s | Short enough for quick recovery; long enough to be meaningful |
| Max delay (cap) | 10-30s | Prevents individual retries from exceeding useful timeout budgets |
| Overall timeout | Sum of all delays + execution time < client timeout | Retries must complete within the caller's patience window |

### Retryable vs Non-Retryable Classification

| Retryable (Transient) | Non-Retryable (Permanent) |
|----------------------|--------------------------|
| Connection reset / refused | Authentication failure (401, 403) |
| DNS resolution timeout | Bad request (400) |
| Socket timeout | Not found (404) |
| HTTP 503 Service Unavailable | Unique constraint violation |
| HTTP 429 Too Many Requests (with Retry-After) | Business validation error |
| Lock wait timeout | Data format / parsing error |
| Optimistic lock conflict | Unsupported media type (415) |

**Rule:** Classify errors explicitly. The default for unknown errors should be non-retryable. Only retry errors you have confirmed are transient.

### Retry Budgets

A retry budget limits the total number of retries a service performs across all operations within a time window, preventing a service from amplifying load on a struggling dependency.

| Aspect | Guideline |
|--------|-----------|
| Budget scope | Per dependency (not global) |
| Budget size | 10-20% of normal request volume |
| Measurement window | Rolling 10-60 second window |
| Exceeded budget | Stop retrying; fail immediately |
| Monitoring | Track budget utilization as a metric |

### Interaction with Timeouts

- The total time for all retry attempts MUST be less than the caller's timeout
- Each individual attempt has its own timeout (connection timeout + read timeout)
- Calculate: max_attempts * (attempt_timeout + max_delay) must fit within the overall timeout budget
- If remaining budget is less than one attempt, do not retry

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Retry without jitter | Thundering herd on recovery | Always add jitter |
| Retry non-idempotent operations | Duplicated side effects | Only retry idempotent operations |
| Infinite retries | Never gives up; accumulates threads | Set max attempts |
| Fixed delay without backoff | Does not give dependency time to recover | Use exponential or decorrelated backoff |
| Retry across all services simultaneously | Amplified load cascades | Use retry budgets |
| Retry on circuit-open | Bypasses the circuit breaker | Retry wraps inside circuit breaker |
| Retry business errors | Will never succeed | Classify errors; only retry transient |

## Relationship to Other Patterns

- **Reference**: `core/09-resilience-principles.md` defines retry as a core resilience primitive with retryable vs non-retryable classification
- **Circuit Breaker**: The circuit breaker wraps the retry logic; when the circuit opens, retries are suppressed. Retried failures contribute to the circuit breaker's failure count
- **Timeout Patterns**: Each retry attempt must have its own timeout; the total retry time must fit within the overall operation timeout
- **Idempotency**: Retries are only safe when the operation is idempotent; without idempotency, retries risk duplication
- **Bulkhead**: Retries consume bulkhead capacity; a high retry rate can exhaust the bulkhead for legitimate new requests
- **Dead Letter Queue**: Operations that fail after all retries are exhausted should be routed to a DLQ for investigation
