# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Spring Boot — Native Build (GraalVM / Spring AOT)

> Spring Boot 3.x supports GraalVM native images via Spring AOT (Ahead-of-Time) processing. This rule defines compatibility constraints and patterns.

## Performance Targets (Native)

| Metric                | Target     |
| --------------------- | ---------- |
| Startup time          | < 200ms    |
| RSS Memory (idle)     | < 256MB    |
| First request latency | < 100ms    |
| Throughput            | > 500 TPS  |

> Spring Boot native is heavier than Quarkus native. Targets are relaxed accordingly but still represent significant improvement over JVM mode (typically 2-5s startup, 512MB+ RSS).

## Native Compatibility Matrix

| Allowed                                            | Forbidden                               |
| -------------------------------------------------- | --------------------------------------- |
| Spring DI (`@Service`, `@Component`, `@Bean`)      | Reflection without `@RegisterReflectionForBinding` |
| Records (natively supported)                       | Dynamic `Class.forName()`               |
| Sealed interfaces (natively supported)             | Dynamic proxies without config          |
| Jackson serialization (with reflection hints)      | Static initialization with I/O          |
| Spring Data JPA repositories                       | Dynamic classloading at runtime         |
| `@ConfigurationProperties` with records            | `java.lang.reflect.Proxy` without registry |
| Interface-based proxies (Spring default)           | CGLIB proxies on final classes          |

## Spring AOT (Ahead-of-Time) Processing

Spring AOT analyzes the application at build time and generates:
- Bean definitions as source code (no runtime reflection for DI)
- Reflection hints for classes that need it
- Proxy hints for interfaces
- Resource hints for classpath resources

AOT runs automatically during native build. No manual configuration needed for standard Spring patterns.

## @RegisterReflectionForBinding Rules

Spring's equivalent of Quarkus's `@RegisterForReflection`. Registers classes for Jackson serialization/deserialization in native images.

### WHERE it IS mandatory

```java
// REST request records (deserialized by Jackson)
@RegisterReflectionForBinding
public record CreateMerchantRequest(
    @NotBlank @Size(max = 15) String mid,
    @NotBlank @Size(max = 100) String name
) {}

// REST response records (serialized by Jackson)
@RegisterReflectionForBinding
public record MerchantResponse(Long id, String mid, String name, String status) {}

// Error response records
@RegisterReflectionForBinding
public record ProblemDetail(String type, String title, int status, String detail, String instance) {}

// Generic wrappers AND nested records
@RegisterReflectionForBinding
public record PaginatedResponse<T>(List<T> data, PaginationInfo pagination) {
    @RegisterReflectionForBinding
    public record PaginationInfo(int page, int limit, long total, int totalPages) {}
}

// Enums deserialized via Jackson
@RegisterReflectionForBinding
public enum TransactionStatus { PENDING, APPROVED, DENIED, REVERSED }
```

### WHERE it is NOT necessary

```java
// JPA Entities — Hibernate registers automatically
@Entity
@Table(name = "merchants", schema = "simulator")
public class MerchantEntity { ... }

// Internal domain models that never pass through Jackson
public record Transaction(String mti, String stan, String responseCode) {}

// Mappers and utility classes (not serialized)
public final class MerchantDtoMapper { ... }

// Spring-managed beans (AOT handles these)
@Service
public class TransactionService { ... }
```

## RuntimeHints — Programmatic Registration

For cases where annotations are insufficient or for third-party classes:

```java
public class ApplicationRuntimeHints implements RuntimeHintsRegistrar {

    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        // Register third-party class for reflection
        hints.reflection().registerType(
            ThirdPartyDto.class,
            MemberCategory.INVOKE_DECLARED_CONSTRUCTORS,
            MemberCategory.INVOKE_DECLARED_METHODS,
            MemberCategory.DECLARED_FIELDS
        );

        // Register resource files
        hints.resources().registerPattern("db/migration/*.sql");

        // Register proxy interface
        hints.proxies().registerJdkProxy(MyServiceInterface.class);
    }
}
```

