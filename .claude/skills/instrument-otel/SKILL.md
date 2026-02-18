---
name: instrument-otel
description: "Skill: Observability (OpenTelemetry) — Guide for OpenTelemetry instrumentation in the simulator, covering traces, metrics, logs, and compliance with Rule 18. Resilience metrics (circuit breaker, rate limiting, degradation) per Rule 24."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[STORY-NNN]"
context: fork
agent: general-purpose
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Observability (OpenTelemetry)

## Description

Guide for OpenTelemetry instrumentation in the authorizer simulator.

## Quarkus Extension

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-opentelemetry</artifactId>
</dependency>
```

## Traces — How to Instrument

### Automatic (Quarkus auto-instruments)

- HTTP requests (JAX-RS)
- JDBC queries
- CDI bean methods (with `@WithSpan`)

### Manual (ISO 8583 transactions)

```java
@Inject Tracer tracer;

public TransactionResult processTransaction(IsoMessage msg) {
    Span span = tracer.spanBuilder("transaction.process")
        .setAttribute("iso.mti", msg.getMti())
        .setAttribute("iso.stan", msg.getStan())
        .startSpan();
    try (Scope scope = span.makeCurrent()) {
        // ... processing ...
        span.setAttribute("iso.response_code", result.responseCode());
        span.setStatus(StatusCode.OK);
        return result;
    } catch (Exception e) {
        span.setStatus(StatusCode.ERROR);
        span.recordException(e);
        throw e;
    } finally {
        span.end();
    }
}
```

### Sub-spans

```java
Span parseSpan = tracer.spanBuilder("message.parse")
    .setParent(Context.current())  // inherits from parent span
    .startSpan();
```

## Metrics — How to Instrument

```java
@Inject Meter meter;

// Counter
LongCounter txCounter = meter.counterBuilder("simulator.transactions").build();
txCounter.add(1, Attributes.of(
    AttributeKey.stringKey("mti"), "1200",
    AttributeKey.stringKey("response_code"), "00"
));

// Histogram
DoubleHistogram duration = meter.histogramBuilder("simulator.transaction.duration")
    .setUnit("s").build();
duration.record(0.045, Attributes.of(...));

// UpDownCounter (gauge-like)
LongUpDownCounter connections = meter.upDownCounterBuilder("simulator.connections.active").build();
connections.add(1);   // connection opened
connections.add(-1);  // connection closed
```

## Logging — Correlation with Traces

```java
// Quarkus automatically injects trace_id/span_id into logs
// Just use SLF4J normally
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

log.info("Transaction processed: mti={}, rc={}", mti, rc);
// JSON output will include trace_id and span_id automatically
```

## Health Checks

```java
@Liveness
@ApplicationScoped
public class AppLiveness implements HealthCheck {
    public HealthCheckResponse call() {
        return HealthCheckResponse.up("alive");
    }
}

@Readiness
@ApplicationScoped
public class DbReadiness implements HealthCheck {
    @Inject DataSource ds;
    public HealthCheckResponse call() {
        try (var conn = ds.getConnection()) {
            return HealthCheckResponse.up("db");
        } catch (Exception e) {
            return HealthCheckResponse.down("db");
        }
    }
}
```

## Configuration per Environment

```properties
# Dev (disabled)
%dev.quarkus.otel.enabled=false

# Test (disabled)
%test.quarkus.otel.enabled=false

