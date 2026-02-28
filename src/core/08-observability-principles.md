# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 08 — Observability Principles

## Principles
- **3 Pillars:** Traces, Metrics, Logs — all interconnected
- **Vendor-agnostic:** Use open standards (OpenTelemetry preferred)
- **Sensitive data:** NEVER in spans, metrics, or logs
- **Correlation:** Every log line must be traceable to a span

## Distributed Tracing

### Span Tree Pattern

Each operation MUST create a structured span tree:

```
[service-name] operation.process (ROOT)
├── [service-name] message.parse
├── [service-name] message.validate
│   ├── [service-name] rule.decision-a
│   └── [service-name] rule.decision-b
├── [service-name] data.persist
│   └── [database] INSERT/SELECT/UPDATE
├── [service-name] message.build-response
└── [service-name] message.send
```

### Mandatory Span Attributes

| Attribute | Type | When |
|----------|------|------|
| `operation.type` | string | Always |
| `operation.id` | string | Always (correlation ID) |
| `operation.status` | string | In root span |
| `error.type` | string | Only on error |

> **Customize:** Add domain-specific attributes (e.g., `merchant.id`, `transaction.type`, `user.id`).

### PROHIBITED Attributes

NEVER include in spans:
- Passwords, tokens, secrets
- Full PII (use masked versions)
- Encryption keys
- Request/response bodies with sensitive data

## Metrics

### Naming Convention

- Prefix: `{service_name}.`
- Separator: `.` (dot)
- snake_case for composite names
- Units: `seconds`, `bytes`, `1` (count)

### Recommended Metric Types

| Metric Pattern | Type | Use Case |
|---------------|------|----------|
| `{service}.operations` | Counter | Total operations processed |
| `{service}.operation.duration` | Histogram | Processing duration |
| `{service}.connections.active` | UpDownCounter | Active connections |
| `{service}.errors` | Counter | Error count by type |
| `{service}.db.query.duration` | Histogram | Database query duration |

### Mandatory Tags/Labels

| Tag | Values | Purpose |
|-----|--------|---------|
| `operation_type` | Domain-specific | Group by operation |
| `status` | success, error | Success vs failure |
| `protocol` | tcp, http, grpc | Connection type |

## Structured Logging

### Format
- **Production:** JSON format
- **Development:** Human-readable text

### Mandatory Fields

```json
{
  "timestamp": "2026-02-16T14:30:00.123Z",
  "level": "INFO",
  "logger": "com.example.service.Handler",
  "message": "Operation completed",
  "trace_id": "abc123def456",
  "span_id": "789ghi012",
  "context": {
    "operation_id": "1001",
    "operation_type": "debit",
    "client_id": "123456"
  }
}
```

### Log Levels

| Level | Use |
|-------|-----|
| DEBUG | Parsing details, internal state, field values |
| INFO | Operation completed, resource created, connection established |
| WARN | Simulated delay, optional data missing, retry attempt |
| ERROR | Exception, parsing failure, database error, timeout |

### Masking

Sensitive data MUST be masked before logging:

```
// GOOD
log.info("Processing client {}", maskIdentifier(clientId))

// BAD
log.info("Processing client {}", clientId)
```

## Health Checks

Three types of health checks:

| Type | Endpoint | Purpose |
|------|----------|---------|
| **Liveness** | `/health/live` | Application is running (not deadlocked) |
| **Readiness** | `/health/ready` | Application can serve traffic (dependencies OK) |
| **Startup** | `/health/started` | Application finished initialization |

### Readiness Check Components
- Database connection
- External service connectivity
- Protocol listeners (TCP, gRPC, etc.)
- Degradation level (if resilience is implemented)

## Configuration

```
# Tracing
otel.traces.enabled=true
otel.traces.sampler=parentbased_always_on

# Metrics
otel.metrics.enabled=true

# Logs
otel.logs.enabled=true

# Exporter
otel.exporter.endpoint=http://collector:4317
otel.exporter.protocol=grpc

# Service identity
otel.service.name={SERVICE_NAME}
otel.resource.attributes=service.version={VERSION},deployment.environment={ENV}
```

> Disable tracing/metrics in dev/test to avoid overhead. Enable in staging/production.

## Anti-Patterns (FORBIDDEN)

- Sensitive data in spans, metrics, or logs
- Logs without trace_id correlation
- Metrics without meaningful tags/labels
- Health checks that don't verify real dependencies
- Tracing enabled in unit tests (slows down CI)
- Vendor-specific instrumentation APIs (use OpenTelemetry)
- Logs in non-structured format in production
- Missing error attribution (log errors without span context)
