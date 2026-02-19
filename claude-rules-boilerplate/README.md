# Claude Code Boilerplate

A **reusable, project-agnostic** generator for complete `.claude/` directories. Produces rules, skills, agents, hooks, settings, and documentation — everything a Claude Code project needs to enforce engineering standards from day one.

## Quick Start

```bash
# 1. Clone the boilerplate
git clone <repo-url> claude-rules-boilerplate
cd claude-rules-boilerplate

# 2. Run the interactive generator
./setup.sh

# 3. The complete .claude/ directory is generated — copy to your project
cp -r .claude/ /path/to/your-project/.claude/
```

Or use a config file:

```bash
cp setup-config.example.yaml setup-config.yaml
# Edit setup-config.yaml with your project settings
./setup.sh --config setup-config.yaml --output /path/to/your-project/.claude/
```

## What's Generated

The generator produces a **complete `.claude/` directory** with 8 components:

```
.claude/
├── README.md               <- Auto-generated project guide
├── settings.json           <- Permissions and hooks (committed to git)
├── settings.local.json     <- Local overrides template (gitignored)
├── rules/                  <- Coding rules (≤30 files, consolidated)
│   ├── 01-12-*.md          <- Core: universal engineering principles
│   ├── 13-protocol-conventions.md <- ALL protocols consolidated
│   ├── 14-architecture-patterns.md <- ALL patterns consolidated
│   ├── 15-security-principles.md <- Base + crypto + pentest consolidated
│   ├── 16-compliance-requirements.md <- ALL compliance consolidated (conditional)
│   ├── 20-25-*.md          <- Language: conventions + version features
│   ├── 30-{fw}-core.md     <- Framework: DI + config + web (consolidated)
│   ├── 31-{fw}-data.md     <- Framework: ORM + database (consolidated)
│   ├── 32-{fw}-operations.md <- Framework: testing + observability (consolidated)
│   └── 50-51-*.md          <- Domain: project identity + template
├── skills/                 <- Skills invocable via /command
│   ├── {core-skills}/      <- Always included (11 skills)
│   ├── {conditional}/      <- Feature-gated (up to 7 skills)
│   └── {knowledge-packs}/  <- Internal context packs (not user-invocable)
│       └── database-patterns/references/  <- DB + cache reference docs (auto-selected)
├── agents/                 <- AI personas used by skills
│   ├── {mandatory}.md      <- Always included (3 agents: architect, tech-lead, developer)
│   ├── {core-engineers}.md <- Always included (3 engineers: security, qa, performance)
│   └── {conditional}.md    <- Feature-gated (up to 4 engineers)
└── hooks/                  <- Automation scripts
    └── post-compile-check.sh  <- Auto-compile on file changes
```

| Component | Count | Description |
|-----------|-------|-------------|
| Rules | 12 core + 1 protocols + 1 patterns + 1-2 security + ~5 language + 3 framework + 2 domain | ≤30 consolidated rule files |
| Skills | 11 core + up to 9 conditional | `/command` invocable workflows |
| Knowledge Packs | Framework packs (10 frameworks) + infra packs (7 types) + database + cloud | Internal context for agents (not user-invocable) |
| Agents | 3 mandatory + 3 core + up to 4 conditional | AI personas for planning, implementation, review |
| Hooks | 1 (compiled languages) | Post-compile check on file changes |
| Settings | 2 files | Permissions (shared + local) |

## Architecture

### Four-Layer Rules

```
┌─────────────────────────────────────────────┐
│  CORE (Layer 1) — Files 01-11               │
│  Universal principles — no tech references  │
│  Clean code, SOLID, testing, git, arch,     │
│  API, security, observability, resilience,  │
│  infrastructure, database                    │
├─────────────────────────────────────────────┤
│  LANGUAGE (Layer 2) — Files 20-25           │
│  Language conventions + version features    │
│  e.g., java/common + java/java-21           │
├─────────────────────────────────────────────┤
│  FRAMEWORK (Layer 3) — Files 30-42          │
│  Framework implementation patterns          │
│  e.g., quarkus/common, spring-boot/common   │
├─────────────────────────────────────────────┤
│  DOMAIN (Layer 4) — Files 50+               │
│  Project-specific rules and business logic  │
│  Project identity + domain template         │
└─────────────────────────────────────────────┘
```

The 4-layer architecture separates **language** from **framework**, enabling:
- Multiple Java versions (11, 17, 21) independently
- Framework versioning (Quarkus 2.x vs 3.x, Spring Boot 2.7 vs 3.4)
- Content reuse (~40-50%) between frameworks on the same language

