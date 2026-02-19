# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Kubernetes Deployment Patterns

## Workload Types

### Deployment
- **Use when:** Stateless applications, web servers, APIs, microservices
- **Characteristics:** Rolling updates, rollback, horizontal scaling
- **Strategy:** `RollingUpdate` with `maxSurge: 25%` and `maxUnavailable: 0` for zero-downtime deployments
- **Rule:** Default choice for most workloads. If unsure, start here.

### StatefulSet
- **Use when:** Databases, message brokers, distributed systems requiring stable identity
- **Characteristics:** Stable network identity (`pod-0`, `pod-1`), ordered startup/teardown, persistent volumes per pod
- **Strategy:** `RollingUpdate` with `partition` for canary-style rollouts
- **Rule:** NEVER use for stateless workloads. If the pod does not need stable storage or identity, use Deployment.

### DaemonSet
- **Use when:** Node-level agents (log collectors, monitoring agents, network plugins, storage drivers)
- **Characteristics:** Exactly one pod per node (or subset via `nodeSelector`/`affinity`)
- **Typical examples:** Fluentd/Fluent Bit, Datadog agent, Cilium, CSI drivers
- **Rule:** NEVER schedule application workloads as DaemonSets.

### Job / CronJob
- **Use when:** Batch processing, one-off tasks, scheduled tasks (reports, cleanup, backups)
- **Job settings:** `backoffLimit`, `activeDeadlineSeconds`, `ttlSecondsAfterFinished`
- **CronJob settings:** `concurrencyPolicy` (Forbid, Replace, Allow), `startingDeadlineSeconds`
- **Rule:** Always set `activeDeadlineSeconds` to prevent runaway jobs. Always set `ttlSecondsAfterFinished` to clean up completed pods.

### Operators (Custom Controllers)
- **Use when:** Managing complex stateful systems (databases, Kafka, Elasticsearch) that need domain-specific lifecycle automation
- **Examples:** Strimzi (Kafka), CloudNativePG (PostgreSQL), Elastic Operator, Prometheus Operator
- **Rule:** Prefer battle-tested community operators over building custom ones. Building an operator is a significant maintenance commitment.

## Pod Specification Best Practices

### Resources (Mandatory)

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m        # Optional — consider removing CPU limits (see below)
    memory: 256Mi    # ALWAYS set memory limits
```

| Rule | Standard |
|------|----------|
| Memory requests | ALWAYS set. Base on p99 observed usage |
| Memory limits | ALWAYS set. 1.5x-2x of requests |
| CPU requests | ALWAYS set. Base on average observed usage |
| CPU limits | OPTIONAL. Removing CPU limits avoids throttling; keep memory limits always |
| No resources | FORBIDDEN. Pods without requests/limits will be evicted first |

### Probes (Mandatory)

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
```

| Probe | Purpose | Rule |
|-------|---------|------|
| Liveness | Restart stuck containers | MUST NOT check dependencies (DB, cache). Only check if process is alive |
| Readiness | Remove from Service endpoints | MAY check critical dependencies |
| Startup | Gate liveness/readiness during boot | Use for slow-starting apps (JVM, large ML models) |

### Pod Disruption Budget (PDB)

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 1          # OR maxUnavailable: 1
  selector:
    matchLabels:
      app: my-app
```

**Rule:** EVERY production Deployment with >= 2 replicas MUST have a PDB.

### Anti-Affinity & Topology Spread

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: my-app
          topologyKey: kubernetes.io/hostname

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: my-app
```

**Rule:** Production workloads MUST spread across availability zones. Use `topologySpreadConstraints` for zone spreading and `podAntiAffinity` for host spreading.

### Security Context (Mandatory)

```yaml
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
```

| Rule | Standard |
|------|----------|
| Root | NEVER run as root (`runAsNonRoot: true`) |
| Privilege escalation | ALWAYS disable (`allowPrivilegeEscalation: false`) |
| Root filesystem | Read-only when possible (`readOnlyRootFilesystem: true`) |
| Capabilities | Drop ALL, add only what is needed |
| Seccomp | ALWAYS set to `RuntimeDefault` minimum |

### Service Account

```yaml
serviceAccountName: my-app-sa
automountServiceAccountToken: false    # Unless the app needs K8s API access
```

**Rule:** NEVER use the `default` service account. Create a dedicated SA per workload. Disable token auto-mount unless the application explicitly needs Kubernetes API access.

### Image Pull Policy

| Environment | Policy |
|-------------|--------|
| Production | `IfNotPresent` with immutable tags (SHA or semver) |
| Development | `Always` acceptable for iteration speed |
| NEVER | `latest` tag in production |

## Scaling

### Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 20
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 25
          periodSeconds: 120
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

**Rule:** ALWAYS configure `behavior` to prevent flapping. Scale up fast, scale down slow.

### Custom Metrics HPA
- Use Prometheus Adapter or KEDA for metrics like requests-per-second, queue depth, latency
- Prefer custom metrics over CPU/memory for request-driven workloads

