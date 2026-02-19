# Unit of Work

## Intent

The Unit of Work pattern maintains a list of objects affected by a business transaction and coordinates the writing of changes to the database in a single atomic operation. It tracks which objects have been created, modified, or deleted during a business operation and ensures all changes are committed together or rolled back together, preventing partial updates that would leave the system in an inconsistent state.

## When to Use

- Business operations that modify multiple entities or aggregates within the same bounded context
- When multiple repository operations must succeed or fail as a single atomic unit
- Applications using ORMs where transaction management should be explicit and controlled
- Use cases that span multiple domain operations but require a single commit point
- When the application layer needs to orchestrate multiple repository calls within one transaction

## When NOT to Use

- Single-entity operations where the repository's save method is sufficient
- Event-sourced systems where each event is appended independently (event store handles consistency)
- Microservice architectures where transactions span multiple services (use Sagas instead)
- Read-only operations that do not modify state
- When the ORM's built-in session/context already provides adequate unit of work behavior and explicit control is unnecessary

## Structure

```
    ┌─────────────────────────────────────────────────────┐
    │                    Use Case                          │
    │                                                      │
    │   1. Begin Unit of Work                              │
    │   2. Repository A: create entity                     │
    │   3. Repository B: update entity                     │
    │   4. Repository C: delete entity                     │
    │   5. Commit Unit of Work                             │
    │                                                      │
    └──────────────────────┬──────────────────────────────┘
                           │
                           ▼
    ┌─────────────────────────────────────────────────────┐
    │                 Unit of Work                          │
    │                                                      │
    │   ┌──────────────┐                                   │
    │   │ Change Track  │                                  │
    │   │               │                                  │
    │   │ New:    [A1]  │                                  │
    │   │ Dirty:  [B3]  │                                  │
    │   │ Deleted:[C7]  │                                  │
    │   └──────────────┘                                   │
    │                                                      │
    │   commit() ──► BEGIN                                 │
    │                INSERT A1                              │
    │                UPDATE B3                              │
    │                DELETE C7                              │
    │                COMMIT                                 │
    │                                                      │
    │   rollback() ──► ROLLBACK (discard all changes)      │
    └─────────────────────────────────────────────────────┘
```

## Implementation Guidelines

### Core Responsibilities

| Responsibility | Description |
|---------------|-------------|
| Change tracking | Track which entities are new, modified, or deleted |
| Transaction boundary | Define the start and end of the database transaction |
| Commit coordination | Persist all tracked changes in a single transaction |
| Rollback | Discard all tracked changes if any operation fails |
| Identity map | Ensure each entity is loaded only once per unit of work (prevent duplicate instances) |

### Transaction Boundary Placement

| Layer | Appropriate? | Rationale |
|-------|:------------:|-----------|
| Domain layer | No | Domain must not know about transactions |
| Application layer (Use Case) | Yes | Use cases define the business operation boundary |
| Adapter layer (Repository) | No | Too fine-grained; each repo call would be its own transaction |
| Controller/Handler | Sometimes | Acceptable for simple operations; prefer application layer |

**Rule:** The application layer (use case) is the correct place to begin and commit a unit of work. This aligns with the principle that use cases define the scope of a business operation.

### Commit and Rollback Rules

| Rule | Detail |
|------|--------|
| Explicit commit | The unit of work MUST be explicitly committed; no auto-commit on scope exit |
| Automatic rollback on failure | If an exception occurs before commit, the unit of work MUST roll back |
| Resource cleanup | Connections, cursors, and locks MUST be released in a finally block or equivalent |
| Single commit | Each unit of work commits exactly once; multiple commits within the same unit are forbidden |
| No business logic after commit | Once committed, no further domain operations should depend on the transaction |

### Nested Transaction Guidelines

| Approach | Behavior | Use When |
|----------|----------|----------|
| Flat (no nesting) | Inner "transactions" join the outer transaction | Default; simplest model |
| Savepoints | Inner scope creates a savepoint; can roll back to savepoint without aborting outer | Inner operations are independently retriable |
| Independent | Inner scope has its own transaction (separate connection) | Audit logging that must persist even if outer fails |

**Guideline:** Prefer flat transactions. Use savepoints sparingly for specific retry scenarios. Independent nested transactions are rare and should be justified explicitly.

### Ordering of Operations

| Phase | Actions | Rationale |
|-------|---------|-----------|
| 1. Inserts | Persist new entities first | Satisfy foreign key dependencies |
| 2. Updates | Apply modifications | Entities may reference newly inserted rows |
| 3. Deletes | Remove marked entities last | Avoid foreign key violations from premature deletion |

### Concurrency Control

| Strategy | Mechanism | Trade-off |
|----------|-----------|-----------|
| Optimistic locking | Version column checked at commit time; conflict = retry | Higher throughput; occasional retry on conflict |
| Pessimistic locking | SELECT FOR UPDATE at read time | Lower throughput; guaranteed no conflict |

**Guideline:** Prefer optimistic locking for most web applications. Use pessimistic locking only for high-contention scenarios where retry cost is prohibitive.

### Anti-Patterns

| Anti-Pattern | Problem | Solution |
|-------------|---------|----------|
| Transaction per repository call | Each save is its own transaction; no atomicity across operations | One unit of work per use case |
| Long-running transactions | Holds database locks for extended periods | Keep transactions short; do expensive computation outside the transaction |
| Unit of work crossing service boundaries | Distributed transaction disguised as a unit of work | Use Saga pattern for cross-service coordination |
| Business logic inside commit hooks | Hard to test; hidden side effects | Keep business logic in domain layer |
| Forgetting to commit | Changes are silently lost | Enforce commit in the application layer; framework support helps |
| Committing in a loop | Multiple transactions where one is needed | Collect all changes; commit once |

## Relationship to Other Patterns

- **Repository Pattern**: Repositories perform operations within the unit of work's transaction context; they do not manage their own transactions
- **Hexagonal Architecture**: The unit of work is typically managed in the application layer (use case), orchestrating domain operations and persistence
- **CQRS**: The unit of work applies to the command side; the query side has no write transactions
- **Saga Pattern**: When business operations span multiple services, the saga replaces the unit of work as the consistency mechanism
- **Event Sourcing**: In event-sourced systems, appending events to the event store replaces the traditional unit of work; the event store provides its own consistency guarantees