### Rule Numbering

| Range | Layer | Source |
|-------|-------|--------|
| 01-12 | Core | `core/` |
| 13 | Protocols | ALL protocols consolidated into single file |
| 14 | Patterns | ALL patterns consolidated into single file |
| 15 | Security | Base + crypto + pentest consolidated |
| 16 | Compliance | All compliance frameworks consolidated (conditional) |
| 20-22 | Language Common | `languages/{lang}/common/` |
| 24-25 | Language Version | `languages/{lang}/{lang}-{ver}/` |
| 30 | Framework Core | DI + config + web + resilience (consolidated) |
| 31 | Framework Data | ORM + database (consolidated) |
| 32 | Framework Operations | Testing + observability + native-build + infrastructure (consolidated) |
| 50 | Project Identity | Generated at setup time |
| 51 | Domain Template | `templates/` |

### 8-Phase Assembly

```
setup.sh
├── Phase 1:   Rules      <- core + language + framework + project identity + domain template
├── Phase 1.5: Patterns   <- select by architecture.style, concatenate into 14-*-patterns.md
├── Phase 1.6: Protocols  <- select by interfaces, concatenate into 13-*-conventions.md
├── Phase 2:   Skills     <- core + conditional (feature-gated) + knowledge packs
├── Phase 3:   Agents     <- mandatory + core engineers + conditional + developer
├── Phase 4:   Hooks      <- post-compile check (compiled languages only)
├── Phase 5:   Settings   <- settings.json from permission fragments
├── Phase 6:   README     <- auto-generated project documentation
└── Phase 7:   Verify     <- cross-reference validation
```

## Rules Consolidation Strategy

Source files in the boilerplate repository remain **modular** for maintainability (one concern per file). However, the generated `.claude/rules/` files are **consolidated** for context efficiency. The target is **30 or fewer rule files** for ANY project configuration.

### Why Consolidation Matters

Claude Code loads all rules into context for every conversation. More rules means less room for code, analysis, and conversation. The consolidation strategy keeps source files modular but merges them at generation time, giving you the best of both worlds.

### Expected File Counts

```
MINIMAL PROJECT (library):          ~22 files, ~80KB
TYPICAL MICROSERVICE:               ~25 files, ~120KB
ENTERPRISE MICROSERVICE:            ~26 files, ~160KB
MAXIMUM CONFIG:                     ~26 files + 6-8 knowledge packs, ~180KB rules
```

### Decision Matrix: Rule vs Knowledge Pack

| Criteria | Rule (`.claude/rules/`) | Knowledge Pack (`.claude/skills/`) |
|----------|------------------------|------------------------------------|
| Loaded when | Every conversation (system prompt) | Only when invoked by a skill/agent |
| Size target | Small, consolidated (<10KB per file) | Can be larger (reference docs, examples) |
| Use for | Coding standards, conventions, principles | Framework patterns, DB references, cloud mappings |
| Examples | SOLID, git workflow, security principles | Quarkus CDI patterns, PostgreSQL query optimization |
| Impact on context | Direct — reduces available tokens | Indirect — only loaded on demand |

### Context Audit

The `setup.sh` generator runs an automatic post-generation audit that reports:
- Total rule file count (warns if >30 files)
- Total rules size in KB (warns if >200KB)
- Knowledge pack count and size

## Supported Languages

| Language | Versions | Common Files | Version Files |
|----------|----------|--------------|---------------|
| Java | 11, 17, 21 | coding-conventions, testing-conventions, libraries | version-features |
| TypeScript | 5 | coding-conventions, testing-conventions, libraries | version-features |
| Python | 3.12 | coding-conventions, testing-conventions, libraries | version-features |
| Go | 1.22 | coding-conventions, testing-conventions, libraries | version-features |
| Kotlin | 2.0 | coding-conventions, testing-conventions, libraries | version-features |
| Rust | 2024 | coding-conventions, testing-conventions, libraries | version-features |
| C# | 12 | coding-conventions, testing-conventions, libraries | version-features |

## Supported Frameworks

