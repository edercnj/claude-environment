# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 08 — Configuration (Quarkus Profiles + SmallRye)

## Principles
- **Profile-based configuration:** each environment has its own properties file
- **Type-safe:** use `@ConfigMapping` (SmallRye) instead of `@ConfigProperty` for groups
- **Override hierarchy:** env var > profile property > base property > `@WithDefault`
- **No duplication:** base properties live in `application.properties`, profile-specific overrides in `application-{profile}.properties`

## File Structure

```
src/main/resources/
├── application.properties              # Base shared (ALL profiles)
├── application-dev.properties          # Overrides for local development
├── application-test.properties         # Overrides for tests (H2, random port)
├── application-staging.properties      # Overrides for staging
└── application-prod.properties         # Overrides for production
```

### Quarkus Override Hierarchy

```
1. Environment Variable (SIMULATOR_SOCKET_PORT=9583)     ← highest priority
2. System Property (-Dsimulator.socket.port=9583)
3. application-{profile}.properties                       ← profile override
4. application.properties                                 ← base shared
5. @WithDefault("8583")                                   ← fallback in code
```

## application.properties (Base Shared)

Contains ONLY configurations that are **identical across all profiles** or serve as **reasonable defaults**:

```properties
# TCP Socket
simulator.socket.port=8583
simulator.socket.host=0.0.0.0
simulator.socket.max-connections=100
simulator.socket.idle-timeout=300
simulator.socket.read-timeout=30
simulator.socket.length-header-bytes=2

# ISO 8583
simulator.iso.default-version=1993

# Datasource (PostgreSQL as default)
quarkus.datasource.db-kind=postgresql
quarkus.datasource.jdbc.url=${DB_URL:jdbc:postgresql://localhost:5432/authorizer_simulator}
quarkus.datasource.username=${DB_USER:simulator}
quarkus.datasource.password=${DB_PASSWORD:simulator}

# Hibernate
quarkus.hibernate-orm.database.default-schema=simulator
quarkus.hibernate-orm.database.generation=none

# Flyway
quarkus.flyway.enabled=true
quarkus.flyway.migrate-at-start=true
quarkus.flyway.default-schema=simulator

# Health
quarkus.health.extensions.enabled=true

# OpenTelemetry (disabled by default, enabled in staging/prod)
quarkus.otel.enabled=false
```

## Differences by Profile

| Configuration | dev | test | staging | prod |
|-------------|-----|------|---------|------|
| DB kind | postgresql (DevServices) | **h2** | postgresql | postgresql |
| Flyway | enabled | **disabled** | enabled | enabled |
| Hibernate generation | none | **drop-and-create** | none | none |
| Socket port | 8583 | **0** (random) | 8583 | 8583 |
| OTel | disabled | disabled | **enabled** | **enabled** |
| Log format | text | text | **JSON** | **JSON** |
| Swagger UI | **included** | excluded | excluded | excluded |

### application-dev.properties
```properties
# DevServices manages PostgreSQL automatically
quarkus.devservices.enabled=true
quarkus.otel.enabled=false
quarkus.swagger-ui.always-include=true
```

### application-test.properties
```properties
# H2 in PostgreSQL mode — lightweight and fast for tests
quarkus.datasource.db-kind=h2
quarkus.datasource.jdbc.url=jdbc:h2:mem:testdb;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH
quarkus.datasource.username=sa
quarkus.datasource.password=

# Hibernate manages schema (no Flyway)
quarkus.hibernate-orm.database.generation=drop-and-create
quarkus.hibernate-orm.database.default-schema=simulator
quarkus.flyway.enabled=false

# Random port to avoid CI conflicts
simulator.socket.port=0

# Swagger disabled in tests
quarkus.swagger-ui.always-include=false
```

### application-staging.properties / application-prod.properties
```properties
quarkus.otel.enabled=true
quarkus.log.console.json=true
quarkus.log.level=INFO
```

## @ConfigMapping (SmallRye) — Mandatory Pattern

For **configuration groups** (3+ properties with common prefix), use `@ConfigMapping` with interface:

```java
// ✅ CORRECT — @ConfigMapping with hierarchical interface
@ConfigMapping(prefix = "simulator")
public interface SimulatorConfig {

    SocketConfig socket();
    IsoConfig iso();

    interface SocketConfig {
        @WithDefault("8583")
        int port();

        @WithDefault("0.0.0.0")
        String host();

        @WithDefault("100")
        int maxConnections();

        @WithDefault("300")
        int idleTimeout();

        @WithDefault("30")
        int readTimeout();

        @WithDefault("2")
        int lengthHeaderBytes();
    }

    interface IsoConfig {
        @WithDefault("1993")
        String defaultVersion();
    }
}
```

**Usage in code:**
```java
@ApplicationScoped
public class TcpServer {
    private final SimulatorConfig config;

    @Inject
    public TcpServer(SimulatorConfig config) {
        this.config = config;
    }

    void start() {
        int port = config.socket().port();
        String host = config.socket().host();
        // ...
    }
}
```

### When to Use @ConfigProperty vs @ConfigMapping

| Scenario | Use |
|---------|------|
| Isolated property (1-2 properties) | `@ConfigProperty` |
| Group of 3+ properties with common prefix | `@ConfigMapping` (interface) |
| Simulator configuration (`simulator.*`) | `SimulatorConfig` (already exists) |
| Quarkus property (`quarkus.*`) | Only in `application.properties` |

```java
// ✅ CORRECT — isolated property
@ConfigProperty(name = "simulator.socket.port")
int port;

// ❌ WRONG — group of properties without @ConfigMapping
@ConfigProperty(name = "simulator.socket.port") int port;
@ConfigProperty(name = "simulator.socket.host") String host;
@ConfigProperty(name = "simulator.socket.max-connections") int maxConnections;
@ConfigProperty(name = "simulator.socket.idle-timeout") int idleTimeout;
// Should be SimulatorConfig.socket()
```

## Resilience (Rule 24)

Resilience properties are configured via `application.properties` and `@ConfigMapping`:

| Prefix | Pattern | Technology |
|--------|--------|-----------|
| `simulator.resilience.rate-limit.*` | Rate Limiting | Bucket4j |
| `simulator.resilience.degradation.*` | Graceful Degradation | Custom |
| `{Class}/{method}/CircuitBreaker/*` | Circuit Breaker | MicroProfile FT |
| `{Class}/{method}/Retry/*` | Retry | MicroProfile FT |
| `{Class}/{method}/Timeout/*` | Timeout | MicroProfile FT |
| `{Class}/{method}/Bulkhead/*` | Bulkhead | MicroProfile FT |

> See **Rule 24 — Resilience of Application** for default values, `@ConfigMapping` and complete documentation.

## Anti-Patterns

- ❌ Duplicate base property in profiles — if it's the same across all profiles, keep it only in `application.properties`
- ❌ Use `@ConfigProperty` for groups of 3+ properties — use `@ConfigMapping`
- ❌ Hardcode configuration values in Java code — always externalize
- ❌ Use Testcontainers when H2 `MODE=PostgreSQL` is sufficient for the test
- ❌ Leave OTel enabled in dev/test — causes unnecessary overhead
- ❌ Use `quarkus.hibernate-orm.database.generation=update` in production — use Flyway
- ❌ Forget `simulator.socket.port=0` in test profile — causes port conflict in CI
