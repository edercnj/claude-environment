# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot — Native Build (Spring AOT / GraalVM)

> Extends: `core/10-infrastructure-principles.md`
> All container, security, and deployment principles apply.

## Performance Targets

| Metric | JVM Mode | Native Mode |
|--------|----------|-------------|
| Startup time | ~2s | < 200ms |
| RSS Memory (idle) | ~256MB | < 128MB |
| First request latency | ~500ms | < 100ms |
| Docker image size | ~300MB | < 100MB |

## Spring AOT Processing

Spring Boot 3.x includes Spring AOT (Ahead-of-Time) processing that pre-computes bean definitions, configuration metadata, and proxies at build time for GraalVM native compilation.

### How It Works

1. **Build time:** Spring AOT analyzes the application context and generates optimized code
2. **Compilation:** GraalVM compiles the AOT-processed code into a native binary
3. **Runtime:** Native binary starts without class scanning, reflection, or proxy generation

### AOT Phases

| Phase | What Happens | Output |
|-------|-------------|--------|
| Bean Definition | Scans `@Component`, `@Service`, etc. | Programmatic bean registration |
| Configuration | Resolves `@ConfigurationProperties`, `@Value` | Static bindings |
| Proxy Generation | Pre-generates CGLIB/JDK proxies | Concrete proxy classes |
| Reflection Hints | Records reflection needs | `reflect-config.json` |
| Resource Hints | Records resource needs | `resource-config.json` |

## @RegisterReflectionForBinding

Records and classes used in JSON serialization/deserialization MUST be registered:

```java
// Request DTOs
@RegisterReflectionForBinding
public record CreateMerchantRequest(
    @NotBlank String mid,
    @NotBlank String name,
    @NotBlank String document,
    @NotBlank String mcc
) {}

// Response DTOs
@RegisterReflectionForBinding
public record MerchantResponse(
    Long id,
    String mid,
    String name,
    String documentMasked,
    String mcc,
    String status,
    OffsetDateTime createdAt,
    OffsetDateTime updatedAt
) {}

// Error responses
@RegisterReflectionForBinding
public record ProblemDetail(
    String type,
    String title,
    int status,
    String detail,
    String instance,
    Map<String, Object> extensions
) {}

// Paginated wrapper (nested record ALSO needs it)
@RegisterReflectionForBinding
public record PaginatedResponse<T>(
    List<T> data,
    PaginationInfo pagination
) {
    @RegisterReflectionForBinding
    public record PaginationInfo(int page, int limit, long total, int totalPages) {}
}

// Enums deserialized via Jackson
@RegisterReflectionForBinding
public enum MerchantStatus { ACTIVE, INACTIVE, SUSPENDED }
```

### Where Reflection Registration is Mandatory

| Element | Annotation | Reason |
|---------|-----------|--------|
| REST request records | `@RegisterReflectionForBinding` | Jackson deserialization |
| REST response records | `@RegisterReflectionForBinding` | Jackson serialization |
| Error/ProblemDetail records | `@RegisterReflectionForBinding` | Jackson serialization |
| Nested records in DTOs | `@RegisterReflectionForBinding` | Jackson does not auto-detect |
| Enums in DTOs | `@RegisterReflectionForBinding` | Jackson enum deserialization |
| `@ConfigurationProperties` records | Automatic (Spring AOT) | Handled by AOT |
| JPA Entities | Automatic (Hibernate) | Handled by Hibernate |
| Spring-managed beans | Automatic (Spring AOT) | Handled by AOT |

## RuntimeHintsRegistrar

For programmatic reflection/resource hints when annotations are not sufficient:

```java
public class SimulatorRuntimeHints implements RuntimeHintsRegistrar {

    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        // Register classes for reflection
        hints.reflection().registerType(CreateMerchantRequest.class,
            MemberCategory.INVOKE_DECLARED_CONSTRUCTORS,
            MemberCategory.INVOKE_DECLARED_METHODS);

        hints.reflection().registerType(MerchantResponse.class,
            MemberCategory.INVOKE_DECLARED_CONSTRUCTORS,
            MemberCategory.INVOKE_DECLARED_METHODS);

        // Register resources
        hints.resources().registerPattern("db/migration/*");
        hints.resources().registerPattern("META-INF/services/*");

        // Register serialization
        hints.serialization().registerType(MerchantStatus.class);
    }
}

// Register via annotation on main class or @Configuration
@ImportRuntimeHints(SimulatorRuntimeHints.class)
@SpringBootApplication
public class AuthorizerSimulatorApplication {
    public static void main(String[] args) {
        SpringApplication.run(AuthorizerSimulatorApplication.class, args);
    }
}
```

## Forbidden Patterns in Native Mode

| Forbidden | Alternative |
|-----------|-------------|
| `Class.forName("...")` | Use direct class reference or register hints |
| `Method.invoke(...)` (dynamic) | Pre-register with `@RegisterReflectionForBinding` |
| `Proxy.newProxyInstance(...)` | Use Spring AOT-generated proxies |
| Static initializers with I/O | Use `@PostConstruct` or `ApplicationRunner` |
| Dynamic classloading at runtime | Register all classes at build time |
| `java.lang.reflect.Proxy` | Use interface-based Spring beans |
| CGLIB proxies on final classes | Remove `final` or use interface-based injection |

