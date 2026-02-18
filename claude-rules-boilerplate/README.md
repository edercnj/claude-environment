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
├── README.md               ← Auto-generated project guide
├── settings.json           ← Permissions and hooks (committed to git)
├── settings.local.json     ← Local overrides template (gitignored)
├── rules/                  ← Coding rules (loaded in every conversation)
│   ├── 01-11-*.md          ← Core: universal engineering principles
│   ├── 20-29-*.md          ← Profile: technology-specific patterns
│   └── 30-31-*.md          ← Domain: project identity + template
├── skills/                 ← Skills invocable via /command
│   ├── {core-skills}/      ← Always included (11 skills)
│   ├── {conditional}/      ← Feature-gated (up to 7 skills)
│   └── {knowledge-packs}/  ← Internal context packs (not user-invocable)
├── agents/                 ← AI personas used by skills
│   ├── {core-agents}.md    ← Always included (5 agents)
│   ├── {conditional}.md    ← Feature-gated (up to 5 agents)
│   └── {developer}.md      ← Language-specific developer agent
└── hooks/                  ← Automation scripts
    └── post-compile-check.sh  ← Auto-compile on file changes
```

| Component | Count | Description |
|-----------|-------|-------------|
| Rules | 11 core + 9 profile + 2 domain | Coding standards loaded in system prompt |
| Skills | 11 core + up to 7 conditional | `/command` invocable workflows |
| Knowledge Packs | Up to 3 | Internal context for agents (not user-invocable) |
| Agents | 5 core + up to 6 conditional | AI personas for planning, implementation, review |
| Hooks | 1 (compiled languages) | Post-compile check on file changes |
| Settings | 2 files | Permissions (shared + local) |

## Architecture

### Three-Layer Rules

```
┌─────────────────────────────────────────────┐
│  CORE (Layer 1) — Files 01-11               │
│  Universal principles — no tech references  │
│  Clean code, SOLID, testing, git, arch,     │
│  API, security, observability, resilience,  │
│  infrastructure, database                    │
├─────────────────────────────────────────────┤
│  PROFILES (Layer 2) — Files 20-29           │
│  Technology-specific patterns and examples  │
│  e.g., java21-quarkus, java21-spring-boot   │
├─────────────────────────────────────────────┤
│  DOMAIN (Layer 3) — Files 30+               │
│  Project-specific rules and business logic  │
│  Project identity + domain template         │
└─────────────────────────────────────────────┘
```

### 6-Phase Assembly

```
setup.sh
├── Phase 1: Rules        ← core + profile + project identity + domain template
├── Phase 2: Skills       ← core + conditional (feature-gated) + knowledge packs
├── Phase 3: Agents       ← core + conditional + language-specific developer
├── Phase 4: Hooks        ← post-compile check (compiled languages only)
├── Phase 5: Settings     ← settings.json from permission fragments
└── Phase 6: README       ← auto-generated project documentation
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
| instrument-otel | `/instrument-otel` | observability != `none` |
| setup-environment | `/setup-environment` | orchestrator != `none` |
| run-smoke-api | `/run-smoke-api` | smoke_tests + `rest` |
| run-smoke-socket | `/run-smoke-socket` | smoke_tests + `tcp-custom` |
| run-e2e | `/run-e2e` | Always available |
| run-perf-test | `/run-perf-test` | Always available |

### Knowledge Packs (internal, not user-invocable)

| Pack | Condition |
|------|-----------|
| layer-templates | Always |
| database-patterns | database != `none` |
| {framework}-patterns | One per profile (quarkus, spring) |

## Agents Catalog

### Core Agents (always included)

| Agent | Role | Model |
|-------|------|-------|
| Architect | Planner — creates implementation plans | Opus |
| Tech Lead | Approver — 40-point GO/NO-GO review | Adaptive |
| Security Reviewer | Reviewer — 20-point security checklist | Adaptive |
| QA Reviewer | Reviewer — 24-point quality checklist | Adaptive |
| Performance Reviewer | Reviewer — 26-point performance checklist | Adaptive |

### Conditional Agents (feature-gated)

| Agent | Condition |
|-------|-----------|
| Database Engineer | database != `none` |
| Database Reviewer | database != `none` |
| Observability Engineer | observability != `none` |
| DevOps Engineer | container or orchestrator != `none` |
| API Designer | `rest` in protocols |

### Developer Agents (one per language)

| Agent | Language |
|-------|----------|
| java-developer | Java 21 (Quarkus / Spring Boot) |
| typescript-developer | TypeScript (NestJS / Express / Fastify) |
| python-developer | Python (FastAPI / Django / Flask) |
| go-developer | Go (stdlib / Gin / Fiber) |
| kotlin-developer | Kotlin (Ktor / Spring Boot) |
| rust-developer | Rust (Axum / Actix) |
| csharp-developer | C# (.NET) |

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
| Python | _(no compile hook)_ | — |

## Settings

`settings.json` is composed from permission fragments based on your stack:

| Fragment | Included When |
|----------|--------------|
| `base` | Always (git, gh, curl, WebSearch) |
| `{language}` | Always (mvn, npm, go, cargo, etc.) |
| `docker` | container = docker/podman |
| `kubernetes` | orchestrator = kubernetes |
| `docker-compose` | orchestrator = docker-compose |
| `database-psql` | database = postgresql |
| `database-mysql` | database = mysql |
| `testing-newman` | smoke_tests = true |

## Available Profiles

| Profile | Language | Framework | Status |
|---------|----------|-----------|--------|
| `java21-quarkus` | Java 21 | Quarkus 3.x | Available |
| `java21-spring-boot` | Java 21 | Spring Boot 3.x | Available |
| `typescript-nestjs` | TypeScript | NestJS | Planned |
| `python-fastapi` | Python 3.12+ | FastAPI | Planned |
| `go-stdlib` | Go 1.22+ | Standard Library | Planned |

## Domain Examples

| Example | Description |
|---------|-------------|
| `iso8583-authorizer` | Financial transaction authorizer (ISO 8583) |
| `ecommerce-api` | E-commerce REST API |
| `saas-multi-tenant` | Multi-tenant SaaS platform |

## Customization

After generating `.claude/`:

1. **Review `rules/30-project-identity.md`** — Update with your project specifics
2. **Fill in `rules/31-domain.md`** — Add your domain rules and business logic
3. **Customize git scopes** — Add domain-specific scopes to `rules/04-git-workflow.md`
4. **Review `settings.json`** — Verify permissions match your workflow
5. **Add local overrides** — Use `settings.local.json` for personal preferences

## Contributing

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for how to:
- Add a new language/framework profile
- Add a new domain example
- Add new skills or agents
- Improve existing rules

## License

MIT
