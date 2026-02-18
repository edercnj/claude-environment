# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Spring Boot — Configuration

> Technology-specific configuration patterns for Spring Boot profiles and externalized configuration.

## Principles

- **Profile-based configuration:** each environment has its own YAML file
- **Type-safe:** use `@ConfigurationProperties` for groups of 3+ properties
- **Override hierarchy:** env var > system property > profile YAML > base YAML > `@Value` default
- **No duplication:** base properties live in `application.yml`, profile-specific overrides in `application-{profile}.yml`
- **YAML preferred:** use `application.yml` over `application.properties` for readability and hierarchy

## File Structure

```
src/main/resources/
├── application.yml                    # Base shared (ALL profiles)
├── application-dev.yml                # Overrides for local development
├── application-test.yml               # Overrides for tests (H2, random port)
├── application-staging.yml            # Overrides for staging
└── application-prod.yml               # Overrides for production
```

## Override Hierarchy

```
1. Environment Variable (SIMULATOR_SOCKET_PORT=9583)     <- highest priority
2. System Property (-Dsimulator.socket.port=9583)
3. application-{profile}.yml                              <- profile override
4. application.yml                                        <- base shared
5. @Value("${simulator.socket.port:9090}")                <- fallback in code
```

**Relaxed Binding:** Spring Boot maps properties flexibly:
- `simulator.socket.port` (YAML/properties)
- `SIMULATOR_SOCKET_PORT` (environment variable)
- `simulator.socket-port` (kebab-case — also valid)

All resolve to the same `@ConfigurationProperties` field `socketPort` or `port`.

## application.yml (Base Shared)

Contains ONLY configurations that are identical across all profiles or serve as reasonable defaults:

```yaml
# Application
simulator:
  socket:
    port: 9090
    host: 0.0.0.0
    max-connections: 100
    idle-timeout: 300
    read-timeout: 30
    length-header-bytes: 2

# Datasource (PostgreSQL as default)
spring:
  datasource:
    url: ${DB_URL:jdbc:postgresql://localhost:5432/myapp}
    username: ${DB_USER:simulator}
    password: ${DB_PASSWORD:simulator}
    driver-class-name: org.postgresql.Driver

  # JPA / Hibernate
  jpa:
    hibernate:
      ddl-auto: none
    properties:
      hibernate:
        default_schema: simulator
    open-in-view: false

  # Flyway
  flyway:
    enabled: true
    default-schema: simulator
    locations: classpath:db/migration

# Actuator
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when_authorized
      probes:
        enabled: true

# Server
server:
  port: 8080
  shutdown: graceful

# Logging
logging:
  level:
    root: INFO
    com.example: INFO
```

## Profile Differences

| Configuration | dev | test | staging | prod |
|-------------|-----|------|---------|------|
| DB kind | postgresql (Docker Compose) | **H2** | postgresql | postgresql |
| Flyway | enabled | **disabled** | enabled | enabled |
| Hibernate ddl-auto | none | **create-drop** | none | none |
| Server port | 8080 | **0** (random) | 8080 | 8080 |
| Actuator | full | minimal | full | full |
| Log format | text | text | **JSON** | **JSON** |
| Swagger/OpenAPI | **included** | excluded | excluded | excluded |

### application-dev.yml

```yaml
spring:
  devtools:
    restart:
      enabled: true

springdoc:
  swagger-ui:
    enabled: true

logging:
  level:
    com.example: DEBUG
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

# Random port to avoid CI conflicts
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
logging:
  pattern:
    console: '{"timestamp":"%d","level":"%p","logger":"%c","message":"%m","trace_id":"%X{traceId}","span_id":"%X{spanId}"}%n'

management:
  tracing:
    enabled: true
    sampling:
      probability: 1.0
  otlp:
    tracing:
      endpoint: ${OTEL_ENDPOINT:http://otel-collector:4318/v1/traces}
```

## @ConfigurationProperties — Mandatory Pattern

For configuration groups (3+ properties with common prefix), use `@ConfigurationProperties` with a record or POJO:

