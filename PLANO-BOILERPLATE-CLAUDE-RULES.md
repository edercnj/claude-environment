# Plan: Claude Rules Boilerplate — Project-Agnostic Workflow

## Overview

Transform the current `.claude/rules/` ruleset — currently coupled to the `authorizer-simulator` project (Java 21 + Quarkus + ISO 8583) — into a **reusable boilerplate** that any team can adopt by selecting language, framework, database, protocols, and architecture.

---

## Diagnosis: Classification of Current Rules

### Coupling Map (17 files)

| File | Core | Tech Profile | Domain | Action |
|------|:----:|:------------:|:------:|--------|
| `01-project.md` | 10% | 30% | 60% | Rewrite as parameterizable template |
| `02-java-coding.md` | 40% | 55% | 5% | Split: Clean Code → core, Java/Quarkus → profile |
| `03-testing.md` | 35% | 55% | 10% | Split: philosophy → core, frameworks → profile |
| `04-iso8583-domain.md` | 0% | 0% | 100% | Move entirely to domain layer |
| `05-architecture.md` | 30% | 40% | 30% | Split: hex arch principles → core, packages → profile |
| `06-git-workflow.md` | 85% | 5% | 10% | Almost entirely core, remove domain-specific scopes |
| `07-infrastructure.md` | 20% | 60% | 20% | Split: principles → core, Docker/K8s patterns → profile |
| `08-configuration.md` | 20% | 75% | 5% | Most goes to Quarkus profile |
| `16-database-design.md` | 40% | 40% | 20% | Split: conventions → core, PostgreSQL/Flyway → profile |
| `17-api-design.md` | 50% | 40% | 10% | Split: REST principles → core, JAX-RS/Quarkus → profile |
| `18-observability.md` | 45% | 45% | 10% | Split: 3 pillars → core, OTel/Quarkus → profile |
| `19-devops.md` | 30% | 55% | 15% | Split: principles → core, Docker/K8s → profile |
| `20-tcp-connections.md` | 10% | 30% | 60% | Mostly domain (ISO 8583 framing) |
| `21-security.md` | 50% | 20% | 30% | Split: principles → core, PAN/PIN → domain |
| `22-smoke-tests.md` | 30% | 20% | 50% | Split: philosophy → core, scenarios → domain |
| `23-kubernetes.md` | 60% | 35% | 5% | Almost entirely core + infra profile |
| `24-resilience.md` | 40% | 50% | 10% | Split: patterns → core, MicroProfile FT → profile |

---

## Boilerplate Architecture

