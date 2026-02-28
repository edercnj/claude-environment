---
name: k8s-helm
description: "Helm chart patterns for application deployment covering chart structure, values templates, multi-environment configuration, dependencies, testing, GitOps integration, and Helmfile orchestration. Internal reference for agents managing infrastructure."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Helm Chart Patterns

## Purpose

Provide production-grade Helm chart patterns for packaging, deploying, and managing Kubernetes applications across multiple environments with GitOps workflows.

---

## 1. Chart Structure

### Complete Chart Directory

```
charts/my-service/
├── Chart.yaml
├── Chart.lock
├── values.yaml
├── values-dev.yaml
├── values-staging.yaml
├── values-prod.yaml
├── .helmignore
├── templates/
│   ├── _helpers.tpl
│   ├── NOTES.txt
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── networkpolicy.yaml
│   └── tests/
│       └── test-connection.yaml
└── ci/
    ├── dev-values.yaml
    └── prod-values.yaml
```

### Chart.yaml

```yaml
apiVersion: v2
name: my-service
description: A Helm chart for my-service
type: application
version: 0.1.0       # Chart version (bump on chart changes)
appVersion: "1.0.0"  # Application version (bump on app changes)

maintainers:
  - name: Platform Team
    email: platform@example.com

dependencies:
  - name: postgresql
    version: "15.x.x"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: postgresql.enabled
  - name: redis
    version: "19.x.x"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: redis.enabled
    alias: cache
```

### _helpers.tpl

```yaml
{{/* templates/_helpers.tpl */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "my-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncate at 63 chars because Kubernetes name fields are limited to this.
*/}}
{{- define "my-service.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "my-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "my-service.labels" -}}
helm.sh/chart: {{ include "my-service.chart" . }}
{{ include "my-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "my-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "my-service.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the image reference
*/}}
{{- define "my-service.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}
```

