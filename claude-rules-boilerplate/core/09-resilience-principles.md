# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 09 — Resilience Principles

## Principles
- **Fail Secure:** On failure, DENY/REJECT — NEVER approve or allow
- **Failure Isolation:** Failure in one component MUST NOT propagate to others
- **Graceful Degradation:** Under pressure, reduce functionality progressively instead of collapsing
- **Observability:** Every resilience event MUST generate a metric and log
- **Application-Level:** Resilience is the responsibility of the application, NOT the orchestrator

## 1. Rate Limiting (Flow Control)

### Scopes

| Scope | Algorithm | Purpose |
|-------|-----------|---------|
| Per client (IP / API key / connection) | Token Bucket | Prevent single client abuse |
| Per endpoint (write operations) | Fixed Window | Protect state-changing operations |
| Global | Sliding Window | Protect overall system capacity |

### Response to Rate Limit

| Channel | Action | Code |
|---------|--------|------|
| REST API | HTTP 429 + `Retry-After` header | 429 Too Many Requests |
| Protocol (TCP/gRPC) | Error response code | System error / overloaded |
| Global | Reject new connections | Connection refused |

### Rules
- ALWAYS provide `Retry-After` header or equivalent
- ALWAYS track rate limit metrics (accepted vs rejected)
- Per-client AND global limits (never just global)
- Evict idle buckets periodically to prevent memory leak

## 2. Circuit Breaker

### States

```
CLOSED (normal) ──[failure ratio >= threshold]──► OPEN (rejects everything)
                                                     │
                                                 [delay expires]
                                                     │
                                                     ▼
                                              HALF_OPEN (tests)
                                                     │
                                    ┌────────────────┼────────────────┐
                              [success >= N]                    [failure]
                                    │                              │
                                    ▼                              ▼
                                 CLOSED                          OPEN
```

### Configuration Guidelines

| Parameter | Guideline |
|-----------|-----------|
| Request volume threshold | 10+ (avoid opening on small samples) |
| Failure ratio | 30-50% (depends on expected error rate) |
| Delay (open -> half-open) | 15-30 seconds |
| Success threshold (half-open -> closed) | 3-5 successes |

### Behavior by State

| State | Action |
|-------|--------|
| CLOSED | Normal processing |
| OPEN | Return error immediately (fail-fast) |
| HALF_OPEN | Allow one test request, evaluate result |

### Golden Rule — Fail Secure

> When the circuit breaker for a critical dependency (e.g., database) is OPEN,
> ALL operations requiring that dependency MUST fail safely.
> NEVER approve/allow an operation without completing its required steps.

## 3. Bulkhead (Load Isolation)

Isolate different workloads to prevent one from consuming all resources.

### Partitioning Strategy

| Workload | Type | Purpose |
|----------|------|---------|
| Protocol A processing | Semaphore | Isolate protocol A traffic |
| Protocol B processing | Semaphore | Isolate protocol B traffic |
| Database operations | Semaphore | Limit DB connection pressure |
| Long-running tasks | Thread Pool | Prevent blocking main threads |

**Rule:** Different protocols/channels MUST have separate bulkheads. A traffic spike in one channel MUST NOT affect the other.

## 4. Timeout (Time Control)

### Guidelines

| Operation | Recommended Timeout | Action |
|-----------|-------------------|--------|
| Database query | 5s | Abort + error response |
| Database write | 5s | Abort + error response |
| DB connection acquire | 3s | Abort + error response |
| Total operation processing | 10s | Abort + error response |
| External API call | 5-10s | Abort + fallback |
| HTTP request processing | 30s | HTTP 503 |

**Rule:** Application timeout MUST be shorter than client timeout. A response arriving after the client gives up is wasted work.

## 5. Retry

### Policy

| Operation Type | Retry? | Why |
|---------------|:------:|-----|
| Idempotent reads (SELECT) | Yes | Safe to retry |
| Connection acquisition | Yes | Transient failures |
| Non-idempotent writes (INSERT) | **NO** | Risk of duplication |
| Business processing | **NO** | Already failed validation |
| Health checks | Yes | Should recover automatically |

### Rules

- **NEVER** retry non-idempotent operations
- **NEVER** retry business errors (validation, authorization)
- **ONLY** retry on transient failures (connection reset, network timeout)
- **ALWAYS** with jitter to avoid thundering herd
- **ALWAYS** with max attempts (never infinite retry)
- **ALWAYS** with exponential or fixed backoff

### Retryable vs Non-Retryable

