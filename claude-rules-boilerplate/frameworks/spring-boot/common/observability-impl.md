# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot — Observability Implementation

> Extends the base observability rules. All OpenTelemetry, sensitive data masking, and structured logging principles apply.

## Technology Stack

| Component | Technology | Spring Boot Integration |
|-----------|-----------|------------------------|
| Metrics | Micrometer | `spring-boot-starter-actuator` |
| Tracing | Micrometer Tracing + OpenTelemetry | `micrometer-tracing-bridge-otel` |
| Exporter | OTLP | `opentelemetry-exporter-otlp` |
| Logs | Logback + Logstash Encoder | `logstash-logback-encoder` |
| Health | Spring Actuator | Built-in |
| Resilience Metrics | Resilience4j Micrometer | Automatic |

## Configuration (application.yml)

### Tracing and Metrics

```yaml
management:
  otlp:
    tracing:
      endpoint: ${OTEL_ENDPOINT:http://otel-collector:4318/v1/traces}
    metrics:
      export:
        enabled: true
        endpoint: ${OTEL_ENDPOINT:http://otel-collector:4318/v1/metrics}
        step: 30s

  tracing:
    enabled: ${TRACING_ENABLED:false}
    sampling:
      probability: 1.0

  metrics:
    tags:
      application: ${spring.application.name}
      environment: ${ENV:dev}
    distribution:
      percentiles-histogram:
        http.server.requests: true
        simulator.transaction.duration: true
      slo:
        http.server.requests: 50ms,100ms,200ms,500ms,1s

  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true
      group:
        liveness:
          include: livenessState
        readiness:
          include: readinessState,db
```

### Profile-Specific

```yaml
# application-dev.yml — tracing disabled
management:
  tracing:
    enabled: false

# application-staging.yml / application-prod.yml — tracing enabled
management:
  tracing:
    enabled: true
```

## Distributed Tracing

### Micrometer Observation API

Spring Boot 3.x uses the Micrometer Observation API as the abstraction for tracing:

```java
@Service
public class TransactionTracingService {

    private final ObservationRegistry observationRegistry;

    public TransactionTracingService(ObservationRegistry observationRegistry) {
        this.observationRegistry = observationRegistry;
    }

    public <T> T traceTransaction(String mti, String stan, Supplier<T> operation) {
        return Observation.createNotStarted("transaction.process", observationRegistry)
            .lowCardinalityKeyValue("iso.mti", mti)
            .lowCardinalityKeyValue("iso.version", "1993")
            .highCardinalityKeyValue("iso.stan", stan)
            .observe(operation);
    }
}
```

### Manual Span Creation with OpenTelemetry Tracer

For finer control, use the OpenTelemetry Tracer directly:

```java
@Service
public class TransactionTracer {

    private final Tracer tracer;

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

    public Span startSpan(String name) {
        return tracer.spanBuilder(name).startSpan();
    }
}
```

### Mandatory Span Tree

Each ISO 8583 transaction creates this hierarchy:

```
[authorizer-simulator] transaction.process (ROOT)
+-- [authorizer-simulator] message.parse
+-- [authorizer-simulator] message.validate
|   +-- [authorizer-simulator] rule.cents-decision
|   +-- [authorizer-simulator] rule.timeout-check
+-- [authorizer-simulator] transaction.persist
|   +-- [postgresql] INSERT INTO simulator.transactions
+-- [authorizer-simulator] message.pack
+-- [authorizer-simulator] message.send
```

### Mandatory Span Attributes

| Attribute | Type | Required |
|----------|------|----------|
| `iso.mti` | string | Always |
| `iso.version` | string | Always |
| `iso.stan` | string | Always |
| `iso.response_code` | string | In root span |
| `merchant.id` | string | If available |
| `terminal.id` | string | If available |
| `transaction.amount_cents` | long | If available |
| `transaction.type` | string | Always |

### PROHIBITED Span Attributes

- `pan` (Primary Account Number)
- `pin_block`
- `cvv` / `cvc`
- `track_data`
- `card_expiry`
- Any credentials

## Custom Metrics with Micrometer