```
claude-rules-boilerplate/
│
├── README.md                              # Boilerplate documentation
├── setup.sh                               # Interactive generator
├── setup-config.example.yaml              # Configuration example
│
├── core/                                  # LAYER 1 — Universal
│   ├── 01-clean-code.md                   # CC-01 to CC-10, naming, formatting
│   ├── 02-solid-principles.md             # SRP, OCP, LSP, ISP, DIP
│   ├── 03-testing-philosophy.md           # Coverage, naming, categories, fixtures
│   ├── 04-git-workflow.md                 # Conventional commits, branch strategy
│   ├── 05-architecture-principles.md      # Hexagonal/Clean/Ports&Adapters conceptual
│   ├── 06-api-design-principles.md        # REST, RFC 7807, pagination, versioning
│   ├── 07-security-principles.md          # Fail secure, input validation, classification
│   ├── 08-observability-principles.md     # 3 pillars, tracing, metrics, logs
│   ├── 09-resilience-principles.md        # CB, retry, timeout, bulkhead, rate limit
│   ├── 10-infrastructure-principles.md    # Cloud-agnostic, IaC, containers, K8s
│   └── 11-database-principles.md          # Naming, migrations, indexing, security
│
├── profiles/                              # LAYER 2 — Technology Stack
│   ├── java21-quarkus/
│   │   ├── coding-patterns.md             # CDI, Panache, Records, sealed interfaces
│   │   ├── testing-patterns.md            # JUnit5, AssertJ, REST Assured, Testcontainers
│   │   ├── configuration.md               # @ConfigMapping, profiles, application.properties
│   │   ├── api-patterns.md                # RESTEasy Reactive, ExceptionMapper, OpenAPI
│   │   ├── database-patterns.md           # Panache, Flyway, H2 test, PostgreSQL
│   │   ├── resilience-patterns.md         # MicroProfile FT, Bucket4j, SmallRye
│   │   ├── observability-patterns.md      # OTel Quarkus, SmallRye Health
│   │   ├── infrastructure-patterns.md     # Dockerfile.native, Kustomize, GraalVM
│   │   └── native-build.md               # @RegisterForReflection, native restrictions
│   │
│   ├── java21-spring-boot/                # (future)
│   │   ├── coding-patterns.md
│   │   ├── testing-patterns.md
│   │   └── ...
│   │
│   ├── typescript-nestjs/                 # (future)
│   │   └── ...
│   │
│   ├── python-fastapi/                    # (future)
│   │   └── ...
│   │
│   └── go-stdlib/                         # (future)
│       └── ...
│
├── templates/                             # LAYER 3 — Domain Scaffolding
│   ├── domain-template.md                 # Template with placeholders
│   ├── project-identity-template.md       # Template for 01-project.md
│   └── examples/
│       ├── iso8583-authorizer/            # Example: our current project
│       │   ├── project-identity.md
│       │   ├── iso8583-domain.md
│       │   ├── tcp-connections.md
│       │   ├── security-payment.md
│       │   └── smoke-tests.md
│       ├── ecommerce-api/                 # Example: e-commerce API
│       │   ├── project-identity.md
│       │   └── ecommerce-domain.md
│       └── saas-multi-tenant/             # Example: multi-tenant SaaS
│           ├── project-identity.md
│           └── multi-tenant-domain.md
│
└── docs/
    ├── CONTRIBUTING.md                    # How to add profiles/examples
    ├── ANATOMY-OF-A-RULE.md              # Format and best practices for writing rules
    └── FAQ.md
```

---

## Execution Plan — 8 Phases

### PHASE 1: Extract Core Rules (Universal)

**Goal:** Create the 11 core layer files by extracting universal content from current rules.

**Tasks:**

1.1. **Create `core/01-clean-code.md`**
   - Extract from `02-java-coding.md`: CC-01 to CC-10 (remove Java-specific examples)
   - Rewrite examples in pseudocode or with `{LANGUAGE}` placeholders
   - Keep: function limits (25 lines, 4 params), class limits (250 lines), naming rules
   - Keep: vertical formatting, newspaper rule, command-query separation
   - Add: "how to apply per language" table (filled in by profiles)

1.2. **Create `core/02-solid-principles.md`**
   - Extract from `02-java-coding.md`: complete SOLID section
   - Rewrite examples without CDI/Quarkus (use generic interfaces)
   - Keep: conceptual explanation of each principle
   - Add: generic violation examples

1.3. **Create `core/03-testing-philosophy.md`**
   - Extract from `03-testing.md`: thresholds (95% line, 90% branch), naming convention
   - Extract: test categories (unit, integration, e2e, performance, smoke)
   - Extract: fixture pattern (final class, private constructor, static methods)
   - Extract: data uniqueness strategy
   - Remove: references to JUnit, AssertJ, REST Assured (goes to profile)

1.4. **Create `core/04-git-workflow.md`**
   - Extract from `06-git-workflow.md`: almost entirely
   - Parameterize scopes (remove `socket`, `debit`, `merchant` etc.)
   - Keep: conventional commits, branch naming, checklist before merge
   - Add: placeholder `{PROJECT_SCOPES}` for domain to fill in