| Retryable (transient) | Non-Retryable (permanent) |
|----------------------|--------------------------|
| Connection reset | Unique constraint violation |
| Network timeout | Validation error |
| Lock timeout | Authorization failure |
| Service unavailable (503) | Bad request (400) |

## 6. Fallback (Graceful Degradation)

### Strategies

| Component | Trigger | Fallback | Result |
|-----------|---------|----------|--------|
| DB write | Circuit open / timeout | Log + throw | Error (fail secure) |
| DB read | Circuit open / timeout | Empty result | Error if data was mandatory |
| Decision logic | Unexpected exception | Deny/reject | **NEVER approve/allow** |
| Rate limit | Bucket empty | Error response | Keep connection alive |
| Bulkhead full | Queue full | Error response | Error code |

### Golden Rule — Fail Secure

```
// GOOD — fallback denies
function decideFallback(input):
    log.error("Decision engine fallback — denying")
    return SYSTEM_ERROR  // Deny

// BAD — fallback approves
function decideFallback(input):
    return APPROVED  // DANGER: failure = approval
```

## 7. Backpressure (Counterpressure)

For protocols supporting flow control (TCP, streams):

| Mechanism | Threshold | Action |
|-----------|-----------|--------|
| Pending messages per connection | > N (e.g., 10) | Pause reading from connection |
| Resume threshold | <= N/2 (e.g., 5) | Resume reading |
| Pending messages global | > M (e.g., 1000) | Reject new connections |

**Rules:**
- NEVER use `sleep()` for backpressure — use protocol-native pause/resume
- Always implement resume logic (never leave connections frozen permanently)
- Clean up counters when connections close

## 8. Graceful Degradation (Progressive)

### Degradation Levels

| Level | Condition | Actions |
|-------|-----------|--------|
| **NORMAL** | All metrics healthy | Full functionality |
| **WARNING** | Elevated load indicators | Reduce rate limits, disable verbose logging |
| **CRITICAL** | High load or single circuit open | Reject new connections, process only existing |
| **EMERGENCY** | Multiple failures or critical dependency down | Minimal functionality only, reject everything else |

### Health Exposure

Readiness probe MUST reflect degradation level:
- NORMAL, WARNING → UP
- CRITICAL → UP with warning metadata
- EMERGENCY → DOWN

## Resilience Metrics

### Automatic (from resilience library)

| Metric | Type |
|--------|------|
| Circuit breaker state | Gauge (per circuit) |
| Circuit breaker calls | Counter (success/failure/rejected) |
| Bulkhead active executions | Gauge |
| Bulkhead rejected | Counter |
| Retry attempts | Counter |
| Timeout triggered | Counter |
| Fallback invoked | Counter |

### Custom (application)

| Metric | Type |
|--------|------|
| Rate limit accepted | Counter (per scope, client) |
| Rate limit rejected | Counter (per scope, client) |
| Degradation level | Gauge |
| Degradation level changes | Counter (from→to) |
| Backpressure activations | Counter |

## Logging Resilience Events

| Event | Log Level | Mandatory Context |
|-------|-----------|------------------|
| Rate limit rejected | WARN | scope, client_key, current_rate |
| Circuit opened | ERROR | circuit_name, failure_count, failure_ratio |
| Circuit half-opened | INFO | circuit_name |
| Circuit closed | INFO | circuit_name, success_count |
| Bulkhead rejected | WARN | bulkhead_name, active_count, queue_size |
| Timeout triggered | ERROR | operation, duration_ms, threshold_ms |
| Retry attempted | WARN | operation, attempt, max_attempts, error |
| Fallback invoked | WARN | operation, reason |
| Degradation level changed | WARN | from_level, to_level, trigger_metric |

## Anti-Patterns (FORBIDDEN)

### General
- Approve/allow on fallback — **ALWAYS deny/reject**
- Retry non-idempotent operations
- Retry without jitter
- Infinite retry without max attempts
- Timeout longer than client timeout
- Resilience only at infrastructure level (K8s) without application-level patterns

### Rate Limiting
- Global rate limit without per-client limits
- Rate limit without metrics
- Rate limit without `Retry-After` header (REST)

### Circuit Breaker
- Too low threshold (1-2 failures) — opens on normal fluctuation
- Too long delay (> 60s) — slow to recover
- Circuit breaker without fallback
- Fallback that calls the same protected resource (infinite loop)

### Bulkhead
- Single bulkhead for all workloads
- Long-running tasks in main bulkhead
- Queue too large — messages grow stale

### Backpressure
- `sleep()` for backpressure — blocks threads
- Ignore pause/resume protocol features
- Never resume paused connections