| Framework | Language | Files | Knowledge Pack |
|-----------|----------|-------|----------------|
| Quarkus | Java | cdi, panache, resteasy, config, resilience, observability, testing, native-build, infrastructure, database | ✅ quarkus-patterns |
| Spring Boot | Java | di, jpa, web, config, resilience, observability, testing, native-build, infrastructure, database | ✅ spring-patterns |
| NestJS | TypeScript | di, prisma, web, config, testing | ✅ nestjs-patterns |
| Express | TypeScript | middleware, web, config, testing | ✅ express-patterns |
| FastAPI | Python | di, sqlalchemy, web, config, testing | ✅ fastapi-patterns |
| Django | Python | web, orm, config, testing | ✅ django-patterns |
| Gin | Go | middleware, web, config, testing | ✅ gin-patterns |
| Ktor | Kotlin | di, exposed, web, config, testing | ✅ ktor-patterns |
| Axum | Rust | web, config, testing | ✅ axum-patterns |
| dotnet | C# | di, ef, web, config, testing | ✅ dotnet-patterns |

### Compatibility Matrix

| Language | Compatible Frameworks |
|----------|----------------------|
| Java | quarkus, spring-boot |
| TypeScript | nestjs, express |
| Python | fastapi, django |
| Go | gin |
| Kotlin | ktor, spring-boot |
| Rust | axum |
| C# | dotnet |

## Supported Databases & Caches

The generator ships with **22 reference documents** in `databases/` covering schema design, migration patterns, query optimization, and caching strategies. References are automatically selected and copied based on your config.

### SQL Databases

| Database | Versions | Migration Tools | References |
|----------|----------|-----------------|------------|
| PostgreSQL | 14, 15, 16, 17 | Flyway, Liquibase | types-and-conventions, migration-patterns, query-optimization |
| Oracle | 19c, 21c, 23ai | Flyway, Liquibase | types-and-conventions, migration-patterns, query-optimization |
| MySQL/MariaDB | 8.0, 8.4, 9.x | Flyway, Liquibase | types-and-conventions, migration-patterns, query-optimization |

All SQL databases share `sql-principles.md` (DDL transactions, ACID, locking, ORM mapping).

### NoSQL Databases

| Database | Versions | Migration Tools | References |
|----------|----------|-----------------|------------|
| MongoDB | 6.0, 7.0, 8.0 | Mongock, mongosh scripts | modeling-patterns, migration-patterns, query-optimization |
| Cassandra | 4.1, 5.0, DSE, ScyllaDB | CQL scripts, Cognitor | modeling-patterns, migration-patterns, query-optimization |

All NoSQL databases share `nosql-principles.md` (CAP theorem, query-driven modeling, denormalization).

### Cache Systems

| Cache | Versions | Wire Protocol | References |
|-------|----------|---------------|------------|
| Redis | 7.0, 7.2, 7.4 | RESP3 | redis-patterns (data structures, Cluster vs Sentinel, Lua) |
| Dragonfly | 1.x | Redis-compatible | dragonfly-patterns (multi-thread, 25-40% less memory) |
| Memcached | 1.6 | Memcached text/binary | memcached-patterns (slab allocator, key-value only) |

All cache systems share `cache-principles.md` (Cache-Aside, TTL, key naming, thundering herd prevention).

A consolidated `version-matrix.md` cross-references all databases, caches, and framework integrations.

### Reference Selection Logic

```
databases/
├── sql/
│   ├── common/sql-principles.md        <- Copied for postgresql, oracle, mysql
│   ├── postgresql/                      <- Copied only when database = postgresql
│   ├── oracle/                          <- Copied only when database = oracle
│   └── mysql/                           <- Copied only when database = mysql
├── nosql/
│   ├── common/nosql-principles.md       <- Copied for mongodb, cassandra
│   ├── mongodb/                         <- Copied only when database = mongodb
│   └── cassandra/                       <- Copied only when database = cassandra
├── cache/
│   ├── common/cache-principles.md       <- Copied when cache != none
│   ├── redis/                           <- Copied only when cache = redis
│   ├── dragonfly/                       <- Copied only when cache = dragonfly
│   └── memcached/                       <- Copied only when cache = memcached
└── version-matrix.md                    <- Always copied when database or cache != none
```

## Architecture Styles

The `architecture.style` field drives pattern selection and cross-cutting concerns:

| Style | Description | Patterns Included |
|-------|-------------|-------------------|
| `microservice` | Independent deployable service with own data store | All microservice, resilience, integration, data patterns |
| `modular-monolith` | Single deployment with strict module boundaries | Modular-monolith, selective resilience, data patterns |
| `monolith` | Traditional single deployment, shared DB | Data patterns, circuit-breaker |
| `library` | Reusable package/SDK, no runtime deployment | Minimal — repository (if DB), adapter |
| `serverless` | Function-based, event-triggered, managed infra | Resilience, integration patterns |

