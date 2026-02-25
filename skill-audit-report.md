# Skill Templates Audit Report — Hardcoded vs Dynamic Content

**Date:** 2026-02-25
**Scope:** All 28 skill templates (15 core + 13 conditional)
**Objective:** Identify content hardcoded in skill templates that should instead reference the generated rules, knowledge packs, or use placeholders resolved by `setup.sh`.

---

## Executive Summary

| Classification         | Count | Skills |
|------------------------|:-----:|--------|
| CRITICAL (heavily hardcoded) | 4 | `implement-story`, `task-decomposer`, `feature-lifecycle`, `group-verifier` |
| HIGH (partially hardcoded) | 2 | `review-pr`, `troubleshoot` |
| OK (uses placeholders/dynamic) | 22 | All others |

**Root Problem:** 6 skills embed hexagonal architecture specifics (layer names, package structure, G1-G7 groups) and/or Java-specific idioms directly in the SKILL.md instead of delegating to the generated rules and knowledge packs. Since `setup.sh` already generates `rules/05-architecture-principles.md`, `rules/20-coding-conventions.md`, and the `architecture-patterns` + `layer-templates` knowledge packs with all this information, these skills should reference those artifacts at runtime.

---

## Detailed Findings

### CRITICAL — Heavily Hardcoded

#### 1. `implement-story` (core)

| Issue | Line(s) | Hardcoded Content | Should Reference |
|-------|---------|-------------------|------------------|
| Architecture layers | 79-87 | "Follow the hexagonal architecture layer order: 1. Domain Models, 2. Ports, 3. Domain Engine, 4. Persistence, 5. Application, 6. Inbound Adapters, 7. Tests" | `rules/05-architecture-principles.md` or `layer-templates` knowledge pack |
| Java Records | 102 | "Records for DTOs, Value Objects, Events" | `rules/20-coding-conventions.md` or `rules/24-version-features.md` |
| Java Optional | 101 | "`Optional<T>` for search returns (never null)" | `rules/20-coding-conventions.md` |
| Java Constructor injection | 100 | "Constructor injection (never field injection)" | `rules/20-coding-conventions.md` |

**Impact:** If a project uses Clean Architecture (different layer names), a non-Java language, or a different architectural style, this skill will give wrong instructions.

**Recommendation:** Replace the hardcoded layer order with: "Read the architecture rules and layer-templates knowledge pack to determine implementation order. Follow the layer dependency defined there." Replace Java-specific items with: "Follow the coding conventions in the project rules."

---

#### 2. `task-decomposer` (core)

| Issue | Line(s) | Hardcoded Content | Should Reference |
|-------|---------|-------------------|------------------|
| Entire Layer Task Catalog | 59-81 | 20-row table with `domain.model`, `domain.port.inbound`, `adapter.outbound.entity`, `adapter.inbound.rest`, etc. | `rules/05-architecture-principles.md` + `layer-templates` knowledge pack |
| G1-G7 dependency graph | 86-92 | Fixed group definitions tied to hexagonal package names | Architecture rules |
| "sealed interfaces" | 49 | Java-specific idiom | `rules/24-version-features.md` |
| "Records, Enums" | 62 | Java-specific naming | `rules/20-coding-conventions.md` |

**Impact:** This is the most severely hardcoded skill. The entire Layer Task Catalog is a mirror of hexagonal architecture with Java package names. Any project with a different architecture style or language will get incorrect decomposition.

**Recommendation:** The Layer Task Catalog should be generated as a template by `setup.sh` (reading from `layer-templates` knowledge pack) or the skill should read the architecture rules at runtime and derive the catalog dynamically.

---

#### 3. `feature-lifecycle` (core)

| Issue | Line(s) | Hardcoded Content | Should Reference |
|-------|---------|-------------------|------------------|
| G1-G7 group structure | 62-68 | "G1: Foundation (Migration + Domain Models), G2: Contracts (Ports + DTOs + Engine), G3: Outbound Adapters (Entity + Mapper + Repository), G4: Orchestration (Use Case), G5: Inbound Adapters (REST + TCP + Config), G6: Observability, G7: Tests" | `rules/05-architecture-principles.md` + `layer-templates` |
| No rules/knowledge-pack read | — | Does NOT instruct agents to read rules or knowledge packs during implementation phases | Should instruct agents to read relevant rules before coding |

**Impact:** The G1-G7 structure assumes hexagonal architecture with specific adapter types. If the project uses Clean Architecture or a different layer decomposition, the lifecycle phases will be wrong.

