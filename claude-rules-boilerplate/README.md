# Claude Rules Boilerplate

A **reusable, project-agnostic** collection of `.claude/rules/` for Claude Code. Transform opinionated engineering standards into a modular system that any team can adopt by selecting their language, framework, database, and architecture.

## Quick Start

```bash
# 1. Clone the boilerplate
git clone <repo-url> claude-rules-boilerplate
cd claude-rules-boilerplate

# 2. Run the interactive generator
./setup.sh

# 3. Rules are generated in .claude/rules/ — copy to your project
cp -r .claude/rules/ /path/to/your-project/.claude/rules/
```

Or use a config file:

```bash
cp setup-config.example.yaml setup-config.yaml
# Edit setup-config.yaml with your project settings
./setup.sh --config setup-config.yaml --output /path/to/your-project/.claude/rules/
```

## Architecture

The boilerplate has three layers:

```
┌─────────────────────────────────────────────┐
│  CORE (Layer 1)                             │
│  Universal principles — no tech references  │
│  11 files: clean code, SOLID, testing,      │
│  git, architecture, API, security,          │
│  observability, resilience, infra, database │
├─────────────────────────────────────────────┤
│  PROFILES (Layer 2)                         │
│  Technology-specific patterns and examples  │
│  e.g., java21-quarkus, java21-spring-boot   │
├─────────────────────────────────────────────┤
│  DOMAIN (Layer 3)                           │
│  Project-specific rules and business logic  │
│  e.g., ISO 8583, e-commerce, multi-tenant   │
└─────────────────────────────────────────────┘
```

### File Numbering Convention

| Range | Layer | Content |
|-------|-------|---------|
| 01-11 | Core | Universal engineering principles |
| 20-29 | Profile | Technology-specific patterns |
| 30+ | Domain | Project-specific rules |

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

## What's in the Core?

| File | Topic | Key Contents |
|------|-------|-------------|
| `01-clean-code.md` | Clean Code | CC-01 to CC-10, naming, formatting, 25-line functions, 250-line classes |
| `02-solid-principles.md` | SOLID | SRP, OCP, LSP, ISP, DIP with examples |
| `03-testing-philosophy.md` | Testing | 95% line / 90% branch, naming convention, categories, fixtures |
| `04-git-workflow.md` | Git | Conventional commits, branch naming, checklist |
| `05-architecture-principles.md` | Architecture | Hexagonal / Ports & Adapters, dependency rules |
| `06-api-design-principles.md` | API Design | REST, RFC 7807, pagination, validation |
| `07-security-principles.md` | Security | Data classification, fail secure, input validation |
| `08-observability-principles.md` | Observability | Traces, metrics, logs, health checks |
| `09-resilience-principles.md` | Resilience | Circuit breaker, retry, timeout, rate limiting |
| `10-infrastructure-principles.md` | Infrastructure | Docker, Kubernetes, cloud-agnostic |
| `11-database-principles.md` | Database | Naming, migrations, indexing, data security |

## Customization

After generating rules:

1. **Review `30-project-identity.md`** — Update with your project specifics
2. **Fill in `31-domain.md`** — Add your domain rules, business logic, sensitive data
3. **Customize git scopes** — Add domain-specific scopes to `04-git-workflow.md`
4. **Tune thresholds** — Adjust coverage targets, line limits, etc. in core files if needed

## Contributing

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for how to:
- Add a new language/framework profile
- Add a new domain example
- Improve existing rules

## License

MIT