**Activate in main class:**
```java
@SpringBootApplication
@ImportRuntimeHints(ApplicationRuntimeHints.class)
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

**Rules:**
- Use `@RegisterReflectionForBinding` on your own classes first
- Use `RuntimeHintsRegistrar` for third-party classes or complex scenarios
- Register with `@ImportRuntimeHints` on `@Configuration` or `@SpringBootApplication` class
- Test hints with `RuntimeHintsPredicates` in unit tests

### Testing RuntimeHints

```java
@Test
void runtimeHints_registersThirdPartyDto() {
    var hints = new RuntimeHints();
    new ApplicationRuntimeHints().registerHints(hints, getClass().getClassLoader());

    assertThat(RuntimeHintsPredicates.reflection()
        .onType(ThirdPartyDto.class)
        .withMemberCategories(MemberCategory.INVOKE_DECLARED_CONSTRUCTORS))
        .accepts(hints);
}
```

## Forbidden Patterns in Native

### Dynamic Reflection

```java
// FORBIDDEN — will fail at native runtime
Class<?> clazz = Class.forName("com.example.SomeClass");
Object instance = clazz.getDeclaredConstructor().newInstance();

// ALLOWED — use Spring DI instead
@Autowired
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

// ALLOWED — use Spring configuration
@ConfigurationProperties(prefix = "app")
public record AppConfig(String someProperty) {}
```

### Dynamic Proxies

```java
// FORBIDDEN — dynamic proxy without registration
Proxy.newProxyInstance(classLoader, interfaces, handler);

// ALLOWED — Spring-managed beans and standard proxies are handled by AOT
```

### CGLIB Proxies on Final Classes

```java
// FORBIDDEN — CGLIB cannot proxy final class in native
@Service
public final class TransactionService { ... }

// ALLOWED — use interface-based proxying
public interface TransactionService { ... }

@Service
public class TransactionServiceImpl implements TransactionService { ... }

// ALSO ALLOWED — non-final class (Spring default CGLIB works)
@Service
public class TransactionService { ... }
```

### Conditional Beans with Runtime Checks

```java
// PROBLEMATIC — condition evaluated at build time in native, may not work as expected
@Bean
@ConditionalOnProperty(name = "feature.enabled", havingValue = "true")
public FeatureService featureService() { ... }

// SAFER — use @Profile for environment-based conditions
@Bean
@Profile("prod")
public FeatureService featureService() { ... }
```

**Note:** `@ConditionalOnProperty` works in native mode but the evaluation happens at build time during AOT processing. Ensure the property is available at build time or use `@Profile` instead.

### Heavy Static Initialization

```java
// FORBIDDEN — static connection pool
public class DbPool {
    private static final DataSource DS = createDataSource(); // I/O in static init
}

// ALLOWED — Spring-managed lifecycle
@Configuration
public class DbConfig {
    @Bean
    public DataSource dataSource() {
        return createDataSource(); // Managed by Spring
    }
}
```

## Build Commands

```bash
# Dev (JVM mode — hot reload with DevTools)
mvn spring-boot:run

# Test (JVM mode)
mvn verify

# Production (Native — requires GraalVM installed locally)
mvn -Pnative native:compile

# Production (Native — container build, no local GraalVM needed)
mvn -Pnative spring-boot:build-image

# Native with specific GraalVM args
mvn -Pnative native:compile -Dnative.build.args="--initialize-at-build-time"
```

### Build Profiles

| Environment | Build | Command | Startup |
|----------|-------|---------|---------|
| Dev | JVM (hot reload) | `mvn spring-boot:run` | ~2-5s |
| Test/CI | JVM | `mvn verify` | ~2-5s |
| Staging | Native | `mvn -Pnative native:compile` | < 200ms |
| **Production** | **Native** | **`mvn -Pnative spring-boot:build-image`** | **< 200ms** |

## Maven Configuration

### spring-boot-starter-parent with native profile

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.4.x</version>
</parent>

<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
</dependencies>

<profiles>
    <profile>
        <id>native</id>
        <build>
            <plugins>
                <plugin>
                    <groupId>org.graalvm.buildtools</groupId>
                    <artifactId>native-maven-plugin</artifactId>
                    <configuration>
                        <buildArgs>
                            <buildArg>--initialize-at-build-time</buildArg>
                        </buildArgs>
                    </configuration>
                </plugin>
            </plugins>
        </build>
    </profile>
</profiles>
```

