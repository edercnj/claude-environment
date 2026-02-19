# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Helm Patterns

## When to Use Helm vs Kustomize

| Criteria | Helm | Kustomize |
|----------|------|-----------|
| **Primary Use** | Distribution, parameterization, packaging | Internal deployments, GitOps overlays |
| **Best For** | Shared charts across teams/orgs, complex templating, conditional resources | Environment-specific overrides, simple patching |
| **Templating** | Go templates (powerful but complex) | No templating — patch-based (WYSIWYG) |
| **Dependencies** | Built-in dependency management (`Chart.yaml`) | Manual resource inclusion |
| **Versioning** | Chart versioning with semantic version | Git-based versioning |
| **Learning Curve** | Higher (Go templates, hooks, library charts) | Lower (patches, overlays) |
| **Debugging** | `helm template` to inspect rendered output | `kustomize build` to inspect output |

### Decision Matrix

- **Use Helm when:**
  - Distributing charts to external consumers (open-source, shared platform charts)
  - Heavy parameterization is required (100+ configurable values)
  - You need lifecycle hooks (pre-install, post-upgrade, pre-delete)
  - Managing third-party applications (cert-manager, ingress-nginx, Prometheus)

- **Use Kustomize when:**
  - Internal application deployments with environment overlays
  - You prefer declarative, patch-based configuration over templating
  - GitOps with ArgoCD or Flux (native Kustomize support)
  - Simple environment-specific overrides (replicas, resources, config)

- **Use both together when:**
  - Consuming Helm charts but applying environment-specific overlays via Kustomize
  - ArgoCD with `helm` + Kustomize post-rendering
  - Platform team provides Helm chart, application teams overlay with Kustomize

```yaml
# ArgoCD Application — Helm + Kustomize post-rendering
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    chart: my-platform-chart
    repoURL: https://charts.example.com
    targetRevision: 2.1.0
    helm:
      valueFiles:
        - values-prod.yaml
    kustomize:
      patches:
        - target:
            kind: Deployment
          patch: |-
            - op: add
              path: /spec/template/metadata/annotations/custom
              value: "true"
```

## Chart Structure Best Practices

```
my-chart/
├── Chart.yaml                 # Chart metadata (name, version, dependencies)
├── Chart.lock                 # Locked dependency versions
├── values.yaml                # Default values (documented, sane defaults)
├── values.schema.json         # JSON Schema for values validation (optional but recommended)
├── README.md                  # Auto-generated from values (helm-docs)
├── LICENSE
├── .helmignore
├── templates/
│   ├── _helpers.tpl           # Template helpers (labels, names, selectors)
│   ├── NOTES.txt              # Post-install instructions
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   ├── ingress.yaml
│   ├── serviceaccount.yaml
│   ├── networkpolicy.yaml
│   └── tests/
│       └── test-connection.yaml
├── charts/                    # Packaged dependency charts
└── ci/
    ├── ci-values.yaml         # Values for CI testing
    └── lint-values.yaml       # Values for linting
```

### Chart.yaml

```yaml
apiVersion: v2
name: my-app
description: A Helm chart for My Application
type: application
version: 1.2.0              # Chart version — bump on ANY chart change
appVersion: "3.5.1"         # Application version — matches container image tag

maintainers:
  - name: Platform Team
    email: platform@example.com

dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

## Helm Best Practices

### Semantic Versioning (Mandatory)

| Version Component | When to Bump | Example |
|-------------------|--------------|---------|
| MAJOR | Breaking changes to values.yaml (removed keys, changed structure) | `1.0.0` -> `2.0.0` |
| MINOR | New features, new values keys, non-breaking additions | `1.0.0` -> `1.1.0` |
| PATCH | Bug fixes, documentation, template fixes | `1.0.0` -> `1.0.1` |

**Rule:** `version` (chart version) and `appVersion` (app version) are independent. Bump chart version on every chart change, even if appVersion stays the same.

### Documented values.yaml

```yaml
# -- Number of replicas for the deployment
# @default -- 1
replicaCount: 1

image:
  # -- Container image repository
  repository: ghcr.io/myorg/my-app
  # -- Image pull policy
  # @default -- IfNotPresent
  pullPolicy: IfNotPresent
  # -- Overrides the image tag (default is the chart appVersion)
  tag: ""

