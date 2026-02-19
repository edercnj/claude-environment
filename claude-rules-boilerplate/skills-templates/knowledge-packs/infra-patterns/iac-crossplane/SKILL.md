---
name: iac-crossplane
description: "Crossplane patterns reference covering CompositeResourceDefinitions, Compositions, Claims, Provider configuration, and comparison with Terraform. Internal reference for agents managing infrastructure."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Crossplane Patterns

## Purpose

Provide production-grade Crossplane patterns for managing cloud infrastructure using Kubernetes-native APIs, including Composite Resources, Claims, Provider configuration, and guidance on when to use Crossplane versus Terraform.

---

## 1. XRD + Composition

### CompositeResourceDefinition (XRD)

An XRD defines the schema for a custom infrastructure API. It creates both a cluster-scoped Composite Resource (XR) and an optional namespace-scoped Claim (XRC).

```yaml
# xrd-database.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdatabases.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XDatabase
    plural: xdatabases
  claimNames:
    kind: Database
    plural: databases
  defaultCompositionRef:
    name: database-aws
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                parameters:
                  type: object
                  description: Database configuration parameters
                  properties:
                    engine:
                      type: string
                      description: Database engine type
                      enum:
                        - postgres
                        - mysql
                      default: postgres
                    engineVersion:
                      type: string
                      description: Database engine version
                      default: "16"
                    storageGB:
                      type: integer
                      description: Storage size in GB
                      minimum: 10
                      maximum: 1000
                      default: 20
                    instanceSize:
                      type: string
                      description: Instance size category
                      enum:
                        - small
                        - medium
                        - large
                      default: small
                    highAvailability:
                      type: boolean
                      description: Enable multi-AZ deployment
                      default: false
                  required:
                    - engine
                    - instanceSize
              required:
                - parameters
            status:
              type: object
              properties:
                endpoint:
                  type: string
                  description: Database connection endpoint
                port:
                  type: integer
                  description: Database connection port
                secretName:
                  type: string
                  description: Name of the secret containing credentials
```

### Composition

A Composition maps an XRD to actual cloud provider resources. Multiple Compositions can exist for the same XRD (e.g., one per cloud provider).

```yaml
# composition-database-aws.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-aws
  labels:
    provider: aws
    crossplane.io/xrd: xdatabases.platform.example.com
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XDatabase
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          # DB Subnet Group
          - name: subnet-group
            base:
              apiVersion: rds.aws.upbound.io/v1beta1
              kind: SubnetGroup
              spec:
                forProvider:
                  region: us-east-1
                  description: "Managed by Crossplane"
                  subnetIds:
                    - subnet-0abc123def456789a
                    - subnet-0abc123def456789b
                    - subnet-0abc123def456789c
                providerConfigRef:
                  name: aws-provider
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: metadata.labels[crossplane.io/claim-namespace]
                toFieldPath: metadata.labels[namespace]

          # Security Group
          - name: security-group
            base:
              apiVersion: ec2.aws.upbound.io/v1beta1
              kind: SecurityGroup
              spec:
                forProvider:
                  region: us-east-1
                  vpcId: vpc-0abc123def456789a
                  description: "Database security group managed by Crossplane"
                providerConfigRef:
                  name: aws-provider
            patches:
              - type: CombineFromComposite
                combine:
                  variables:
                    - fromFieldPath: metadata.name
                  strategy: string
                  string:
                    fmt: "%s-db-sg"
                toFieldPath: spec.forProvider.name

          # Security Group Rule
          - name: security-group-rule
            base:
              apiVersion: ec2.aws.upbound.io/v1beta1
              kind: SecurityGroupIngressRule
              spec:
                forProvider:
                  region: us-east-1
                  ipProtocol: tcp
                  fromPort: 5432
                  toPort: 5432
                  cidrIpv4: "10.0.0.0/8"
                  securityGroupIdSelector:
                    matchControllerRef: true
                providerConfigRef:
                  name: aws-provider

          # RDS Instance
          - name: rds-instance
            base:
              apiVersion: rds.aws.upbound.io/v1beta2
              kind: Instance
              spec:
                forProvider:
                  region: us-east-1
                  dbSubnetGroupNameSelector:
                    matchControllerRef: true
                  vpcSecurityGroupIdSelector:
                    matchControllerRef: true
                  autoGeneratePassword: true
                  passwordSecretRef:
                    namespace: crossplane-system
                    key: password
                  username: admin
                  publiclyAccessible: false
                  storageEncrypted: true
                  storageType: gp3
                  backupRetentionPeriod: 7
                  deletionProtection: false
                  skipFinalSnapshot: true
                  autoMinorVersionUpgrade: true
                  performanceInsightsEnabled: true
                providerConfigRef:
                  name: aws-provider
                writeConnectionSecretToRef:
                  namespace: crossplane-system
            patches:
              # Engine
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.engine
                toFieldPath: spec.forProvider.engine
              # Engine version
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.engineVersion
                toFieldPath: spec.forProvider.engineVersion
              # Storage
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.storageGB
                toFieldPath: spec.forProvider.allocatedStorage
              # Instance class mapping
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.instanceSize
                toFieldPath: spec.forProvider.instanceClass
                transforms:
                  - type: map
                    map:
                      small: db.t4g.micro
                      medium: db.t4g.medium
                      large: db.r6g.large
              # High availability
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.highAvailability
                toFieldPath: spec.forProvider.multiAz
              # Connection secret name
              - type: CombineFromComposite
                combine:
                  variables:
                    - fromFieldPath: metadata.name
                  strategy: string
                  string:
                    fmt: "%s-db-conn"
                toFieldPath: spec.writeConnectionSecretToRef.name
            connectionDetails:
              - type: FromConnectionSecretKey
                name: endpoint
                key: endpoint
              - type: FromConnectionSecretKey
                name: port
                key: port
              - type: FromConnectionSecretKey
                name: username
                key: username
              - type: FromConnectionSecretKey
                name: password
                key: password
```

