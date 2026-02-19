# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Crossplane Patterns -- Kubernetes-Native Infrastructure

## When to Use Crossplane

| Use Crossplane For | Do NOT Use Crossplane For |
|--------------------|---------------------------|
| Self-service infrastructure for application teams | Complex multi-step provisioning with conditional logic |
| Kubernetes-native infrastructure management (GitOps) | Teams already proficient with Terraform and no K8s platform |
| Abstracting cloud complexity behind simple claims | One-off infrastructure that will never change |
| Multi-cloud resource provisioning from a single API | Air-gapped environments without Crossplane operator support |
| Platform engineering: golden paths for developers | Resources that require imperative provisioning steps |
| Infrastructure that follows the same lifecycle as K8s workloads | Legacy infrastructure with extensive Terraform state |

**Decision rule:** If your team runs a Kubernetes platform and wants developers to self-service infrastructure via `kubectl apply`, use Crossplane. If your team manages infrastructure separately from K8s, Terraform is likely a better fit.

## Composition Pattern (XRDs + Compositions)

### Architecture Overview

```
Developer (Claim) → XRD (API Definition) → Composition (Implementation) → Managed Resources (Cloud)

┌─────────────┐     ┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│   Claim      │────>│     XRD      │────>│  Composition  │────>│  Managed     │
│ (namespace)  │     │ (cluster)    │     │  (cluster)    │     │  Resources   │
│              │     │              │     │               │     │  (cloud)     │
│ "I need a    │     │ Defines the  │     │ Implements    │     │ RDS instance │
│  database"   │     │ API schema   │     │ the mapping   │     │ Security Grp │
│              │     │              │     │ to real infra │     │ Subnet Group │
└─────────────┘     └──────────────┘     └───────────────┘     └──────────────┘
```

### Composite Resource Definition (XRD)

The XRD defines the API that developers interact with. It abstracts away cloud-specific details.

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xpostgresqlinstances.database.example.com
spec:
  group: database.example.com
  names:
    kind: XPostgreSQLInstance
    plural: xpostgresqlinstances
  claimNames:
    kind: PostgreSQLInstance
    plural: postgresqlinstances
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
                    size:
                      type: string
                      enum: ["small", "medium", "large"]
                      description: "Database size tier"
                    version:
                      type: string
                      default: "15"
                      description: "PostgreSQL major version"
                    storage:
                      type: integer
                      default: 20
                      description: "Storage in GB"
                  required:
                    - size
              required:
                - parameters
```

**Rule:** XRDs MUST expose a simplified API. Developers should NOT need to know cloud-specific parameters. Use enums (`small`, `medium`, `large`) instead of raw instance types.

### Composition

The Composition maps the abstract XRD to concrete cloud resources.

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgresql-aws
  labels:
    provider: aws
    crossplane.io/xrd: xpostgresqlinstances.database.example.com
spec:
  compositeTypeRef:
    apiVersion: database.example.com/v1alpha1
    kind: XPostgreSQLInstance
  resources:
    - name: rds-instance
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: Instance
        spec:
          forProvider:
            engine: postgres
            publiclyAccessible: false
            storageEncrypted: true
            autoMinorVersionUpgrade: true
            backupRetentionPeriod: 7
            deletionProtection: true
            skipFinalSnapshot: false
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.version
          toFieldPath: spec.forProvider.engineVersion
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.storage
          toFieldPath: spec.forProvider.allocatedStorage
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.size
          toFieldPath: spec.forProvider.instanceClass
          transforms:
            - type: map
              map:
                small: db.t3.micro
                medium: db.r6g.large
                large: db.r6g.xlarge
        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.endpoint
          toFieldPath: status.endpoint

    - name: security-group
      base:
        apiVersion: ec2.aws.upbound.io/v1beta1
        kind: SecurityGroup
        spec:
          forProvider:
            description: "PostgreSQL access"
      patches:
        - type: CombineFromComposite
          combine:
            variables:
              - fromFieldPath: metadata.name
            strategy: string
            string:
              fmt: "%s-pg-sg"
          toFieldPath: metadata.name

    - name: db-subnet-group
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: SubnetGroup
        spec:
          forProvider:
            description: "Database subnet group"
```

**Rule:** Compositions MUST enforce security defaults (encryption, private access, backups). Developers should NOT be able to create insecure resources through claims.

### Claim (Developer Interface)

```yaml
# This is what a developer writes — simple, cloud-agnostic
apiVersion: database.example.com/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: my-app-db
  namespace: my-app
spec:
  parameters:
    size: medium
    version: "15"
    storage: 50
  compositionSelector:
    matchLabels:
      provider: aws
  writeConnectionSecretToRef:
    name: my-app-db-credentials
```

**Rule:** Claims are namespace-scoped. Developers create claims in their namespace; the platform team manages XRDs and Compositions at the cluster level.

## Provider Model

### Available Providers

