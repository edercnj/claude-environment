# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot 2.x — Version-Specific Rules

> Extends: `frameworks/spring-boot/common/` (all common patterns apply)

## Version Summary

| Aspect | Spring Boot 2.x |
|--------|-----------------|
| Namespace | `javax.*` (Java EE) |
| Java minimum | 8+ (11+ recommended) |
| Spring Framework | 5.x |
| Spring Security | 5.x (`WebSecurityConfigurerAdapter`) |
| Spring Data JPA | 2.x (Hibernate 5.x) |
| Observability | Micrometer + Spring Actuator |
| Native Build | Experimental (Spring Native, separate project) |
| Status | **End of OSS support — migrate to 3.x** |

## Namespace: javax.*

All imports use the Java EE namespace:

```java
import javax.persistence.Entity;
import javax.persistence.Table;
import javax.persistence.Id;
import javax.persistence.GeneratedValue;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.Size;
import javax.servlet.http.HttpServletRequest;
```

## Key Differences from Spring Boot 3.x

| Feature | Spring Boot 2.x | Spring Boot 3.x |
|---------|-----------------|-----------------|
| Namespace | `javax.*` | `jakarta.*` |
| Java minimum | 8+ | 17+ |
| Spring Security | `WebSecurityConfigurerAdapter` | `SecurityFilterChain` (component-based) |
| Observability | Micrometer only | Micrometer + Observation API |
| Native Build | Spring Native (experimental) | GraalVM AOT (integrated) |
| HTTP Client | `RestTemplate` (default) | `RestClient` / `WebClient` |
| Problem Details | Manual implementation | RFC 7807 built-in |
| Hibernate | 5.x | 6.x |
| Flyway | 8.x | 9.x+ |

## Mandatory Patterns (Spring Boot 2.x)

### Spring Security Configuration

```java
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;

@Configuration
@EnableWebSecurity
public class SecurityConfig extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .csrf().disable()
            .authorizeRequests()
                .antMatchers("/actuator/health/**").permitAll()
                .antMatchers("/api/**").authenticated()
            .and()
            .httpBasic();
    }
}
```

### JPA Entity

```java
import javax.persistence.Entity;
import javax.persistence.Table;
import javax.persistence.Id;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;

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

### REST Controller

```java
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import javax.validation.Valid;

@RestController
@RequestMapping("/api/v1/merchants")
public class MerchantController {

    @GetMapping
    public List<MerchantResponse> list() { ... }

    @PostMapping
    public ResponseEntity<MerchantResponse> create(@Valid @RequestBody CreateMerchantRequest request) { ... }
}
```

### Observability (Micrometer)

```java
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Counter;

@Service
public class TransactionMetrics {
    private final Counter transactionCounter;

    public TransactionMetrics(MeterRegistry registry) {
        this.transactionCounter = Counter.builder("transactions.total")
            .description("Total transactions processed")
            .register(registry);
    }
}
```

## Anti-Patterns (Spring Boot 2.x Specific)

- Do NOT use `jakarta.*` imports — use `javax.*` exclusively
- Do NOT use `SecurityFilterChain` bean pattern — use `WebSecurityConfigurerAdapter`
- Do NOT use `@RegisterForReflection` — that is Quarkus-specific
- Do NOT rely on GraalVM AOT compilation — Spring Native is experimental in 2.x
- Do NOT use `ProblemDetail` (RFC 7807) — not built-in, implement manually
- Do NOT use `RestClient` — not available, use `RestTemplate` or `WebClient`