1.5. **Create `core/05-architecture-principles.md`**
   - Extract from `05-architecture.md`: hexagonal concept, dependency rules
   - Rewrite diagram without Java packages
   - Keep: golden rule (domain never imports adapter), thread-safety principles
   - Add: variants (Clean Architecture, Onion, Ports&Adapters)

1.6. **Create `core/06-api-design-principles.md`**
   - Extract from `17-api-design.md`: URL structure, status codes, RFC 7807, pagination
   - Extract: JSON serialization rules, anti-patterns
   - Remove: JAX-RS annotations, `@RegisterForReflection`, Quarkus specifics

1.7. **Create `core/07-security-principles.md`**
   - Extract from `21-security.md`: data classification, input validation, fail secure
   - Extract: credentials management principles, container security
   - Remove: PAN/PIN masking specifics (goes to ISO 8583 domain)
   - Generalize: "sensitive data" with examples across industries

1.8. **Create `core/08-observability-principles.md`**
   - Extract from `18-observability.md`: 3 pillars, naming convention, structured logging
   - Extract from `07-infrastructure.md`: health checks strategy
   - Remove: OTel Quarkus config, ISO 8583-specific spans
   - Keep: "sensitive data NEVER in spans/logs/metrics"

1.9. **Create `core/09-resilience-principles.md`**
   - Extract from `24-resilience.md`: concepts (CB, retry, timeout, bulkhead, rate limit)
   - Extract: state diagrams (CLOSED → OPEN → HALF_OPEN)
   - Extract: universal anti-patterns, fail secure principle
   - Remove: MicroProfile FT, Bucket4j, Vert.x specifics

1.10. **Create `core/10-infrastructure-principles.md`**
   - Extract from `07-infrastructure.md` and `19-devops.md`: cloud-agnostic, multi-stage build
   - Extract from `23-kubernetes.md`: labels, PSS restricted, probes, graceful shutdown
   - Remove: Quarkus-specific Dockerfile, Mandrel, image names

1.11. **Create `core/11-database-principles.md`**
   - Extract from `16-database-design.md`: naming conventions, index rules, migration rules
   - Extract: universal anti-patterns, data security principles
   - Remove: PostgreSQL-specific types, Flyway naming

**Deliverable:** 11 markdown files in `core/`, zero references to Java/Quarkus/ISO8583.

---

### PHASE 2: Create First Profile (java21-quarkus)

**Goal:** Extract all Java/Quarkus content from current rules into the profile.

**Tasks:**

2.1. **Create `profiles/java21-quarkus/coding-patterns.md`**
   - Move from `02-java-coding.md`: Records, sealed interfaces, pattern matching
   - Move: CDI patterns (@ApplicationScoped, constructor injection)
   - Move: Panache repository pattern
   - Move: Mapper pattern (static utility classes)
   - Move: @RegisterForReflection rules
   - Move: domain exception pattern, formatting rules (4 spaces, K&R, 120 chars)
   - Move: anti-patterns (Lombok, field injection, etc.)

2.2. **Create `profiles/java21-quarkus/testing-patterns.md`**
   - Move from `03-testing.md`: JUnit 5, AssertJ, REST Assured
   - Move: @QuarkusTest, @TestTransaction, Testcontainers config
   - Move: H2 MODE=PostgreSQL configuration
   - Move: Awaitility patterns
   - Move: TcpTestClient pattern, Gatling structure
   - Move: data uniqueness (`System.nanoTime()`)

2.3. **Create `profiles/java21-quarkus/configuration.md`**
   - Move from `08-configuration.md`: entirely (already 100% Quarkus)
   - @ConfigMapping, profiles, property hierarchy

2.4. **Create `profiles/java21-quarkus/api-patterns.md`**
   - Move from `17-api-design.md`: RESTEasy Reactive patterns
   - Move: ExceptionMapper dual pattern, ProblemDetail record
   - Move: PaginatedResponse\<T\>, @Schema annotations
   - Move: ConstraintViolationExceptionMapper

