# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Quarkus 3.x — Version-Specific Rules

> Extends: `frameworks/quarkus/common/` (all common patterns apply)

## Version Summary

| Aspect | Quarkus 3.x |
|--------|-------------|
| Namespace | `jakarta.*` (Jakarta EE 10) |
| Java minimum | 17+ (21 recommended) |
| MicroProfile | 6.x |
| DevServices | v2 (reusable, configurable networking) |
| CDI | `jakarta.inject.*`, `jakarta.enterprise.*` |
| JAX-RS | `jakarta.ws.rs.*` |
| JPA | `jakarta.persistence.*` |
| Bean Validation | `jakarta.validation.*` |
| Native Build | Mandrel (recommended) or GraalVM |
| Virtual Threads | Supported (Java 21+, `@RunOnVirtualThread`) |
| Status | **Current — recommended version** |

## Namespace: jakarta.*

All imports use the Jakarta EE 10 namespace:

```java
import jakarta.inject.Inject;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import jakarta.validation.constraints.NotBlank;
```

## Key Differences from Quarkus 2.x

| Feature | Quarkus 2.x | Quarkus 3.x |
|---------|-------------|-------------|
| Namespace | `javax.*` | `jakarta.*` |
| DevServices | Basic | Advanced (reuse, config, networking) |
| Config API | `@ConfigProperty` | `@ConfigMapping` (preferred) |
| Hibernate ORM | 5.x | 6.x |
| RESTEasy | Classic + Reactive | Reactive by default |
| SmallRye FT | MicroProfile FT 3.x | MicroProfile FT 4.x |
| Testing | `@QuarkusTest` | `@QuarkusTest` + `@QuarkusComponentTest` |
| Native Build | GraalVM CE | Mandrel (recommended) |
| Virtual Threads | Not supported | `@RunOnVirtualThread` (Java 21+) |

## Mandatory Patterns (Quarkus 3.x)

### CDI Injection

```java
import jakarta.inject.Inject;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class TransactionService {
    private final TransactionRepository repository;

    @Inject
    public TransactionService(TransactionRepository repository) {
        this.repository = repository;
    }
}
```

### REST Endpoint (RESTEasy Reactive)

```java
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.core.MediaType;

@Path("/api/v1/merchants")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class MerchantResource {

    @GET
    public List<MerchantResponse> list() { ... }
}
```

### Type-Safe Configuration (@ConfigMapping)

```java
import io.smallrye.config.ConfigMapping;
import io.smallrye.config.WithDefault;

@ConfigMapping(prefix = "simulator")
public interface SimulatorConfig {

    SocketConfig socket();

    interface SocketConfig {
        @WithDefault("8583")
        int port();

        @WithDefault("0.0.0.0")
        String host();
    }
}
```

### Virtual Threads (Java 21+)

```java
import io.smallrye.common.annotation.RunOnVirtualThread;

@Path("/api/v1/reports")
public class ReportResource {

    @GET
    @RunOnVirtualThread
    public ReportResponse generateReport() {
        // Blocking operations are safe here — runs on virtual thread
        return reportService.generate();
    }
}
```

### DevServices v2

```properties
# Dev mode — containers are reused across restarts
quarkus.devservices.enabled=true
quarkus.datasource.devservices.enabled=true
quarkus.datasource.devservices.image-name=postgres:16-alpine
quarkus.datasource.devservices.port=5432
```

### Native Build (Mandrel)

```bash
# Recommended: Mandrel (Red Hat build of GraalVM)
mvn package -Dnative -Dquarkus.native.container-build=true

# Container image for native build
# quay.io/quarkus/ubi-quarkus-mandrel-builder-image:jdk-21
```

## Anti-Patterns (Quarkus 3.x Specific)

- Do NOT use `javax.*` imports — migration to `jakarta.*` is mandatory
- Do NOT use `@ConfigProperty` for groups of 3+ properties — use `@ConfigMapping`
- Do NOT use RESTEasy Classic — use RESTEasy Reactive
- Do NOT use GraalVM Community for native builds — use Mandrel
- Do NOT block the Vert.x event loop — use `@RunOnVirtualThread` or reactive APIs
