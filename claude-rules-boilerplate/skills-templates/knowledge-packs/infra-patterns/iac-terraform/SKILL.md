---
name: iac-terraform
description: "Terraform patterns reference covering module structure, remote state, naming conventions, CI/CD workflows, drift detection, and common infrastructure modules. Internal reference for agents managing infrastructure."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Terraform Patterns

## Purpose

Provide production-grade Terraform patterns for infrastructure-as-code including project structure, state management, CI/CD integration, and reusable module design across AWS, GCP, and Azure.

---

## 1. Module Structure

### Root + Modules + Environments Layout

```
terraform/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   ├── database/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── cache/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── k8s-cluster/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   ├── backend.tf
│   │   └── versions.tf
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   ├── backend.tf
│   │   └── versions.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       ├── backend.tf
│       └── versions.tf
└── global/
    ├── iam/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── dns/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### Environment main.tf

```hcl
# environments/prod/main.tf

module "vpc" {
  source = "../../modules/vpc"

  environment        = var.environment
  project            = var.project
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets

  tags = local.common_tags
}

module "database" {
  source = "../../modules/database"

  environment       = var.environment
  project           = var.project
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  instance_class    = var.db_instance_class
  engine_version    = var.db_engine_version
  allocated_storage = var.db_allocated_storage

  tags = local.common_tags
}

module "k8s_cluster" {
  source = "../../modules/k8s-cluster"

  environment    = var.environment
  project        = var.project
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  cluster_version = var.k8s_version
  node_groups    = var.node_groups

  tags = local.common_tags
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "github.com/example/infrastructure"
  }
}
```

### Module versions.tf

```hcl
# modules/vpc/versions.tf
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

---

## 2. Remote State

### AWS: S3 + DynamoDB

```hcl
# environments/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state"
    key            = "prod/infrastructure.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    kms_key_id     = "alias/terraform-state"
  }
}
```

```hcl
# Bootstrap module for state backend (apply once manually)
# global/state-backend/main.tf

resource "aws_s3_bucket" "terraform_state" {
  bucket = "mycompany-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}
```

### GCP: Google Cloud Storage

```hcl
# environments/prod/backend.tf
terraform {
  backend "gcs" {
    bucket = "mycompany-terraform-state"
    prefix = "prod/infrastructure"
  }
}
```

```hcl
# Bootstrap
resource "google_storage_bucket" "terraform_state" {
  name          = "mycompany-terraform-state"
  location      = "US"
  force_destroy = false

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }
}
```

### Azure: Blob Storage

```hcl
# environments/prod/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "prod/infrastructure.tfstate"
    use_oidc             = true
  }
}
```

```hcl
# Bootstrap
resource "azurerm_storage_account" "terraform_state" {
  name                     = "stterraformstate"
  resource_group_name      = azurerm_resource_group.terraform.name
  location                 = azurerm_resource_group.terraform.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.terraform_state.id
  container_access_type = "private"
}
```

---

## 3. Naming Conventions

### Resource Naming Pattern

```
{provider_prefix}_{resource_type}.{project}_{environment}_{component}
```

### Rules

| Element | Convention | Example |
|---|---|---|
| **Resources** | `snake_case`, descriptive | `aws_vpc.main`, `aws_subnet.private` |
| **Variables** | `snake_case`, noun-based | `vpc_cidr`, `instance_class` |
| **Outputs** | `snake_case`, prefixed by resource | `vpc_id`, `private_subnet_ids` |
| **Locals** | `snake_case` | `common_tags`, `subnet_cidrs` |
| **Modules** | `snake_case`, short | `module.vpc`, `module.database` |
| **Files** | `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `locals.tf` | Standard file set |
| **Cloud resources** | `{project}-{env}-{component}` | `myapp-prod-vpc`, `myapp-prod-rds` |

### Variable Definition Pattern

```hcl
# variables.tf
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project" {
  description = "Project name used for resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project))
    error_message = "Project must be lowercase alphanumeric with hyphens, 3-21 characters."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

### Output Definition Pattern

```hcl
# outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "database_endpoint" {
  description = "Connection endpoint for the database"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}
```

---

## 4. CI/CD

### Plan on PR, Apply on Merge