Cross-cutting flags:
- `domain_driven: true` — enables DDD pattern (Anti-Corruption Layer)
- `event_driven: true` — enables event patterns (Saga, Outbox, Event Store, DLQ, Event Sourcing)

## Interfaces

The `interfaces` section defines how the service communicates with the outside world. Each interface type triggers inclusion of the corresponding protocol rules as flat `13-*-conventions.md` files.

| Type | Protocol File | Contents |
|------|--------------|----------|
| `rest` | `13-rest-conventions.md` | REST conventions + OpenAPI conventions |
| `grpc` | `13-grpc-conventions.md` | gRPC conventions + gRPC versioning |
| `graphql` | `13-graphql-conventions.md` | GraphQL conventions |
| `websocket` | `13-websocket-conventions.md` | WebSocket conventions |
| `event-consumer` / `event-producer` | `13-event-driven-conventions.md` | Event conventions + broker patterns |
| `tcp-custom` | _(no protocol file)_ | Custom TCP — define in domain rules |
| `cli` | _(no protocol file)_ | CLI — define in domain rules |
| `scheduled` | _(no protocol file)_ | Cron/batch — define in domain rules |

## Patterns Catalog

22 pattern files organized in 5 categories, selected by `architecture.style` and concatenated into flat `14-*-patterns.md` files.

> **Note:** In the "Included When" column, multiple conditions are OR — the pattern is included if **any** listed condition is met.

### Architectural (4 patterns)

| Pattern | File | Included When |
|---------|------|---------------|
| Hexagonal Architecture | `architectural/hexagonal-architecture.md` | Always |
| CQRS | `architectural/cqrs.md` | microservice, modular-monolith |
| Event Sourcing | `architectural/event-sourcing.md` | event_driven = true |
| Modular Monolith | `architectural/modular-monolith.md` | modular-monolith |

### Microservice (7 patterns)

| Pattern | File | Included When |
|---------|------|---------------|
| API Gateway | `microservice/api-gateway.md` | microservice |
| Bulkhead | `microservice/bulkhead.md` | microservice |
| Idempotency | `microservice/idempotency.md` | microservice, event_driven |
| Outbox Pattern | `microservice/outbox-pattern.md` | microservice, event_driven |
| Saga Pattern | `microservice/saga-pattern.md` | microservice, event_driven |
| Service Discovery | `microservice/service-discovery.md` | microservice |
| Strangler Fig | `microservice/strangler-fig.md` | microservice |

### Resilience (4 patterns)

| Pattern | File | Included When |
|---------|------|---------------|
| Circuit Breaker | `resilience/circuit-breaker.md` | microservice, modular-monolith, monolith, serverless |
| Dead Letter Queue | `resilience/dead-letter-queue.md` | microservice, serverless, event_driven |
| Retry with Backoff | `resilience/retry-with-backoff.md` | microservice, modular-monolith, serverless |
| Timeout Patterns | `resilience/timeout-patterns.md` | microservice, serverless |

### Data (4 patterns)

| Pattern | File | Included When |
|---------|------|---------------|
| Cache-Aside | `data/cache-aside.md` | microservice, modular-monolith, monolith |
| Event Store | `data/event-store.md` | microservice, modular-monolith, monolith, event_driven |
| Repository Pattern | `data/repository-pattern.md` | microservice, modular-monolith, monolith, library (if DB) |
| Unit of Work | `data/unit-of-work.md` | microservice, modular-monolith, monolith |

### Integration (3 patterns)

| Pattern | File | Included When |
|---------|------|---------------|
| Adapter Pattern | `integration/adapter-pattern.md` | microservice, library, serverless |
| Anti-Corruption Layer | `integration/anti-corruption-layer.md` | microservice, domain_driven |
| Backend for Frontend | `integration/backend-for-frontend.md` | microservice, serverless |

## Protocols Catalog

8 protocol files in 5 directories, selected by `interfaces` and concatenated into flat `13-*-conventions.md` files:

| Directory | Files | Triggered By |
|-----------|-------|-------------|
| `protocols/rest/` | rest-conventions.md, openapi-conventions.md | `type: rest` |
| `protocols/grpc/` | grpc-conventions.md, grpc-versioning.md | `type: grpc` |
| `protocols/graphql/` | graphql-conventions.md | `type: graphql` |
| `protocols/websocket/` | websocket-conventions.md | `type: websocket` |
| `protocols/event-driven/` | event-conventions.md, broker-patterns.md | `type: event-consumer` or `event-producer` |

