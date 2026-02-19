# Bulkhead Pattern

## Intent

The Bulkhead pattern isolates system resources into independent compartments so that a failure or resource exhaustion in one compartment does not cascade to others. Named after the watertight compartments in ship hulls, this pattern ensures that a slow or failing dependency, tenant, or operation type consumes only its allocated resources, preserving the health of the rest of the system.

## When to Use

- `architecture.style=microservice` where services call multiple downstream dependencies
- Multi-tenant systems where one tenant's load must not impact others
- Services that handle multiple operation types with different latency profiles
- Systems where a single slow dependency has historically caused cascading failures
- Reference: `core/09-resilience-principles.md` for the resilience context

## When NOT to Use

- Single-purpose services with only one downstream dependency and one operation type
- Systems where all operations share identical latency and resource profiles
- When resource isolation overhead exceeds the benefit (very low-traffic systems)
- Applications where a single failure should halt all processing by design (fail-stop semantics)

## Structure

```
    Incoming Requests
    ┌────────────────────────────────────────────────┐
    │                                                │
    │   ┌──────────────┐  ┌──────────────┐          │
    │   │  Bulkhead A   │  │  Bulkhead B   │         │
    │   │  (Service X)  │  │  (Service Y)  │         │
    │   │               │  │               │         │
    │   │  Capacity: 10 │  │  Capacity: 20 │         │
    │   │  Active: 7    │  │  Active: 3    │         │
    │   │  Waiting: 2   │  │  Waiting: 0   │         │
    │   └───────┬───────┘  └───────┬───────┘         │
    │           │                  │                  │
    │           ▼                  ▼                  │
    │      Service X          Service Y              │
    │      (slow)             (healthy)              │
    │                                                │
    │   Service X slowness does NOT affect           │
    │   Service Y requests                           │
    └────────────────────────────────────────────────┘
```

## Implementation Guidelines

### Isolation Strategies

| Strategy | Mechanism | Overhead | Isolation Level | Best For |
|----------|-----------|----------|----------------|----------|
| Thread pool | Dedicated thread pool per resource | High (thread creation) | Strong | Long-running operations, blocking I/O |
| Semaphore | Counter limiting concurrent access | Low | Medium | Fast operations, non-blocking I/O |
| Connection pool | Separate pool per dependency | Medium | Strong | Database and HTTP connections |
| Process-level | Separate process or container | Very high | Very strong | Complete fault isolation |

### Thread Pool Isolation

| Parameter | Guideline |
|-----------|-----------|
| Pool size | Based on expected concurrency and downstream latency (requests/sec * avg_latency_sec) |
| Queue size | Small or zero; prefer rejection over unbounded queueing |
| Rejection policy | Return error immediately; never block the calling thread |
| Thread naming | Include bulkhead identity for debugging (e.g., bulkhead-serviceX-1) |
| Timeout | Each thread pool operation MUST have a timeout; never wait indefinitely |

### Semaphore Isolation

| Parameter | Guideline |
|-----------|-----------|
| Permits | Maximum concurrent executions allowed |
| Acquire timeout | Short (milliseconds); fail fast if permits unavailable |
| Fairness | Use fair ordering only if strict request ordering matters (adds overhead) |
| Release guarantee | ALWAYS release in a finally block; leaked permits cause resource starvation |

### Partitioning Strategies

| Partition By | Example | Rationale |
|-------------|---------|-----------|
| Downstream service | Bulkhead per external API | Slow API X does not exhaust resources for API Y |
| Operation type | Read vs Write bulkheads | Writes are slower; reads should not wait |
| Tenant | Bulkhead per tenant tier | Premium tenants isolated from noisy neighbors |
| Priority | Critical vs background tasks | Background processing does not starve critical path |
| Protocol | REST vs TCP vs gRPC | Traffic spikes in one protocol do not affect others |

### Sizing Guidelines

| Factor | Consideration |
|--------|--------------|
| Expected throughput | Requests per second for the protected operation |
| Downstream latency | Average and P99 latency of the dependency |
| Acceptable queue time | How long a request can wait before timing out |
| System capacity | Total threads or connections available to the service |
| Formula (thread pool) | pool_size = target_rps * p99_latency_seconds * safety_factor |

### Rejection Handling

When a bulkhead is full, requests MUST be rejected immediately with clear feedback:

| Channel | Rejection Response |
|---------|-------------------|
| REST API | HTTP 503 Service Unavailable with Retry-After header |
| gRPC | RESOURCE_EXHAUSTED status code |
| Async messaging | Negative acknowledgment; message returns to queue |
| Internal call | Throw specific BulkheadFullException |

### Monitoring Requirements

| Metric | Type | Alert Condition |
|--------|------|----------------|
| Active executions | Gauge (per bulkhead) | Sustained at or near capacity |
| Queue depth | Gauge (per bulkhead) | Growing over time |
| Rejected requests | Counter (per bulkhead) | Any rejections (investigate) |
| Wait time | Histogram (per bulkhead) | P99 approaching timeout |
| Execution time | Histogram (per bulkhead) | Drift from baseline |

## Relationship to Other Patterns

- **Reference**: `core/09-resilience-principles.md` defines bulkhead as a core resilience primitive with partitioning strategy
- **Circuit Breaker**: Bulkheads limit concurrent access; circuit breakers detect failure rates. Use both: bulkhead prevents resource exhaustion while circuit breaker detects downstream failure
- **Timeout Patterns**: Every bulkhead-protected operation MUST have a timeout; without it, slow requests occupy permits indefinitely
- **Retry with Backoff**: Retries against a bulkhead-protected resource must respect the bulkhead capacity; excessive retries can fill the bulkhead
- **API Gateway**: The gateway can enforce bulkhead isolation per route or per backend service, protecting the gateway's own resources