### Metric Registration

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
            .publishPercentiles(0.5, 0.75, 0.95, 0.99)
            .publishPercentileHistogram()
            .register(registry);

        this.activeConnections = registry.gauge("simulator.connections.active",
            new AtomicInteger(0));
    }

    public void recordTransaction(String mti, String responseCode, String isoVersion) {
        transactionCounter.increment(
            Tags.of("mti", mti, "response_code", responseCode, "iso_version", isoVersion)
        );
    }

    public Timer.Sample startTimer() {
        return Timer.start();
    }

    public void stopTimer(Timer.Sample sample, String mti, String responseCode) {
        sample.stop(Timer.builder("simulator.transaction.duration")
            .tag("mti", mti)
            .tag("response_code", responseCode)
            .register(transactionDuration.getId().getTag("mti") != null
                ? transactionDuration : transactionDuration));
    }

    public void connectionOpened() {
        activeConnections.incrementAndGet();
    }

    public void connectionClosed() {
        activeConnections.decrementAndGet();
    }
}
```

### Mandatory Metrics Table

| Name | Type | Unit | Tags |
|------|------|------|------|
| `simulator.transactions` | Counter | 1 | mti, response_code, iso_version, type |
| `simulator.transaction.duration` | Timer | seconds | mti, response_code |
| `simulator.connections.active` | Gauge | 1 | protocol (tcp, http) |
| `simulator.timeout.simulations` | Counter | 1 | merchant_id, terminal_id |
| `simulator.messages.parsed` | Counter | 1 | mti, iso_version, status |
| `simulator.db.query.duration` | Timer | seconds | query_type |
| `simulator.rate_limit.rejected` | Counter | 1 | scope, client_key |
| `simulator.degradation.level` | Gauge | 1 | -- |

### Resilience4j Automatic Metrics

Resilience4j with Micrometer exposes metrics automatically:

| Metric | Type | Tags |
|--------|------|------|
| `resilience4j.circuitbreaker.state` | Gauge | name, state |
| `resilience4j.circuitbreaker.calls` | Counter | name, kind |
| `resilience4j.bulkhead.available.concurrent.calls` | Gauge | name |
| `resilience4j.retry.calls` | Counter | name, kind |
| `resilience4j.timelimiter.calls` | Counter | name, kind |

Activation in YAML:

```yaml
resilience4j:
  circuitbreaker:
    configs:
      default:
        register-health-indicator: true
  # Micrometer integration is automatic with resilience4j-micrometer on classpath
```

## Health Checks

### Built-In Indicators

Spring Boot auto-configures health indicators for common components:

| Indicator | Checks | Auto-configured when |
|-----------|--------|---------------------|
| `db` | Database connection | DataSource on classpath |
| `diskSpace` | Available disk | Always |
| `ping` | Application alive | Always |

### Custom Health Indicator

```java
@Component
public class TcpServerHealthIndicator implements HealthIndicator {

    private final TcpServerBootstrap tcpServer;

    public TcpServerHealthIndicator(TcpServerBootstrap tcpServer) {
        this.tcpServer = tcpServer;
    }

    @Override
    public Health health() {
        if (tcpServer.isListening()) {
            return Health.up()
                .withDetail("port", tcpServer.getPort())
                .withDetail("activeConnections", tcpServer.getActiveConnectionCount())
                .build();
        }
        return Health.down()
            .withDetail("reason", "TCP server not listening")
            .build();
    }
}

@Component
public class DegradationHealthIndicator implements HealthIndicator {

    private final DegradationManager degradationManager;

    public DegradationHealthIndicator(DegradationManager degradationManager) {
        this.degradationManager = degradationManager;
    }

    @Override
    public Health health() {
        var level = degradationManager.getCurrentLevel();
        return switch (level) {
            case NORMAL, WARNING -> Health.up()
                .withDetail("level", level.name())
                .build();
            case CRITICAL -> Health.up()
                .withDetail("level", level.name())
                .withDetail("warning", "system under high load")
                .build();
            case EMERGENCY -> Health.down()
                .withDetail("level", level.name())
                .withDetail("reason", "emergency degradation active")
                .build();
        };
    }
}
```

### Health Groups for Kubernetes

```yaml
management:
  endpoint:
    health:
      probes:
        enabled: true
      group:
        liveness:
          include: livenessState,ping
        readiness:
          include: readinessState,db,degradation
