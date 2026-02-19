# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Container Registry Patterns

## Image Tagging Strategy

### Standard Tag Format

```
{service}:{version}-{git-sha-short}
```

**Examples:**

```
myorg/payment-service:1.5.2-a3f8c1d
myorg/api-gateway:2.0.0-b7e2f4a
myorg/worker:0.12.1-c9d3e5f
```

### Tag Types

| Tag Pattern | Environment | Purpose |
|-------------|-------------|---------|
| `{service}:{semver}-{sha7}` | Production | Immutable, traceable to exact commit |
| `{service}:{semver}` | Staging / Release | Semantic version without SHA |
| `{service}:sha-{full-sha}` | CI/CD | Unique per commit, used in pipelines |
| `{service}:{branch}-{sha7}` | Development | Branch-based for feature testing |
| `{service}:latest` | Development ONLY | Mutable, for local dev convenience |

### CI/CD Tagging Example

```bash
# Variables
SERVICE=payment-service
VERSION=$(cat VERSION)           # or extract from pom.xml, package.json
GIT_SHA=$(git rev-parse --short=7 HEAD)
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Build and tag
docker build -t ${REGISTRY}/${SERVICE}:${VERSION}-${GIT_SHA} .
docker tag ${REGISTRY}/${SERVICE}:${VERSION}-${GIT_SHA} ${REGISTRY}/${SERVICE}:${VERSION}
docker tag ${REGISTRY}/${SERVICE}:${VERSION}-${GIT_SHA} ${REGISTRY}/${SERVICE}:sha-$(git rev-parse HEAD)

# Push all tags
docker push ${REGISTRY}/${SERVICE} --all-tags
```

**Rule:** NEVER use `latest` in production. ALWAYS tag with a version and/or commit SHA. The production tag MUST be traceable to a specific commit.

## Tag Immutability

| Rule | Standard |
|------|----------|
| Production tags | IMMUTABLE. Once pushed, NEVER overwrite |
| `latest` tag | MUTABLE. Acceptable in dev registries only |
| Branch tags | MUTABLE. Overwritten on every push to branch |
| Semantic version tags | IMMUTABLE after release |
| SHA-based tags | IMMUTABLE by nature |

### Enforcing Immutability

```bash
# AWS ECR — enable tag immutability
aws ecr put-image-tag-mutability \
  --repository-name my-app \
  --image-tag-mutability IMMUTABLE

# GCP Artifact Registry — use immutable tags policy
gcloud artifacts repositories set-iam-policy ...

# Harbor — enable tag immutability per project
# Settings > Tag Immutability > Add Rule
```

**Rule:** Enable tag immutability on ALL production registries. This prevents accidental or malicious overwrites of deployed images.

## Retention Policy

### Recommended Retention Rules

| Rule | Criteria | Action |
|------|----------|--------|
| Keep tagged releases | Tags matching `v*` or `*.*.*` | Retain indefinitely (or 1 year minimum) |
| Keep recent images | Last 30 untagged images | Retain |
| Clean old untagged | Untagged images older than 14 days | Delete |
| Clean branch tags | Branch tags older than 30 days | Delete |
| Clean PR tags | PR-based tags older than 7 days | Delete |

### ECR Lifecycle Policy Example

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 30 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v", "sha-"],
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Remove untagged images older than 14 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 14
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

**Rule:** EVERY registry MUST have a retention policy. Without retention policies, registries grow unbounded and incur unnecessary storage costs.

## Vulnerability Scanning at Push

### Scanning Strategy

| Trigger | Action | Blocking |
|---------|--------|----------|
| Image push | Automatic scan | Non-blocking (async) |
| CI pipeline | Scan before push | Blocking (fail build on CRITICAL/HIGH) |
| Scheduled | Weekly full rescan | Alert on new vulnerabilities |
| Admission control | Scan at deploy time | Blocking (prevent unscanned images) |

### Integration Examples

```yaml
# GitHub Actions — scan with Trivy before push
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE }}
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'          # Fail build on CRITICAL/HIGH
```

```yaml
# Kubernetes admission — only allow scanned images
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: image-scan-webhook
# ... webhook that rejects unscanned or vulnerable images
```

**Rule:** CRITICAL vulnerabilities MUST block deployment. HIGH vulnerabilities SHOULD block deployment (with exception process). MEDIUM and LOW are tracked but do not block.

## Multi-Architecture Builds

```bash
# Create and use buildx builder
docker buildx create --name multiarch --use

# Build and push multi-arch image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ${REGISTRY}/${SERVICE}:${VERSION}-${GIT_SHA} \
  --push \
  .
```

```yaml
# GitHub Actions — multi-arch build
- name: Build and push multi-arch
  uses: docker/build-push-action@v5
  with:
    context: .
    platforms: linux/amd64,linux/arm64
    push: true
    tags: |
      ${{ env.REGISTRY }}/${{ env.SERVICE }}:${{ env.VERSION }}-${{ env.GIT_SHA }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

**Rule:** Build for `linux/amd64` AND `linux/arm64` at minimum. ARM64 instances (AWS Graviton, GCP Tau T2A) are significantly cheaper and more power-efficient.

## Registry Options

| Registry | Cloud | Strengths | Best For |
|----------|-------|-----------|----------|
| **ECR** | AWS | Native IAM, lifecycle policies, replication, scanning | AWS-native workloads |
| **ACR** | Azure | AAD integration, geo-replication, tasks (in-registry builds) | Azure-native workloads |
| **GCR / GAR** | GCP | Artifact Registry (multi-format), vulnerability analysis | GCP-native workloads |
| **Docker Hub** | Neutral | Largest public registry, Docker Official Images | Open-source distribution |
| **Harbor** | Self-hosted | RBAC, replication, scanning, audit logs, OCI-compliant | On-prem, multi-cloud, compliance |
| **GHCR** | GitHub | GitHub Actions integration, free for public repos, OCI support | Open-source, GitHub-centric workflows |

### Selection Criteria

| Criteria | Recommendation |
|----------|----------------|
| Single cloud | Use the cloud-native registry (ECR, ACR, GAR) |
| Multi-cloud | Harbor (self-hosted) or replicate across cloud registries |
| Open-source distribution | Docker Hub or GHCR |
| Compliance requirements | Harbor (full audit trail, on-prem option) |
| Cost sensitivity | GHCR (free for public), ECR (free tier), Harbor (self-hosted) |
| Air-gapped environments | Harbor (on-prem deployment) |

## Registry Rules Summary

| Rule | Standard |
|------|----------|
| Tagging | `{service}:{version}-{sha7}` for production |
| `latest` tag | FORBIDDEN in production |
| Immutability | Enabled on all production registries |
| Retention | MANDATORY lifecycle/retention policy |
| Scanning | MANDATORY on push; CRITICAL blocks deployment |
| Multi-arch | Build for amd64 + arm64 minimum |
| Authentication | NEVER embed registry credentials in Dockerfiles |
| Pull secrets | Use `imagePullSecrets` in Kubernetes, IAM roles where available |
| Mirror/cache | Use a pull-through cache to avoid Docker Hub rate limits |