### Vertical Pod Autoscaler (VPA)
- **Mode:** Use `recommendation` mode only. NEVER use `Auto` mode in production (it restarts pods).
- **Purpose:** Right-sizing resource requests based on observed usage
- **Rule:** VPA and HPA on the same metric (CPU/memory) conflict. Use VPA for recommendations, HPA for scaling.

### KEDA (Event-Driven Autoscaling)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: my-app-scaler
spec:
  scaleTargetRef:
    name: my-app
  minReplicaCount: 1
  maxReplicaCount: 50
  triggers:
    - type: kafka
      metadata:
        bootstrapServers: kafka:9092
        consumerGroup: my-group
        topic: events
        lagThreshold: "100"
```

**Use when:** Scaling based on external events (Kafka lag, SQS depth, Prometheus queries, cron schedules, HTTP request rate).

### Cluster Autoscaler / Karpenter

| Tool | Use When |
|------|----------|
| Cluster Autoscaler | Traditional node group scaling; works with managed node groups (EKS, GKE, AKS) |
| Karpenter | Fast, flexible node provisioning; right-sized instances; consolidation; AWS-native (expanding to others) |

**Rule:** Application teams should NOT manage cluster-level autoscaling. Set correct resource requests and let the platform team handle node provisioning.

## Networking

### Service Types

| Type | Use When | Notes |
|------|----------|-------|
| `ClusterIP` | Internal service-to-service communication | Default. Use this unless you need external access |
| `NodePort` | Development/testing, on-prem without LB | Avoid in production cloud environments |
| `LoadBalancer` | Direct external access to a single service | Expensive (one LB per service). Prefer Ingress |
| `ExternalName` | CNAME alias to external service | No proxying, DNS only |
| `Headless` (`clusterIP: None`) | StatefulSet direct pod addressing, client-side load balancing | Returns pod IPs in DNS |

### Ingress Controllers

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - api.example.com
      secretName: api-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 8080
```

**Options:** NGINX Ingress Controller, Traefik, Envoy Gateway, AWS ALB Ingress Controller, Istio Gateway

**Rule:** Use ONE ingress controller per cluster (or per tenant). TLS termination at the ingress layer is the default pattern.

### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-app-netpol
  namespace: my-app
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: api-gateway
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: database
      ports:
        - protocol: TCP
          port: 5432
    - to:                          # Allow DNS
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
```

**Rule:** Default-deny all traffic per namespace. Explicitly allow only required ingress/egress. ALWAYS allow DNS (UDP 53) in egress rules.

### DNS (FQDN)

```
# Within same namespace
my-service

# Cross-namespace
my-service.other-namespace.svc.cluster.local

# Short form (works with search domains)
my-service.other-namespace
```

**Rule:** Use fully-qualified names (`*.svc.cluster.local`) in configuration for clarity. Short names are acceptable in application code within the same namespace.

### Service Mesh (When Needed)

| Mesh | Strengths |
|------|-----------|
| Istio | Feature-rich, battle-tested, complex |
| Linkerd | Lightweight, simple, Rust-based proxy |
| Cilium Service Mesh | eBPF-based, no sidecar, integrated with CNI |

**Rule:** Do NOT add a service mesh unless you need mTLS, advanced traffic management, or cross-service observability that cannot be achieved with simpler tools. Service meshes add operational complexity.

## Configuration & Secrets

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-config
data:
  application.yaml: |
    server:
      port: 8080
    feature:
      new-checkout: true
```

### Secret Mounting (Best Practice)

```yaml
# GOOD — mount as volume (files are tmpfs, not visible in env dumps)
volumes:
  - name: db-credentials
    secret:
      secretName: my-app-db-secret
volumeMounts:
  - name: db-credentials
    mountPath: /etc/secrets/db
    readOnly: true

# BAD — environment variables (visible in /proc, logs, error reports)
# env:
#   - name: DB_PASSWORD
#     valueFrom:
#       secretRef:
#         name: my-app-db-secret
#         key: password
```

**Rule:** ALWAYS mount secrets as volumes, NEVER as environment variables. Environment variables leak in crash dumps, debug endpoints, and child processes.

### External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-db-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: my-app-db-secret
  data:
    - secretKey: password
      remoteRef:
        key: /prod/my-app/db-password
```

**Rule:** Production secrets MUST be sourced from an external secrets manager (AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, GCP Secret Manager). NEVER store plaintext secrets in Git.

### Sealed Secrets (Alternative)

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-app-secret
spec:
  encryptedData:
    password: AgBy8h...encrypted...==
```

**Use when:** You want encrypted secrets stored in Git (GitOps-friendly). The Sealed Secrets controller in-cluster decrypts them into regular Kubernetes Secrets.

**Rule:** Sealed Secrets are acceptable for non-critical environments. For production, prefer External Secrets Operator with a dedicated secrets manager.
