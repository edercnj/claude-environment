---
name: instrument-otel
description: "Skill: OpenTelemetry Instrumentation — Adds or reviews distributed tracing, metrics, and structured logging using OpenTelemetry SDK with OTLP export."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[component-name or 'full']"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: OpenTelemetry Instrumentation

## Description

Adds or reviews OpenTelemetry instrumentation across the application. Covers the three observability pillars: distributed traces (spans), metrics (counters, histograms, gauges), and structured logs with trace correlation. Uses OTLP exporter for vendor-agnostic collection.

**Condition**: This skill applies when observability is not "none".

## Prerequisites

- OpenTelemetry SDK dependency added to {{BUILD_FILE}}
- OTLP exporter configured (default: `http://otel-collector:4317`)
- {{FRAMEWORK}} OpenTelemetry integration enabled

## Execution Flow

1. **Verify OTel dependencies** — Check {{BUILD_FILE}} for:
   - OpenTelemetry SDK or framework-specific OTel extension
   - OTLP exporter (gRPC or HTTP)
   - Confirm dependency versions are compatible

2. **Check configuration** — Verify OTel properties:
   - `otel.service.name` set to project name
   - `otel.exporter.otlp.endpoint` externalized (env var)
   - Traces, metrics, and logs enabled
   - Sampling strategy configured (e.g., `parentbased_always_on`)
   - OTel disabled in dev/test profiles, enabled in staging/prod

3. **Instrument traces** — For the target component:
   - Create root span for each inbound request/message
   - Add child spans for: parsing, validation, business logic, persistence, response
   - Set mandatory span attributes: operation type, identifier, status
   - Set span status (OK or ERROR) and record exceptions
   - Ensure sensitive data (passwords, tokens, PII) is NEVER in span attributes

4. **Instrument metrics** — Add application-specific metrics:
   - **Counter**: requests processed, errors, specific event counts
   - **Histogram**: request duration, query duration
   - **UpDownCounter**: active connections, active sessions, pool usage
   - Use consistent naming: `{{PROJECT_PREFIX}}.metric.name`
   - Add relevant tags/attributes for filtering

5. **Instrument logging** — Set up structured logging:
   - JSON format in production, text in dev
   - Automatic trace_id/span_id correlation in log entries
   - MDC/context fields for domain identifiers
   - Appropriate log levels (DEBUG, INFO, WARN, ERROR)
   - Sensitive data masking before logging

6. **Add health checks** — Implement probes:
   - Liveness: application process is alive
   - Readiness: dependencies (DB, external services) are reachable
   - Startup: application initialization complete

7. **Validate** — Run {{BUILD_COMMAND}} and verify:
   - No compilation errors from instrumentation code
   - OTel configuration loads without warnings
   - Health endpoints respond correctly

## Usage Examples

```
/instrument-otel full
/instrument-otel transaction-service
/instrument-otel persistence-layer
```

## Metric Naming Convention

- Prefix: `{{PROJECT_PREFIX}}.`
- Separator: `.` (dot)
- Style: snake_case for composite names
- Units: `seconds`, `bytes`, `1` (dimensionless count)

## Review Checklist

- [ ] OTel SDK dependency present in {{BUILD_FILE}}
- [ ] OTLP endpoint externalized via environment variable
- [ ] OTel disabled in dev/test, enabled in staging/prod
- [ ] Root span created for each inbound operation
- [ ] Child spans for sub-operations (parse, validate, persist, respond)
- [ ] Mandatory attributes set on spans (operation, identifier, status)
- [ ] ZERO sensitive data in spans, metrics, or logs
- [ ] Counter, histogram, and gauge metrics defined
- [ ] Structured JSON logging in production
- [ ] Trace ID and span ID correlated in log entries
- [ ] Health checks implemented (liveness, readiness, startup)
- [ ] Sampling strategy configured appropriately