**Recommendation:** Replace hardcoded G1-G7 with: "Use the `task-decomposer` skill to derive groups from architecture rules." Add explicit instruction for implementation agents to read relevant rules and knowledge packs before coding.

---

#### 4. `group-verifier` (core)

| Issue | Line(s) | Hardcoded Content | Should Reference |
|-------|---------|-------------------|------------------|
| G1-G7 commit messages | 94-100 | "G1: feat(domain): add foundation models, G2: feat(domain): add ports, DTOs, engine, G3: feat(persistence): add entity, mapper, repository, G4: feat(application): add use case, G5: feat(adapter): add inbound adapters, G6: feat(observability): add tracing, G7: test: add tests" | `rules/04-git-workflow.md` + architecture rules |
| Java error patterns | 49-50 | "`cannot find symbol` referencing a PREVIOUS group type" | Should be language-agnostic or use `{{LANGUAGE}}` conditional |

**Impact:** Commit messages reference hexagonal-specific scopes (domain, persistence, application, adapter). Java-specific error patterns won't apply to Go, Python, TypeScript projects.

**Recommendation:** Commit messages should be derived from the active architecture style. Error classification should use `{{LANGUAGE}}`-conditional tables or reference the `troubleshoot` skill.

---

### HIGH — Partially Hardcoded

#### 5. `review-pr` (core)

| Issue | Line(s) | Hardcoded Content | Should Reference |
|-------|---------|-------------------|------------------|
| "hexagonal boundaries" in rubric | 77 | Section G: "SRP, DIP, hexagonal boundaries, follows plan" | `rules/05-architecture-principles.md` (could be "architecture boundaries" generically) |

**Impact:** Minor. The rubric says "hexagonal" when it should say "architecture boundaries" generically. The rest of the skill is well-parameterized with `{{COMPILE_COMMAND}}`, `{{BUILD_COMMAND}}`.

**Recommendation:** Change "hexagonal boundaries" to "architecture layer boundaries (per project architecture rules)".

---

#### 6. `troubleshoot` (core)

| Issue | Line(s) | Hardcoded Content | Should Reference |
|-------|---------|-------------------|------------------|
| Java compilation errors | 42-44 | "`cannot find symbol`, `package does not exist`, `sealed type not permitted`" | Should be `{{LANGUAGE}}`-conditional |
| Java runtime errors | 77-78 | "`ClassNotFoundException`, `NoSuchMethodError`" | Should be `{{LANGUAGE}}`-conditional |

**Impact:** Skills for Go, Python, TypeScript projects will show irrelevant Java error patterns.

**Recommendation:** Use `{{LANGUAGE}}`-conditional sections, or restructure as a table that `setup.sh` populates based on the language.

---

### OK — Dynamic / Properly Parameterized

| Skill | Type | Status | Notes |
|-------|------|--------|-------|
| `audit-rules` | core | OK | Reads rules and knowledge packs at runtime |
| `review` | core | OK | References "project rules relevant to their domain"; conditional engineers |
| `plan-tests` | core | OK | References "project testing rules" and "architecture rules" |
| `run-tests` | core | OK | Uses `{{TEST_COMMAND}}`, `{{COVERAGE_COMMAND}}` |
| `commit-and-push` | core | OK | Uses `{{BUILD_COMMAND}}`, `{{LANGUAGE}}`, `{{PROJECT_NAME}}` |
| `create-epic` | core | OK | Reads templates from disk at runtime |
| `create-story` | core | OK | Reads templates from disk at runtime |
| `create-epic-and-story` | core | OK | Orchestrates other skills, reads templates |
| `create-implementation-map` | core | OK | Reads templates from disk at runtime |
| `review-api` | conditional | OK | Uses `{{FRAMEWORK}}`; validates REST generically |
| `review-events` | conditional | OK | Protocol-generic event review |
| `review-graphql` | conditional | OK | Protocol-specific, correctly scoped |
| `review-grpc` | conditional | OK | Protocol-specific, correctly scoped |
| `review-gateway` | conditional | OK | Reads "gateway knowledge pack" at runtime |
| `instrument-otel` | conditional | OK | Uses `{{BUILD_FILE}}`, `{{FRAMEWORK}}`, `{{PROJECT_PREFIX}}`; protocol-conditional sections |
| `run-smoke-api` | conditional | OK | Uses `{{ORCHESTRATOR}}`; generic REST smoke tests |
| `run-smoke-socket` | conditional | OK | Uses `{{BUILD_COMMAND}}`, `{{ORCHESTRATOR}}` |
| `run-e2e` | conditional | OK | Uses `{{FRAMEWORK}}`, `{{DB_TYPE}}`, `{{BUILD_FILE}}`, `{{TEST_COMMAND}}` |
| `run-perf-test` | conditional | OK | Fully generic performance test runner |
| `run-contract-tests` | conditional | OK | Language-agnostic contract testing |
| `security-compliance-review` | conditional | OK | Reads compliance rules at runtime |
| `setup-environment` | conditional | OK | Uses `{{ORCHESTRATOR}}`, `{{DB_TYPE}}`, `{{BUILD_TOOL}}`, `{{BUILD_COMMAND}}`, `{{PROJECT_NAME}}` |

