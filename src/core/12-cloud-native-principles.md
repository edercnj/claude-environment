# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 12 — Cloud Native & 12-Factor Principles

## Principles
- **12-Factor Compliance:** Every deployable service MUST follow the 12-Factor methodology
- **Cloud Native:** Design for dynamic, orchestrated environments (containers, schedulers)
- **Stateless by Default:** Application processes share nothing; state lives in backing services
- **Observable:** Health, metrics, and logs are first-class citizens, not afterthoughts
- **Disposable:** Fast startup, graceful shutdown, resilient to sudden termination

## Applicability by Project Type

| Principle Area | Microservice | Monolith | Library / SDK |
|---------------|:------------:|:--------:|:-------------:|
| 12-Factor Compliance | **Full** | **Mostly** (I, VIII less relevant) | **N/A** — libraries are not deployed |
| Health Probes | **Full** | **Full** | **N/A** |
| Graceful Shutdown | **Full** | **Full** | **N/A** — no process lifecycle |
| Configuration Hierarchy | **Full** | **Full** | Partial (defaults only) |
| Container Best Practices | **Full** | **Full** | **N/A** — not containerized |
| Service Mesh Awareness | **Full** | Partial (single service) | **N/A** |

> **Library / SDK projects:** Most cloud-native principles do not apply. Libraries have no process, no container, no probes. Focus on clean code (Rule 01), SOLID (Rule 02), and testing (Rule 03) instead.

## 12-Factor Compliance

Explicit checklist for every deployable service:

| Factor | Requirement | Microservice | Monolith |
|--------|-------------|:------------:|:--------:|
| I. Codebase | One repo per service, tracked in version control | Strong | Weaker (single repo, multiple modules) |
| II. Dependencies | Explicitly declared, no implicit system dependencies | Strong | Strong |
| III. Config | Strict separation from code, environment variables or ConfigMap/Secret | Strong | Strong |
| IV. Backing Services | Treat databases, caches, brokers as attached resources via URI | Strong | Strong |
| V. Build/Release/Run | Strict separation, immutable releases | Strong | Strong |
| VI. Processes | Stateless, share-nothing, session data in external store | Strong | Strong |
| VII. Port Binding | Self-contained, export services via port binding | Strong | Strong |
| VIII. Concurrency | Scale out via process model, horizontal scaling | Strong | Weaker (vertical scaling more common) |
| IX. Disposability | Fast startup (<10s), graceful shutdown (drain connections, finish in-flight) | Strong | Strong |
| X. Dev/Prod Parity | Same container image across all environments | Strong | Strong |
| XI. Logs | Write to stdout/stderr as structured JSON, never manage log files | Strong | Strong |
| XII. Admin Processes | Run as one-off containers in same environment | Strong | Strong |

> See Rule 08 (Observability) for structured logging format and health check implementation.

## Health Probes (Kubernetes-native)

Three mandatory probes for every service running in Kubernetes:

| Probe | Endpoint | Purpose | On Failure |
|-------|----------|---------|------------|
| Liveness | `/health/live` | Checks process is alive | Kubernetes restarts the pod |
| Readiness | `/health/ready` | Checks dependencies (DB, cache, broker) | Removed from load balancer |
| Startup | `/health/started` | For slow-starting apps | Prevents premature liveness kills |

### Probe Implementation Rules
- Liveness: lightweight, no dependency checks (CPU-bound only)
- Readiness: verify database connection, cache availability, broker connectivity
- Startup: use for JVM or heavy-initialization apps; set `failureThreshold` high enough

> See Rule 10 (Infrastructure) for detailed Kubernetes manifests and probe timing.
> See Rule 08 (Observability) for health check implementation details and readiness check components.

## Graceful Shutdown

Every service MUST handle termination cleanly:

1. **Handle SIGTERM signal** — register shutdown hook at startup
2. **Stop accepting new requests** — close server socket / deregister from service discovery
3. **Drain in-flight requests** — configurable timeout (default 30s)
4. **Close resources** — database connections, message broker consumers, flush buffers
5. **Exit with code 0** — signals clean shutdown to orchestrator

```
SIGTERM received
    → stop accepting new connections
    → wait for in-flight requests (up to terminationGracePeriodSeconds)
    → close DB pools, flush logs, close broker connections
    → exit 0
```

> See Rule 10 (Infrastructure) for Kubernetes `terminationGracePeriodSeconds` and `preStop` hook configuration.
> See Rule 09 (Resilience) for graceful degradation levels and how shutdown interacts with circuit breakers.

## Configuration Hierarchy

Strict precedence order (highest to lowest):

