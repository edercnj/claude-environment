---
name: k8s-kustomize
description: "Kustomize patterns for environment management covering directory structure, patches, components, secret management, generators, and patch types. Internal reference for agents managing infrastructure."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Kustomize Patterns

## Purpose

Provide production-grade Kustomize patterns for managing Kubernetes manifests across multiple environments, enabling consistent configuration management without template engines.

---

## 1. Directory Structure

### Complete Base + Overlays Layout

```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   └── networkpolicy.yaml
├── components/
│   ├── observability-sidecar/
│   │   └── kustomization.yaml
│   ├── security-context/
│   │   └── kustomization.yaml
│   └── istio-sidecar/
│       └── kustomization.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   ├── patches/
    │   │   ├── replicas.yaml
    │   │   ├── resources.yaml
    │   │   └── env.yaml
    │   └── configmap.env
    ├── staging/
    │   ├── kustomization.yaml
    │   ├── patches/
    │   │   ├── replicas.yaml
    │   │   ├── resources.yaml
    │   │   └── env.yaml
    │   └── configmap.env
    └── prod/
        ├── kustomization.yaml
        ├── patches/
        │   ├── replicas.yaml
        │   ├── resources.yaml
        │   └── env.yaml
        └── configmap.env
```

### Base kustomization.yaml

```yaml
# k8s/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: my-service-base

commonLabels:
  app.kubernetes.io/name: my-service
  app.kubernetes.io/managed-by: kustomize

resources:
  - deployment.yaml
  - service.yaml
  - serviceaccount.yaml
  - hpa.yaml
  - pdb.yaml
  - networkpolicy.yaml
```

### Overlay kustomization.yaml (prod example)

```yaml
# k8s/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: my-service-prod

namespace: my-service-prod

resources:
  - ../../base

components:
  - ../../components/observability-sidecar
  - ../../components/security-context

commonLabels:
  app.kubernetes.io/environment: prod

commonAnnotations:
  team: platform

patches:
  - path: patches/replicas.yaml
  - path: patches/resources.yaml
  - path: patches/env.yaml

configMapGenerator:
  - name: my-service-config
    envs:
      - configmap.env

images:
  - name: registry.example.com/my-service
    newTag: 1.2.3-abc1234
```

---

## 2. Common Patches

### Replicas by Environment

```yaml
# k8s/overlays/dev/patches/replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
spec:
  replicas: 1
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-service
spec:
  minReplicas: 1
  maxReplicas: 2
```

```yaml
# k8s/overlays/staging/patches/replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
spec:
  replicas: 2
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-service
spec:
  minReplicas: 2
  maxReplicas: 5
```

```yaml
# k8s/overlays/prod/patches/replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
spec:
  replicas: 3
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-service
spec:
  minReplicas: 3
  maxReplicas: 15
```

### Resources by Environment

```yaml
# k8s/overlays/dev/patches/resources.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
spec:
  template:
    spec:
      containers:
        - name: my-service
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 250m
              memory: 256Mi
```

```yaml
# k8s/overlays/prod/patches/resources.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
spec:
  template:
    spec:
      containers:
        - name: my-service
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
```

### Environment Variables by Environment

```yaml
# k8s/overlays/dev/patches/env.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
spec:
  template:
    spec:
      containers:
        - name: my-service
          env:
            - name: LOG_LEVEL
              value: "debug"
            - name: ENABLE_TRACING
              value: "false"
```

```yaml
# k8s/overlays/prod/patches/env.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
spec:
  template:
    spec:
      containers:
        - name: my-service
          env:
            - name: LOG_LEVEL
              value: "info"
            - name: ENABLE_TRACING
              value: "true"
```

---

## 3. Components

Components are reusable cross-cutting concerns that can be included in any overlay.

### Observability Sidecar Component

```yaml
# k8s/components/observability-sidecar/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
  - target:
      kind: Deployment
    patch: |
      - op: add
        path: /spec/template/spec/containers/-
        value:
          name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.96.0
          args:
            - "--config=/etc/otel/config.yaml"
          ports:
            - name: otlp-grpc
              containerPort: 4317
              protocol: TCP
            - name: otlp-http
              containerPort: 4318
              protocol: TCP
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            capabilities:
              drop:
                - ALL
          volumeMounts:
            - name: otel-config
              mountPath: /etc/otel
              readOnly: true
      - op: add
        path: /spec/template/spec/volumes/-
        value:
          name: otel-config
          configMap:
            name: otel-collector-config
```

### Security Context Component

