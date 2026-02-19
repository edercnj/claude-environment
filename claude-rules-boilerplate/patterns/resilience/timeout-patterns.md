# Timeout Patterns

## Intent

Timeout patterns prevent operations from waiting indefinitely for responses that may never arrive. In distributed systems, a missing timeout means a single slow or unresponsive dependency can consume threads, connections, and memory until the entire service becomes unresponsive. Timeouts are the foundational mechanism that makes all other resilience patterns (circuit breakers, retries, bulkheads) effective by ensuring that failures are detected within bounded time.

## When to Use

- Every external call: database queries, API calls, cache lookups, message broker operations
- Every network operation: connection establishment, TLS handshake, data transfer
- `architecture.style=microservice` where service-to-service calls traverse the network
- Long-running internal operations that must complete within a business SLA
- Reference: `core/09-resilience-principles.md` defines timeout as a core resilience mechanism

## When NOT to Use

- In-process computations with deterministic, bounded execution time
- Fire-and-forget operations where the caller does not wait for a result
- Streaming operations that are expected to run indefinitely (use heartbeat and idle timeout instead)

## Structure

```
    Client                   Service A                  Service B
      │                         │                          │
      │── Overall Timeout ─────►│                          │
      │   (e.g., 30s)          │── Connection Timeout ───►│
      │                         │   (e.g., 3s)            │
      │                         │                          │
      │                         │◄─ Connected ─────────────│
      │                         │                          │
      │                         │── Read Timeout ─────────►│
      │                         │   (e.g., 5s)            │
      │                         │                          │
      │                         │◄─ Response ──────────────│
      │◄─ Response ─────────────│                          │
      │                         │                          │

    Deadline Propagation:
    ┌──────────────────────────────────────────────────────────┐
    │ Client deadline: T=30s                                    │
    │                                                           │
    │ Service A receives at T=0, spends 2s processing           │
    │ Service A calls B with deadline: T=28s                    │
    │                                                           │
    │ Service B receives, spends 1s processing                  │
    │ Service B calls C with deadline: T=27s                    │
    │                                                           │
    │ Each hop reduces the remaining deadline                   │
    └──────────────────────────────────────────────────────────┘
```

## Implementation Guidelines

### Timeout Types

| Timeout Type | What It Guards | Typical Range |
|-------------|---------------|---------------|
| Connection timeout | Time to establish a TCP connection | 1-5 seconds |
| TLS handshake timeout | Time to complete TLS negotiation | 2-5 seconds |
| Read timeout (socket) | Time waiting for data after connection established | 3-10 seconds |
| Write timeout | Time to send request data | 3-10 seconds |
| Request timeout (overall) | Total time from request start to response complete | 5-30 seconds |
| Idle timeout | Time a connection can remain idle before being closed | 30s-10 minutes |
| Pool acquire timeout | Time to acquire a connection from a pool | 3-5 seconds |

### Configuration Guidelines

| Operation | Connection Timeout | Read Timeout | Overall Timeout |
|-----------|-------------------|-------------|-----------------|
| Database query | 3s | 5s | 10s |
| Database write | 3s | 5s | 10s |
| Internal API call | 2s | 5s | 10s |
| External API call | 5s | 10s | 15s |
| Cache lookup | 1s | 2s | 3s |
| Message publish | 2s | 5s | 8s |
| Health check | 1s | 2s | 3s |

**Rule:** Application-level timeouts MUST be shorter than client-level timeouts. A response that arrives after the client has given up is wasted work and wasted resources.

### Deadline Propagation

Deadline propagation passes the remaining time budget from service to service through a call chain, ensuring downstream services know how much time they have and can fail fast if the budget is already exhausted.

| Principle | Guideline |
|-----------|-----------|
| Carry deadline | Pass the absolute deadline (wall clock time) or remaining duration in request headers/metadata |
| Subtract overhead | Each service subtracts its own processing time before passing the deadline downstream |
| Fail fast | If remaining deadline is less than the expected operation time, fail immediately without calling downstream |
| Standard headers | Use gRPC deadlines natively; for HTTP, use a custom header (e.g., X-Request-Deadline) |
| Clock skew | Prefer duration-based (remaining seconds) over absolute timestamps to avoid clock sync issues |

### Timeout Hierarchy

Timeouts must be ordered from innermost to outermost:

```
    Connection timeout < Read timeout < Request timeout < Client timeout

    Example:
    Connection: 3s < Read: 5s < Request: 10s < Client: 30s
```

**Rule:** Inner timeouts MUST be shorter than outer timeouts. A read timeout of 30s inside a request timeout of 10s means the request timeout is ineffective.

### Timeout on Pooled Resources

| Pool Type | Acquire Timeout | Guideline |
|-----------|----------------|-----------|
| Database connection pool | 3-5s | Fail fast; do not queue indefinitely for a connection |
| HTTP connection pool | 2-3s | Create new connection or fail; do not wait |
| Thread pool (bulkhead) | 0-1s | Reject immediately if pool is full |

### What to Do When a Timeout Fires

| Action | Detail |
|--------|--------|
| Cancel the operation | Close the connection, cancel the query, abort the request |
| Release resources | Return connections to pools, release semaphore permits |
| Log with context | Operation name, timeout value, elapsed time, destination |
| Emit metric | Counter for timeout events per operation type |
| Apply fallback | Return default, cached value, or error based on the pattern in use |
| Count as failure | Timeouts count toward circuit breaker failure ratio |

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| No timeout configured | Thread hangs indefinitely waiting for response | Every external call MUST have a timeout |
| Timeout too large (> 60s) | Slow leak of threads/connections on failing dependencies | Align with SLA; usually 5-15s for synchronous calls |
| Inner timeout > outer timeout | Inner timeout never fires; outer fires first confusingly | Order: connection < read < request < client |
| Timeout without cancellation | Operation continues after timeout; wasted resources | Cancel downstream operations when timeout fires |
| Same timeout for all operations | Slow queries and fast cache lookups treated the same | Configure per-operation-type |
| Hardcoded timeouts | Cannot adjust without code changes | Externalize to configuration |

## Relationship to Other Patterns

- **Reference**: `core/09-resilience-principles.md` defines timeout as a core resilience mechanism with guidelines per operation type
- **Circuit Breaker**: Timeout events count as failures for the circuit breaker; without timeouts, the circuit breaker cannot detect slow failures
- **Retry with Backoff**: Each retry attempt has its own timeout; total retry time (attempts * timeout + backoff delays) must fit within the overall deadline
- **Bulkhead**: Timeout ensures that slow operations do not hold bulkhead permits indefinitely
- **Saga Pattern**: Each saga step has an individual timeout; the saga itself has an overall deadline
- **Dead Letter Queue**: Messages that timeout during processing should be negatively acknowledged and eventually routed to a DLQ
