---
name: k8s-deployment
description: "Kubernetes deployment patterns reference covering workload types, pod specifications, resource sizing, probes, autoscaling, network policies, and security contexts. Internal reference for agents managing infrastructure."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Kubernetes Deployment Patterns

## Purpose

Provide production-grade Kubernetes deployment patterns, resource sizing guidelines, and security configurations for agents generating or reviewing Kubernetes manifests across multiple languages and workload types.

---

## 1. Workload Type Decision Tree

Select the appropriate workload controller based on your application characteristics.

### Decision Criteria Table

| Criteria | Deployment | StatefulSet | DaemonSet | Job | CronJob |
|---|---|---|---|---|---|
| **Stateless web/API service** | Yes | - | - | - | - |
| **Requires stable network identity** | - | Yes | - | - | - |
| **Requires persistent storage per pod** | - | Yes | - | - | - |
| **Must run on every node** | - | - | Yes | - | - |
| **One-time batch processing** | - | - | - | Yes | - |
| **Scheduled recurring task** | - | - | - | - | Yes |
| **Rolling update strategy** | RollingUpdate | RollingUpdate / OnDelete | RollingUpdate | N/A | N/A |
| **Scaling** | HPA / manual | Manual / limited HPA | Per node | Parallelism | Schedule |
| **Pod ordering guarantees** | None | Ordered start/stop | None | None | None |

### Decision Flow

```
Is the workload a one-time or scheduled task?
  Yes, one-time       -> Job
  Yes, scheduled       -> CronJob
  No (long-running)    ->
    Must it run on every node? (log collector, monitoring agent, CNI)
      Yes              -> DaemonSet
      No               ->
        Does it need stable identity, ordered deployment, or persistent volumes?
          Yes          -> StatefulSet
          No           -> Deployment
```

---

## 2. Pod Specification Template

Complete pod spec with all required production fields.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
  namespace: my-namespace
  labels:
    app.kubernetes.io/name: my-service
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: my-platform
    app.kubernetes.io/managed-by: kustomize
  annotations:
    meta.helm.sh/release-name: my-service
spec:
  replicas: 2
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: my-service
  template:
    metadata:
      labels:
        app.kubernetes.io/name: my-service
        app.kubernetes.io/version: "1.0.0"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: my-service
      terminationGracePeriodSeconds: 30
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: my-service
          image: registry.example.com/my-service:1.0.0-abc1234
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          env:
            - name: LOG_LEVEL
              value: "info"
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: my-service-db
                  key: host
          envFrom:
            - configMapRef:
                name: my-service-config
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            capabilities:
              drop:
                - ALL
          startupProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 12
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            periodSeconds: 10
            failureThreshold: 3
            timeoutSeconds: 3
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
            periodSeconds: 5
            failureThreshold: 3
            timeoutSeconds: 3
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir:
            sizeLimit: 64Mi
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: my-service
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: my-service
                topologyKey: kubernetes.io/hostname
```

---

## 3. Resource Sizing Guide

Baseline resource requests and limits by language runtime. Adjust based on profiling.

| Language / Runtime | Memory Request | Memory Limit | CPU Request | CPU Limit | Notes |
|---|---|---|---|---|---|
| **Java (JVM)** | 512Mi | 1Gi | 500m | 1000m | Set `-Xmx` to 75% of memory limit |
| **Java (Native / GraalVM)** | 128Mi | 256Mi | 250m | 500m | No JVM overhead; fast startup |
| **Go** | 64Mi | 128Mi | 100m | 250m | Low baseline; watch goroutine leaks |
| **Node.js** | 256Mi | 512Mi | 250m | 500m | Set `--max-old-space-size` to 75% of limit |
| **Python** | 256Mi | 512Mi | 250m | 500m | Watch for C extension memory usage |
| **Rust** | 32Mi | 64Mi | 100m | 250m | Minimal runtime overhead |
| **Kotlin (JVM)** | 512Mi | 1Gi | 500m | 1000m | Same as Java JVM |
| **C# / .NET** | 128Mi | 256Mi | 250m | 500m | .NET 8+ with Native AOT similar to Go |

### JVM-Specific Configuration

```yaml
env:
  - name: JAVA_OPTS
    value: >-
      -XX:MaxRAMPercentage=75.0
      -XX:InitialRAMPercentage=50.0
      -XX:+UseG1GC
      -XX:+ExitOnOutOfMemoryError