# Prod (enabled)
quarkus.otel.enabled=true
quarkus.otel.exporter.otlp.endpoint=${OTEL_ENDPOINT:http://otel-collector:4317}
quarkus.otel.service.name=authorizer-simulator
quarkus.otel.resource.attributes=service.version=0.1.0,deployment.environment=${ENV:prod}
quarkus.otel.traces.enabled=true
quarkus.otel.traces.sampler=parentbased_always_on
quarkus.otel.metrics.enabled=true
quarkus.otel.logs.enabled=true
```

## Required Spans (Architecture)

Each ISO 8583 transaction MUST create this span tree:

```
[authorizer-simulator] transaction.process (ROOT)
├── [authorizer-simulator] message.parse
├── [authorizer-simulator] message.validate
│   ├── [authorizer-simulator] rule.cents-decision
│   ├── [authorizer-simulator] rule.mcc-validation
│   └── [authorizer-simulator] rule.timeout-check
├── [authorizer-simulator] transaction.persist
│   └── [postgresql] INSERT INTO simulator.transactions
├── [authorizer-simulator] message.pack
└── [authorizer-simulator] message.send
```

## Required Span Attributes

| Attribute                  | Type   | Example                          | Required      |
| -------------------------- | ------ | -------------------------------- | ------------- |
| `iso.mti`                  | string | "1200"                           | Always        |
| `iso.version`              | string | "1993"                           | Always        |
| `iso.stan`                 | string | "123456"                         | Always        |
| `iso.response_code`        | string | "00"                             | On root span  |
| `merchant.id`              | string | "123456789012345"                | If available  |
| `terminal.id`              | string | "12345678"                       | If available  |
| `transaction.amount_cents` | long   | 10000                            | If available  |
| `transaction.type`         | string | "DEBIT_SALE"                     | Always        |
| `error.type`               | string | "TransactionProcessingException" | Only on error |

## PROHIBITED Attributes (sensitive data)

- `pan` (Primary Account Number)
- `pin_block`
- `cvv` / `cvc`
- `track_data`
- `card_expiry`

## Required Metrics

| Name                             | Type          | Unit    | Tags                                  |
| -------------------------------- | ------------- | ------- | ------------------------------------- |
| `simulator.transactions`         | Counter       | 1       | mti, response_code, iso_version, type |
| `simulator.transaction.duration` | Histogram     | seconds | mti, response_code                    |
| `simulator.connections.active`   | UpDownCounter | 1       | protocol (tcp, http)                  |
| `simulator.timeout.simulations`  | Counter       | 1       | merchant_id, terminal_id              |
| `simulator.messages.parsed`      | Counter       | 1       | mti, iso_version, status (ok, error)  |
| `simulator.db.query.duration`    | Histogram     | seconds | query_type (insert, select, update)   |
| `simulator.db.pool.active`       | UpDownCounter | 1       | —                                     |

## Structured Logging (JSON)

### Example

```json
{
  "timestamp": "2026-02-16T14:30:00.123Z",
  "level": "INFO",
  "logger": "com.bifrost.simulator.domain.engine.CentsDecisionEngine",
  "message": "Transaction authorized",
  "trace_id": "abc123def456",
  "span_id": "789ghi012",
  "mdc": {
    "transaction_id": "1001",
    "mti": "1200",
    "merchant_id": "123456789012345",
    "terminal_id": "12345678"
  }
}
```

## Logging Rules

- `DEBUG`: Parsing details, individual fields
- `INFO`: Transaction processed, merchant created, connection established
- `WARN`: Simulated timeout, optional field missing, connection retry
- `ERROR`: Exception, parsing failure, database error
- NEVER log: full PAN, PIN, CVV, Track Data, credentials

## Sensitive Data Masking

```java
// Mask PAN before logging
public static String maskPan(String pan) {
    if (pan == null || pan.length() < 10) return "****";
    return pan.substring(0, 6) + "****" + pan.substring(pan.length() - 4);
}
```

## Health Checks (K8S Probes)

```yaml
livenessProbe:
  httpGet:
    path: /q/health/live
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /q/health/ready
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 5

startupProbe:
  httpGet:
    path: /q/health/started
    port: 8080
  initialDelaySeconds: 1
  periodSeconds: 2
  failureThreshold: 5
```

## Review Checklist

- [ ] Spans created for all critical operations
- [ ] Required attributes in each span (mti, stan, response_code, etc.)
- [ ] ZERO sensitive data in spans (PAN, PIN, CVV, track data)
- [ ] Metrics defined with appropriate tags
- [ ] Logging in JSON (production) or text (dev)
- [ ] Appropriate log levels (DEBUG/INFO/WARN/ERROR)
- [ ] PAN masked in logs (123456\*\*\*\*1234)
- [ ] Health checks implemented (@Liveness, @Readiness, @Startup)
- [ ] OpenTelemetry configured via environment variables
- [ ] No hardcoding of OTEL_ENDPOINT
- [ ] Resilience metrics exposed (circuit breaker, rate limiting, degradation — Rule 24)
- [ ] Resilience events logged with context (circuit open/close, rate limit reject, degradation change)