| Priority | Source | Use Case |
|----------|--------|----------|
| 1 (highest) | Environment variables | Runtime overrides, secrets |
| 2 | ConfigMap (mounted or env) | Environment-specific config |
| 3 (lowest) | Application defaults (code) | Sensible fallbacks |

### Secret Management

| Data Type | Allowed Source | Forbidden Source |
|-----------|---------------|-----------------|
| Database credentials | Kubernetes Secret, external vault | Code, ConfigMap, environment file in repo |
| API keys / tokens | Kubernetes Secret, external vault | Code, ConfigMap |
| TLS certificates | Kubernetes Secret (type: tls) | Code, ConfigMap |
| Feature flags | ConfigMap, external config service | Compile-time constants |
| Non-sensitive config | ConfigMap, environment variables | Hardcoded only if truly static |

**Rules:**
- Secrets NEVER in code, NEVER in ConfigMap, NEVER committed to version control
- Feature flags MUST be external configuration, NEVER compile-time
- All config values MUST have sensible defaults where possible
- Config changes MUST NOT require a rebuild (Factor III)

## Container Best Practices

| Practice | Requirement | Rationale |
|----------|-------------|-----------|
| Non-root user | `USER 1001` in Dockerfile | Principle of least privilege |
| Read-only filesystem | `readOnlyRootFilesystem: true` where possible | Prevent runtime tampering |
| Resource limits | CPU and memory requests/limits always defined | Prevent noisy neighbors, enable HPA |
| Single process | One process per container | Clean lifecycle, clear signals, simple logging |
| No SSH | No SSH daemon in production image | Use `kubectl exec` for debugging |
| No package managers | Remove or don't install apt/apk in production | Reduce attack surface |
| Minimal base image | Alpine, distroless, or slim variants | Smaller image, fewer CVEs |

> See Rule 10 (Infrastructure) for multi-stage Dockerfile patterns, tagging strategy, and security context manifests.

## Service Mesh Awareness

When running in a service mesh (Istio, Linkerd, Consul Connect):

| Concern | Application Responsibility | Mesh Responsibility |
|---------|---------------------------|---------------------|
| mTLS | Do NOT terminate TLS in app if mesh handles it | Encrypts pod-to-pod traffic |
| Trace context | Propagate W3C Trace Context headers (`traceparent`, `tracestate`) | Routes and observes traffic |
| Retries | Coordinate with mesh retry policy to avoid retry storms | Can perform automatic retries |
| Timeouts | Set application timeout shorter than mesh timeout | Enforces overall timeout |
| Health checks | Implement probes as usual | Sidecar has its own health |

### Header Propagation (Mandatory)

When receiving an inbound request, propagate these headers to ALL outbound requests:

- `traceparent` (W3C Trace Context)
- `tracestate` (W3C Trace Context)
- `x-request-id` (correlation)

> See Rule 08 (Observability) for distributed tracing span tree patterns and mandatory span attributes.

## Statelessness Checklist

Every service MUST pass this checklist:

- [ ] No local file storage for user data (use object store or database)
- [ ] No in-memory session state (use Redis, database, or JWT)
- [ ] No local cron/scheduler state (use external scheduler or leader election)
- [ ] No sticky sessions required (any instance can serve any request)
- [ ] No local cache that causes inconsistency across replicas (use shared cache or accept eventual consistency)

## Anti-Patterns (FORBIDDEN)

### 12-Factor Violations
- Storing config in code (hardcoded URLs, credentials, feature flags)
- Writing logs to local files instead of stdout/stderr
- Relying on local filesystem for persistent state
- Different container images per environment (build once, deploy everywhere)
- Implicit system dependencies (e.g., assuming `imagemagick` is installed)
- In-memory sessions without external store (breaks horizontal scaling)

### Container Anti-Patterns
- Running as root in production
- Using `latest` tag in production deployments
- Installing SSH or package managers in production images
- Baking secrets into container images
- Multiple processes in a single container (use sidecar pattern instead)
- No resource limits defined (CPU/memory)

### Health Probe Anti-Patterns
- Liveness probe that checks external dependencies (causes cascading restarts)
- No startup probe for slow-starting applications (premature kills)
- Health endpoints that perform heavy computation (probe timeout)
- Readiness probe that never checks actual dependencies (always returns OK)

### Shutdown Anti-Patterns
- Ignoring SIGTERM (forceful kill after grace period)
- Not draining in-flight requests (dropped connections, data loss)
- Not closing database connections (connection pool exhaustion)
- Exit code != 0 on clean shutdown (triggers unnecessary alerts)

### Service Mesh Anti-Patterns
- Terminating TLS in the application when mesh provides mTLS
- Not propagating trace context headers (broken distributed traces)
- Application retries + mesh retries without coordination (retry storm)
- Hardcoding service URLs instead of using service discovery
