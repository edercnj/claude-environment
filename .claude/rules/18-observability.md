# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 18 — Observability (OpenTelemetry)

## Principles
- **OpenTelemetry** as UNIQUE standard (NEVER direct Micrometer, NEVER Jaeger SDK)
- **3 pillars:** Traces, Metrics, Logs — all via OTLP
- **Vendor-agnostic:** Collection backend is not application responsibility
- **Sensitive data:** NEVER in spans, metrics or logs

## Stack
| Component | Technology |
|-----------|-----------|
| SDK | OpenTelemetry Java SDK (via Quarkus) |
| Exporter | OTLP gRPC (port 4317) |
| Collector | OpenTelemetry Collector (K8S) |
| Traces Backend | Jaeger / Grafana Tempo (suggestion) |
| Metrics Backend | Prometheus / Grafana Mimir (suggestion) |
| Logs Backend | Loki / Elasticsearch (suggestion) |
| Dashboards | Grafana (suggestion) |

## Distributed Tracing

### Mandatory Spans
Each ISO 8583 transaction MUST create this span tree:
```
[authorizer-simulator] transaction.process (ROOT)
├── [authorizer-simulator] message.parse
├── [authorizer-simulator] message.validate
│   ├── [authorizer-simulator] rule.cents-decision
│   ├── [authorizer-simulator] rule.mcc-validation (if applicable)
│   └── [authorizer-simulator] rule.timeout-check
├── [authorizer-simulator] transaction.persist
│   └── [postgresql] INSERT INTO simulator.transactions
├── [authorizer-simulator] message.pack
└── [authorizer-simulator] message.send
```

### Mandatory Attributes in Spans
| Attribute | Type | Example | Mandatory |
|----------|------|---------|-----------|
| `iso.mti` | string | "1200" | ✅ Always |
| `iso.version` | string | "1993" | ✅ Always |
| `iso.stan` | string | "123456" | ✅ Always |
| `iso.response_code` | string | "00" | ✅ In root span |
| `merchant.id` | string | "123456789012345" | ✅ If available |
| `terminal.id` | string | "12345678" | ✅ If available |
| `transaction.amount_cents` | long | 10000 | ✅ If available |
| `transaction.type` | string | "DEBIT_SALE" | ✅ Always |
| `error.type` | string | "TransactionProcessingException" | ❌ Only on error |

### PROHIBITED Attributes (sensitive data)
- ❌ `pan` (Primary Account Number)
- ❌ `pin_block`
- ❌ `cvv` / `cvc`
- ❌ `track_data`
- ❌ `card_expiry`

### Implementation
```java
@ApplicationScoped
public class TransactionTracer {
    @Inject
    Tracer tracer;

    public <T> T traceTransaction(String mti, String stan, Supplier<T> operation) {
        Span span = tracer.spanBuilder("transaction.process")
            .setAttribute("iso.mti", mti)
            .setAttribute("iso.stan", stan)
            .startSpan();
        try (Scope scope = span.makeCurrent()) {
            T result = operation.get();
            span.setStatus(StatusCode.OK);
            return result;
        } catch (Exception e) {
            span.setStatus(StatusCode.ERROR, e.getMessage());
            span.recordException(e);
            throw e;
        } finally {
            span.end();
        }
    }
}
```

## Metrics

### Mandatory Metrics
| Name | Type | Unit | Tags |
|------|------|------|------|
| `simulator.transactions` | Counter | 1 | mti, response_code, iso_version, type |
| `simulator.transaction.duration` | Histogram | seconds | mti, response_code |
| `simulator.connections.active` | UpDownCounter | 1 | protocol (tcp, http) |
| `simulator.timeout.simulations` | Counter | 1 | merchant_id, terminal_id |
| `simulator.messages.parsed` | Counter | 1 | mti, iso_version, status (ok, error) |
| `simulator.db.query.duration` | Histogram | seconds | query_type (insert, select, update) |
| `simulator.db.pool.active` | UpDownCounter | 1 | — |

### Resilience Metrics (Rule 24)

SmallRye Fault Tolerance exposes metrics automatically via OpenTelemetry:

| Metric | Type | Tags |
|--------|------|------|
| `ft.circuitbreaker.state.total` | Gauge | method, state (closed/open/halfOpen) |
| `ft.circuitbreaker.calls.total` | Counter | method, result (success/failure/cbOpen) |
| `ft.bulkhead.executionsRunning` | Gauge | method |
| `ft.bulkhead.callsRejected.total` | Counter | method |
| `ft.retry.retries.total` | Counter | method |
| `ft.timeout.calls.total` | Counter | method, timedOut (true/false) |
| `simulator.rate_limit.rejected` | Counter | scope (tcp/rest), client_key |
| `simulator.degradation.level` | Gauge | — |

> See **Rule 24 — Application Resilience** for complete implementation and custom metrics.

### Naming Convention
- Prefix: `simulator.`
- Separator: `.` (dot)
- snake_case for composite names
- Units: `seconds`, `bytes`, `1` (count)

## Structured Logging

### Format
JSON in production, human-readable text in dev.

### Mandatory Fields
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

### Logging Rules
- `DEBUG`: Parsing details, individual fields
- `INFO`: Transaction processed, merchant created, connection established
- `WARN`: Simulated timeout, optional field missing, connection retry
- `ERROR`: Exception, parsing failure, database error
- NEVER log: Full PAN, PIN, CVV, Track Data, credentials

### Masking
```java
// ✅ Mask PAN before logging
public static String maskPan(String pan) {
    if (pan == null || pan.length() < 10) return "****";
    return pan.substring(0, 6) + "****" + pan.substring(pan.length() - 4);
}
```

## Health Checks
```java
@Liveness
@ApplicationScoped
public class ApplicationLivenessCheck implements HealthCheck {
    @Override
    public HealthCheckResponse call() {
        return HealthCheckResponse.up("alive");
    }
}

@Readiness
@ApplicationScoped
public class DatabaseReadinessCheck implements HealthCheck {
    @Inject DataSource dataSource;

    @Override
    public HealthCheckResponse call() {
        try (Connection conn = dataSource.getConnection()) {
            return HealthCheckResponse.up("database");
        } catch (SQLException e) {
            return HealthCheckResponse.down("database");
        }
    }
}
```

## Configuration
```properties
# application.properties
quarkus.otel.enabled=true
quarkus.otel.exporter.otlp.endpoint=${OTEL_ENDPOINT:http://otel-collector:4317}
quarkus.otel.exporter.otlp.protocol=grpc
quarkus.otel.service.name=authorizer-simulator
quarkus.otel.resource.attributes=service.version=${APP_VERSION:0.1.0},deployment.environment=${ENV:dev}
quarkus.otel.traces.enabled=true
quarkus.otel.traces.sampler=parentbased_always_on
quarkus.otel.metrics.enabled=true
quarkus.otel.logs.enabled=true

# Logging JSON
quarkus.log.console.json=true
quarkus.log.console.json.additional-field."service".value=authorizer-simulator
```
