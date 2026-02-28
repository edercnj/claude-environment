# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 10 — Infrastructure Principles

## Principles
- **Cloud-Agnostic:** ZERO dependencies on cloud-specific services (AWS, GCP, Azure)
- **Infrastructure as Code:** Everything versioned in Git
- **Immutable Infrastructure:** Build once, deploy everywhere
- **Observability Built-in:** Health checks, metrics, structured logs from day one

## Docker / Containers

### Multi-Stage Build (Mandatory)

```dockerfile
# Build stage — contains build tools, dependencies
FROM {build-image} AS build
WORKDIR /app
COPY {dependency-manifest} .
RUN {install-dependencies}
COPY src ./src
RUN {build-command}

# Runtime stage — minimal, production-ready
FROM {runtime-image}
WORKDIR /app
COPY --from=build /app/{build-output}/ ./
EXPOSE {ports}
USER 1001
ENTRYPOINT [{run-command}]
```

### Container Rules

| Rule | Standard |
|------|----------|
| Build | Multi-stage ALWAYS |
| User | Non-root (USER 1001) |
| Labels | Standard OCI labels (`org.opencontainers.image.*`) |
| Health check | HEALTHCHECK instruction |
| Ports | Only expose necessary ports |
| Debug tools | NOT in production images |
| Secrets | NEVER baked into image |
| Base image | Minimal (alpine, distroless, slim) |

### Tagging Strategy

```
{image}:latest              → latest build (dev only)
{image}:v{semver}           → semantic version
{image}:sha-{commit}        → commit SHA (CI)
```

**Rule:** NEVER use `latest` in production. Always pin to a version or SHA.

## Kubernetes

### Cloud-Agnostic Principles

- **NO** cloud provider-specific resources (LoadBalancer type configurable by overlay)
- **NO** proprietary operators (e.g., AWS RDS Operator)
- Use only native K8s resources: Deployment, Service, ConfigMap, Secret, StatefulSet, PVC
- PersistentVolumeClaim with configurable `storageClassName` (not hardcoded)

### Kustomize (NEVER Helm)

```
k8s/
├── base/                          # Shared manifests
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── app/                       # Application
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── hpa.yaml
│   │   ├── pdb.yaml
│   │   ├── networkpolicy.yaml
│   │   └── serviceaccount.yaml
│   ├── database/                  # Database StatefulSet
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   └── secret.yaml
│   └── observability/             # Telemetry collector
│       ├── collector-deployment.yaml
│       └── collector-service.yaml
└── overlays/                      # Per-environment patches
    ├── dev/
    ├── staging/
    └── prod/
```

### Mandatory Labels

```yaml
metadata:
  labels:
    app.kubernetes.io/name: {app-name}
    app.kubernetes.io/instance: {instance}
    app.kubernetes.io/version: "{version}"
    app.kubernetes.io/component: {component}    # api | database | collector
    app.kubernetes.io/part-of: {project}
    app.kubernetes.io/managed-by: kustomize
```

### Security Context (Restricted PSS)

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    runAsGroup: 1001
    fsGroup: 1001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir:
      sizeLimit: 64Mi
```

### Probes

Three probes, adjusted for build type:

| Probe | Path | Purpose |
|-------|------|---------|
| Startup | `/health/started` | Application finished initialization |
| Liveness | `/health/live` | Application is not deadlocked |
| Readiness | `/health/ready` | Application can serve traffic |

Probe timing depends on startup speed (native vs JVM vs interpreted):

| Build Type | startupProbe.initialDelay | livenessProbe.initialDelay |
|-----------|--------------------------|---------------------------|
| Native / compiled | 1s | 5s |
| JVM | 5s | 15s |
| Interpreted | 3s | 10s |

### Resources per Environment

| Config | Dev | Staging | Prod |
|--------|-----|---------|------|
| Replicas | 1 | 2 | 3+ |
| Memory Request | Higher (debug) | Right-sized | Right-sized |
| Memory Limit | Higher (debug) | Right-sized | Right-sized |
| CPU Request | Lower | Moderate | Production load |

### ConfigMap vs Secret

| Data | Type |
|------|------|
| Ports, feature flags, non-sensitive config | ConfigMap |
| Database credentials, API keys, passwords | Secret |
| TLS certificates | Secret (type: tls) |

**Rule:** Credentials ALWAYS in Secret, NEVER in ConfigMap.

### Graceful Shutdown

```yaml
spec:
  terminationGracePeriodSeconds: 30
  containers:
  - name: app
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 5"]
```

The `sleep 5` in preStop allows the Service to remove the pod from endpoints before SIGTERM.

### Database (StatefulSet)

- ALWAYS use StatefulSet for databases
- Headless Service (`clusterIP: None`) for stable DNS
- PVC with configurable `storageClassName`
- Probes with database-specific health commands

### Auto-Scaling (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### NetworkPolicy

Default-deny with explicit allowlist:
- Ingress: only declared protocol ports
- Egress: database, telemetry collector, DNS

## Docker Compose (Local Development)

```yaml
services:
  app:
    build:
      context: .
      dockerfile: {Dockerfile}
    ports:
      - "{http_port}:{http_port}"
      - "{protocol_port}:{protocol_port}"
    environment:
      DB_URL: jdbc:postgresql://db:5432/{db_name}
    depends_on:
      db:
        condition: service_healthy

  db:
    image: {database_image}
    ports:
      - "{db_port}:{db_port}"
    healthcheck:
      test: [{health_command}]
      interval: 5s
      timeout: 5s
      retries: 5

  collector:
    image: otel/opentelemetry-collector-contrib:latest
    ports:
      - "4317:4317"
    profiles:
      - observability
```

## Deploy Checklist

- [ ] Build succeeds without errors
- [ ] Container image created and tested
- [ ] K8s manifests validated (`kubectl apply --dry-run=client`)
- [ ] Probes responding
- [ ] Metrics exposed
- [ ] Logs in JSON (staging/prod)
- [ ] Secrets configured (not hardcoded)
- [ ] HPA configured (production)
- [ ] PDB configured (production)
- [ ] NetworkPolicy applied

## Anti-Patterns (FORBIDDEN)

### Containers
- Running as root
- `latest` tag in production
- Secrets baked into image
- Debug tools in production image
- Single-stage Dockerfile

### Kubernetes
- Helm charts (use Kustomize)
- Cloud provider-specific resources in base manifests
- Pods without resource requests/limits
- No probes (liveness, readiness, startup)
- No graceful shutdown
- `default` namespace
- Credentials in ConfigMap
- Deployment for stateful workloads (use StatefulSet)
- PVC without configurable storageClassName
- Missing standard labels
- `automountServiceAccountToken: true` without need