---

## Cross-Cutting Issues

### Issue A: No Skill Instructs Agents to Read Rules/Knowledge Packs Before Coding

The implementation-focused skills (`implement-story`, `feature-lifecycle`, `task-decomposer`) do NOT instruct the AI agents to read the generated rules or knowledge packs before writing code. This is a significant gap because:

1. `setup.sh` generates ~20 rules files and multiple knowledge packs with detailed patterns
2. The skills bypass all of this and hardcode the patterns directly
3. The rules and knowledge packs may be customized per project, but the skills ignore customizations

**Recommendation:** Every implementation skill should include a "Read Context" phase that explicitly reads relevant rules and knowledge packs before generating code.

### Issue B: G1-G7 Group System is Tightly Coupled to Hexagonal

The G1-G7 parallelism group system (`task-decomposer` → `feature-lifecycle` → `group-verifier`) assumes a specific architecture:

- G1 = Domain Models + Migration (hexagonal domain layer)
- G2 = Ports + DTOs + Engine (hexagonal port/domain layers)
- G3 = Entity + Mapper + Repository (hexagonal outbound adapter layer)
- G4 = Use Case (hexagonal application layer)
- G5 = REST + TCP + Config (hexagonal inbound adapter layer)
- G6 = Observability (cross-cutting)
- G7 = Tests

For Clean Architecture, the layers would be different. For non-layered architectures (e.g., feature-based modules), this entire system breaks down.

**Recommendation:** The group system should be derivable from the architecture rules, not hardcoded. One approach: `setup.sh` generates a `group-definitions.md` file based on the architecture style, and skills read it at runtime.

### Issue C: Java-Specific Idioms in "Generic" Skills

Three skills contain Java-specific code patterns in sections that should be language-agnostic:

| Idiom | Skills | Java-Specific? |
|-------|--------|:--------------:|
| `Records for DTOs` | implement-story, task-decomposer | Yes (Java 16+ Records) |
| `Optional<T>` | implement-story | Yes (Java 8+) |
| `sealed interfaces` | task-decomposer | Yes (Java 17+) |
| `Constructor injection` | implement-story | Mostly Java/CDI pattern |
| `cannot find symbol` | troubleshoot, group-verifier | Java compiler error |
| `ClassNotFoundException` | troubleshoot | Java runtime error |

**Recommendation:** These should either use `{{LANGUAGE}}`-conditional blocks or reference `rules/20-coding-conventions.md` which already contains the correct idioms per language.

---

## Summary of Recommendations

1. **implement-story**: Replace hardcoded layer order and Java idioms with references to architecture rules and coding conventions rules
2. **task-decomposer**: Either generate the Layer Task Catalog via `setup.sh` or instruct the skill to derive it from architecture rules at runtime
3. **feature-lifecycle**: Replace hardcoded G1-G7 with dynamic derivation from architecture rules; add "read rules" phase
4. **group-verifier**: Derive commit scopes from architecture style; make error patterns language-conditional
5. **review-pr**: Change "hexagonal boundaries" to "architecture boundaries"
6. **troubleshoot**: Make error patterns language-conditional using `{{LANGUAGE}}`
7. **All implementation skills**: Add explicit "Read relevant rules and knowledge packs" step before coding

---

## Priority Order for Fixes

| Priority | Skill | Effort | Impact |
|:--------:|-------|:------:|--------|
| 1 | `implement-story` | Medium | Most-used coding skill; wrong instructions break everything |
| 2 | `task-decomposer` | High | Drives the entire G1-G7 system |
| 3 | `feature-lifecycle` | Medium | Orchestrator; fixes cascade from task-decomposer |
| 4 | `group-verifier` | Medium | Depends on task-decomposer fix |
| 5 | `troubleshoot` | Low | Cosmetic; Java errors still useful as examples |
| 6 | `review-pr` | Low | Single word change |
