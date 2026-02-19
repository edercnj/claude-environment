# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot 3.x — Version-Specific Rules

> Extends: `frameworks/spring-boot/common/` (all common patterns apply)

## Version Summary

| Aspect | Spring Boot 3.x |
|--------|-----------------|
| Namespace | `jakarta.*` (Jakarta EE 10) |
| Java minimum | 17+ (21 recommended) |
| Spring Framework | 6.x |
| Spring Security | 6.x (`SecurityFilterChain`, component-based) |
| Spring Data JPA | 3.x (Hibernate 6.x) |
| Observability | Micrometer Observation API + OpenTelemetry bridge |
| Native Build | GraalVM AOT (integrated, production-ready) |
| Virtual Threads | Supported (Java 21+, `spring.threads.virtual.enabled=true`) |
| Status | **Current — recommended version** |

## Namespace: jakarta.*

All imports use the Jakarta EE 10 namespace:

```java
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import jakarta.persistence.Id;
import jakarta.persistence.GeneratedValue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import jakarta.servlet.http.HttpServletRequest;
```

## Key Differences from Spring Boot 2.x

| Feature | Spring Boot 2.x | Spring Boot 3.x |
|---------|-----------------|-----------------|
| Namespace | `javax.*` | `jakarta.*` |
| Java minimum | 8+ | 17+ |
| Spring Security | `WebSecurityConfigurerAdapter` | `SecurityFilterChain` |
| Observability | Micrometer only | Observation API + OTel bridge |
| Native Build | Experimental | GraalVM AOT (integrated) |
| HTTP Client | `RestTemplate` | `RestClient` (preferred) |
| Problem Details | Manual | `ProblemDetail` built-in (RFC 7807) |
| Hibernate | 5.x | 6.x |
| Virtual Threads | Not supported | `spring.threads.virtual.enabled=true` |

## Mandatory Patterns (Spring Boot 3.x)

### Spring Security Configuration (Component-Based)

```java
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health/**").permitAll()
                .requestMatchers("/api/**").authenticated()
            )
            .httpBasic(Customizer.withDefaults())
            .build();
    }
}
```

### JPA Entity

```java
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import jakarta.persistence.Id;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;

@Entity
@Table(name = "merchants")
public class MerchantEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 15, unique = true)
    private String mid;
}
```

### REST Controller with ProblemDetail (RFC 7807)

```java
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.http.ProblemDetail;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/merchants")
public class MerchantController {

    @GetMapping
    public List<MerchantResponse> list() { ... }

    @PostMapping
    public ResponseEntity<MerchantResponse> create(@Valid @RequestBody CreateMerchantRequest request) { ... }
}
```

### Error Handling (ProblemDetail)

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MerchantNotFoundException.class)
    public ProblemDetail handleNotFound(MerchantNotFoundException ex) {
        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Not Found");
        problem.setType(URI.create("/errors/not-found"));
        return problem;
    }
}
```

### Observability (Observation API + OpenTelemetry)

```java
import io.micrometer.observation.Observation;
import io.micrometer.observation.ObservationRegistry;

@Service
public class TransactionService {
    private final ObservationRegistry registry;

    public TransactionService(ObservationRegistry registry) {
        this.registry = registry;
    }

    public TransactionResult process(Transaction tx) {
        return Observation.createNotStarted("transaction.process", registry)
            .lowCardinalityKeyValue("mti", tx.mti())
            .observe(() -> doProcess(tx));
    }
}
```

### Virtual Threads (Java 21+)

```properties
# application.properties
spring.threads.virtual.enabled=true
```

```java
// No code changes needed — Spring automatically uses virtual threads
// for request handling when enabled
```

### GraalVM AOT (Native Build)

```bash
# Build native image (integrated in Spring Boot 3.x)
mvn -Pnative native:compile

# Or using Buildpacks
mvn spring-boot:build-image -Pnative
```

```java
// Register types for reflection if needed
@RegisterReflectionForBinding({MerchantResponse.class, CreateMerchantRequest.class})
@SpringBootApplication
public class Application { }
```

### HTTP Client (RestClient — preferred)

```java
@Service
public class ExternalApiClient {
    private final RestClient restClient;

    public ExternalApiClient(RestClient.Builder builder) {
        this.restClient = builder
            .baseUrl("https://api.example.com")
            .build();
    }

    public MerchantResponse getMerchant(String mid) {
        return restClient.get()
            .uri("/merchants/{mid}", mid)
            .retrieve()
            .body(MerchantResponse.class);
    }
}
```

## Anti-Patterns (Spring Boot 3.x Specific)

- Do NOT use `javax.*` imports — migration to `jakarta.*` is mandatory
- Do NOT extend `WebSecurityConfigurerAdapter` — removed in Spring Security 6.x
- Do NOT use `RestTemplate` for new code — use `RestClient` or `WebClient`
- Do NOT implement RFC 7807 manually — use built-in `ProblemDetail`
- Do NOT use `@RegisterForReflection` — that is Quarkus-specific, use `@RegisterReflectionForBinding`
- Do NOT use `antMatchers()` — replaced by `requestMatchers()` in Spring Security 6.x
