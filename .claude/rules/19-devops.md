# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 19 — DevOps and Infrastructure

## Principles
- **Cloud-Agnostic:** ZERO dependencies on cloud providers
- **Kubernetes-Native:** Use only native K8S resources
- **Quarkus Native:** Production ALWAYS with native build
- **Infrastructure as Code:** Everything versioned in Git
- **Observability:** OpenTelemetry Collector on cluster

## Docker

### Required Docker Files
```
src/main/docker/
├── Dockerfile.jvm              → Dev/Test (JVM mode)
├── Dockerfile.native           → Staging/Production (Native)
└── Dockerfile.native-micro     → Optimized production (distroless)
```

### Container Rules
- Multi-stage build ALWAYS
- Non-root user (USER 1001)
- Standard OCI labels (org.opencontainers.image.*)
- HEALTHCHECK instruction
- Only necessary ports exposed (8080, 8583)
- No debug tools in production

### Tagging Strategy
```
authorizer-simulator:latest           → latest build (dev)
authorizer-simulator:v0.1.0           → semantic version
authorizer-simulator:v0.1.0-native    → native build
authorizer-simulator:sha-abc123       → commit SHA (CI)
```

## Kubernetes

### Kustomize Structure
```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── app/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   └── hpa.yaml
│   ├── database/
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   └── pvc.yaml
│   └── observability/
│       ├── otel-collector-deployment.yaml
│       ├── otel-collector-service.yaml
│       └── otel-collector-configmap.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patches/
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patches/
    └── prod/
        ├── kustomization.yaml
        └── patches/
```

### Configuration per Environment
| Config | Dev | Staging | Prod |
|--------|-----|---------|------|
| Replicas | 1 | 2 | 3+ |
| Build | JVM | Native | Native |
| Memory Request | 256Mi | 64Mi | 64Mi |
| Memory Limit | 512Mi | 128Mi | 128Mi |
| CPU Request | 250m | 100m | 200m |
| DB | PostgreSQL local | StatefulSet | StatefulSet |
| OTel | Disabled | Enabled | Enabled |
| Log Format | Text | JSON | JSON |

### Probes
```yaml
livenessProbe:
  httpGet:
    path: /q/health/live
    port: 8080
  initialDelaySeconds: 5      # native = fast
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /q/health/ready
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 5

startupProbe:
  httpGet:
    path: /q/health/started
    port: 8080
  initialDelaySeconds: 1      # native starts in < 100ms
  periodSeconds: 2
  failureThreshold: 5
```

### HPA (Horizontal Pod Autoscaler)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: authorizer-simulator
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: authorizer-simulator
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

## Docker Compose (Local Dev)
```yaml
version: '3.8'
services:
  simulator:
    build:
      context: .
      dockerfile: src/main/docker/Dockerfile.jvm
    ports:
      - "8080:8080"
      - "8583:8583"
    environment:
      DB_URL: jdbc:postgresql://db:5432/simulator
      DB_USER: simulator
      DB_PASSWORD: simulator
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: simulator
      POSTGRES_USER: simulator
      POSTGRES_PASSWORD: simulator
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U simulator"]
      interval: 5s
      timeout: 5s
      retries: 5

  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    ports:
      - "4317:4317"
      - "4318:4318"
    profiles:
      - observability

volumes:
  pgdata:
```

## Deploy Checklist
- [ ] Native build without errors
- [ ] Docker image created and tested
- [ ] K8S manifests validated (`kubectl apply --dry-run=client`)
- [ ] Probes responding
- [ ] Metrics exposed at /q/metrics
- [ ] Logs in JSON
- [ ] Secrets configured (not hardcoded)
- [ ] HPA configured
- [ ] PDB configured
