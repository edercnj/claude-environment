# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Kustomize Patterns

## Directory Structure

```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   ├── network-policy.yaml
│   └── service-account.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   ├── patches/
    │   │   ├── deployment-resources.yaml
    │   │   └── replicas.yaml
    │   └── configmap-values.env
    ├── staging/
    │   ├── kustomization.yaml
    │   ├── patches/
    │   │   ├── deployment-resources.yaml
    │   │   └── replicas.yaml
    │   └── configmap-values.env
    └── prod/
        ├── kustomization.yaml
        ├── patches/
        │   ├── deployment-resources.yaml
        │   ├── replicas.yaml
        │   ├── hpa.yaml
        │   └── pdb.yaml
        └── configmap-values.env
```

### Base kustomization.yaml

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

commonLabels:
  app.kubernetes.io/name: my-app
  app.kubernetes.io/managed-by: kustomize

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - service-account.yaml
  - network-policy.yaml
```

**Rule:** The base MUST be deployable on its own (valid, working manifests). Overlays customize — they do NOT fix broken base manifests.

## Patching Strategies

### Strategic Merge Patch

Merges fields into the existing resource by matching on `name` and `kind`. Best for simple field overrides.

```yaml
# overlays/prod/patches/deployment-resources.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
        - name: my-app
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              memory: 1Gi
```

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-app-prod

resources:
  - ../../base

patches:
  - path: patches/deployment-resources.yaml
  - path: patches/replicas.yaml
  - path: patches/hpa.yaml
  - path: patches/pdb.yaml
```

**When to use:** Overriding specific fields (replicas, resources, env vars). This is the default and most common patching strategy.

### JSON 6902 Patch

Precise, surgical operations on specific JSON paths. Supports `add`, `remove`, `replace`, `move`, `copy`, `test`.

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-app-dev

resources:
  - ../../base

patches:
  - target:
      kind: Deployment
      name: my-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/cpu
        value: 50m
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: 64Mi
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: 128Mi
      - op: remove
        path: /spec/template/spec/containers/0/livenessProbe/initialDelaySeconds
```

**When to use:** Removing fields, array manipulation, conditional patching by target selectors. More precise than strategic merge but less readable.

### Components

Reusable, composable sets of patches that can be included in any overlay. Ideal for cross-cutting concerns.

```yaml
# components/monitoring/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
  - target:
      kind: Deployment
    patch: |-
      - op: add
        path: /spec/template/metadata/annotations/prometheus.io~1scrape
        value: "true"
      - op: add
        path: /spec/template/metadata/annotations/prometheus.io~1port
        value: "9090"

resources:
  - service-monitor.yaml
```

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

components:
  - ../../components/monitoring
  - ../../components/service-mesh

patches:
  - path: patches/deployment-resources.yaml
```

**When to use:** Shared functionality across overlays (monitoring sidecars, service mesh annotations, security policies). Avoids copy-paste between environments.

## Common Overlays per Environment

### Dev Environment

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-app-dev

resources:
  - ../../base

patches:
  - target:
      kind: Deployment
      name: my-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/cpu
        value: 50m
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: 64Mi
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: 128Mi
      - op: replace
        path: /spec/template/spec/containers/0/imagePullPolicy
        value: Always
```

| Setting | Dev Value | Rationale |
|---------|-----------|-----------|
| Replicas | 1 | Cost savings, no HA needed |
| CPU request | 50m | Minimal footprint |
| Memory request | 64Mi | Minimal footprint |
| Memory limit | 128Mi | Low ceiling acceptable |
| Image pull policy | Always | Fast iteration with mutable tags |
| HPA | Disabled (not included) | Single replica, no scaling |
| PDB | Disabled (not included) | Single replica, no disruption budget |

### Staging Environment

```yaml
# overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-app-staging

resources:
  - ../../base

patches:
  - target:
      kind: Deployment
      name: my-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 2
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/cpu
        value: 200m
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: 256Mi
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: 512Mi
```

| Setting | Staging Value | Rationale |
|---------|---------------|-----------|
| Replicas | 2 | Validate HA behavior, test rolling updates |
| CPU request | 200m | Closer to production |
| Memory request | 256Mi | Closer to production |
| Memory limit | 512Mi | Closer to production |
| HPA | Optional (smaller range) | Test autoscaling behavior |
| PDB | Enabled | Validate disruption handling |
| Network Policies | Enabled | Match production security posture |

### Production Environment

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-app-prod

resources:
  - ../../base
  - hpa.yaml
  - pdb.yaml

components:
  - ../../components/monitoring

patches:
  - path: patches/deployment-resources.yaml
  - target:
      kind: Deployment
      name: my-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
```

| Setting | Prod Value | Rationale |
|---------|------------|-----------|
| Replicas | 3+ (via HPA minReplicas) | High availability across AZs |
| CPU request | 500m+ | Based on observed p99 usage |
| Memory request | 512Mi+ | Based on observed p99 usage |
| Memory limit | 1Gi+ | 1.5-2x of request |
| HPA | Enabled (min: 3, max: 20) | Auto-scale with demand |
| PDB | Enabled (minAvailable: 1) | Protect during node drains |
| Network Policies | Strict | Least-privilege communication |
| Topology Spread | Enabled | Cross-zone resilience |
| Anti-Affinity | Enabled | Avoid single-host failure |

## Kustomize Rules Summary

| Rule | Standard |
|------|----------|
| Base validity | Base MUST be deployable standalone |
| Namespace | Set per overlay, NEVER in base |
| Image tags | Use `images` transformer in kustomization.yaml, NEVER hardcode tags in patches |
| Secret generation | Use `secretGenerator` with env files, NEVER commit plaintext secrets |
| Labels | Use `commonLabels` in base for app identification |
| Naming | Use `namePrefix` or `nameSuffix` in overlays for disambiguation |
| Validation | Run `kustomize build overlays/{env} | kubectl apply --dry-run=server -f -` in CI |
