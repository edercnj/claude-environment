# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot — Configuration Patterns

> Extends the base configuration and infrastructure rules. All externalized configuration and profile principles apply.

## File Structure

```
src/main/resources/
├── application.yml                 # Base shared (ALL profiles)
├── application-dev.yml             # Overrides for local development
├── application-test.yml            # Overrides for tests (H2, random port)
├── application-staging.yml         # Overrides for staging
└── application-prod.yml            # Overrides for production
```

## Override Hierarchy

Spring Boot resolves properties in this order (highest priority first):

```
1. Command-line arguments (--server.port=9090)              <- highest priority
2. SPRING_APPLICATION_JSON (inline JSON)
3. Environment variables (SIMULATOR_SOCKET_PORT=9583)
4. System properties (-Dsimulator.socket.port=9583)
5. Profile-specific YAML (application-{profile}.yml)
6. Base YAML (application.yml)
7. @ConfigurationProperties defaults                         <- lowest priority
```

### Spring Relaxed Binding

Spring Boot supports multiple formats for the same property:

| Format | Example |
|--------|---------|
| Kebab case (recommended) | `simulator.socket.max-connections` |
| Camel case | `simulator.socket.maxConnections` |
| Underscore | `simulator.socket.max_connections` |
| Upper case (env vars) | `SIMULATOR_SOCKET_MAX_CONNECTIONS` |

**Standard:** Use kebab-case in YAML, UPPER_SNAKE_CASE for environment variables.

## application.yml (Base Shared)

```yaml
spring:
  application:
    name: authorizer-simulator

  datasource:
    url: ${DB_URL:jdbc:postgresql://localhost:5432/authorizer_simulator}
    username: ${DB_USER:simulator}
    password: ${DB_PASSWORD:simulator}
    driver-class-name: org.postgresql.Driver
    hikari:
      minimum-idle: 5
      maximum-pool-size: 20
      connection-timeout: 5000
      idle-timeout: 300000

  jpa:
    hibernate:
      ddl-auto: none
    properties:
      hibernate:
        default_schema: simulator
        format_sql: false
    open-in-view: false

  flyway:
    enabled: true
    schemas:
      - simulator
    locations:
      - classpath:db/migration

  jackson:
    serialization:
      write-dates-as-timestamps: false
    default-property-inclusion: non_null

server:
  port: 8080
  shutdown: graceful

management:
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

simulator:
  socket:
    port: 8583
    host: 0.0.0.0
    max-connections: 100
    idle-timeout: 300
    read-timeout: 30
    length-header-bytes: 2

  iso:
    default-version: "1993"
```

## Profile Differences

| Configuration | dev | test | staging | prod |
|-------------|-----|------|---------|------|
| DB kind | PostgreSQL (Docker) | **H2** | PostgreSQL | PostgreSQL |
| Flyway | enabled | **disabled** | enabled | enabled |
| Hibernate ddl-auto | none | **create-drop** | none | none |
| Socket port | 8583 | **0** (random) | 8583 | 8583 |
| OTel | disabled | disabled | **enabled** | **enabled** |
| Log format | text | text | **JSON** | **JSON** |
| Swagger UI | **enabled** | disabled | disabled | disabled |
| Server port | 8080 | **0** (random) | 8080 | 8080 |

### application-dev.yml

```yaml
spring:
  devtools:
    restart:
      enabled: true

springdoc:
  swagger-ui:
    enabled: true
  api-docs:
    enabled: true

management:
  endpoint:
    health:
      show-details: always

logging:
  level:
    com.bifrost.simulator: DEBUG
    org.hibernate.SQL: DEBUG
```

### application-test.yml

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH
    username: sa
    password:
    driver-class-name: org.h2.Driver

  jpa:
    hibernate:
      ddl-auto: create-drop
    properties:
      hibernate:
        default_schema: simulator

  flyway:
    enabled: false

  h2:
    console:
      enabled: false

server:
  port: 0

simulator:
  socket:
    port: 0

springdoc:
  swagger-ui:
    enabled: false
```

### application-staging.yml / application-prod.yml

```yaml
spring:
  datasource:
    url: ${DB_URL}
    username: ${DB_USER}
    password: ${DB_PASSWORD}

