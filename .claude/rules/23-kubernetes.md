# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 23 — Kubernetes Best Practices

## Principles
- **Cloud-Agnostic:** ZERO dependencies on cloud providers (AWS, GCP, Azure)
- **Kustomize:** Only templating tool (NEVER Helm)
- **Pod Security Standards:** Mode `restricted` is mandatory
- **Least Privilege:** Minimal ServiceAccounts, explicit RBAC
- **Immutability:** Containers read-only filesystem, no disk writes
- **Observability:** Standardized probes, metrics, and logs

## Kustomize Structure

```
k8s/
├── base/                          # Shared manifests
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── app/                       # Main application
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── hpa.yaml
│   │   ├── pdb.yaml
│   │   ├── networkpolicy.yaml
│   │   └── serviceaccount.yaml
│   ├── database/                  # PostgreSQL StatefulSet
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   └── observability/             # OpenTelemetry Collector
│       ├── otel-collector-deployment.yaml
│       ├── otel-collector-service.yaml
│       └── otel-collector-configmap.yaml
└── overlays/                      # Patches per environment
    ├── dev/
    │   └── kustomization.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

## Mandatory Labels

All resources MUST have these labels:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: authorizer-simulator
    app.kubernetes.io/instance: authorizer-simulator
    app.kubernetes.io/version: "0.1.0"
    app.kubernetes.io/component: api          # api | database | collector
    app.kubernetes.io/part-of: bifrost
    app.kubernetes.io/managed-by: kustomize
```

## Security Context — Restricted PSS

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
        drop:
          - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir:
      sizeLimit: 64Mi
```

**Rules:**
- `runAsNonRoot: true` — ALWAYS
- `readOnlyRootFilesystem: true` — ALWAYS (use emptyDir for /tmp)
- `allowPrivilegeEscalation: false` — ALWAYS
- `capabilities.drop: ["ALL"]` — ALWAYS
- `seccompProfile.type: RuntimeDefault` — ALWAYS

## Probes

### Quarkus Native Application
```yaml
startupProbe:
  httpGet:
    path: /q/health/started
    port: 8080
  initialDelaySeconds: 1
  periodSeconds: 2
  failureThreshold: 5

livenessProbe:
  httpGet:
    path: /q/health/live
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /q/health/ready
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 5
  failureThreshold: 3
```

### Quarkus JVM Application (dev overlay)
```yaml
startupProbe:
  httpGet:
    path: /q/health/started
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 10

livenessProbe:
  httpGet:
    path: /q/health/live
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /q/health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

### PostgreSQL
```yaml
livenessProbe:
  exec:
    command:
    - pg_isready
    - -U
    - simulator
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  exec:
    command:
    - pg_isready
    - -U
    - simulator
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

## Resources and QoS per Environment

| Config | Dev (JVM) | Staging (Native) | Prod (Native) |
|--------|-----------|-------------------|----------------|
| Replicas | 1 | 2 | 3+ |
| Memory Request | 256Mi | 64Mi | 64Mi |
| Memory Limit | 512Mi | 128Mi | 128Mi |
| CPU Request | 250m | 100m | 200m |
| CPU Limit | 500m | 500m | 1000m |
| QoS Class | Burstable | Burstable | Burstable |

## StatefulSet for Databases

PostgreSQL MUST use StatefulSet with:
- Headless Service (`clusterIP: None`) for stable DNS
- PVC with configurable `storageClassName` (NEVER hardcoded)
- `subPath: postgres` in volumeMount to avoid `lost+found` issue
- Probes with `pg_isready`

## NetworkPolicy

Default-deny with explicit allowlist:
- App ingress: ports 8080 (HTTP) and 8583 (ISO 8583)
- App egress: PostgreSQL (5432), OTel Collector (4317), DNS (53)

## ConfigMap vs Secret

| Data | Type | Example |
|------|------|---------|
| Socket port, ISO version, OTel endpoint | ConfigMap | `SOCKET_PORT=8583` |
| DB URL, DB user, DB password | Secret | `DB_PASSWORD=simulator` |
| TLS certificates | Secret (type: tls) | — |
| Feature flags | ConfigMap | `OTEL_ENABLED=false` |

**Rule:** Credentials ALWAYS in Secret, NEVER in ConfigMap.

## ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: authorizer-simulator
automountServiceAccountToken: false
```

## Graceful Shutdown

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

The `sleep 5` in preStop allows the Service to remove the pod from endpoints before sending SIGTERM.

## Integration with Application Resilience (Rule 24)

Resilience at K8S level (HPA, probes, PDB) is **complementary** to application-level resilience:

| Layer | Mechanism | Responsible |
|--------|-----------|-------------|
| Application | Rate limiting, circuit breaker, bulkhead, retry | **Rule 24** (MicroProfile FT + Bucket4j) |
| Application | TCP backpressure, graceful degradation | **Rule 24** (Vert.x + custom) |
| Kubernetes | Auto-scaling (HPA), self-healing (probes), disruption budget (PDB) | **Rule 23** (this rule) |

- Readiness probe MUST reflect the application's degradation level (Rule 24): in EMERGENCY, readiness returns DOWN
- HPA + rate limiting (Bucket4j) form defense in depth against traffic spikes
- NEVER rely ONLY on K8S for resilience — the application MUST implement its own patterns

## Anti-Patterns (PROHIBITED)

### Security
- ❌ Container running as root
- ❌ `allowPrivilegeEscalation: true`
- ❌ Read-write filesystem without necessity
- ❌ `automountServiceAccountToken: true` without necessity
- ❌ Capabilities not dropped
- ❌ Credentials in ConfigMap
- ❌ Secrets in plain text in repository

### Resources
- ❌ Pods without resource requests/limits
- ❌ No HPA in production
- ❌ No PDB in production

### Networking
- ❌ Service type LoadBalancer in base (cloud-specific)
- ❌ No NetworkPolicy (default allow-all)
- ❌ hostNetwork or hostPort without justification

### Database
- ❌ Deployment for database (use StatefulSet)
- ❌ PVC without configurable storageClassName
- ❌ DB credentials hardcoded in manifests

### General
- ❌ Helm charts (use Kustomize)
- ❌ Cloud provider-specific resources
- ❌ `latest` tag on production images
- ❌ No probes (liveness, readiness, startup)
- ❌ No graceful shutdown (preStop hook)
- ❌ Namespace `default`
- ❌ Manifests without standardized labels