```yaml
# k8s/components/security-context/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
  - target:
      kind: Deployment
    patch: |
      - op: add
        path: /spec/template/spec/securityContext
        value:
          runAsNonRoot: true
          runAsUser: 10001
          runAsGroup: 10001
          fsGroup: 10001
          seccompProfile:
            type: RuntimeDefault
      - op: add
        path: /spec/template/spec/containers/0/securityContext
        value:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
              - ALL
```

---

## 4. Secret Management

### SealedSecrets Pattern

```yaml
# Install kubeseal CLI, then encrypt secrets
# kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# k8s/overlays/prod/sealed-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-service-db
  namespace: my-service-prod
spec:
  encryptedData:
    host: AgBz8... # Encrypted by kubeseal
    password: AgCx9... # Encrypted by kubeseal
    username: AgDy0... # Encrypted by kubeseal
  template:
    metadata:
      name: my-service-db
      namespace: my-service-prod
    type: Opaque
```

### ExternalSecrets Operator Pattern

```yaml
# k8s/overlays/prod/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-service-db
  namespace: my-service-prod
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: my-service-db
    creationPolicy: Owner
    deletionPolicy: Retain
  data:
    - secretKey: host
      remoteRef:
        key: prod/my-service/db
        property: host
    - secretKey: username
      remoteRef:
        key: prod/my-service/db
        property: username
    - secretKey: password
      remoteRef:
        key: prod/my-service/db
        property: password
```

### ClusterSecretStore (AWS Example)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
```

---

## 5. Generators

### ConfigMapGenerator

```yaml
# Generate ConfigMap from environment file
configMapGenerator:
  - name: my-service-config
    envs:
      - configmap.env
    options:
      disableNameSuffixHash: false  # Default: appends hash for rollout

  # Generate ConfigMap from literal values
  - name: my-service-feature-flags
    literals:
      - FEATURE_NEW_UI=true
      - FEATURE_DARK_MODE=false

  # Generate ConfigMap from files
  - name: my-service-nginx
    files:
      - nginx.conf
      - mime.types
```

### configmap.env Example

```env
# k8s/overlays/prod/configmap.env
APP_NAME=my-service
APP_PORT=8080
DB_POOL_SIZE=20
CACHE_TTL=300
CORS_ORIGINS=https://app.example.com
```

### SecretGenerator

```yaml
# For non-sensitive defaults (dev only); use SealedSecrets or ExternalSecrets in prod
secretGenerator:
  - name: my-service-dev-secrets
    envs:
      - secrets.env
    type: Opaque
    options:
      disableNameSuffixHash: false
```

---

## 6. Patch Types

### Decision Guide

| Criteria | Strategic Merge Patch | JSON 6902 Patch |
|---|---|---|
| **Use when** | Modifying existing fields | Adding/removing array items, precise operations |
| **Syntax** | Partial YAML matching target | JSON operations (add, remove, replace, move, copy, test) |
| **Array handling** | Merges by key (e.g., `name` for containers) | Explicit index or append (`/-`) |
| **Readability** | More readable for simple changes | More explicit for complex changes |
| **Recommended for** | Replicas, resources, env vars, labels | Sidecar injection, volume addition, annotation removal |

### Strategic Merge Patch Example

```yaml
# patches/increase-memory.yaml
# Used inline in kustomization.yaml:
# patches:
#   - path: patches/increase-memory.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
spec:
  template:
    spec:
      containers:
        - name: my-service
          resources:
            limits:
              memory: 1Gi
```

### JSON 6902 Patch Example

```yaml
# patches/add-sidecar.yaml
# Used in kustomization.yaml:
# patches:
#   - target:
#       kind: Deployment
#       name: my-service
#     path: patches/add-sidecar.yaml
- op: add
  path: /spec/template/spec/containers/-
  value:
    name: log-forwarder
    image: fluent/fluent-bit:3.0
    resources:
      requests:
        cpu: 25m
        memory: 32Mi
      limits:
        cpu: 50m
        memory: 64Mi

- op: replace
  path: /spec/replicas
  value: 5

- op: remove
  path: /metadata/annotations/deprecated-annotation
```

### Inline Patch (JSON 6902 in kustomization.yaml)

```yaml
# k8s/overlays/prod/kustomization.yaml
patches:
  - target:
      kind: Deployment
      name: my-service
    patch: |
      - op: replace
        path: /spec/replicas
        value: 5
      - op: add
        path: /spec/template/metadata/annotations/cluster-autoscaler.kubernetes.io~1safe-to-evict
        value: "true"
```