## GraalVM Reachability Metadata Repository

Spring Boot 3.x integrates with the [GraalVM Reachability Metadata Repository](https://github.com/oracle/graalvm-reachability-metadata), which provides pre-built native metadata for popular libraries.

```xml
<plugin>
    <groupId>org.graalvm.buildtools</groupId>
    <artifactId>native-maven-plugin</artifactId>
    <configuration>
        <metadataRepository>
            <enabled>true</enabled>
        </metadataRepository>
    </configuration>
</plugin>
```

Libraries with metadata available include: Jackson, Hibernate, Flyway, Logback, SLF4J, and many more. This eliminates the need for manual reflection hints for most common dependencies.

## Buildpacks Alternative

Spring Boot supports building native OCI images without installing GraalVM locally using Cloud Native Buildpacks:

```bash
# Build native OCI image (no local GraalVM required)
mvn -Pnative spring-boot:build-image

# With custom image name
mvn -Pnative spring-boot:build-image \
    -Dspring-boot.build-image.imageName=myregistry/my-application:native

# Run the native image
docker run -p 8080:8080 myregistry/my-application:native
```

**Advantages:**
- No local GraalVM installation needed
- Reproducible builds across CI environments
- Produces optimized OCI images directly
- Automatic layering for efficient caching

**Disadvantages:**
- Slower than local native compilation (downloads builder image)
- Requires Docker daemon running
- Less control over GraalVM configuration

## Native Build Troubleshooting

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `ClassNotFoundException` at runtime | Class used via reflection | Add `@RegisterReflectionForBinding` or `RuntimeHints` |
| `UnsupportedFeatureError` | Dynamic proxy | Register in `RuntimeHintsRegistrar` |
| Build failure with static init | I/O in `static {}` block | Move to `@PostConstruct` or `@Bean` lifecycle |
| Missing method at runtime | Method accessed via reflection | Add reflection hint for containing class |
| `ImageBuildError` with third-party lib | Library uses reflection internally | Check reachability metadata repo or add manual hints |
| `BeanDefinitionStoreException` | `@Conditional` evaluated at build time | Use `@Profile` or ensure property available at build time |
| CGLIB proxy failure | Final class cannot be proxied | Remove `final` modifier or use interface-based proxy |

### Reflection Configuration (Escape Hatch)

For third-party classes that need reflection but cannot be annotated:

```json
// src/main/resources/META-INF/native-image/reflect-config.json
[
  {
    "name": "com.thirdparty.SomeClass",
    "allDeclaredConstructors": true,
    "allPublicMethods": true,
    "allDeclaredFields": true
  }
]
```

Use this as a **last resort** — prefer `@RegisterReflectionForBinding` and `RuntimeHintsRegistrar`.

## Testing Native Build

```java
// Use @SpringBootTest with native profile for native integration tests
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class NativeHealthCheckIT {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void healthCheck_nativeBuild_returns200() {
        var response = restTemplate.getForEntity("/actuator/health/liveness", String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }
}
```

Run native tests:
```bash
mvn -PnativeTest verify
```

## Anti-Patterns

- Using `Class.forName()` for dynamic class loading
- Static blocks with I/O operations (file reads, network calls, connection pools)
- Dynamic proxies without explicit registration
- Forgetting `@RegisterReflectionForBinding` on REST DTOs
- Using `java.lang.reflect.*` directly without native registration
- Using `final` on `@Service`/`@Component` classes that need CGLIB proxying
- Relying on `@ConditionalOnProperty` for runtime-varying properties in native
- Third-party libraries that rely heavily on reflection without providing GraalVM metadata
- Using `Unsafe` or internal JDK APIs
- Skipping `RuntimeHints` testing — hints failures only manifest at native runtime