## Security Configuration

The boilerplate includes a layered security system with base rules always included and compliance frameworks conditionally selected.

### Base Security Rules (always included)

Two security rule files are always assembled into every generated project:

- **`application-security.md`** — OWASP Top 10, input validation, authentication/authorization patterns, session management, error handling, logging security events.
- **`cryptography.md`** — Encryption at rest and in transit, hashing algorithms, key management, secrets handling, certificate rotation.

### Compliance Frameworks

Selected via `security.compliance[]` in the YAML config. Multiple frameworks can be combined.

| Framework | Config Value | What It Adds | Use When |
|-----------|-------------|--------------|----------|
| PCI-DSS | `pci-dss` | Cardholder data protection, audit trail, network segmentation rules | Processing credit card payments |
| PCI-SSF | `pci-ssf` | Secure software lifecycle, authentication controls | Building payment software |
| LGPD | `lgpd` | Brazilian data protection, consent management, data subject rights | Processing Brazilian personal data |
| GDPR | `gdpr` | EU data protection, privacy by design, right to be forgotten | Processing EU personal data |
| HIPAA | `hipaa` | PHI protection, minimum necessary standard, 6-year audit trail | Handling health information |
| SOX | `sox` | Change management, segregation of duties, financial audit trail | Financial reporting systems |

### Encryption Settings

Configured via `security.encryption`:

- **`at_rest`** — `aes-256-gcm` (default), `aes-256-cbc`, `chacha20-poly1305`, or `none`
- **`in_transit`** — `tls-1.3` (default), `tls-1.2`, or `mtls`
- **`key_management`** — `vault`, `aws-kms`, `azure-keyvault`, `gcp-kms`, `oci-vault`, or `manual`

> **Auto-enforcement:** Selecting `pci-dss` or `hipaa` compliance automatically forces `encryption.at_rest` to a non-`none` value.

### Pentest Readiness Checklist

When `security.pentest_readiness` is `true`, the generator includes a pentest readiness checklist covering:
- Threat modeling (STRIDE)
- Dependency scanning (CVE)
- SAST/DAST integration points
- Security headers audit
- API authentication/authorization matrix

## Cloud Provider Knowledge Packs

Selected via `cloud.provider` in the YAML config. Knowledge packs are reference documents, not rules. They map boilerplate concepts to provider-specific services.

| Provider | Config Value | Services Mapped |
|----------|-------------|----------------|
| AWS | `aws` | ECS/EKS, RDS, S3, VPC, IAM, KMS, CloudWatch, Lambda |
| Azure | `azure` | AKS, Azure SQL, Blob Storage, VNet, Entra ID, Key Vault, Monitor |
| GCP | `gcp` | GKE/Cloud Run, Cloud SQL, Cloud Storage, VPC, IAM, KMS, Monitoring |
| OCI | `oci` | OKE, Autonomous DB, Object Storage, VCN, IAM, Vault, Monitoring |

Each knowledge pack maps the abstract infrastructure, database, observability, and security patterns from the core rules to the concrete services and APIs of the selected provider.

## Infrastructure Tooling

### Kubernetes Patterns

- **Deployment patterns** — Pod specs, resource limits, health probes, rolling updates, disruption budgets
- **Kustomize patterns** — Base/overlay structure, patches, configMapGenerator, secretGenerator
- **Helm patterns** — Chart structure, values.yaml conventions, helpers, hooks, dependency management

### Container Patterns

- **Dockerfile** — Multi-stage builds per language, non-root users, layer caching, `.dockerignore`
- **Container registry** — Tagging strategy, vulnerability scanning, image signing, retention policies

### Infrastructure as Code (IaC)

- **Terraform** — Module structure, state management, workspaces, provider configuration
- **Crossplane** — Composite resources, compositions, provider configs, XRDs

### API Gateway

- **Kong** — Plugin configuration, rate limiting, authentication, service mesh integration
- **Istio** — VirtualService, DestinationRule, Gateway, AuthorizationPolicy
- **AWS API Gateway** — REST/HTTP API, Lambda integration, usage plans, throttling
- **Traefik** — IngressRoute, middleware chains, Let's Encrypt, Docker/Kubernetes providers

### Service Mesh

- **Istio** — mTLS, traffic management, circuit breaking, observability, authorization policies
- **Linkerd** — Automatic mTLS, traffic split, service profiles, retries, timeouts

