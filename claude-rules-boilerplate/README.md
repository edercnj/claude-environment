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

The generator produces a **complete `.claude/` directory** with 6 components:

```
.claude/
├── README.md               <- Auto-generated project guide
├── settings.json           <- Permissions and hooks (committed to git)
├── settings.local.json     <- Local overrides template (gitignored)
├── rules/                  <- Coding rules (loaded in every conversation)
│   ├── 01-11-*.md          <- Core: universal engineering principles
│   ├── 20-25-*.md          <- Language: conventions + version features
│   ├── 30-42-*.md          <- Framework: implementation patterns
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
| Rules | 11 core + ~5 language + ~10 framework + 2 domain | Coding standards loaded in system prompt |
| Skills | 11 core + up to 7 conditional | `/command` invocable workflows |
| Knowledge Packs | Up to 3 | Internal context for agents (not user-invocable) |
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
| 01-11 | Core | `core/` |
| 20-22 | Language Common | `languages/{lang}/common/` |
| 24-25 | Language Version | `languages/{lang}/{lang}-{ver}/` |
| 30-39 | Framework Common | `frameworks/{fw}/common/` |
| 40-42 | Framework Version | `frameworks/{fw}/{fw}-{ver}/` (if exists) |
| 50 | Project Identity | Generated at setup time |
| 51 | Domain Template | `templates/` |

### 6-Phase Assembly

```
setup.sh
├── Phase 1: Rules        <- core + language + framework + project identity + domain template
├── Phase 2: Skills       <- core + conditional (feature-gated) + knowledge packs
├── Phase 3: Agents       <- mandatory + core engineers + conditional + developer
├── Phase 4: Hooks        <- post-compile check (compiled languages only)
├── Phase 5: Settings     <- settings.json from permission fragments
└── Phase 6: README       <- auto-generated project documentation
```

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

| Framework | Language | Files |
|-----------|----------|-------|
| Quarkus | Java | cdi, panache, resteasy, config, resilience, observability, testing, native-build, infrastructure, database |
| Spring Boot | Java | di, jpa, web, config, resilience, observability, testing, native-build, infrastructure, database |
| NestJS | TypeScript | di, prisma, web, config, testing |
| Express | TypeScript | middleware, web, config, testing |
| FastAPI | Python | di, sqlalchemy, web, config, testing |
| Django | Python | web, orm, config, testing |
| Gin | Go | middleware, web, config, testing |
| Ktor | Kotlin | di, exposed, web, config, testing |
| Axum | Rust | web, config, testing |
| dotnet | C# | di, ef, web, config, testing |

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

## Configuration (YAML)

```yaml
# setup-config.yaml
project:
  name: "my-project"
  type: "api"                    # api | cli | library | worker | fullstack
  purpose: "Brief description"
  architecture: "hexagonal"      # hexagonal | clean | layered | modular

language:
  name: "java"                   # java | typescript | python | go | kotlin | rust | csharp
  version: "21"                  # Depends on language

framework:
  name: "quarkus"                # Must be compatible with language
  version: "3.17"                # Optional
  build_tool: "maven"            # java: maven | gradle
  native_build: true             # GraalVM/Mandrel support

stack:
  database:
    type: "postgresql"           # postgresql | oracle | mysql | mongodb | cassandra | sqlite | none
    migration: "flyway"          # flyway | liquibase | prisma | alembic | mongock | none
  cache:
    type: "none"                 # redis | dragonfly | memcached | none
  protocols:
    - rest                       # rest | grpc | graphql | websocket | tcp-custom
  infrastructure:
    container: "docker"          # docker | podman | none
    orchestrator: "kubernetes"   # kubernetes | docker-compose | none
    observability: "opentelemetry"  # always enabled — choose backend
  smoke_tests: true

conventions:
  languages:
    code: "english"
    commits: "english"
    documentation: "english"
    logs: "english"
  git_scopes:
    - { scope: "auth", area: "Authentication module" }
```

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
| Java (Maven) | `mvn compile -q` | `.java` |
| Java (Gradle) | `gradle compileJava -q` | `.java` |
| Kotlin | `gradle compileKotlin -q` | `.kt` |
| TypeScript | `npx tsc --noEmit` | `.ts` |
| Go | `go build ./...` | `.go` |
| Rust | `cargo check` | `.rs` |
| C# | `dotnet build --no-restore -q` | `.cs` |
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
