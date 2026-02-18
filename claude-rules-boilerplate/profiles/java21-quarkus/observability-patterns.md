# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Quarkus — Observability Patterns

> Extends: `core/08-observability-principles.md`

## Technology Stack

| Component | Technology |
|-----------|-----------|
| SDK | OpenTelemetry Java SDK (via Quarkus) |
| Exporter | OTLP gRPC (port 4317) |
| Collector | OpenTelemetry Collector (K8S) |
| Health | SmallRye Health (Quarkus) |

## Quarkus OpenTelemetry Configuration

```properties
# application.properties
quarkus.otel.enabled=true
quarkus.otel.exporter.otlp.endpoint=${OTEL_ENDPOINT:http://otel-collector:4317}
quarkus.otel.exporter.otlp.protocol=grpc
quarkus.otel.service.name=authorizer-simulator
quarkus.otel.resource.attributes=service.version=${APP_VERSION:0.1.0},deployment.environment=${ENV:dev}

# Traces
quarkus.otel.traces.enabled=true
quarkus.otel.traces.sampler=parentbased_always_on

# Metrics
quarkus.otel.metrics.enabled=true

# Logs (via SLF4J bridge)
quarkus.otel.logs.enabled=true
quarkus.log.handler.open-telemetry.enabled=true
```

Disable in dev/test to avoid overhead:
```properties
# application-dev.properties / application-test.properties
quarkus.otel.enabled=false
```

## Distributed Tracing — Span Pattern

```java
@ApplicationScoped
public class TransactionTracer {

    private final Tracer tracer;

    @Inject
    public TransactionTracer(Tracer tracer) {
        this.tracer = tracer;
    }

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

### Mandatory Span Attributes

| Attribute | Type | Mandatory |
|----------|------|-----------|
| `iso.mti` | string | Always |
| `iso.version` | string | Always |
| `iso.stan` | string | Always |
| `iso.response_code` | string | In root span |
| `merchant.id` | string | If available |
| `terminal.id` | string | If available |
| `transaction.amount_cents` | long | If available |
| `transaction.type` | string | Always |
| `error.type` | string | Only on error |

### PROHIBITED Attributes

- `pan` (Primary Account Number)
- `pin_block`
- `cvv` / `cvc`
- `track_data`
- `card_expiry`

## Custom Metrics (OpenTelemetry API)

```java
@ApplicationScoped
public class TransactionMetrics {

    private final LongCounter transactionCounter;
    private final DoubleHistogram transactionDuration;
    private final LongUpDownCounter activeConnections;

    @Inject
    public TransactionMetrics(Meter meter) {
        this.transactionCounter = meter.counterBuilder("simulator.transactions")
            .setDescription("Total transactions processed")
            .build();
        this.transactionDuration = meter.histogramBuilder("simulator.transaction.duration")
            .setDescription("Transaction processing duration in seconds")
            .setUnit("s")
            .build();
        this.activeConnections = meter.upDownCounterBuilder("simulator.connections.active")
            .setDescription("Active TCP connections")
            .build();
    }

    public void recordTransaction(String mti, String responseCode, String isoVersion) {
        transactionCounter.add(1, Attributes.builder()
            .put("mti", mti)
            .put("response_code", responseCode)
            .put("iso_version", isoVersion)
            .build());
    }

    public void recordDuration(String mti, String responseCode, double durationSeconds) {
        transactionDuration.record(durationSeconds, Attributes.builder()
            .put("mti", mti)
            .put("response_code", responseCode)
            .build());
    }

    public void connectionOpened() {
        activeConnections.add(1, Attributes.builder().put("protocol", "tcp").build());
    }

    public void connectionClosed() {
        activeConnections.add(-1, Attributes.builder().put("protocol", "tcp").build());
    }
}
```

### Mandatory Metrics

| Name | Type | Tags |
|------|------|------|
| `simulator.transactions` | Counter | mti, response_code, iso_version |
| `simulator.transaction.duration` | Histogram | mti, response_code |
| `simulator.connections.active` | UpDownCounter | protocol |
| `simulator.timeout.simulations` | Counter | merchant_id, terminal_id |
| `simulator.db.query.duration` | Histogram | query_type |

### Naming Convention

- Prefix: `simulator.`
- Separator: `.` (dot)
- snake_case for composite names
- Units: `seconds`, `bytes`, `1` (count)

## Health Checks (SmallRye Health)

### Liveness

```java
@Liveness
@ApplicationScoped
public class ApplicationLivenessCheck implements HealthCheck {

    @Override
    public HealthCheckResponse call() {
        return HealthCheckResponse.up("alive");
    }
}
```

### Readiness

```java
@Readiness
@ApplicationScoped
public class DatabaseReadinessCheck implements HealthCheck {

    private final DataSource dataSource;

    @Inject
    public DatabaseReadinessCheck(DataSource dataSource) {
        this.dataSource = dataSource;
    }

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

### Health Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/q/health/live` | Application is running (liveness) |
| `/q/health/ready` | DB connected + socket listening (readiness) |
| `/q/health/started` | Application finished startup |

## JSON Logging Configuration

```properties
# Production (staging/prod profiles)
quarkus.log.console.json=true
quarkus.log.console.json.additional-field."service".value=authorizer-simulator

# Log levels
quarkus.log.level=INFO
quarkus.log.category."com.bifrost".level=DEBUG
```

### Log Level Guidelines

| Level | Use |
|-------|-----|
| DEBUG | Parsing details, individual fields |
| INFO | Transaction processed, merchant created, connection established |
| WARN | Simulated timeout, optional field missing, connection retry |
| ERROR | Exception, parsing failure, database error |

### PAN Masking

```java
public static String maskPan(String pan) {
    if (pan == null || pan.length() < 10) return "****";
    return pan.substring(0, 6) + "****" + pan.substring(pan.length() - 4);
}
```

NEVER log full PAN, PIN, CVV, Track Data, or credentials, even at DEBUG/TRACE level.

## Resilience Metrics (Automatic)

SmallRye Fault Tolerance exposes metrics automatically via OpenTelemetry when `quarkus-smallrye-fault-tolerance` is on the classpath:

| Metric | Type |
|--------|------|
| `ft.circuitbreaker.state.total` | Gauge |
| `ft.circuitbreaker.calls.total` | Counter |
| `ft.bulkhead.executionsRunning` | Gauge |
| `ft.bulkhead.callsRejected.total` | Counter |
| `ft.retry.retries.total` | Counter |
| `ft.timeout.calls.total` | Counter |
| `ft.fallback.calls.total` | Counter |
