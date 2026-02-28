# Saga Pattern

## Intent

The Saga pattern manages distributed transactions across multiple services where traditional ACID transactions are impossible. It decomposes a long-running business process into a sequence of local transactions, each within a single service, coordinated through events or a central orchestrator. When a step fails, previously completed steps are compensated (undone) through compensating transactions, maintaining eventual consistency across the system.

## When to Use

- `architecture.style=microservice` with `event_driven=true`
- Business processes that span multiple services and require all-or-nothing semantics
- Operations where distributed two-phase commit (2PC) is impractical or too slow
- Workflows with well-defined compensation logic for each step
- Long-running business processes (minutes to days) that cannot hold locks

## When NOT to Use

- Operations that fit within a single service's transactional boundary
- When strong consistency is required and a single database can serve the need
- Simple request-response interactions with no multi-step coordination
- When the team lacks experience with eventual consistency patterns
- Processes where compensation is impossible or undefined (e.g., sending a physical shipment)

## Structure

### Orchestration Approach

```
                         ┌──────────────┐
                         │    Saga       │
                         │ Orchestrator  │
                         └──────┬───────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                  │
              ▼                 ▼                  ▼
        ┌──────────┐    ┌──────────┐       ┌──────────┐
        │ Service A │    │ Service B │       │ Service C │
        │ Step 1    │    │ Step 2    │       │ Step 3    │
        │ Comp. 1   │    │ Comp. 2   │       │ Comp. 3   │
        └──────────┘    └──────────┘       └──────────┘
```

### Choreography Approach

```
   Service A          Service B          Service C
   ┌────────┐         ┌────────┐         ┌────────┐
   │ Step 1  │──Event──►│ Step 2  │──Event──►│ Step 3  │
   │         │         │         │         │         │
   │ Comp. 1 │◄─Event──┤ Comp. 2 │◄─Event──┤ Comp. 3 │
   └────────┘         └────────┘         └────────┘
```

### Comparison

| Aspect | Orchestration | Choreography |
|--------|--------------|--------------|
| Control flow | Centralized in orchestrator | Distributed across services |
| Visibility | Single place to see full workflow | Requires tracing across services |
| Coupling | Services coupled to orchestrator | Services coupled to event contracts |
| Complexity | Orchestrator can become complex | Hard to reason about with many steps |
| Scalability | Orchestrator can be bottleneck | Naturally distributed |
| Best for | Complex workflows (5+ steps) | Simple workflows (2-4 steps) |

## Implementation Guidelines

### Saga Design Principles

| Principle | Guideline |
|-----------|-----------|
| Atomicity per step | Each step is a local transaction within one service |
| Compensation | Every step (except the last) MUST have a defined compensating action |
| Idempotency | Every step and every compensation MUST be idempotent |
| Ordering | Compensation executes in reverse order of the original steps |
| State tracking | The saga's current state (which steps completed) MUST be persisted |

### Compensation Design

- Compensating actions undo the semantic effect, not necessarily the technical operation
- Compensation MUST be idempotent: running it multiple times produces the same result
- Compensation MAY fail; design for retry of compensating actions
- Some compensations are logical: instead of deleting a record, mark it as "cancelled"
- Track compensation status separately from forward step status

### Failure Handling

| Failure Type | Response |
|-------------|----------|
| Step fails (business error) | Begin compensation from the last successful step |
| Step fails (transient error) | Retry with backoff; compensate only after max retries exhausted |
| Compensation fails | Retry compensation with backoff; alert on repeated failure |
| Orchestrator crashes | Recover saga state from persistent store; resume from last known state |
| Timeout | Treat as failure after deadline; begin compensation |

### Timeout Management

| Aspect | Guideline |
|--------|-----------|
| Step timeout | Each step has an individual timeout proportional to its expected duration |
| Saga timeout | Overall saga has a maximum duration; exceeded = compensation |
| Timeout detection | Orchestrator polls or uses scheduled timers |
| Timeout action | Log, alert, and initiate compensation |
| Deadline propagation | Pass remaining saga deadline to each step so steps can fail fast |

### State Machine

```
  STARTED ──► STEP_1_PENDING ──► STEP_1_COMPLETE ──► STEP_2_PENDING ──► ...
                    │                                       │
                    ▼                                       ▼
              STEP_1_FAILED                           STEP_2_FAILED
                    │                                       │
                    ▼                                       ▼
              COMPENSATING ◄────────────────────────── COMPENSATING
                    │
                    ▼
              COMPENSATED (or COMPENSATION_FAILED)
```

### Observability Requirements

- Every saga instance MUST have a unique correlation ID propagated to all steps
- Log saga state transitions with step name, status, duration, and correlation ID
- Emit metrics: saga success/failure rate, average duration, compensation frequency
- Alert on sagas stuck in COMPENSATING for longer than expected

## Relationship to Other Patterns

- **Outbox Pattern**: Ensures reliable event publishing between saga steps; without it, events can be lost between committing a local transaction and publishing
- **Idempotency**: Every saga step and compensation MUST be idempotent to handle retries safely
- **Circuit Breaker**: Wrap external service calls within saga steps with circuit breakers to fail fast
- **Event Sourcing**: Saga state can be event-sourced, providing a complete history of the saga's progression
- **Dead Letter Queue**: Failed saga events that cannot be processed go to a DLQ for manual investigation