## Domain Templates

Domain templates provide industry-specific rules and project scaffolding. Selected via `domain.template` in the YAML config.

| Domain | Config Value | Use When |
|--------|-------------|----------|
| ISO 8583 | `iso8583` | Payment message authorizer/simulator |
| Open Banking | `open-banking` | PIX, BACEN APIs, Open Finance |
| Healthcare FHIR | `healthcare-fhir` | FHIR R4/R5, SMART on FHIR, HL7 |
| E-commerce | `ecommerce` | Catalog, cart, checkout, payments |
| SaaS Multi-tenant | `saas-multitenant` | Tenant isolation, billing, onboarding |
| Telecom TMF | `telecom-tmf` | TM Forum Open APIs, SID model |
| Insurance ACORD | `insurance-acord` | Policy lifecycle, claims, ACORD standards |
| IoT Telemetry | `iot-telemetry` | Device registry, MQTT, edge computing |

Each domain template includes a `domain-rules.md` (coding conventions specific to the domain) and a `domain-template.md` (project structure and business logic scaffolding).

## Knowledge Pack Catalog

Knowledge packs are reference documents loaded on demand by skills and agents. They are NOT loaded into every conversation — only when a skill or agent explicitly references them.

### Framework Packs

| Pack | Condition | Content |
|------|-----------|---------|
| quarkus-patterns | framework = quarkus | CDI, Panache, RESTEasy, native build |
| spring-patterns | framework = spring-boot | Spring DI, JPA, RestController, AOT |
| nestjs-patterns | framework = nestjs | Injectable, Prisma/TypeORM, Guards |
| express-patterns | framework = express | Middleware, Router, DI patterns |
| fastapi-patterns | framework = fastapi | Depends(), SQLAlchemy, Pydantic |
| django-patterns | framework = django | ORM, CBV, DRF, Migrations |
| gin-patterns | framework = gin | Middleware, Context, GORM/sqlx |
| ktor-patterns | framework = ktor | Plugins, Routing DSL, Exposed, Koin |
| axum-patterns | framework = axum | Extractors, Tower, sqlx, Router |
| dotnet-patterns | framework = dotnet | DI, EF Core, Minimal APIs, NativeAOT |

### Infrastructure Packs

| Pack | Condition | Content |
|------|-----------|---------|
| k8s-deployment | orchestrator = kubernetes | Pod specs, resources, probes, HPA |
| k8s-kustomize | templating = kustomize | Base/overlays, patches, generators |
| k8s-helm | templating = helm | Chart structure, values, GitOps |
| dockerfile | container != none | Multi-stage builds per language |
| container-registry | registry != none | Tagging, scanning, retention |
| iac-terraform | iac = terraform | Modules, state, CI/CD, drift |
| iac-crossplane | iac = crossplane | XRD, Composition, Claims |

### Data & Cloud Packs

| Pack | Condition | Content |
|------|-----------|---------|
| database-patterns | database != none | DB-specific reference docs |
| layer-templates | Always | Layer code templates |
| cloud-{provider} | cloud.provider != none | Provider service mapping |

## Context Budget Guide

Claude Code loads **all** `.claude/rules/` files into context for every conversation. This means:

- More rules = less room for code, analysis, and conversation
- The consolidation strategy keeps source files modular but merges them at generation time
- Target: **30 or fewer rules** and **200KB or less** total size

The `setup.sh` generator runs an automatic post-generation audit that warns if these limits are exceeded. If you see warnings:

1. Review knowledge packs — move reference-heavy content from rules to knowledge packs
2. Check for redundant compliance frameworks — only include what your project actually requires
3. Consider whether all selected interfaces are necessary

## Configuration (YAML)

The v3 configuration structure (see `setup-config.example.yaml` for full reference):

