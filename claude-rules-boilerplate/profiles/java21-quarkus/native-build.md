# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Quarkus — Native Build (GraalVM / Mandrel)

> Quarkus Native Build is mandatory for production. This rule defines compatibility constraints and patterns.

## Performance Targets (Native)

| Metric                | Target     |
| --------------------- | ---------- |
| Startup time          | < 100ms    |
| RSS Memory (idle)     | < 128MB    |
| First request latency | < 50ms     |
| Throughput            | > 1000 TPS |

## Native Compatibility Matrix

| Allowed                                            | Forbidden                               |
| -------------------------------------------------- | --------------------------------------- |
| CDI (`@ApplicationScoped`, `@Inject`)              | Reflection without `@RegisterForReflection` |
| Records (natively supported)                       | Dynamic `Class.forName()`               |
| Sealed interfaces (natively supported)             | Dynamic proxies without config          |
| Jackson serialization (with `@RegisterForReflection`) | Static initialization with I/O          |
| Panache repositories                               | Dynamic classloading at runtime         |
| Vert.x handlers                                    | `java.lang.reflect.Proxy` without registry |

## @RegisterForReflection Rules

### WHERE it IS mandatory

```java
// REST request records (deserialized by Jackson)
@RegisterForReflection
public record CreateMerchantRequest(
    @NotBlank @Size(max = 15) String mid,
    @NotBlank @Size(max = 100) String name
) {}

// REST response records (serialized by Jackson)
@RegisterForReflection
public record MerchantResponse(Long id, String mid, String name, String status) {}

// Error response records
@RegisterForReflection
public record ProblemDetail(String type, String title, int status, String detail, String instance) {}

// Generic wrappers AND nested records
@RegisterForReflection
public record PaginatedResponse<T>(List<T> data, PaginationInfo pagination) {
    @RegisterForReflection
    public record PaginationInfo(int page, int limit, long total, int totalPages) {}
}

// Enums deserialized via Jackson
@RegisterForReflection
public enum TransactionStatus { PENDING, APPROVED, DENIED, REVERSED }
```

### WHERE it is NOT necessary

```java
// JPA Entities — Hibernate/Panache registers automatically
@Entity
@Table(name = "merchants", schema = "simulator")
public class MerchantEntity { ... }

// Internal domain models that never pass through Jackson
public record Transaction(String mti, String stan, String responseCode) {}

// Mappers and utility classes (not serialized)
public final class MerchantDtoMapper { ... }

// CDI beans (already managed by Quarkus)
@ApplicationScoped
public class TransactionService { ... }
```

## Forbidden Patterns in Native

### Dynamic Reflection

```java
// FORBIDDEN — will fail at native runtime
Class<?> clazz = Class.forName("com.example.SomeClass");
Object instance = clazz.getDeclaredConstructor().newInstance();

// ALLOWED — use CDI instead
@Inject
SomeClass instance;
```

### Static Initialization with I/O

```java
// FORBIDDEN — static block with I/O
public class ConfigLoader {
    private static final Properties PROPS;
    static {
        PROPS = new Properties();
        PROPS.load(new FileInputStream("config.properties")); // Fails in native
    }
}

// ALLOWED — use Quarkus config
@ConfigMapping(prefix = "app")
public interface AppConfig {
    String someProperty();
}
```

### Dynamic Proxies

```java
// FORBIDDEN — dynamic proxy without registration
Proxy.newProxyInstance(classLoader, interfaces, handler);

// ALLOWED — CDI beans and standard Quarkus proxies are handled automatically
```

### Heavy Static Initialization

```java
// FORBIDDEN — static connection pool
public class DbPool {
    private static final DataSource DS = createDataSource(); // I/O in static init
}

// ALLOWED — CDI-managed lifecycle
@ApplicationScoped
public class DbPool {
    @Inject
    DataSource dataSource; // Managed by Quarkus
}
```

## Build Commands

```bash
# Dev (JVM mode — hot reload)
mvn quarkus:dev

# Test (JVM mode)
mvn verify

# Production (Native — GraalVM/Mandrel)
mvn package -Dnative -Dquarkus.native.container-build=true

# Native with additional build args
mvn package -Dnative \
    -Dquarkus.native.container-build=true \
    -Dquarkus.native.additional-build-args="--initialize-at-build-time"
```

## Native Build Troubleshooting

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `ClassNotFoundException` at runtime | Class used via reflection | Add `@RegisterForReflection` |
| `UnsupportedFeatureError` | Dynamic proxy | Register proxy in `reflection-config.json` or use CDI |
| Build failure with static init | I/O in `static {}` block | Move to `@PostConstruct` or CDI lifecycle |
| Missing method at runtime | Method accessed via reflection | Add `@RegisterForReflection` on containing class |
| `ImageBuildError` with third-party lib | Library uses reflection internally | Add `--initialize-at-build-time` or provide substitution |

### Reflection Configuration (Escape Hatch)

For third-party classes that need reflection but cannot be annotated:

```json
// src/main/resources/reflection-config.json
[
  {
    "name": "com.thirdparty.SomeClass",
    "allDeclaredConstructors": true,
    "allPublicMethods": true,
    "allDeclaredFields": true
  }
]
```

Reference in `application.properties`:
```properties
quarkus.native.additional-build-args=-H:ReflectionConfigurationFiles=reflection-config.json
```

Use this as a **last resort** — prefer `@RegisterForReflection` on your own classes.

## Testing Native Build

```java
// Use @QuarkusIntegrationTest for native integration tests
@QuarkusIntegrationTest
class NativeHealthCheckIT {

    @Test
    void healthCheck_nativeBuild_returns200() {
        given()
            .when().get("/q/health/live")
            .then().statusCode(200);
    }
}
```

Run native tests:
```bash
mvn verify -Dnative
```

## Anti-Patterns

- Using `Class.forName()` for dynamic class loading
- Static blocks with I/O operations (file reads, network calls, connection pools)
- Dynamic proxies without explicit registration
- Forgetting `@RegisterForReflection` on REST DTOs
- Using `java.lang.reflect.*` directly without native registration
- Third-party libraries that rely heavily on reflection without providing GraalVM metadata
- Using `Unsafe` or internal JDK APIs
