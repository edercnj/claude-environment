# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Quarkus 2.x — Version-Specific Rules

> Extends: `frameworks/quarkus/common/` (all common patterns apply)

## Version Summary

| Aspect | Quarkus 2.x |
|--------|-------------|
| Namespace | `javax.*` (Java EE) |
| Java minimum | 11+ |
| MicroProfile | 3.x / 4.x |
| DevServices | v1 (basic container lifecycle) |
| CDI | `javax.inject.*`, `javax.enterprise.*` |
| JAX-RS | `javax.ws.rs.*` |
| JPA | `javax.persistence.*` |
| Bean Validation | `javax.validation.*` |
| Native Build | GraalVM (not Mandrel by default) |
| Status | **Legacy — consider migrating to 3.x** |

## Namespace: javax.*

All imports use the Java EE namespace:

```java
import javax.inject.Inject;
import javax.enterprise.context.ApplicationScoped;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.persistence.Entity;
import javax.persistence.Table;
import javax.validation.constraints.NotBlank;
```

## Key Differences from Quarkus 3.x

| Feature | Quarkus 2.x | Quarkus 3.x |
|---------|-------------|-------------|
| Namespace | `javax.*` | `jakarta.*` |
| DevServices | Basic (start/stop only) | Advanced (reuse, config, networking) |
| MicroProfile Config | `@ConfigProperty` preferred | `@ConfigMapping` preferred |
| Hibernate ORM | 5.x | 6.x (different defaults) |
| RESTEasy | Classic + Reactive | Reactive only (default) |
| SmallRye FT | MicroProfile FT 3.x | MicroProfile FT 4.x |
| Test framework | `@QuarkusTest` | `@QuarkusTest` + `@QuarkusComponentTest` |
| GraalVM | Community edition | Mandrel (recommended) |

## Mandatory Patterns (Quarkus 2.x)

### CDI Injection

```java
import javax.inject.Inject;
import javax.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class TransactionService {
    private final TransactionRepository repository;

    @Inject
    public TransactionService(TransactionRepository repository) {
        this.repository = repository;
    }
}
```

### REST Endpoint

```java
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.Consumes;
import javax.ws.rs.core.MediaType;

@Path("/api/v1/merchants")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class MerchantResource {

    @GET
    public List<MerchantResponse> list() { ... }
}
```

### Configuration

```java
import org.eclipse.microprofile.config.inject.ConfigProperty;

@ApplicationScoped
public class TcpServer {
    @ConfigProperty(name = "simulator.socket.port", defaultValue = "8583")
    int port;
}
```

## Anti-Patterns (Quarkus 2.x Specific)

- Do NOT mix `javax.*` and `jakarta.*` imports — use `javax.*` exclusively
- Do NOT use `@ConfigMapping` (Quarkus 3.x feature) — use `@ConfigProperty`
- Do NOT rely on `@QuarkusComponentTest` — not available in 2.x
- Do NOT use Hibernate ORM 6.x APIs — use 5.x compatible APIs