```

## Structured JSON Logging

### Logback Configuration with Logstash Encoder

```xml
<!-- src/main/resources/logback-spring.xml -->
<configuration>

    <springProfile name="dev">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
    </springProfile>

    <springProfile name="staging,prod">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <fieldNames>
                    <timestamp>timestamp</timestamp>
                    <thread>thread</thread>
                    <level>level</level>
                    <logger>logger</logger>
                    <message>message</message>
                </fieldNames>
                <customFields>{"service":"authorizer-simulator"}</customFields>
            </encoder>
        </appender>
    </springProfile>

    <root level="INFO">
        <appender-ref ref="CONSOLE" />
    </root>

    <logger name="com.bifrost.simulator" level="INFO" />
</configuration>
```

### Log Correlation (traceId/spanId in MDC)

Spring Boot 3.x automatically propagates `traceId` and `spanId` to the MDC when Micrometer Tracing is enabled. The Logstash encoder picks these up automatically.

Structured log output in production:

```json
{
    "timestamp": "2026-02-18T14:30:00.123Z",
    "level": "INFO",
    "logger": "com.bifrost.simulator.domain.engine.CentsDecisionEngine",
    "message": "Transaction authorized",
    "thread": "vert.x-eventloop-thread-0",
    "traceId": "abc123def456",
    "spanId": "789ghi012",
    "mdc": {
        "mti": "1200",
        "merchant_id": "123456789012345",
        "terminal_id": "12345678"
    },
    "service": "authorizer-simulator"
}
```

### Logging Levels

| Level | Usage |
|-------|-------|
| `DEBUG` | Parsing details, individual field values |
| `INFO` | Transaction processed, connection established, merchant created |
| `WARN` | Simulated timeout, rate limit hit, optional field missing |
| `ERROR` | Exception, parsing failure, database error, circuit opened |

### Sensitive Data Masking

```java
public final class LogMasker {

    private LogMasker() {}

    public static String maskPan(String pan) {
        if (pan == null || pan.length() < 13) return "****";
        return pan.substring(0, 6) + "****" + pan.substring(pan.length() - 4);
    }

    public static String maskDocument(String document) {
        if (document == null || document.length() < 5) return "****";
        return document.substring(0, 3) + "****" + document.substring(document.length() - 2);
    }
}
```

NEVER log:
- Full PAN
- PIN Block
- CVV/CVC
- Track Data
- Card Expiry
- Credentials

## Maven Dependencies

```xml
<!-- Spring Boot Actuator (metrics, health, endpoints) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>

<!-- Micrometer Tracing Bridge for OpenTelemetry -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>

<!-- OpenTelemetry OTLP Exporter -->
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
</dependency>

<!-- Micrometer Prometheus Registry (optional, for /actuator/prometheus) -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>

<!-- Micrometer OTLP Registry (for pushing metrics via OTLP) -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-otlp</artifactId>
</dependency>

<!-- Logstash Logback Encoder (structured JSON logs) -->
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>${logstash-logback.version}</version>
</dependency>

<!-- Resilience4j Micrometer (automatic resilience metrics) -->
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-micrometer</artifactId>
</dependency>
```

## Anti-Patterns (FORBIDDEN)

```java
// FORBIDDEN — Direct Micrometer import without Spring abstraction
// Use MeterRegistry injection, not static Metrics class

// FORBIDDEN — Sensitive data in spans
span.setAttribute("card.pan", "4111111111111111");
span.setAttribute("card.pin_block", pinBlock);

// FORBIDDEN — OTel enabled in dev/test profiles
management:
  tracing:
    enabled: true  # Only in staging/prod

// FORBIDDEN — Full PAN in logs
LOG.info("Processing card {}", pan);  // Use maskPan()

// FORBIDDEN — No traceId correlation in logs
// Always use logstash-logback-encoder or Spring structured logging

// FORBIDDEN — Custom metrics without description
Counter.builder("simulator.transactions").register(registry);  // Missing .description()

// FORBIDDEN — Vendor-specific observability APIs
// Use Micrometer (metrics) + Micrometer Tracing (traces), not direct Jaeger/Zipkin/Datadog SDKs
```