### Deployment Template

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-service.fullname" . }}
  labels:
    {{- include "my-service.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  revisionHistoryLimit: {{ .Values.revisionHistoryLimit | default 5 }}
  selector:
    matchLabels:
      {{- include "my-service.selectorLabels" . | nindent 6 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: {{ .Values.strategy.maxSurge | default 1 }}
      maxUnavailable: {{ .Values.strategy.maxUnavailable | default 0 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "my-service.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      serviceAccountName: {{ include "my-service.serviceAccountName" . }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds | default 30 }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: {{ include "my-service.image" . }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort | default 8080 }}
              protocol: TCP
          {{- with .Values.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          {{- if .Values.startupProbe.enabled }}
          startupProbe:
            httpGet:
              path: {{ .Values.startupProbe.path }}
              port: http
            initialDelaySeconds: {{ .Values.startupProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.startupProbe.periodSeconds }}
            failureThreshold: {{ .Values.startupProbe.failureThreshold }}
          {{- end }}
          {{- if .Values.livenessProbe.enabled }}
          livenessProbe:
            httpGet:
              path: {{ .Values.livenessProbe.path }}
              port: http
            periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
            failureThreshold: {{ .Values.livenessProbe.failureThreshold }}
          {{- end }}
          {{- if .Values.readinessProbe.enabled }}
          readinessProbe:
            httpGet:
              path: {{ .Values.readinessProbe.path }}
              port: http
            periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
            failureThreshold: {{ .Values.readinessProbe.failureThreshold }}
          {{- end }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            {{- with .Values.extraVolumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
      volumes:
        - name: tmp
          emptyDir:
            sizeLimit: 64Mi
        {{- with .Values.extraVolumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

---

## 2. Values Template

### values.yaml with All Common Fields

```yaml
# charts/my-service/values.yaml

# -- Number of replicas (ignored when autoscaling is enabled)
replicaCount: 2

# -- Override chart name
nameOverride: ""
# -- Override full name
fullnameOverride: ""

# -- Labels to add to all resources
commonLabels: {}

image:
  # -- Container registry
  registry: registry.example.com
  # -- Image repository
  repository: my-service
  # -- Image tag (defaults to Chart.appVersion)
  tag: ""
  # -- Image pull policy
  pullPolicy: IfNotPresent

# -- Image pull secrets
imagePullSecrets: []

serviceAccount:
  # -- Create a ServiceAccount
  create: true
  # -- ServiceAccount name (auto-generated if empty)
  name: ""
  # -- Annotations for the ServiceAccount (e.g., IAM role)
  annotations: {}

# -- Pod-level security context
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault

# -- Container-level security context
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  capabilities:
    drop:
      - ALL

service:
  # -- Service type
  type: ClusterIP
  # -- Service port
  port: 80
  # -- Container target port
  targetPort: 8080

ingress:
  # -- Enable Ingress
  enabled: false
  # -- Ingress class name
  className: nginx
  # -- Ingress annotations
  annotations: {}
  # -- Ingress hosts
  hosts:
    - host: my-service.example.com
      paths:
        - path: /
          pathType: Prefix
  # -- TLS configuration
  tls: []

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

# -- Environment variables
env: []
# -- Environment from ConfigMap/Secret references
envFrom: []

startupProbe:
  enabled: true
  path: /healthz
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 12

livenessProbe:
  enabled: true
  path: /healthz
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  enabled: true
  path: /readyz
  periodSeconds: 5
  failureThreshold: 3

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

pdb:
  enabled: true
  minAvailable: "50%"

strategy:
  maxSurge: 1
  maxUnavailable: 0

# -- Termination grace period in seconds
terminationGracePeriodSeconds: 30

# -- Pod annotations
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"

# -- Pod labels (in addition to common labels)
podLabels: {}

# -- Topology spread constraints
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels: {}

# -- Node selector
nodeSelector: {}
# -- Tolerations
tolerations: []

# -- Extra volumes
extraVolumes: []
# -- Extra volume mounts
extraVolumeMounts: []

# -- Dependency: PostgreSQL subchart
postgresql:
  enabled: false

# -- Dependency: Redis subchart (aliased as cache)
cache:
  enabled: false
```

---

## 3. Multi-Environment

### values-dev.yaml

```yaml
# charts/my-service/values-dev.yaml
replicaCount: 1

image:
  tag: "latest"

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: false

pdb:
  enabled: false

env:
  - name: LOG_LEVEL
    value: "debug"
  - name: ENABLE_TRACING
    value: "false"

ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
  hosts:
    - host: my-service.dev.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: my-service-dev-tls
      hosts:
        - my-service.dev.example.com
```

### values-staging.yaml

```yaml
# charts/my-service/values-staging.yaml
replicaCount: 2

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5

env:
  - name: LOG_LEVEL
    value: "info"
  - name: ENABLE_TRACING
    value: "true"

ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
  hosts:
    - host: my-service.staging.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: my-service-staging-tls
      hosts:
        - my-service.staging.example.com
```

### values-prod.yaml

```yaml
# charts/my-service/values-prod.yaml
replicaCount: 3

resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 15

env:
  - name: LOG_LEVEL
    value: "warn"
  - name: ENABLE_TRACING
    value: "true"

ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
  hosts:
    - host: my-service.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: my-service-prod-tls
      hosts:
        - my-service.example.com

serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-service-prod
```

---

## 4. Dependencies

### Subchart Management in Chart.yaml

```yaml
dependencies:
  # Conditionally enabled subchart
  - name: postgresql
    version: "15.5.x"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: postgresql.enabled

  # Aliased subchart (use different name in values.yaml)
  - name: redis
    version: "19.6.x"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: cache.enabled
    alias: cache

  # Import specific values from subchart
  - name: common
    version: "2.x.x"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    tags:
      - common
```

### Subchart Configuration in values.yaml

```yaml
# Enable/disable subcharts
postgresql:
  enabled: true
  auth:
    database: myservice
    username: myservice
    existingSecret: my-service-db-credentials
  primary:
    persistence:
      size: 10Gi
    resources:
      requests:
        cpu: 250m
        memory: 256Mi

cache:
  enabled: true
  architecture: standalone
  auth:
    enabled: true
    existingSecret: my-service-cache-credentials
  master:
    persistence:
      size: 1Gi
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
```

---

## 5. Testing

### Post-Deployment Connection Test

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "my-service.fullname" . }}-test-connection"
  labels:
    {{- include "my-service.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: wget
      image: busybox:1.36
      command: ['wget']
      args:
        - '--spider'
        - '--timeout=5'
        - 'http://{{ include "my-service.fullname" . }}:{{ .Values.service.port }}/healthz'
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      resources:
        limits:
          cpu: 50m
          memory: 32Mi
```

### Comprehensive API Test

```yaml
# templates/tests/test-api.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "my-service.fullname" . }}-test-api"
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: test
      image: curlimages/curl:8.7.1
      command: ["/bin/sh", "-c"]
      args:
        - |
          set -e
          BASE_URL="http://{{ include "my-service.fullname" . }}:{{ .Values.service.port }}"

          echo "Testing health endpoint..."
          curl -sf "${BASE_URL}/healthz" || exit 1

          echo "Testing readiness endpoint..."
          curl -sf "${BASE_URL}/readyz" || exit 1

          echo "Testing API response..."
          STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/status")
          [ "$STATUS" = "200" ] || exit 1

          echo "All tests passed."
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      resources:
        limits:
          cpu: 50m
          memory: 32Mi
```

---

## 6. GitOps Integration

### ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-service-prod
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: my-project
  source:
    repoURL: https://github.com/example/platform-charts.git
    targetRevision: main
    path: charts/my-service
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: my-service-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        maxDuration: 3m
        factor: 2
```

### ArgoCD ApplicationSet (Multi-Environment)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-service
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            cluster: https://dev-cluster.example.com
            namespace: my-service-dev
          - env: staging
            cluster: https://staging-cluster.example.com
            namespace: my-service-staging
          - env: prod
            cluster: https://prod-cluster.example.com
            namespace: my-service-prod
  template:
    metadata:
      name: "my-service-{{env}}"
      namespace: argocd
    spec:
      project: my-project
      source:
        repoURL: https://github.com/example/platform-charts.git
        targetRevision: main
        path: charts/my-service
        helm:
          valueFiles:
            - values.yaml
            - "values-{{env}}.yaml"
      destination:
        server: "{{cluster}}"
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

### Flux HelmRelease

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: my-service
  namespace: my-service-prod
spec:
  interval: 10m
  timeout: 5m
  chart:
    spec:
      chart: charts/my-service
      version: "0.1.x"
      sourceRef:
        kind: GitRepository
        name: platform-charts
        namespace: flux-system
      interval: 5m
  values:
    replicaCount: 3
  valuesFrom:
    - kind: ConfigMap
      name: my-service-values
      valuesKey: values-prod.yaml
  upgrade:
    remediation:
      retries: 3
  rollback:
    cleanupOnFail: true
  test:
    enable: true
```

---

## 7. Helmfile

### Multi-Chart Orchestration

```yaml
# helmfile.yaml
helmDefaults:
  wait: true
  timeout: 300
  createNamespace: true
  atomic: true

environments:
  dev:
    values:
      - environments/dev/defaults.yaml
  staging:
    values:
      - environments/staging/defaults.yaml
  prod:
    values:
      - environments/prod/defaults.yaml

repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami
  - name: ingress-nginx
    url: https://kubernetes.github.io/ingress-nginx
  - name: cert-manager
    url: https://charts.jetstack.io

releases:
  # Infrastructure components
  - name: ingress-nginx
    namespace: ingress-nginx
    chart: ingress-nginx/ingress-nginx
    version: 4.10.x
    values:
      - charts/ingress-nginx/values.yaml
      - charts/ingress-nginx/values-{{ .Environment.Name }}.yaml
    installed: true

  - name: cert-manager
    namespace: cert-manager
    chart: cert-manager/cert-manager
    version: 1.15.x
    values:
      - charts/cert-manager/values.yaml
    set:
      - name: installCRDs
        value: "true"
    installed: true

  # Application services
  - name: my-service
    namespace: my-service-{{ .Environment.Name }}
    chart: ./charts/my-service
    values:
      - charts/my-service/values.yaml
      - charts/my-service/values-{{ .Environment.Name }}.yaml
    needs:
      - ingress-nginx/ingress-nginx
      - cert-manager/cert-manager
    installed: true

  - name: worker-service
    namespace: my-service-{{ .Environment.Name }}
    chart: ./charts/worker-service
    values:
      - charts/worker-service/values.yaml
      - charts/worker-service/values-{{ .Environment.Name }}.yaml
    needs:
      - my-service-{{ .Environment.Name }}/my-service
    installed: true
```

### Usage Commands

```bash
# Diff changes before applying
helmfile -e prod diff

# Apply to specific environment
helmfile -e prod apply

# Apply a specific release
helmfile -e prod -l name=my-service apply

# Destroy all releases in an environment
helmfile -e dev destroy
```