```yaml
# .github/workflows/terraform.yaml
name: Terraform
on:
  pull_request:
    paths:
      - 'terraform/**'
  push:
    branches: [main]
    paths:
      - 'terraform/**'

permissions:
  id-token: write   # OIDC authentication
  contents: read
  pull-requests: write

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      environments: ${{ steps.changes.outputs.environments }}
    steps:
      - uses: actions/checkout@v4
      - name: Detect changed environments
        id: changes
        run: |
          ENVS=$(git diff --name-only ${{ github.event.before }} ${{ github.sha }} \
            | grep '^terraform/environments/' \
            | cut -d'/' -f3 \
            | sort -u \
            | jq -R -s -c 'split("\n") | map(select(. != ""))')
          echo "environments=${ENVS}" >> "$GITHUB_OUTPUT"

  plan:
    needs: detect-changes
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: ${{ fromJson(needs.detect-changes.outputs.environments) }}
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.x"

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/terraform-plan
          aws-region: us-east-1

      - name: Terraform Init
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform init -input=false

      - name: Terraform Validate
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform validate

      - name: Terraform Plan
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform plan -input=false -out=tfplan

      - name: Post plan to PR
        uses: borchero/terraform-plan-comment@v2
        with:
          working-directory: terraform/environments/${{ matrix.environment }}
          plan-file: tfplan

  apply:
    needs: detect-changes
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    strategy:
      max-parallel: 1
      matrix:
        environment: ${{ fromJson(needs.detect-changes.outputs.environments) }}
    environment: ${{ matrix.environment }}
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.x"

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/terraform-apply
          aws-region: us-east-1

      - name: Terraform Init
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform init -input=false

      - name: Terraform Apply
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform apply -input=false -auto-approve
```

---

## 5. Drift Detection

### Scheduled Plan with Notification

```yaml
# .github/workflows/drift-detection.yaml
name: Terraform Drift Detection
on:
  schedule:
    - cron: '0 6 * * 1-5'  # Mon-Fri at 6:00 UTC
  workflow_dispatch: {}

jobs:
  drift:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.x"

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/terraform-plan
          aws-region: us-east-1

      - name: Terraform Init
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform init -input=false

      - name: Terraform Plan (detect drift)
        id: plan
        working-directory: terraform/environments/${{ matrix.environment }}
        run: |
          terraform plan -input=false -detailed-exitcode -out=tfplan 2>&1 | tee plan-output.txt
          EXIT_CODE=${PIPESTATUS[0]}
          echo "exit_code=${EXIT_CODE}" >> "$GITHUB_OUTPUT"
          # Exit code 0 = no changes, 1 = error, 2 = changes detected
        continue-on-error: true

      - name: Notify on drift
        if: steps.plan.outputs.exit_code == '2'
        run: |
          curl -X POST "${{ secrets.SLACK_WEBHOOK_URL }}" \
            -H 'Content-Type: application/json' \
            -d "{
              \"text\": \"Terraform drift detected in *${{ matrix.environment }}* environment. Review the plan output and reconcile.\",
              \"blocks\": [
                {
                  \"type\": \"section\",
                  \"text\": {
                    \"type\": \"mrkdwn\",
                    \"text\": \"*Terraform Drift Detected*\nEnvironment: \`${{ matrix.environment }}\`\nRun: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}\"
                  }
                }
              ]
            }"

      - name: Fail on error
        if: steps.plan.outputs.exit_code == '1'
        run: exit 1
```

---

## 6. Common Modules

### VPC Module

```hcl
# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name                              = "${var.project}-${var.environment}-private-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = "${var.project}-${var.environment}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-nat-eip-${var.availability_zones[count.index]}"
  })
}

# Route tables, associations, flow logs omitted for brevity
```

### Database Module

```hcl
# modules/database/main.tf
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  })
}

resource "aws_security_group" "database" {
  name_prefix = "${var.project}-${var.environment}-db-"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.project} ${var.environment} database"

  ingress {
    description     = "PostgreSQL from application"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}"

  engine               = "postgres"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2

  db_name  = var.database_name
  username = var.master_username
  password = var.master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]

  multi_az                = var.environment == "prod"
  backup_retention_period = var.environment == "prod" ? 30 : 7
  deletion_protection     = var.environment == "prod"
  skip_final_snapshot     = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project}-${var.environment}-final" : null

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = var.monitoring_role_arn

  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db"
  })
}
```

### Kubernetes Cluster Module (EKS)

```hcl
# modules/k8s-cluster/main.tf
resource "aws_eks_cluster" "main" {
  name     = "${var.project}-${var.environment}"
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.environment == "dev"
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-eks"
  })

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.vpc_resource_controller,
  ]
}

resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable_percentage = 25
  }

  labels = each.value.labels

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-${each.key}"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_policy,
  ]
}
```

### Cache Module (ElastiCache Redis)

```hcl
# modules/cache/main.tf
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "cache" {
  name_prefix = "${var.project}-${var.environment}-cache-"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.project} ${var.environment} cache"

  ingress {
    description     = "Redis from application"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-cache-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project}-${var.environment}"
  description          = "${var.project} ${var.environment} Redis cluster"

  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = var.environment == "prod" ? 3 : 1
  port                 = 6379
  parameter_group_name = var.parameter_group_name

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.cache.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.auth_token

  automatic_failover_enabled = var.environment == "prod"
  multi_az_enabled           = var.environment == "prod"

  snapshot_retention_limit = var.environment == "prod" ? 7 : 0

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-cache"
  })
}
```
