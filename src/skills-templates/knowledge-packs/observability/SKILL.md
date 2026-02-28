---
name: observability
description: "Observability principles: distributed tracing (span trees, mandatory attributes), metrics naming conventions, structured logging with mandatory fields, health checks (liveness/readiness/startup), correlation IDs, and OpenTelemetry integration."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Observability

## Purpose

Provides comprehensive observability patterns for {{LANGUAGE}} {{FRAMEWORK}}, enabling complete visibility into system behavior through distributed tracing, metrics collection, and structured logging. Includes span tree design, mandatory metric naming conventions, logging standards, health check implementation, and OpenTelemetry integration.

## Quick Reference (always in context)

See `references/observability-principles.md` for the essential observability summary (3 pillars: traces, metrics, logs; span tree pattern; mandatory attributes; health checks).

## Detailed References

Read these files for implementation patterns:

| Reference | Content |
|-----------|---------|
| `patterns/observability/distributed-tracing.md` | Span tree design, root span identification, child span creation, span lifecycle, context propagation, W3C Trace Context headers, baggage propagation |
| `patterns/observability/metrics-collection.md` | Metric types (counter, gauge, histogram, summary), naming convention (service.operation.metric), mandatory labels/tags, cardinality management, metric aggregation, dashboard patterns |
| `patterns/observability/structured-logging.md` | JSON log format, mandatory fields (timestamp, level, logger, message, trace_id, span_id), context objects, log levels (DEBUG/INFO/WARN/ERROR), masking sensitive data, structured field extraction |
| `patterns/observability/health-checks.md` | Liveness probe (process alive), readiness probe (can serve traffic), startup probe (initialization complete), probe implementation, dependency checks, degradation levels, Kubernetes integration |
| `patterns/observability/correlation-ids.md` | Correlation ID generation, propagation across services, header naming (X-Request-ID, X-Correlation-ID), storage in logs/traces, client-side persistence |
| `patterns/observability/opentelemetry-setup.md` | OTel agent/SDK initialization, instrumentation libraries, exporter configuration (OTLP, Jaeger, Prometheus), environment variables, sampling strategies, span processors |