resources:
  # -- CPU/memory resource requests
  requests:
    cpu: 100m
    memory: 128Mi
  # -- CPU/memory resource limits
  limits:
    memory: 256Mi

# -- Enable autoscaling via HPA
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# -- Enable PodDisruptionBudget
podDisruptionBudget:
  enabled: false
  minAvailable: 1

# -- Ingress configuration
ingress:
  enabled: false
  className: nginx
  annotations: {}
  hosts:
    - host: my-app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls: []
```

**Rule:** EVERY value MUST have a comment explaining its purpose. Use `helm-docs` to auto-generate README from comments. Provide sane defaults that work out of the box for development.

### _helpers.tpl (Template Helpers)

```yaml
{{/* templates/_helpers.tpl */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "my-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "my-app.labels" -}}
helm.sh/chart: {{ include "my-app.chart" . }}
{{ include "my-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

**Rule:** ALWAYS use `_helpers.tpl` for labels, names, and selectors. NEVER hardcode chart name or release name in templates. Use `trunc 63` for Kubernetes name length limits.

### Sane Defaults

| Default | Value | Rationale |
|---------|-------|-----------|
| `replicaCount` | 1 | Works for dev; overlays increase for prod |
| `resources.requests` | Set (low) | Prevents scheduling without resources |
| `resources.limits` | Set (memory only) | Prevents OOM without CPU throttling |
| `autoscaling.enabled` | false | Opt-in for production |
| `ingress.enabled` | false | Opt-in, not every deployment needs ingress |
| `serviceAccount.create` | true | Security best practice |
| `podDisruptionBudget.enabled` | false | Opt-in for production |
| `securityContext` | Non-root, read-only FS | Security by default |

### Helm Test

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "my-app.fullname" . }}-test-connection"
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
spec:
  restartPolicy: Never
  containers:
    - name: wget
      image: busybox:1.36
      command: ['wget']
      args: ['{{ include "my-app.fullname" . }}:{{ .Values.service.port }}/healthz']
```

**Rule:** EVERY chart MUST include at least one `helm test`. Run `helm test <release>` after deployment to verify the release is functional.

### Helmfile / ArgoCD for Deployment

```yaml
# helmfile.yaml — declarative Helm release management
releases:
  - name: my-app
    namespace: my-app-prod
    chart: ./charts/my-app
    version: 1.2.0
    values:
      - values/prod.yaml
    hooks:
      - events: ["presync"]
        showlogs: true
        command: "kubectl"
        args: ["apply", "-f", "pre-deploy-job.yaml"]
```

```yaml
# ArgoCD Application — Helm source
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/my-app
    targetRevision: main
    path: charts/my-app
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Rule:** Use Helmfile or ArgoCD for managing Helm releases. NEVER run `helm install` or `helm upgrade` manually in production. All production deployments MUST be declarative and tracked in Git.

### NEVER `helm install` in Production

| Allowed | Forbidden |
|---------|-----------|
| `helm template` (render locally) | `helm install` in production |
| `helm lint` (validate chart) | `helm upgrade --install` manually in production |
| `helm test` (verify release) | Ad-hoc `helm rollback` without incident process |
| ArgoCD/Flux/Helmfile (declarative) | `helm delete` without change management |
| `helm diff` (preview changes) | `--force` flag in production |

**Rule:** Production Helm releases MUST be managed through GitOps (ArgoCD, Flux) or declarative tooling (Helmfile). Manual `helm install/upgrade` is acceptable ONLY in development and testing environments.

## Helm Rules Summary

| Rule | Standard |
|------|----------|
| Versioning | Semantic versioning for chart version AND app version |
| Values documentation | EVERY value has a comment; use `helm-docs` |
| Helpers | ALL labels, names, selectors via `_helpers.tpl` |
| Defaults | Sane defaults that work for dev out of the box |
| Tests | At least one `helm test` per chart |
| Security | Non-root, read-only FS, no privilege escalation by default |
| Production deploys | GitOps only (ArgoCD, Flux, Helmfile) |
| Linting | `helm lint` and `helm template` in CI pipeline |
| Schema validation | `values.schema.json` for complex charts |
