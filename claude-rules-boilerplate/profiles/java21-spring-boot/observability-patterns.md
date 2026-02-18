# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Spring Boot — Observability Patterns

> Extends: `core/08-observability-principles.md`

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Metrics | Micrometer + OpenTelemetry bridge (Spring Boot 3.x) |
| Tracing | Micrometer Tracing + OpenTelemetry exporter |
| Logging | SLF4J + Logback + logstash-logback-encoder (JSON) |
| Health | Spring Boot Actuator (`HealthIndicator`) |
| Exporter | OTLP gRPC/HTTP to OpenTelemetry Collector |

## Spring Boot Observability Configuration

```yaml
# application.yml
spring:
  application:
    name: my-application

management:
  otlp:
    tracing:
      endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:http://otel-collector:4318/v1/traces}
    metrics:
      export:
        url: ${OTEL_EXPORTER_OTLP_ENDPOINT:http://otel-collector:4318/v1/metrics}
        step: 30s

  tracing:
    sampling:
      probability: 1.0

  endpoints:
    web:
      exposure:
        include: health,metrics,prometheus,info
  endpoint:
    health:
      show-details: always
      probes:
        enabled: true
  health:
    livenessState:
      enabled: true
    readinessState:
      enabled: true

  metrics:
    tags:
      application: ${spring.application.name}
      environment: ${ENV:dev}
    distribution:
      percentiles-histogram:
        http.server.requests: true
```

Disable tracing in dev/test to avoid overhead:
```yaml
# application-dev.yml / application-test.yml
management:
  tracing:
    enabled: false
  otlp:
    tracing:
      endpoint: ""
```

## Distributed Tracing — Micrometer Observation API

### Preferred: Observation API

```java
@Service
public class TransactionTracer {

    private final ObservationRegistry observationRegistry;

    public TransactionTracer(ObservationRegistry observationRegistry) {
        this.observationRegistry = observationRegistry;
    }

    public <T> T traceOperation(String operationType, String operationId, Supplier<T> operation) {
        return Observation.createNotStarted("operation.process", observationRegistry)
            .lowCardinalityKeyValue("operation.type", operationType)
            .lowCardinalityKeyValue("operation.category", resolveCategory(operationType))
            .highCardinalityKeyValue("operation.id", operationId)
            .observe(operation);
    }
}
```

### Alternative: OpenTelemetry Tracer Directly

```java
@Service
public class TransactionTracer {

    private final Tracer tracer;

    public TransactionTracer(Tracer tracer) {
        this.tracer = tracer;
    }

    public <T> T traceOperation(String operationType, String operationId, Supplier<T> operation) {
        Span span = tracer.spanBuilder("operation.process")
            .setAttribute("operation.type", operationType)
            .setAttribute("operation.id", operationId)
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

| Attribute | Type | Mandatory | Example |
|----------|------|-----------|---------|
| `operation.type` | string | Always | `"debit_sale"`, `"echo_test"` |
| `operation.id` | string | Always | STAN or unique operation ID |
| `error.type` | string | Only on error | Exception class name |

Additional attributes to include when available:

| Attribute | Type | When |
|----------|------|------|
| `operation.status` | string | In root span (e.g., response code) |
| `client.id` | string | If the operation is associated with a client (e.g., MID) |
| `device.id` | string | If a device is involved (e.g., TID) |
| `operation.amount_cents` | long | If the operation involves a monetary amount |

### PROHIBITED Attributes

- `credentials`
- `tokens`
- `secrets`
- `personal_identifiers`
- `authentication_data`

## Custom Metrics (Micrometer)

```java
@Component
public class TransactionMetrics {

    private final Counter transactionCounter;
    private final Timer transactionDuration;
    private final AtomicInteger activeConnections;

    public TransactionMetrics(MeterRegistry registry) {
        this.transactionCounter = Counter.builder("simulator.transactions")
            .description("Total transactions processed")
            .register(registry);
        this.transactionDuration = Timer.builder("simulator.transaction.duration")
            .description("Transaction processing duration")
            .publishPercentileHistogram()
            .register(registry);
        this.activeConnections = registry.gauge("simulator.connections.active",
            Tags.of("protocol", "tcp"), new AtomicInteger(0));
    }

    public void recordTransaction(String mti, String responseCode, String isoVersion) {
        Counter.builder("simulator.transactions")
            .tag("mti", mti)
            .tag("response_code", responseCode)
            .tag("iso_version", isoVersion)
            .register(transactionCounter.getId().getMeterRegistry() != null
                ? transactionCounter.getId().getMeterRegistry() : null);
    }