```yaml
# setup-config.yaml (v3)
project:
  name: "my-service"
  purpose: "Brief description"

architecture:
  style: microservice        # microservice | modular-monolith | monolith | library | serverless
  domain_driven: false       # true = DDD pattern (Anti-Corruption Layer)
  event_driven: false        # true = event patterns (Saga, Outbox, DLQ)

interfaces:
  - type: rest
    spec: openapi            # openapi | custom
  # - type: grpc
  #   spec: proto3
  # - type: event-consumer
  #   broker: kafka

language:
  name: java                 # java | typescript | python | go | kotlin | rust | csharp
  version: "21"

framework:
  name: quarkus
  version: "3.17"
  build_tool: maven          # maven | gradle | npm | pip | go-mod | cargo | dotnet
  native_build: true

data:
  database:
    type: postgresql         # postgresql | oracle | mysql | mongodb | cassandra | sqlite | none
    version: "17"
    migration: flyway
  cache:
    type: redis              # redis | dragonfly | memcached | none
    version: "7.4"
  message_broker:
    type: none               # kafka | rabbitmq | sqs | pulsar | nats | none

infrastructure:
  container: docker          # docker | podman | none
  orchestrator: kubernetes   # kubernetes | docker-compose | none

observability:
  standard: opentelemetry
  backend: grafana-stack     # grafana-stack | elastic-stack | datadog | newrelic | custom

testing:
  smoke_tests: true
  performance_tests: true
  contract_tests: false
  chaos_tests: false

security:
  compliance:
    - "pci-dss"                # pci-dss | pci-ssf | lgpd | gdpr | hipaa | sox
  encryption:
    at_rest: "aes-256-gcm"     # aes-256-gcm | aes-256-cbc | chacha20-poly1305 | none
    in_transit: "tls-1.3"      # tls-1.3 | tls-1.2 | mtls
    key_management: "vault"    # vault | aws-kms | azure-keyvault | gcp-kms | oci-vault | manual
  pentest_readiness: true

cloud:
  provider: "aws"              # aws | azure | gcp | oci | none

infrastructure:
  templating: "kustomize"      # kustomize | helm | none
  iac: "terraform"             # terraform | crossplane | none
  registry: "ecr"              # ecr | acr | gcr | oci-registry | dockerhub | none
  api_gateway: "kong"          # kong | istio | aws-apigw | traefik | none
  service_mesh: "istio"        # istio | linkerd | none

domain:
  template: "iso8583"          # iso8583 | open-banking | healthcare-fhir | ecommerce |
                               # saas-multitenant | telecom-tmf | insurance-acord | iot-telemetry

conventions:
  code_language: en
  commit_language: en
  documentation_language: pt-br
  git_scopes:
    - { scope: "auth", area: "Authentication module" }
```

## Migration Guide (v2 to v3)

If you have an existing v2 config file, update these sections:

| v2 Field | v3 Field | Change |
|----------|----------|--------|
| `project.type` | _(removed)_ | No longer needed — use `architecture.style` |
| `project.architecture` | _(removed)_ | Internal architecture (hexagonal) is always applied |
| _(new)_ | `architecture.style` | Required — defines deployment topology |
| _(new)_ | `architecture.domain_driven` | Optional — enables DDD pattern (Anti-Corruption Layer) |
| _(new)_ | `architecture.event_driven` | Optional — enables event patterns |
| `stack.protocols` (string array) | `interfaces` (object array) | Each entry is now `{type, spec?, broker?}` |
| `stack.database` | `data.database` | Moved under `data` section, added `version` |
| `stack.cache` | `data.cache` | Moved under `data` section, added `version` |
| _(new)_ | `data.message_broker` | New field for event broker type |
| `stack.infrastructure` | `infrastructure` | Promoted to top-level section |
| `stack.smoke_tests` | `testing.smoke_tests` | Moved to `testing` section |
| _(new)_ | `testing.performance_tests` | New field |
| _(new)_ | `testing.contract_tests` | New field |
| _(new)_ | `testing.chaos_tests` | New field |
| `conventions.languages.*` | `conventions.code_language`, etc. | Flattened — no nested `languages` object |

The setup script auto-detects v2 configs and migrates them with a deprecation warning.

## Skills Catalog

### Core Skills (always included)

| Skill | Command | Description |
|-------|---------|-------------|
| feature-lifecycle | `/feature-lifecycle` | Orchestrates 8-phase feature implementation cycle |
| commit-and-push | `/commit-and-push` | Git operations: branch, commit, push, PR |
| task-decomposer | `/task-decomposer` | Decomposes plans into parallelizable tasks |
| group-verifier | `/group-verifier` | Build gate between task groups |
| implement-story | `/implement-story` | Implements feature following project conventions |
| run-tests | `/run-tests` | Runs tests with coverage reporting |
| troubleshoot | `/troubleshoot` | Diagnoses errors and build failures |
| review | `/review` | Parallel specialist review (Security, QA, Perf, etc.) |
| review-pr | `/review-pr` | Tech Lead holistic review (GO/NO-GO) |
| audit-rules | `/audit-rules` | Audits code compliance against rules |
| plan-tests | `/plan-tests` | Generates test plan before implementation |

