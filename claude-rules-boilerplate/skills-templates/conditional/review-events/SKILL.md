---
name: review-events
description: "Skill: Event-Driven Review — Validates event schemas, producer/consumer patterns, error handling, dead letter topics, and operational readiness."
allowed-tools: Read, Grep, Glob, Bash
argument-hint: "[event-name or consumer/producer class]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Event-Driven Review

## Description

Reviews event-driven patterns: event schema design, producer/consumer implementation, error handling, dead letter topics, and operational readiness. Covers CloudEvents envelope, schema registry integration, and saga patterns.

**Condition**: This skill applies when the project uses event-driven interfaces (`interfaces` contains `type: event-consumer` or `type: event-producer`).

## Prerequisites

- Event definitions exist (event classes, Avro/Protobuf schemas, or JSON Schema)
- Message broker dependency configured (Kafka, RabbitMQ, SQS, etc.)
- Producer and/or consumer implementations exist

## Execution Flow

1. **Discover event definitions** — Scan for event classes, schemas, Avro/Protobuf definitions:
   - List all event types with their schemas
   - Identify event envelope structure

2. **Discover producers** — Scan for classes publishing events:
   - Map producers to topics and event types
   - Identify publishing patterns (outbox, direct)

3. **Discover consumers** — Scan for classes consuming events:
   - Map consumers to topics and consumer groups
   - Identify idempotency mechanisms

4. **Validate event design** — Check naming, envelope, versioning:
   - Past tense event names
   - CloudEvents spec compliance
   - Schema registry integration
   - Data minimization

5. **Validate producer patterns** — Check reliability:
   - Outbox or at-least-once delivery
   - Acknowledgment levels
   - Error handling and retry

6. **Validate consumer patterns** — Check processing:
   - Idempotency implementation
   - Offset commit strategy
   - Dead letter topic configuration
   - Graceful shutdown

7. **Validate operational readiness** — Check monitoring:
   - Consumer lag monitoring
   - Dead letter topic alerts
   - Schema registry health

8. **Generate report** — Summarize findings as checklist:
   - List compliant items
   - List violations with file paths and line numbers
   - Suggest fixes for each violation

## Usage Examples

```
/review-events OrderCreated
/review-events PaymentConsumer
/review-events
```

## Event Design Checklist (10 points)

### Schema & Naming (1-4)
1. Event names use past tense (`OrderCreated`, `PaymentProcessed`, `InventoryReserved`)
2. Event envelope follows CloudEvents spec or project-standard envelope (type, source, id, time, data)
3. Schema registered in schema registry (Avro, Protobuf, or JSON Schema)
4. Event versioning strategy defined: additive-only changes in same version, new event type for breaking changes

### Data Design (5-7)
5. Events contain only necessary data (data minimization, no full entity dump)
6. Correlation ID present for distributed tracing
7. No sensitive data in event payload (or encrypted if absolutely required)

### Topic/Queue Design (8-10)
8. Topic naming follows convention: `{domain}.{entity}.{event}` (e.g., `payment.transaction.created`)
9. Partition key chosen for ordering guarantees (e.g., entity ID for per-entity ordering)
10. Message retention and compaction policy documented

## Producer Checklist (8 points)

11. Transactional outbox pattern used for reliable publishing (database + event in same transaction)
12. OR: at-least-once delivery with consumer idempotency (if outbox not used, document why)
13. Producer acknowledgment level appropriate (all replicas for critical events)
14. Serialization uses registered schema (not ad-hoc JSON serialization)
15. Error handling: failed publishes logged, retried with backoff, dead-lettered after max retries
16. Idempotency key on producer if exactly-once semantics required
17. Event published AFTER successful business operation (not before)
18. Trace context propagated in event headers (W3C Trace Context)

## Consumer Checklist (10 points)

19. Consumer is idempotent (processing same event twice produces same result)
20. Idempotency key stored and checked (event ID + consumer group, or business key)
21. Consumer group ID follows convention: `{service}.{purpose}` (e.g., `billing.invoice-generator`)
22. Offset commit strategy: commit after successful processing (not auto-commit)
23. Error handling: failed processing → retry with backoff → dead letter topic after N retries
24. Dead letter topic monitored with alerts
25. Consumer lag monitored (alert if lag exceeds threshold)
26. Deserialization errors handled gracefully (poison pill protection)
27. Processing timeout configured (prevent infinite blocking)
28. Graceful shutdown: stop consuming, finish in-flight, commit offsets, then exit

## Saga Pattern Checklist (conditional — if multi-step workflows)

29. Saga orchestrator or choreography pattern documented
30. Compensation actions defined for each saga step
31. Saga state persisted (recoverable after crash)
32. Timeout on saga completion (trigger compensation if exceeded)

## Review Checklist

- [ ] Event names use past tense
- [ ] CloudEvents envelope or project standard
- [ ] Schema registered in registry
- [ ] Consumer is idempotent
- [ ] Dead letter topic configured and monitored
- [ ] No sensitive data in event payload
- [ ] Event published after business operation
- [ ] Trace context propagated in headers
- [ ] Consumer lag monitored
- [ ] Graceful shutdown implemented

## Output Format

```
## Event-Driven Review — [Event/Change Description]

### Event Design: HIGH / MEDIUM / LOW
### Producer Quality: HIGH / MEDIUM / LOW
### Consumer Quality: HIGH / MEDIUM / LOW

### Event Design Findings
1. [Finding with file, line, issue, fix]

### Producer Findings
1. [Finding with file, line, issue, fix]

### Consumer Findings
1. [Finding with file, line, issue, fix]

### Operational Readiness
- Dead Letter Topic: [configured / missing]
- Consumer Lag Monitoring: [configured / missing]
- Schema Registry: [configured / missing]

### Checklist Results
[Items that passed / failed / not applicable]

### Verdict: APPROVE / REQUEST CHANGES
```

## Rules
- REQUEST CHANGES if consumer is not idempotent
- REQUEST CHANGES if no dead letter topic configured
- REQUEST CHANGES if sensitive data in event payload
- REQUEST CHANGES if no schema validation/registry
- REQUEST CHANGES if event published before business operation completes
- Flag missing outbox pattern (suggest it, don't block if documented alternative exists)