    public Timer.Sample startTimer() {
        return Timer.start();
    }

    public void recordDuration(Timer.Sample sample, String mti, String responseCode, MeterRegistry registry) {
        sample.stop(Timer.builder("simulator.transaction.duration")
            .tag("mti", mti)
            .tag("response_code", responseCode)
            .register(registry));
    }

    public void connectionOpened() {
        activeConnections.incrementAndGet();
    }

    public void connectionClosed() {
        activeConnections.decrementAndGet();
    }
}
```

### Mandatory Metrics

| Name | Type | Tags |
|------|------|------|
| `simulator.transactions` | Counter | mti, response_code, iso_version |
| `simulator.transaction.duration` | Timer | mti, response_code |
| `simulator.connections.active` | Gauge | protocol |
| `simulator.timeout.simulations` | Counter | merchant_id, terminal_id |
| `simulator.db.query.duration` | Timer | query_type |

### Naming Convention

- Prefix: `simulator.`
- Separator: `.` (dot)
- snake_case for composite names
- Micrometer convention: Timers measure duration automatically (no explicit unit)

## Resilience Metrics (Automatic)

Resilience4j exposes metrics automatically via Micrometer when on the classpath:

| Metric | Type |
|--------|------|
| `resilience4j.circuitbreaker.state` | Gauge |
| `resilience4j.circuitbreaker.calls` | Counter |
| `resilience4j.bulkhead.available.concurrent.calls` | Gauge |
| `resilience4j.bulkhead.max.allowed.concurrent.calls` | Gauge |
| `resilience4j.retry.calls` | Counter |
| `resilience4j.timelimiter.calls` | Counter |
| `resilience4j.ratelimiter.available.permissions` | Gauge |

## Health Checks (Spring Boot Actuator)

### Liveness

Liveness is automatically provided by Spring Boot Actuator when `management.endpoint.health.probes.enabled=true`. Custom liveness checks are rarely needed.

### Readiness — Custom HealthIndicator

```java
@Component
public class DatabaseReadinessIndicator implements HealthIndicator {

    private final DataSource dataSource;

    public DatabaseReadinessIndicator(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public Health health() {
        try (var conn = dataSource.getConnection()) {
            return Health.up().withDetail("database", "connected").build();
        } catch (SQLException e) {
            return Health.down().withDetail("database", e.getMessage()).build();
        }
    }
}
```

### Grouping Health Indicators for Kubernetes Probes

```yaml
management:
  endpoint:
    health:
      group:
        liveness:
          include: livenessState
        readiness:
          include: readinessState,db,degradation
```

### Health Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/actuator/health/liveness` | Application is running (Kubernetes liveness) |
| `/actuator/health/readiness` | DB connected + dependencies ready (Kubernetes readiness) |
| `/actuator/health` | Overall application health (startup probe) |

## Structured JSON Logging

### Logback Configuration (logback-spring.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <springProfile name="dev,test">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="CONSOLE" />
        </root>
    </springProfile>

    <springProfile name="staging,prod">
        <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <customFields>{"service":"my-application"}</customFields>
                <includeMdcKeyName>traceId</includeMdcKeyName>
                <includeMdcKeyName>spanId</includeMdcKeyName>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="JSON" />
        </root>
    </springProfile>
</configuration>
```

### Log Correlation

Micrometer Tracing automatically propagates `traceId` and `spanId` into MDC, making them available in every log line without manual configuration.

### Log Level Guidelines

| Level | Use |
|-------|-----|
| DEBUG | Parsing details, individual fields |
| INFO | Transaction processed, merchant created, connection established |
| WARN | Simulated timeout, optional field missing, connection retry |
| ERROR | Exception, parsing failure, database error |

### Sensitive Data Masking

```java
public static String maskSensitiveField(String value) {
    if (value == null || value.length() < 6) return "****";
    return value.substring(0, 3) + "****" + value.substring(value.length() - 2);
}
```

NEVER log sensitive data (credentials, tokens, personal identifiers), even at DEBUG/TRACE level.

## Maven Dependencies

```xml
<!-- Spring Boot Actuator -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>

<!-- Micrometer Tracing with OpenTelemetry bridge -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>

<!-- OpenTelemetry OTLP exporter -->
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
</dependency>

<!-- Micrometer OTLP metrics exporter -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-otlp</artifactId>
</dependency>

<!-- JSON structured logging -->
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>${logstash-logback.version}</version>
</dependency>
```