| Provider | Resources | Maturity |
|----------|-----------|----------|
| `provider-aws` (Upbound) | 900+ AWS resources | Stable |
| `provider-azure` (Upbound) | 700+ Azure resources | Stable |
| `provider-gcp` (Upbound) | 600+ GCP resources | Stable |
| `provider-kubernetes` | Kubernetes objects | Stable |
| `provider-helm` | Helm releases | Stable |
| `provider-sql` | Database schemas, roles | Beta |
| `provider-terraform` | Terraform modules as MRs | Beta |

### Provider Configuration

```yaml
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: IRSA                   # Use IAM Roles for Service Accounts
    # OR
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-credentials
      key: credentials
```

**Rule:** ALWAYS use workload identity (IRSA, Workload Identity, Managed Identity) for provider authentication. NEVER store long-lived cloud credentials as Kubernetes secrets in production.

## Claim-Based Consumption

### Self-Service Workflow

```
1. Platform team defines XRD + Composition (one-time setup)
2. Developer writes a Claim (simple YAML)
3. Developer applies: kubectl apply -f claim.yaml
4. Crossplane creates the cloud resources
5. Connection secret is written to the developer's namespace
6. Developer references the secret in their application
```

### Connection Secret Usage

```yaml
# Application Deployment referencing the Crossplane-managed secret
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
        - name: my-app
          volumeMounts:
            - name: db-credentials
              mountPath: /etc/secrets/db
              readOnly: true
      volumes:
        - name: db-credentials
          secret:
            secretName: my-app-db-credentials    # Written by Crossplane claim
```

**Rule:** Connection secrets from Crossplane MUST be mounted as volumes (not environment variables), following the same secret handling patterns as all other Kubernetes secrets.

## Comparison to Terraform

| Aspect | Crossplane | Terraform |
|--------|------------|-----------|
| **Language** | YAML (Kubernetes CRDs) | HCL |
| **State** | Kubernetes etcd (cluster state) | Remote backend (S3, GCS, etc.) |
| **Reconciliation** | Continuous (controller loop) | On-demand (`terraform apply`) |
| **Drift detection** | Automatic (constant reconciliation) | Manual (`terraform plan`) |
| **Self-service** | Native (claims + RBAC) | Requires wrapper tooling |
| **GitOps** | Native (ArgoCD/Flux apply CRDs) | Requires Atlantis or similar |
| **Ecosystem** | Growing (900+ AWS resources) | Mature (thousands of providers) |
| **Learning curve** | Kubernetes knowledge required | HCL knowledge required |
| **Multi-cloud** | Single API, multiple compositions | Separate provider configs |
| **Secrets** | Kubernetes-native secret handling | External tooling needed |
| **Rollback** | Delete the claim (controller cleans up) | `terraform destroy` or revert state |
| **Team model** | Platform team (XRDs) + Dev team (Claims) | Infra team or self-service with wrappers |

### When to Choose Each

- **Choose Crossplane** if: You have a Kubernetes platform, want self-service for developers, need continuous reconciliation, and prefer GitOps-native workflows.
- **Choose Terraform** if: Your team is Terraform-proficient, you manage infrastructure outside Kubernetes, need complex conditional logic, or manage resources with extensive existing Terraform state.
- **Use both** if: Terraform manages foundational infrastructure (VPCs, accounts, clusters), and Crossplane manages application-level infrastructure (databases, caches, queues) that developers consume.

## When NOT to Use Crossplane

| Scenario | Why Not | Alternative |
|----------|---------|-------------|
| No Kubernetes cluster | Crossplane runs on Kubernetes | Use Terraform |
| Complex conditional provisioning | YAML compositions are limited vs HCL | Use Terraform |
| Small team, simple infra | Crossplane adds operational overhead | Use Terraform or cloud console |
| Extensive existing Terraform state | Migration cost is high | Keep Terraform, evaluate incrementally |
| Resources needing imperative steps | Crossplane is declarative-only | Use Terraform with provisioners or scripts |
| Air-gapped without operator support | Crossplane requires controller connectivity | Use Terraform with local providers |

## Crossplane Rules Summary

| Rule | Standard |
|------|----------|
| XRD design | Simple, cloud-agnostic API with enum-based sizing |
| Compositions | Enforce security defaults (encryption, private access, backups) |
| Claims | Namespace-scoped, developer-facing |
| Authentication | Workload identity (IRSA, WI, MI); NEVER long-lived credentials |
| Secrets | Connection secrets mounted as volumes |
| GitOps | XRDs, Compositions, and Claims stored in Git; deployed via ArgoCD/Flux |
| Naming | Standard Kubernetes naming conventions |
| Versioning | Version XRDs (`v1alpha1` -> `v1beta1` -> `v1`) following K8s API conventions |
| Monitoring | Monitor Crossplane controller health and resource reconciliation status |
| RBAC | Platform team: manage XRDs/Compositions; Developers: create Claims only |