### Conditional Skills (feature-gated)

| Skill | Command | Condition |
|-------|---------|-----------|
| review-api | `/review-api` | `rest` in protocols |
| instrument-otel | `/instrument-otel` | Always (observability always enabled) |
| setup-environment | `/setup-environment` | orchestrator != `none` |
| run-smoke-api | `/run-smoke-api` | smoke_tests + `rest` |
| run-smoke-socket | `/run-smoke-socket` | smoke_tests + `tcp-custom` |
| run-e2e | `/run-e2e` | Always available |
| run-perf-test | `/run-perf-test` | Always available |
| security-compliance-review | `/security-compliance-review` | Any item in `security.compliance[]` |
| review-gateway | `/review-gateway` | `infrastructure.api_gateway != none` |

## Agents Catalog

### Mandatory Agents (always included, cannot be disabled)

| Agent | File | Role | Model |
|-------|------|------|-------|
| Architect | `architect.md` | Planner — creates implementation plans | Opus |
| Tech Lead | `tech-lead.md` | Approver — 40-point GO/NO-GO review | Adaptive |
| Developer | `{lang}-developer.md` | Implementer — writes production code | Adaptive |

### Core Engineers (always included by default)

| Agent | File | Checklist | Model |
|-------|------|-----------|-------|
| Security Engineer | `security-engineer.md` | 20-point security checklist | Adaptive |
| QA Engineer | `qa-engineer.md` | 24-point quality checklist | Adaptive |
| Performance Engineer | `performance-engineer.md` | 26-point performance checklist | Adaptive |

### Conditional Engineers (feature-gated)

| Agent | File | Condition |
|-------|------|-----------|
| Database Engineer | `database-engineer.md` | database != `none` OR cache != `none` |
| Observability Engineer | `observability-engineer.md` | Always (observability always enabled) |
| DevOps Engineer | `devops-engineer.md` | container or orchestrator != `none` |
| API Engineer | `api-engineer.md` | `rest` in protocols |

## Hooks

Post-compile hooks automatically check compilation after file changes:

| Language | Compile Command | File Extension |
|----------|----------------|----------------|
| Java (Maven) | `./mvnw compile -q` | `.java` |
| Java (Gradle) | `./gradlew compileJava -q` | `.java` |
| Kotlin | `./gradlew compileKotlin -q` | `.kt` |
| TypeScript | `npx --no-install tsc --noEmit` | `.ts`, `.tsx`, `.mts`, `.cts` |
| Go | `go build ./...` | `.go` |
| Rust | `cargo check` | `.rs` |
| C# | `dotnet build --no-restore --verbosity quiet` | `.cs` |
| Python | _(no compile hook)_ | -- |

## Settings

`settings.json` is composed from permission fragments based on your stack:

| Fragment | Included When | Permissions |
|----------|--------------|-------------|
| `base` | Always | git, gh, curl, WebSearch |
| `{language}` | Always | mvn, npm, go, cargo, etc. |
| `docker` | container = docker/podman | docker |
| `kubernetes` | orchestrator = kubernetes | kubectl, kustomize, minikube |
| `docker-compose` | orchestrator = docker-compose | docker-compose |
| `database-psql` | database = postgresql | psql |
| `database-oracle` | database = oracle | sqlplus, sqlcl |
| `database-mysql` | database = mysql | mysql |
| `database-mongodb` | database = mongodb | mongosh, mongodump, mongorestore |
| `database-cassandra` | database = cassandra | cqlsh, nodetool |
| `cache-redis` | cache = redis | redis-cli |
| `cache-dragonfly` | cache = dragonfly | redis-cli (wire-compatible) |
| `cache-memcached` | cache = memcached | memcstat, memccat, memcflush |
| `testing-newman` | smoke_tests = true | newman |

## Customization

After generating `.claude/`:

1. **Review `rules/50-project-identity.md`** -- Update with your project specifics
2. **Fill in `rules/51-domain.md`** -- Add your domain rules and business logic
3. **Customize git scopes** -- Add domain-specific scopes to `rules/04-git-workflow.md`
4. **Review `settings.json`** -- Verify permissions match your workflow
5. **Add local overrides** -- Use `settings.local.json` for personal preferences

## Contributing

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for how to:
- Add a new language version
- Add a new framework
- Add a new domain example
- Add new skills or agents
- Improve existing rules

## License

MIT