```

---

## 4. Probe Configuration

### Startup Probe Timing by Runtime

| Runtime | initialDelaySeconds | periodSeconds | failureThreshold | Total Budget |
|---|---|---|---|---|
| **Java JVM** | 10 | 5 | 12 | 70s |
| **Java Native / GraalVM** | 2 | 2 | 5 | 12s |
| **Go** | 1 | 2 | 5 | 11s |
| **Rust** | 1 | 2 | 5 | 11s |
| **Node.js** | 3 | 3 | 5 | 18s |
| **Python** | 3 | 3 | 5 | 18s |

### Standard Probe Configuration

```yaml
# Startup probe: gates liveness/readiness until app is ready
startupProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 5   # Adjust per runtime table above
  periodSeconds: 5
  failureThreshold: 12
  timeoutSeconds: 3

# Liveness probe: restart pod if unhealthy
livenessProbe:
  httpGet:
    path: /healthz
    port: http
  periodSeconds: 10
  failureThreshold: 3
  timeoutSeconds: 3

# Readiness probe: remove from service if not ready
readinessProbe:
  httpGet:
    path: /readyz
    port: http
  periodSeconds: 5
  failureThreshold: 3
  timeoutSeconds: 3
```

### gRPC Probe (Kubernetes 1.24+)

```yaml
livenessProbe:
  grpc:
    port: 50051
    service: my.health.v1.Health
  periodSeconds: 10
  failureThreshold: 3
```

---

## 5. Autoscaling

### Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-service
  namespace: my-namespace
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-service
  minReplicas: 2
  maxReplicas: 10
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
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

### KEDA ScaledObject (Custom Metrics)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: my-service
  namespace: my-namespace
spec:
  scaleTargetRef:
    name: my-service
  pollingInterval: 15
  cooldownPeriod: 300
  minReplicaCount: 2
  maxReplicaCount: 20
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus.monitoring:9090
        metricName: http_requests_per_second
        query: sum(rate(http_requests_total{service="my-service"}[2m]))
        threshold: "100"
    - type: rabbitmq
      metadata:
        host: amqp://rabbitmq.messaging:5672
        queueName: my-queue
        queueLength: "50"
```

### Pod Disruption Budget (PDB)

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-service
  namespace: my-namespace
spec:
  # Use ONE of the following (not both):
  minAvailable: "50%"       # At least 50% of pods must remain available
  # maxUnavailable: 1       # At most 1 pod can be unavailable
  selector:
    matchLabels:
      app.kubernetes.io/name: my-service
```

---

## 6. Network Policies

### Default Deny-All Ingress and Egress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: my-namespace
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### Allow Specific Traffic

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-my-service
  namespace: my-namespace
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: my-service
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow traffic from ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
          podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
  egress:
    # Allow DNS resolution
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    # Allow traffic to database
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: postgresql
      ports:
        - protocol: TCP
          port: 5432
    # Allow HTTPS egress to external APIs
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
      ports:
        - protocol: TCP
          port: 443
```

---

## 7. Security Context

### Complete Pod and Container Security Context

```yaml
spec:
  # Pod-level security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
    fsGroupChangePolicy: OnRootMismatch
    seccompProfile:
      type: RuntimeDefault

  containers:
    - name: my-service
      # Container-level security context
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        capabilities:
          drop:
            - ALL
          # Add only if explicitly required:
          # add:
          #   - NET_BIND_SERVICE  # Bind to ports < 1024
      # Writable directories must use emptyDir volumes
      volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/.cache

  volumes:
    - name: tmp
      emptyDir:
        sizeLimit: 64Mi
    - name: cache
      emptyDir:
        sizeLimit: 128Mi
```

### Pod Security Standards (PSS) Labels

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

### ServiceAccount with Disabled Token Auto-Mount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service
  namespace: my-namespace
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-service
automountServiceAccountToken: false
```