2.5. **Create `profiles/java21-quarkus/database-patterns.md`**
   - Move from `16-database-design.md`: PostgreSQL types, Flyway patterns
   - Move: Panache repository, entity mapper patterns
   - Move: BIGSERIAL, TIMESTAMP WITH TIME ZONE, BYTEA

2.6. **Create `profiles/java21-quarkus/resilience-patterns.md`**
   - Move from `24-resilience.md`: MicroProfile FT annotations
   - Move: Bucket4j implementation, @CircuitBreaker/@Retry/@Timeout/@Bulkhead
   - Move: ConfigMapping ResilienceConfig
   - Move: Vert.x backpressure patterns

2.7. **Create `profiles/java21-quarkus/observability-patterns.md`**
   - Move from `18-observability.md`: quarkus.otel.* config
   - Move: SmallRye Health checks, Meter/Tracer injection
   - Move: JSON logging config Quarkus

2.8. **Create `profiles/java21-quarkus/infrastructure-patterns.md`**
   - Move from `07-infrastructure.md` and `19-devops.md`: Dockerfile.jvm, Dockerfile.native
   - Move from `23-kubernetes.md`: Kustomize structure, probes with Quarkus paths
   - Move: docker-compose.yaml, Mandrel build

2.9. **Create `profiles/java21-quarkus/native-build.md`**
   - Move from `02-java-coding.md`: Quarkus Native section
   - @RegisterForReflection rules, build profiles, performance targets

**Deliverable:** 9 files in the `java21-quarkus/` profile, with concrete and opinionated examples.

---

### PHASE 3: Create Domain Templates

**Goal:** Create parameterizable templates for the domain layer.

**Tasks:**

3.1. **Create `templates/project-identity-template.md`**
   - Template based on `01-project.md`
   - Placeholders: `{PROJECT_NAME}`, `{PROJECT_TYPE}`, `{PROJECT_PURPOSE}`
   - Placeholders: `{TECH_STACK_TABLE}`, `{MAVEN_COORDINATES}` or `{PACKAGE_JSON}`
   - Placeholders: `{CONSTRAINTS_LIST}`, `{SOURCE_OF_TRUTH}`
   - Language section (code in English, docs in which language, etc.)

3.2. **Create `templates/domain-template.md`**
   - Generic structure for domain rules
   - Sections: overview, domain model, business rules, sensitive data
   - Sections: communication protocols, specific test scenarios
   - Placeholders with filling instructions

3.3. **Create `templates/examples/iso8583-authorizer/`**
   - Extract from: `04-iso8583-domain.md`, `20-tcp-connections.md`
   - Extract from: `21-security.md` (PAN/PIN section), `22-smoke-tests.md`
   - Keep exactly as-is — this is the reference example
   - 5 files: `project-identity.md`, `iso8583-domain.md`, `tcp-connections.md`, `security-payment.md`, `smoke-tests.md`

3.4. **Create additional examples (skeleton)**
   - `templates/examples/ecommerce-api/` — e-commerce REST API
   - `templates/examples/saas-multi-tenant/` — multi-tenant SaaS
   - Basic structure only to demonstrate the pattern

**Deliverable:** 2 templates + 3 domain examples.

---

### PHASE 4: Build the Generator (`setup.sh`)

**Goal:** Interactive script that assembles the project's `.claude/rules/`.

**Tasks:**

4.1. **Define `setup-config.yaml`**
   ```yaml
   project:
     name: "my-project"
     type: "api"        # api | cli | library | worker | fullstack
     language: "java21"
     framework: "quarkus"

   database:
     type: "postgresql"  # postgresql | mysql | mongodb | none
     migration: "flyway" # flyway | liquibase | prisma | none

   protocols:
     - rest
     - grpc              # rest | grpc | graphql | websocket | tcp-custom

   architecture: "hexagonal"  # hexagonal | clean | layered | modular

   infrastructure:
     container: "docker"      # docker | podman
     orchestrator: "kubernetes" # kubernetes | docker-compose | none
     observability: "opentelemetry" # opentelemetry | datadog | none

   options:
     native_build: true
     resilience: true
     smoke_tests: true
   ```