```java
// FORBIDDEN — Dynamic Class.forName
var clazz = Class.forName(className);  // Fails in native

// CORRECT — Direct reference or RuntimeHints
hints.reflection().registerType(MyClass.class, MemberCategory.values());

// FORBIDDEN — Static init with I/O
public class Config {
    private static final Properties props = loadPropsFromFile();  // Fails in native
}

// CORRECT — PostConstruct
@Component
public class Config {
    private Properties props;

    @PostConstruct
    void init() {
        this.props = loadPropsFromFile();
    }
}
```

## Build Commands

### Maven Native Build

```bash
# Native compile (requires GraalVM installed)
mvn -Pnative native:compile

# Native compile with tests
mvn -Pnative native:compile -Dspring-boot.run.profiles=test

# Native test (run tests as native image)
mvn -Pnative native:test

# Skip native tests for faster build
mvn -Pnative native:compile -DskipNativeTests
```

### Cloud Native Buildpacks (No GraalVM Required)

```bash
# Build native image via Buildpacks (uses Paketo builder)
mvn -Pnative spring-boot:build-image

# With custom image name
mvn -Pnative spring-boot:build-image \
    -Dspring-boot.build-image.imageName=authorizer-simulator:native

# Build JVM image via Buildpacks
mvn spring-boot:build-image \
    -Dspring-boot.build-image.imageName=authorizer-simulator:jvm
```

## Maven Native Profile Configuration

```xml
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
                            <buildArg>-H:+ReportExceptionStackTraces</buildArg>
                        </buildArgs>
                        <metadataRepository>
                            <enabled>true</enabled>
                        </metadataRepository>
                    </configuration>
                </plugin>
                <plugin>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-maven-plugin</artifactId>
                    <configuration>
                        <image>
                            <builder>paketobuildpacks/builder-jammy-tiny:latest</builder>
                            <env>
                                <BP_NATIVE_IMAGE>true</BP_NATIVE_IMAGE>
                            </env>
                        </image>
                    </configuration>
                </plugin>
            </plugins>
        </build>
        <dependencies>
            <dependency>
                <groupId>org.junit.platform</groupId>
                <artifactId>junit-platform-launcher</artifactId>
                <scope>test</scope>
            </dependency>
        </dependencies>
    </profile>
</profiles>
```

## GraalVM Reachability Metadata Repository

Spring Boot 3.x uses the GraalVM Reachability Metadata Repository to automatically include reflection/resource hints for common libraries:

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

Libraries with built-in native support:
- Spring Framework 6.x
- Hibernate 6.x
- Jackson
- Logback
- Flyway
- HikariCP

Libraries that may need manual hints:
- Custom reflection-based code
- Third-party libraries without metadata
- ISO 8583 parsing libraries

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `ClassNotFoundException` at runtime | Class not registered for reflection | Add `@RegisterReflectionForBinding` |
| `NoSuchMethodException` on constructor | Record constructor not in hints | Register with `MemberCategory.INVOKE_DECLARED_CONSTRUCTORS` |
| Jackson serialization fails | DTO not registered | Add `@RegisterReflectionForBinding` on record |
| Flyway migration not found | Resources not in native image | Register in `RuntimeHintsRegistrar` |
| `@ConfigurationProperties` fails | AOT not processing custom binder | Ensure `@ConfigurationPropertiesScan` is present |
| Proxy creation fails | Final class or missing interface | Use interface-based injection |
| Native test fails with missing bean | Conditional bean not resolved at AOT | Review `@ConditionalOn*` annotations |
| Build fails with "unresolved type" | Library not in reachability metadata | Add manual hints or contribute to metadata repo |

## Build Environments

| Environment | Build | Image | Startup |
|-------------|-------|-------|---------|
| Dev | JVM (hot reload) | eclipse-temurin:21-jre-alpine | ~2s |
| Test/CI | JVM | eclipse-temurin:21-jre-alpine | ~2s |
| Staging | Native | Buildpacks or custom Dockerfile | < 200ms |
| **Production** | **Native** | **Buildpacks or custom Dockerfile** | **< 200ms** |

## Anti-Patterns (FORBIDDEN)

```java
// FORBIDDEN — Dynamic Class.forName without hint
Class.forName(config.getHandlerClass());

// FORBIDDEN — Reflection without registration
field.setAccessible(true);
field.set(target, value);

// FORBIDDEN — Static initialization with I/O
private static final Config INSTANCE = loadFromDisk();

// FORBIDDEN — Dynamic proxy without interface
Proxy.newProxyInstance(loader, new Class[]{ConcreteClass.class}, handler);

// FORBIDDEN — Missing @RegisterReflectionForBinding on DTO records
public record MerchantResponse(Long id, String mid) {}  // Will fail in native

// FORBIDDEN — @ConditionalOnClass with non-existent class string
@ConditionalOnClass(name = "com.example.MaybeNotThere")  // Fragile in native

// FORBIDDEN — Using ServiceLoader without META-INF/services registration
ServiceLoader.load(MyInterface.class);  // Register in RuntimeHints

// FORBIDDEN — Final class with AOP proxy
@Transactional  // Needs CGLIB proxy
public final class MerchantService { ... }  // Remove final
```
