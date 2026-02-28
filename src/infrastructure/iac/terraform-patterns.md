# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Terraform Patterns -- Application Team Reference

> **Scope:** This is a REFERENCE document for application teams consuming Terraform modules. For full Terraform authoring patterns, see your platform team's Terraform standards.

## When to Use Terraform

| Use Terraform For | Do NOT Use Terraform For |
|-------------------|--------------------------|
| Cloud infrastructure (VPCs, subnets, load balancers) | Application-level Kubernetes resources (use Kustomize/Helm) |
| Managed services (RDS, ElastiCache, S3, Cloud SQL) | Kubernetes cluster internals (use Crossplane or Helm) |
| IAM roles, policies, service accounts | Secrets rotation (use Vault or cloud-native secrets manager) |
| DNS records, certificates | Application configuration (use ConfigMaps, feature flags) |
| Networking (VPCs, peering, firewalls) | One-off scripts or ad-hoc operations |
| Monitoring infrastructure (dashboards, alert rules) | Ephemeral development environments (use Crossplane or dev tools) |

## Module Structure

```
terraform/
├── modules/                        # Reusable modules
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── database/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── cache/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
├── environments/
│   ├── dev/
│   │   ├── main.tf               # Module invocations
│   │   ├── variables.tf
│   │   ├── terraform.tfvars      # Environment-specific values
│   │   ├── backend.tf            # State configuration
│   │   └── providers.tf
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   ├── backend.tf
│   │   └── providers.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       ├── backend.tf
│       └── providers.tf
└── global/                        # Shared resources (IAM, DNS zones)
    ├── main.tf
    ├── variables.tf
    └── backend.tf
```

**Rule:** NEVER put all environments in a single state file. Each environment MUST have its own state and backend configuration.

## State Management

### Remote State Backend

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "prod/my-app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

| Rule | Standard |
|------|----------|
| Backend | ALWAYS remote (S3, GCS, Azure Blob, Terraform Cloud) |
| Encryption | ALWAYS encrypted at rest |
| Locking | ALWAYS enable state locking (DynamoDB, GCS native, Azure Blob lease) |
| Access | Restrict state access via IAM; state contains sensitive data |
| Backup | Enable versioning on the state bucket |
| Local state | FORBIDDEN (except for learning/experimentation) |

### State Isolation

```
# One state per environment per service
s3://myorg-terraform-state/dev/my-app/terraform.tfstate
s3://myorg-terraform-state/staging/my-app/terraform.tfstate
s3://myorg-terraform-state/prod/my-app/terraform.tfstate
s3://myorg-terraform-state/global/iam/terraform.tfstate
```

## Workspace vs Directory-Based Isolation

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| **Workspaces** | Less code duplication, single config | Shared state backend, risk of applying to wrong env, limited variable isolation | Use for simple, identical environments |
| **Directory-based** | Full isolation, explicit per-env config, independent state | More files, potential duplication | **Preferred for production** |

**Rule:** Use directory-based isolation for production environments. Workspaces are acceptable for ephemeral or identical environments (e.g., multiple dev instances).

## Naming Conventions

```hcl
# Resources — lowercase, underscores, descriptive
resource "aws_security_group" "api_gateway_ingress" { ... }
resource "aws_rds_instance" "payment_service_primary" { ... }

# Variables — lowercase, underscores
variable "environment" { ... }
variable "database_instance_class" { ... }

# Outputs — lowercase, underscores, prefixed with resource type
output "database_endpoint" { ... }
output "cache_primary_endpoint" { ... }

# Modules — lowercase, hyphens (directory names)
module "networking" {
  source = "../../modules/networking"
}
```

| Naming Rule | Standard |
|-------------|----------|
| Resources | `{provider}_{resource_type}` + descriptive name with underscores |
| Variables | `snake_case`, descriptive, with `description` and `type` |
| Outputs | `snake_case`, prefixed for clarity |
| Modules | `snake_case` for module names, hyphenated directory names |
| Tags | Standard tags on ALL resources: `Environment`, `Service`, `Team`, `ManagedBy` |

### Mandatory Tags

```hcl
locals {
  common_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team_name
    ManagedBy   = "terraform"
    Repository  = var.repository_url
  }
}
```

**Rule:** EVERY resource MUST be tagged. Untagged resources are unowned resources.

## Secrets Handling

| Method | Use When |
|--------|----------|
| `sensitive = true` on variables/outputs | Prevent values from appearing in plan/apply output |
| External secrets manager (Vault, AWS SM) | Store and retrieve secrets at apply time |
| `data` source for existing secrets | Reference secrets already in a secrets manager |
| `sops` encrypted files | Encrypt tfvars files in Git |
| Environment variables (`TF_VAR_*`) | CI/CD pipelines, avoid secrets in files |

```hcl
# GOOD — reference existing secret
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/my-app/db-password"
}

resource "aws_rds_instance" "primary" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}

# BAD — hardcoded secret
resource "aws_rds_instance" "primary" {
  password = "my-secret-password"   # NEVER do this
}
```

**Rule:** NEVER store secrets in `.tfvars`, `*.tf` files, or state without encryption. NEVER commit secrets to Git. Use a secrets manager or encrypted variables.

## CI/CD Integration

### Pipeline Stages

```
Plan → Review → Apply (with approval)
```

| Stage | Trigger | Action |
|-------|---------|--------|
| `terraform fmt -check` | Every PR | Validate formatting |
| `terraform validate` | Every PR | Validate configuration syntax |
| `terraform plan` | Every PR | Generate and display execution plan |
| Plan review | Manual | Team reviews plan diff |
| `terraform apply` | Merge to main (with approval) | Apply changes |
| Post-apply | After apply | Run smoke tests, update inventory |

### CI/CD Rules

| Rule | Standard |
|------|----------|
| Auto-apply | FORBIDDEN in production. Always require manual approval |
| Plan output | MUST be visible in PR for review |
| Apply on PR | FORBIDDEN. Apply only on merge to main/release branch |
| Concurrent runs | Prevented by state locking |
| Rollback | Plan the previous known-good state and apply |

## Drift Detection

```yaml
# Scheduled CI job — detect drift daily
- name: Detect Drift
  schedule: "0 8 * * *"        # Daily at 8 AM
  steps:
    - terraform plan -detailed-exitcode
    # Exit code 0 = no changes
    # Exit code 1 = error
    # Exit code 2 = changes detected (drift)
    - if: exit_code == 2
      alert: "Terraform drift detected in prod/my-app"
```

| Rule | Standard |
|------|----------|
| Frequency | Daily for production, weekly for non-prod |
| Response | Investigate and reconcile within 24 hours |
| Manual changes | FORBIDDEN. All changes through Terraform |
| Emergency changes | Allowed with immediate follow-up Terraform import |

**Rule:** If manual changes are made (emergency), they MUST be imported into Terraform state within 24 hours. Unmanaged drift is a security and reliability risk.

## Terraform Rules Summary

| Rule | Standard |
|------|----------|
| State | ALWAYS remote, encrypted, locked, versioned |
| Isolation | Directory-based for production environments |
| Secrets | NEVER in plain text; use secrets manager |
| Tags | MANDATORY on all resources |
| CI/CD | Plan on PR, apply on merge with approval |
| Drift | Daily detection, 24h reconciliation SLA |
| Manual changes | FORBIDDEN (emergency exception with immediate import) |
| Modules | Version-pinned, documented, tested |
| Formatting | `terraform fmt` enforced in CI |
| Validation | `terraform validate` + `tflint` + `checkov`/`tfsec` in CI |