management:
  otlp:
    tracing:
      endpoint: ${OTEL_ENDPOINT:http://otel-collector:4318/v1/traces}
    metrics:
      export:
        enabled: true
        endpoint: ${OTEL_ENDPOINT:http://otel-collector:4318/v1/metrics}
  tracing:
    enabled: true
    sampling:
      probability: 1.0

logging:
  pattern:
    console: ""
  structured:
    format:
      console: logstash

springdoc:
  swagger-ui:
    enabled: false
  api-docs:
    enabled: false
```

## @ConfigurationProperties with Records (Type-Safe)

For **configuration groups** (3+ properties with common prefix), use `@ConfigurationProperties`:

```java
@ConfigurationProperties(prefix = "simulator")
public record SimulatorProperties(
    SocketProperties socket,
    IsoProperties iso
) {

    public record SocketProperties(
        int port,
        String host,
        int maxConnections,
        int idleTimeout,
        int readTimeout,
        int lengthHeaderBytes
    ) {
        public SocketProperties {
            if (port < 0) throw new IllegalArgumentException("Port must be non-negative");
            if (maxConnections <= 0) throw new IllegalArgumentException("Max connections must be positive");
            if (host == null || host.isBlank()) host = "0.0.0.0";
            if (lengthHeaderBytes != 2 && lengthHeaderBytes != 4) {
                throw new IllegalArgumentException("Length header must be 2 or 4 bytes");
            }
        }
    }

    public record IsoProperties(
        String defaultVersion
    ) {
        public IsoProperties {
            if (defaultVersion == null || defaultVersion.isBlank()) defaultVersion = "1993";
        }
    }
}
```

### Enable ConfigurationProperties Scanning

```java
@SpringBootApplication
@ConfigurationPropertiesScan
public class AuthorizerSimulatorApplication {

    public static void main(String[] args) {
        SpringApplication.run(AuthorizerSimulatorApplication.class, args);
    }
}
```

### Usage in Services

```java
@Service
public class TcpServerBootstrap {

    private final SimulatorProperties config;

    public TcpServerBootstrap(SimulatorProperties config) {
        this.config = config;
    }

    public void start() {
        int port = config.socket().port();
        String host = config.socket().host();
        int maxConnections = config.socket().maxConnections();
        // ...
    }
}
```

## @Value vs @ConfigurationProperties Decision Matrix

| Scenario | Use | Example |
|---------|-----|---------|
| Single isolated property | `@Value` | `@Value("${app.name}")` |
| 2 related properties | Either | Preference for `@Value` |
| 3+ properties with common prefix | `@ConfigurationProperties` | `SimulatorProperties` |
| Type-safe with validation | `@ConfigurationProperties` | Record with compact constructor |
| Environment-dependent | `@ConfigurationProperties` | Override in profile YAML |

```java
// CORRECT — @Value for isolated property
@Service
public class VersionService {

    @Value("${app.version:0.0.0}")
    private String appVersion;
}

// CORRECT — @ConfigurationProperties for group
@ConfigurationProperties(prefix = "simulator.resilience.rate-limit")
public record RateLimitProperties(
    int restPerIp,
    int restPost,
    int tcpPerConnection,
    int tcpGlobal
) {
    public RateLimitProperties {
        if (restPerIp <= 0) restPerIp = 100;
        if (restPost <= 0) restPost = 10;
        if (tcpPerConnection <= 0) tcpPerConnection = 50;
        if (tcpGlobal <= 0) tcpGlobal = 5000;
    }
}

// WRONG — @Value for many related properties
@Service
public class BadService {
    @Value("${simulator.socket.port}") int port;
    @Value("${simulator.socket.host}") String host;
    @Value("${simulator.socket.max-connections}") int maxConnections;
    @Value("${simulator.socket.idle-timeout}") int idleTimeout;
    // Should be SimulatorProperties
}
```

## Actuator Endpoints for Kubernetes Probes

```yaml
management:
  endpoint:
    health:
      probes:
        enabled: true
      group:
        liveness:
          include: livenessState
        readiness:
          include: readinessState,db
        startup:
          include: livenessState
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
```

### Probe URLs

| Probe | URL | Purpose |
|-------|-----|---------|
| Liveness | `/actuator/health/liveness` | Application is running |
| Readiness | `/actuator/health/readiness` | DB connected, ready for traffic |
| Startup | `/actuator/health/liveness` | Application finished startup |

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
```

## Graceful Shutdown

```yaml
server:
  shutdown: graceful

spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```

## Anti-Patterns (FORBIDDEN)

```java
// FORBIDDEN — Duplicate base property in profiles
// If simulator.socket.port=8583 is the same in dev/staging/prod,
// keep it ONLY in application.yml

// FORBIDDEN — @Value for groups of 3+ properties
@Value("${simulator.socket.port}") int port;
@Value("${simulator.socket.host}") String host;
@Value("${simulator.socket.max-connections}") int maxConnections;
// Use @ConfigurationProperties

// FORBIDDEN — Hardcoded values in Java
private static final int PORT = 8583;  // Should come from config

// FORBIDDEN — spring.jpa.open-in-view=true (causes lazy loading issues)
// Always set to false explicitly

// FORBIDDEN — spring.jpa.hibernate.ddl-auto=update in production
// Use Flyway migrations

// FORBIDDEN — Credentials in YAML without env var reference
spring:
  datasource:
    password: mySecretPassword123  # Should be ${DB_PASSWORD}

// FORBIDDEN — OTel enabled in dev/test
management:
  tracing:
    enabled: true  # Only in staging/prod

// FORBIDDEN — Missing random port in test profile
server:
  port: 8080  # Should be 0 for tests to avoid CI conflicts
```
