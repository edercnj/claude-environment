---
name: architecture-patterns
description: "Architecture pattern references for {{ARCH_STYLE}} systems: microservice patterns (saga, outbox, bulkhead, idempotency, service discovery, strangler fig, API gateway), resilience patterns (circuit breaker, retry, timeout, dead letter queue), data patterns (cache-aside, event store, repository, unit of work), integration patterns (ACL, BFF, adapter), and architectural patterns (event sourcing, CQRS, modular monolith). Internal reference for agents and planning."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Architecture Patterns

## Purpose

Provides detailed reference documentation for architecture patterns selected based on `architecture.style={{ARCH_STYLE}}`, `event_driven={{EVENT_DRIVEN}}`, and `domain_driven={{DOMAIN_DRIVEN}}`. These patterns complement the core hexagonal architecture rule (`skills/architecture/references/architecture-patterns.md`) with in-depth implementation guidance.

## Condition

This knowledge pack is relevant when implementing or reviewing:
- Microservice integration patterns (saga, outbox, idempotency)
- Resilience patterns (circuit breaker, retry, timeout, DLQ)
- Data access patterns (cache-aside, event store, repository, unit of work)
- Integration patterns (anti-corruption layer, BFF, adapter)
- Architectural patterns (event sourcing, CQRS)

## How to Use

Read the relevant pattern files from the `references/` directory within this skill's folder. Each file covers one pattern with: intent, when to use, when NOT to use, structure, implementation guidelines, and relationship to other patterns.

### Architectural Patterns

- `references/cqrs.md` — Command/query separation, sync strategies, consistency boundaries
- `references/event-sourcing.md` — Append-only event log, snapshots, projections, event versioning
- `references/modular-monolith.md` — Module boundaries, inter-module communication, decomposition

### Microservice Patterns

- `references/api-gateway.md` — Edge routing, aggregation, auth at the edge
- `references/bulkhead.md` — Resource isolation, semaphore vs thread pool, partitioning
- `references/idempotency.md` — Deduplication strategies, exactly-once semantics
- `references/outbox-pattern.md` — Transactional event publishing, relay strategies
- `references/saga-pattern.md` — Orchestration vs choreography, compensation, timeouts
- `references/service-discovery.md` — Registration, health checks, DNS vs registry
- `references/strangler-fig.md` — Incremental migration, routing strategies, parallel running

### Resilience Patterns

- `references/circuit-breaker.md` — States, configuration, fallback strategies, per-dependency circuits
- `references/dead-letter-queue.md` — Poison pill detection, replay, monitoring
- `references/retry-with-backoff.md` — Backoff strategies, jitter, retry budgets
- `references/timeout-patterns.md` — Timeout types, deadline propagation, hierarchy

### Data Patterns

- `references/cache-aside.md` — Cache population, invalidation, TTL, thundering herd prevention
- `references/event-store.md` — Event record structure, snapshots, projections, versioning
- `references/repository-pattern.md` — Interface design, pagination, specification pattern
- `references/unit-of-work.md` — Transaction boundaries, commit/rollback, concurrency control

### Integration Patterns

- `references/anti-corruption-layer.md` — Translation boundary, error handling, testing
- `references/backend-for-frontend.md` — Per-client optimization, aggregation, versioning
- `references/adapter-pattern.md` — Protocol bridging, resilience wrapping, auth handling

## Cross-Reference

- Core architecture rule: `skills/architecture/references/architecture-patterns.md` (hexagonal architecture — always loaded)
- Core resilience rule: `skills/resilience/references/resilience-principles.md`
- Core API rule: `skills/api-design/references/api-design-principles.md`
- Core database rule: `skills/database-patterns/references/database-principles.md`