---

## 2. Claims

Claims are namespace-scoped requests for infrastructure. They abstract the underlying Composition and provider details, enabling developer self-service.

### Database Claim

```yaml
# claim-database.yaml
apiVersion: platform.example.com/v1alpha1
kind: Database
metadata:
  name: orders-db
  namespace: orders-service
spec:
  parameters:
    engine: postgres
    engineVersion: "16"
    storageGB: 50
    instanceSize: medium
    highAvailability: true
  compositionRef:
    name: database-aws
  writeConnectionSecretToRef:
    name: orders-db-credentials
```

### Cache Claim (Redis)

```yaml
# xrd-cache.yaml (abbreviated)
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xcaches.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XCache
    plural: xcaches
  claimNames:
    kind: Cache
    plural: caches
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                parameters:
                  type: object
                  properties:
                    engine:
                      type: string
                      enum: [redis, valkey]
                      default: redis
                    instanceSize:
                      type: string
                      enum: [small, medium, large]
                      default: small
                    highAvailability:
                      type: boolean
                      default: false
                  required:
                    - instanceSize
              required:
                - parameters
```

```yaml
# claim-cache.yaml
apiVersion: platform.example.com/v1alpha1
kind: Cache
metadata:
  name: orders-cache
  namespace: orders-service
spec:
  parameters:
    engine: redis
    instanceSize: small
    highAvailability: false
  writeConnectionSecretToRef:
    name: orders-cache-credentials
```

### Consuming Secrets in Application

```yaml
# The Claim writes connection details to a Kubernetes secret.
# Reference it in your Deployment:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-service
  namespace: orders-service
spec:
  template:
    spec:
      containers:
        - name: orders-service
          env:
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: orders-db-credentials
                  key: endpoint
            - name: DB_PORT
              valueFrom:
                secretKeyRef:
                  name: orders-db-credentials
                  key: port
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: orders-db-credentials
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: orders-db-credentials
                  key: password
```

---

## 3. Provider Configuration

### AWS Provider Setup

```yaml
# Install the AWS provider family
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-rds
spec:
  package: xpkg.upbound.io/upbound/provider-aws-rds:v1.10.0
  runtimeConfigRef:
    name: default
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-ec2
spec:
  package: xpkg.upbound.io/upbound/provider-aws-ec2:v1.10.0
  runtimeConfigRef:
    name: default
```

### Credential Management with IRSA (EKS)

```yaml
# ProviderConfig using IRSA (IAM Roles for Service Accounts)
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: aws-provider
spec:
  credentials:
    source: IRSA
```