4.2. **Implement `setup.sh`**
   - Interactive mode (terminal prompts) and config mode (reads YAML)
   - Copies entire `core/` to `.claude/rules/`
   - Copies selected profile to `.claude/rules/`
   - Generates `01-project.md` from template + answers
   - Generates `domain-template.md` with placeholders
   - Validates: profile exists, valid combination (e.g., Flyway doesn't make sense with MongoDB)

4.3. **Support for profile composition**
   - Base profile: language + framework (e.g., `java21-quarkus`)
   - Database profile: `postgresql`, `mongodb` (specific patterns)
   - Infra profile: `kubernetes`, `docker-compose-only`
   - The generator composes the relevant profiles

4.4. **Automatic file numbering**
   - Core: `01-` to `11-`
   - Profile: `20-` to `29-`
   - Domain: `30-` onwards
   - Avoids numbering collision

**Deliverable:** Functional `setup.sh` + `setup-config.example.yaml`.

---

### PHASE 5: Validation — Rebuild Authorizer-Simulator

**Goal:** Prove the boilerplate generates exactly the equivalent of the current rules.

**Tasks:**

5.1. **Run the generator with the authorizer-simulator config**
   ```yaml
   project:
     name: "authorizer-simulator"
     language: "java21"
     framework: "quarkus"
   database:
     type: "postgresql"
     migration: "flyway"
   protocols:
     - rest
     - tcp-custom
   architecture: "hexagonal"
   infrastructure:
     container: "docker"
     orchestrator: "kubernetes"
     observability: "opentelemetry"
   options:
     native_build: true
     resilience: true
     smoke_tests: true
   ```

5.2. **Diff of generated rules vs. current rules**
   - Core + profile should cover ~90% of current content
   - The remaining 10% should be in the ISO 8583 domain examples
   - No information can be lost

5.3. **Validation checklist**
   - [ ] All anti-patterns are present
   - [ ] All code examples are present (in the profile)
   - [ ] All configuration tables are present
   - [ ] No reference to ISO 8583 in core or profile
   - [ ] No reference to Java/Quarkus in core
   - [ ] Core examples are in pseudocode or language-agnostic

**Deliverable:** Diff report + validated checklist.

---

### PHASE 6: Documentation

**Goal:** Document the boilerplate for consumers.

**Tasks:**

6.1. **Create `README.md`**
   - What it is, who it's for, how to use it
   - Quick start (3 commands)
   - Table of available profiles
   - Link to FAQ

6.2. **Create `docs/CONTRIBUTING.md`**
   - How to add a new language/framework profile
   - How to add a new domain example
   - Rule quality checklist
   - PR template for new profile

6.3. **Create `docs/ANATOMY-OF-A-RULE.md`**
   - Standard format: Global Behavior header, principles, tables, examples, anti-patterns
   - Best practices: be opinionated, provide ✅/❌ examples, keep concise
   - What works well with Claude Code and what doesn't

6.4. **Create `docs/FAQ.md`**
   - "Can I mix profiles?" — Yes, the generator composes them
   - "What if my framework doesn't have a profile?" — Use the template and contribute
   - "Do I need to follow everything?" — Rules are opinionated, adapt to context

**Deliverable:** 4 documents in `docs/`.

---

### PHASE 7: Second Profile (java21-spring-boot)

**Goal:** Validate the generalization by creating a second profile.

**Tasks:**

7.1. **Create `profiles/java21-spring-boot/coding-patterns.md`**
   - @Service, @Repository, @RestController
   - Constructor injection via Lombok or records
   - Spring Data JPA (vs Panache)

7.2. **Create `profiles/java21-spring-boot/testing-patterns.md`**
   - @SpringBootTest, @DataJpaTest, MockMvc
   - H2 + Testcontainers

7.3. **Remaining Spring Boot profile files**
   - configuration (application.yml, @ConfigurationProperties)
   - api-patterns (ResponseEntity, @ControllerAdvice)
   - database-patterns (Spring Data, Liquibase/Flyway)
   - resilience-patterns (Resilience4j, Spring Retry)
   - observability-patterns (Micrometer + OTel bridge, Actuator)
   - infrastructure-patterns (Dockerfile, Buildpacks)

7.4. **Cross-validation**
   - Core must work without changes with Spring Boot
   - If core needs changes → core was coupled, fix it

**Deliverable:** Complete `java21-spring-boot/` profile + cross-validation.

---

### PHASE 8: Publishing and Evolution

**Goal:** Make the boilerplate available for use.

**Tasks:**

8.1. **Create dedicated Git repository**
   - `claude-rules-boilerplate` or `claude-code-rules-template`
   - License: MIT or Apache 2.0
   - CI: link validation, markdown linting

8.2. **Semantic versioning**
   - v1.0.0: core + java21-quarkus + java21-spring-boot
   - v1.1.0: new profiles (TypeScript, Python)
   - v2.0.0: breaking changes in core

8.3. **Future profiles roadmap**
   - Priority 1: `typescript-nestjs`, `python-fastapi`
   - Priority 2: `go-stdlib`, `kotlin-ktor`
   - Priority 3: `rust-axum`, `csharp-dotnet`

8.4. **Update mechanism**
   - `update.sh` script that updates core without overwriting domain
   - Conflict detection between new core and project customizations

---

## Recommended Execution Order

```
PHASE 1 (Core)          ████████████░░░░░░░░  ~3-4 sessions
PHASE 2 (QK Profile)    ████████████░░░░░░░░  ~3-4 sessions
PHASE 3 (Templates)     ██████░░░░░░░░░░░░░░  ~2 sessions
PHASE 4 (Generator)     ████████░░░░░░░░░░░░  ~2-3 sessions
PHASE 5 (Validation)    ████░░░░░░░░░░░░░░░░  ~1 session
PHASE 6 (Docs)          ████░░░░░░░░░░░░░░░░  ~1 session
PHASE 7 (Spring Boot)   ████████████░░░░░░░░  ~3-4 sessions
PHASE 8 (Publishing)    ████░░░░░░░░░░░░░░░░  ~1 session
                                    TOTAL: ~16-20 sessions
```

**Dependencies between phases:**
- Phase 2 depends on Phase 1 (core defines what remains for the profile)
- Phase 4 depends on Phases 1, 2, 3 (needs content to generate)
- Phase 5 depends on Phase 4 (end-to-end validation)
- Phase 7 depends on Phase 5 (core validated before creating second profile)

---

## Pending Decisions

| # | Decision | Options | Impact |
|---|----------|---------|--------|
| 1 | Core file language | English (wider reach) vs Portuguese (current team) | High |
| 2 | Generator format | Bash script vs Python CLI vs Node CLI | Medium |
| 3 | Core examples | Pseudocode vs multiple snippets per language | High |
| 4 | Profile granularity | 1 monolithic file vs 8-9 separate files | Medium |
| 5 | License | MIT vs Apache 2.0 vs proprietary | Low |
| 6 | Repository | Monorepo (core+profiles) vs multi-repo | Medium |
| 7 | Project name | `claude-rules-boilerplate`, `claude-code-rules-template`, other | Low |

---

## Success Criteria

1. **Zero coupling in core**: no mention of Java, Quarkus, PostgreSQL, ISO 8583
2. **100% reconstruction**: authorizer-simulator recreated with no information loss
3. **Second profile works**: Spring Boot uses the same core without changes
4. **Generator < 5 minutes**: new project setup in under 5 minutes
5. **Simple contribution**: adding a profile requires only following the guide
