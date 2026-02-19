# Circuit Breaker

## Intent

The Circuit Breaker pattern prevents an application from repeatedly attempting an operation that is likely to fail, protecting both the calling service and the failing dependency. By detecting sustained failure rates and short-circuiting requests, it enables fast failure responses, gives the failing system time to recover, and prevents cascading failures across the system. When the dependency recovers, the circuit breaker gradually resumes normal traffic.

## When to Use

- Any call to an external dependency (database, API, message broker, cache) that can fail or become slow
- `architecture.style=microservice` where service-to-service calls are common
- Systems where a failing dependency would otherwise cause thread exhaustion or timeout accumulation
- Operations where waiting for a timeout on every request is unacceptable (fail-fast is preferred)
- Reference: `core/09-resilience-principles.md` provides the condensed circuit breaker summary

## When NOT to Use

- In-process method calls with no external dependency
- Operations that are expected to fail frequently by design (e.g., cache lookups where misses are normal)
- Fire-and-forget operations where the caller does not wait for a response
- When the dependency has its own robust retry and recovery mechanisms that should not be bypassed

## Structure

```
    ┌────────────────────────────────────────────────────────┐
    │                  Circuit Breaker States                  │
    │                                                         │
    │   ┌─────────┐    failure ratio    ┌─────────┐          │
    │   │         │    >= threshold     │         │          │
    │   │ CLOSED  │───────────────────►│  OPEN   │          │
    │   │ (normal)│                     │ (reject)│          │
    │   │         │◄────┐              │         │          │
    │   └─────────┘     │              └────┬────┘          │
    │                    │                   │                │
    │              success              delay expires        │
    │              >= N                      │                │
    │                    │              ┌────▼────┐          │
    │                    │              │         │          │
    │                    └──────────────┤HALF-OPEN│          │
    │                                   │ (test)  ├──────┐  │
    │                                   │         │      │  │
    │                                   └─────────┘  failure │
    │                                                    │  │
    │                                        ┌───────────┘  │
    │                                        ▼              │
    │                                     OPEN              │
    └────────────────────────────────────────────────────────┘
```

## Implementation Guidelines

### State Behavior

| State | Behavior | Transitions |
|-------|----------|-------------|
| CLOSED | All requests pass through; failures are counted in a sliding window | Moves to OPEN when failure ratio exceeds threshold within the measurement window |
| OPEN | All requests are rejected immediately without calling the dependency | Moves to HALF-OPEN after a configured delay period |
| HALF-OPEN | A limited number of test requests are allowed through | Moves to CLOSED if test requests succeed; returns to OPEN if any test request fails |

### Configuration Guidelines

| Parameter | Guideline | Rationale |
|-----------|-----------|-----------|
| Sliding window size | 10-100 requests or 10-60 seconds | Must be large enough to smooth out normal fluctuations |
| Failure ratio threshold | 30-50% | Below 30% may be too sensitive; above 50% too lenient |
| Minimum call threshold | 10+ requests in window | Prevents opening on insufficient data |
| Wait duration (open state) | 15-30 seconds | Long enough for transient issues to resolve; short enough to recover quickly |
| Permitted calls in half-open | 3-5 requests | Enough to gain confidence without risking a flood |
| Success threshold (half-open) | 3-5 consecutive successes | Confirms the dependency has genuinely recovered |
| Slow call duration threshold | Based on P99 of healthy operation | Slow calls counted as failures when ratio is exceeded |
| Slow call ratio threshold | 50-80% | When this percentage of calls exceed the duration threshold |

### What Counts as a Failure

| Counts as Failure | Does NOT Count as Failure |
|------------------|--------------------------|
| Connection refused | Client-side validation error (4xx) |
| Connection timeout | Business logic rejection |
| Read timeout | Successful response with error payload |
| HTTP 5xx responses | HTTP 4xx responses (client error) |
| Exceptions from the dependency | Cancellation by the caller |
| Slow responses exceeding threshold | Responses within acceptable latency |

### Fallback Strategies

| Strategy | When to Use | Constraint |
|----------|-------------|-----------|
| Return cached data | Read operations where stale data is acceptable | Track staleness; alert on prolonged fallback |
| Return default value | Operations with a safe default (empty list, default config) | Default must be semantically safe |
| Call alternative dependency | Backup service or replica available | Alternative must be independent (not same failure) |
| Queue for later processing | Write operations that can be deferred | Queue must be bounded; process when circuit closes |
| Fail immediately with clear error | Operations where no degradation is acceptable | Return appropriate error code (503, UNAVAILABLE) |

**Golden Rule (from core/09):** When the circuit is OPEN for a critical dependency, ALWAYS fail secure. NEVER approve, allow, or return success when the dependency required for that decision is unavailable.

### Per-Dependency Circuits

Each external dependency MUST have its own circuit breaker instance. Never share a single circuit breaker across multiple dependencies.

| Dependency | Separate Circuit | Rationale |
|-----------|-----------------|-----------|
| Database | Yes | DB failure should not open the cache circuit |
| Cache | Yes | Cache failure should not block DB operations |
| External API A | Yes | API A failure is independent of API B |
| External API B | Yes | Each dependency fails independently |

### Monitoring and Alerting

| Metric | Type | Alert Condition |
|--------|------|-----------------|
| Circuit state | Gauge | Transition to OPEN |
| Calls total | Counter (success/failure/rejected/ignored) | Rejected count increasing |
| Failure ratio | Gauge | Approaching threshold |
| Not permitted calls | Counter | Any (means circuit is open) |
| State transition events | Counter (per transition type) | OPEN transitions exceeding baseline |

### Logging Requirements

| Event | Level | Required Context |
|-------|-------|-----------------|
| Circuit opened | ERROR | Circuit name, failure count, failure ratio, window duration |
| Circuit half-opened | INFO | Circuit name, wait duration elapsed |
| Circuit closed | INFO | Circuit name, success count in half-open |
| Request rejected (circuit open) | WARN | Circuit name, operation attempted |

## Relationship to Other Patterns

- **Reference**: `core/09-resilience-principles.md` defines the circuit breaker as a core resilience primitive
- **Retry with Backoff**: Retries happen INSIDE the circuit breaker; when the circuit opens, retries stop immediately
- **Timeout Patterns**: Timeouts trigger failures that the circuit breaker counts; without timeouts, slow calls accumulate without opening the circuit
- **Bulkhead**: Bulkheads limit concurrent access; circuit breakers detect failure rates. Use both together for comprehensive protection
- **Fallback/Graceful Degradation**: The circuit breaker triggers the fallback; the fallback defines what happens when the circuit is open
- **Service Discovery**: When a circuit opens for a specific instance, discovery can route to healthy instances