```java
@ConfigurationProperties(prefix = "simulator")
public record SimulatorProperties(SocketProperties socket, IsoProperties iso) {

    public record SocketProperties(
        int port,
        String host,
        int maxConnections,
        int idleTimeout,
        int readTimeout,
        int lengthHeaderBytes
    ) {
        public SocketProperties {
            if (port < 0) throw new IllegalArgumentException("Port must be >= 0");
            if (maxConnections <= 0) throw new IllegalArgumentException("Max connections must be > 0");
        }
    }

    public record IsoProperties(String defaultVersion) {}
}
```

**Enable scanning in main class or config:**
```java
@SpringBootApplication
@ConfigurationPropertiesScan
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

**Usage in code:**
```java
@Service
public class TcpServer {
    private final SimulatorProperties.SocketProperties socketConfig;

    public TcpServer(SimulatorProperties properties) {
        this.socketConfig = properties.socket();
    }

    void start() {
        int port = socketConfig.port();
        String host = socketConfig.host();
    }
}
```

**Rules:**
- Prefer Records for `@ConfigurationProperties` (immutable, validated in compact constructor)
- Spring Boot 3.x+ supports records natively with `@ConfigurationProperties`
- Enable with `@ConfigurationPropertiesScan` or `@EnableConfigurationProperties(SimulatorProperties.class)`
- Validation annotations (`@NotBlank`, `@Min`, `@Max`) work on record components

## @Value vs @ConfigurationProperties

| Scenario | Use |
|---------|------|
| Isolated property (1-2 properties) | `@Value("${property.name:default}")` |
| Group of 3+ properties with common prefix | `@ConfigurationProperties` (record) |
| Application-specific config (`simulator.*`) | `SimulatorProperties` |
| Spring property (`spring.*`) | Only in YAML files |

```java
// CORRECT — isolated property
@Value("${simulator.socket.port:9090}")
private int port;

// WRONG — group of properties without @ConfigurationProperties
@Value("${simulator.socket.port:9090}") private int port;
@Value("${simulator.socket.host:0.0.0.0}") private String host;
@Value("${simulator.socket.max-connections:100}") private int maxConnections;
@Value("${simulator.socket.idle-timeout:300}") private int idleTimeout;
// Should be SimulatorProperties.socket()
```

## @Profile — Conditional Beans

```java
@Configuration
public class DataSourceConfig {

    @Bean
    @Profile("dev")
    public DataSource devDataSource() {
        // embedded or Docker Compose datasource
    }

    @Bean
    @Profile("prod")
    public DataSource prodDataSource() {
        // production datasource with connection pool tuning
    }
}
```

**Rules:**
- Use `@Profile` for environment-specific beans (datasources, external clients, feature flags)
- Prefer YAML-based configuration over `@Profile` beans when possible
- Activate profiles via: `spring.profiles.active=dev` (YAML), `SPRING_PROFILES_ACTIVE=prod` (env var), or `--spring.profiles.active=staging` (CLI)

## Actuator Health Probes

Spring Boot Actuator exposes Kubernetes-compatible probes:

| Probe | Endpoint | Purpose |
|-------|----------|---------|
| Liveness | `/actuator/health/liveness` | Application is running |
| Readiness | `/actuator/health/readiness` | Application is ready to serve |
| Health | `/actuator/health` | Overall health (all indicators) |

```yaml
management:
  endpoint:
    health:
      probes:
        enabled: true
      show-details: when_authorized
      group:
        readiness:
          include: db,diskSpace
```

## Anti-Patterns

- Duplicate base property in profiles — if it is the same across all profiles, keep it only in `application.yml`
- Use `@Value` for groups of 3+ properties — use `@ConfigurationProperties`
- Hardcode configuration values in Java code — always externalize
- Use Testcontainers when H2 `MODE=PostgreSQL` is sufficient for the test
- Leave tracing enabled in dev/test — causes unnecessary overhead
- Use `spring.jpa.hibernate.ddl-auto=update` in production — use Flyway
- Forget `server.port=0` in test profile — causes port conflict in CI
- Use `spring.jpa.open-in-view=true` — causes lazy loading issues and performance problems (set to `false`)
- Put secrets in `application.yml` committed to Git — use environment variables or external secret management
