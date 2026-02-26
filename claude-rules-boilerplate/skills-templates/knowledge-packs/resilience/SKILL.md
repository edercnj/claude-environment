---
name: resilience
description: "Resilience patterns: circuit breaker, rate limiting, bulkhead isolation, timeout control, retry with exponential backoff + jitter, fallback/graceful degradation, backpressure, and resilience metrics."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Resilience

## Purpose

Provides comprehensive resilience patterns for {{LANGUAGE}} {{FRAMEWORK}}, enabling services to gracefully handle failures, prevent cascading outages, and recover quickly. Includes circuit breaker state machines, rate limiting strategies, bulkhead partitioning, timeout coordination, intelligent retry logic, and degradation strategies.

## Quick Reference (always in context)

See `references/resilience-principles.md` for the essential resilience summary (6 core patterns: rate limiting, circuit breaker, bulkhead, timeout, retry, fallback).

## Detailed References

Read these files for detailed pattern implementations:

| Reference | Content |
|-----------|---------|
| `patterns/resilience/circuit-breaker.md` | State machine (CLOSED/OPEN/HALF_OPEN), configuration (failure threshold, wait duration, success threshold), monitoring metrics, fallback strategies, per-dependency circuits |
| `patterns/resilience/rate-limiting.md` | Token bucket, fixed window, sliding window algorithms; per-client, per-endpoint, global scopes; token bucket properties (capacity, refill rate, burst); response to limit (429 with Retry-After) |
| `patterns/resilience/bulkhead.md` | Thread pool isolation, semaphore isolation, partitioning strategies (by downstream service, operation type, tenant, protocol); sizing guidelines; rejection handling; metrics and monitoring |
| `patterns/resilience/timeout-patterns.md` | Timeout types (connection, read, write, overall); per-operation configurations; deadline propagation across services; timeout hierarchy (inner < outer); cancellation on timeout |
| `patterns/resilience/retry-with-backoff.md` | Exponential backoff, linear backoff; mandatory jitter (full, equal, decorrelated); retryable vs non-retryable error classification; retry budgets; interaction with deadlines |
| `patterns/resilience/fallback-degradation.md` | Graceful degradation levels (NORMAL, WARNING, CRITICAL, EMERGENCY); fallback strategies (cached data, default, error); fail-secure principle; degradation triggers and transitions |
| `patterns/resilience/backpressure.md` | Flow control mechanisms, pause/resume protocols, connection-level backpressure, message queue depth limits, timeout-based resumption |
| `patterns/resilience/resilience-metrics.md` | Metric types per pattern, naming conventions, alert thresholds, dashboards, SLA tracking |