```yaml
# ServiceAccount with IAM role annotation (created by Crossplane provider)
# Ensure the IAM role trusts the EKS OIDC provider
apiVersion: v1
kind: ServiceAccount
metadata:
  name: provider-aws-rds
  namespace: crossplane-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/crossplane-provider-aws
```

### Credential Management with Secret

```yaml
# ProviderConfig using a Kubernetes secret (for non-EKS environments)
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: aws-provider
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-credentials
      key: credentials
---
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: crossplane-system
type: Opaque
stringData:
  credentials: |
    [default]
    aws_access_key_id = AKIAIOSFODNN7EXAMPLE
    aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### GCP Provider Setup

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp-sql
spec:
  package: xpkg.upbound.io/upbound/provider-gcp-sql:v1.5.0
---
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: gcp-provider
spec:
  projectID: my-gcp-project-id
  credentials:
    source: InjectedIdentity  # Workload Identity on GKE
```

### Azure Provider Setup

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-dbforpostgresql
spec:
  package: xpkg.upbound.io/upbound/provider-azure-dbforpostgresql:v1.3.0
---
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: azure-provider
spec:
  credentials:
    source: OIDCTokenFile  # Workload Identity on AKS
  subscriptionID: "00000000-0000-0000-0000-000000000000"
  tenantID: "00000000-0000-0000-0000-000000000000"
```

---

## 4. Comparison

### Crossplane vs Terraform Decision Guide

| Criteria | Crossplane | Terraform |
|---|---|---|
| **Paradigm** | Declarative, continuously reconciling (control loop) | Declarative, plan/apply (point-in-time) |
| **State management** | Kubernetes etcd (no external state) | Remote backend (S3, GCS, Azure Blob) |
| **Drift detection** | Automatic and continuous (reconciliation loop) | Manual or scheduled (`terraform plan`) |
| **Drift remediation** | Automatic (reconciles to desired state) | Manual (`terraform apply`) |
| **API** | Kubernetes-native CRDs | CLI + HCL |
| **Self-service model** | Claims (namespace-scoped, RBAC-gated) | Modules (requires Terraform knowledge) |
| **RBAC** | Kubernetes RBAC on CRDs | Cloud IAM + Terraform Cloud teams |
| **Secret handling** | Native Kubernetes Secrets | Vault, environment variables |
| **Ecosystem** | Growing; Upbound providers | Mature; thousands of providers |
| **Learning curve** | Kubernetes expertise required | HCL expertise required |
| **Best for** | Platform teams, developer self-service, GitOps | Infrastructure teams, multi-cloud provisioning |
| **Execution model** | In-cluster controller (always running) | CI/CD pipeline (runs on demand) |
| **Rollback** | Revert manifest in Git; controller reconciles | Re-apply previous state or `terraform apply` |

### When to Use Crossplane

- You have a Kubernetes-centric platform and want infrastructure managed as CRDs.
- You need continuous reconciliation (auto-healing drift).
- You want to offer developer self-service via Claims with Kubernetes RBAC.
- Your team is already comfortable with Kubernetes operators.
- You use GitOps (ArgoCD / Flux) and want infrastructure synced the same way as apps.

### When to Use Terraform

- You manage infrastructure across many providers with complex dependency graphs.
- You need a mature ecosystem with battle-tested providers.
- You require explicit plan/apply workflow with human review gates.
- Your team has strong HCL expertise but limited Kubernetes experience.
- You manage resources that Crossplane does not yet have providers for.

### Hybrid Approach

Many organizations use both:

```
Terraform: Foundational infrastructure (VPC, IAM, EKS cluster itself)
     |
     v
Crossplane: Application-level infrastructure (databases, caches, queues)
            exposed as self-service Claims to development teams
```

```yaml
# Example: Terraform provisions the EKS cluster and installs Crossplane.
# Crossplane then manages application infrastructure via Claims.

# terraform/modules/k8s-cluster/main.tf (excerpt)
resource "helm_release" "crossplane" {
  name       = "crossplane"
  namespace  = "crossplane-system"
  repository = "https://charts.crossplane.io/stable"
  chart      = "crossplane"
  version    = "1.16.x"

  create_namespace = true

  set {
    name  = "args"
    value = "{--enable-usages}"
  }
}
```
