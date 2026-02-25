---
name: audit-rules
description: "Audits compliance of all project rules AND knowledge packs against source code. Scans for violations in parallel (one agent per rule/knowledge-pack), generates a detailed audit report grouped by source with severity classification, and suggests stories for fixes."
allowed-tools: Read, Bash, Grep, Glob, Write
argument-hint: "[--scope all|rules|patterns] [--rules 01,02,03] [--fix]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Audit Rules & Patterns (Codebase Compliance Review)

## Purpose

Automates codebase compliance review by:

1. Reading each rule file AND each knowledge pack from the project
2. Scanning the source code for violations IN PARALLEL (one agent per rule, one agent per knowledge pack)
3. Aggregating findings into a single unified report
4. Suggesting story creation for non-trivial fixes
5. Optionally creating fix stories if the user approves

## Input

**Arguments:** `$ARGUMENTS`

- `--scope all` (default): Review rules + knowledge packs
- `--scope rules`: Review rules only
- `--scope patterns`: Review knowledge packs only
- `--rules all` (default when scope includes rules): Review all rules
- `--rules 01,02,03`: Review specific rules only
- `--fix`: After report, prompt user to create stories

If no arguments provided, default to `--scope all --rules all`.

## Execution Flow

```
1. DISCOVER    -> List all rule files + knowledge packs
2. SCAN RULES  -> Launch parallel agents (one per rule) to check compliance
3. SCAN PACKS  -> Launch parallel agents (one per knowledge pack) to check patterns
4. AGGREGATE   -> Collect findings from all agents
5. REPORT      -> Present unified report grouped by source
6. SUGGEST     -> Propose stories for non-trivial violations
7. CREATE      -> If --fix and user approves, write story files
```

**Note:** Steps 2 and 3 MUST be launched together in the SAME message for maximum parallelism. If `--scope` limits the scan, skip the excluded step.

## Phase 1: Discovery

### 1a. Discover Rules

List all rule files in the project's rules directory:

```bash
ls -1 .claude/rules/*.md
```

Filter by `--rules` argument if provided. Parse each filename to extract rule number and name.

### 1b. Discover Knowledge Packs

Identify all knowledge packs that have reference files:

```bash
# Find all skills with a references/ directory
find .claude/skills/*/references -name "*.md" 2>/dev/null | sort
```

For each knowledge pack found:
1. Read its `SKILL.md` to understand scope and purpose
2. List all files in its `references/` directory
3. Add to scan plan

### 1c. Build Scan Plan

Produce a scan plan before launching agents:

```
Scan Plan:
  Rules: [01, 02, 03, ..., 51] (N rules)
  Knowledge Packs:
    - architecture-patterns (20 references)
    - database-patterns (N references)
    - quarkus-patterns (N references)
    - layer-templates (N references)
    - ...
  Total agents to launch: N
```

## Phase 2: Parallel Scanning — Rules

**CRITICAL: ALL scan tasks (rules + knowledge packs) MUST be launched in a SINGLE message for true parallelism.**

For EACH rule, launch a parallel agent that:

1. Reads the rule file completely
2. Scans ALL relevant source files
3. Identifies EVERY violation with:
   - **File path and line number**
   - **Violation description**
   - **Severity:** CRITICAL (blocks build/deploy), HIGH (quality/security risk), MEDIUM (convention violation), LOW (improvement opportunity)
   - **Rule reference** (which specific section is violated)

### Scanning Strategy per Rule Type

| Rule Type        | Scan Targets                                    |
| ---------------- | ----------------------------------------------- |
| Coding patterns  | `src/main/`, `src/test/` source files           |
| Testing          | `src/test/`, build config (coverage thresholds) |
| Architecture     | Package imports, dependency directions           |
| Git workflow     | Recent commit messages                           |
| Infrastructure   | Dockerfiles, K8S manifests, build files          |
| Configuration    | Properties/YAML files, config classes           |
| Database         | Migrations, entity classes, repository queries   |
| API Design       | REST controllers, DTOs, error handlers           |
| Security         | Logging statements, error responses, data masking|
| Observability    | Span attributes, metric definitions, log format  |

## Phase 3: Parallel Scanning — Knowledge Packs

**Launched in the SAME message as Phase 2.**

For EACH knowledge pack, launch a parallel agent that:

1. Reads the knowledge pack's `SKILL.md` to understand what patterns it covers
2. Reads EVERY reference file in `references/` to extract:
   - Concrete implementation patterns (the "GOOD" examples)
   - Anti-patterns (the "FORBIDDEN" sections)
   - "When to Use" / "When NOT to Use" criteria
3. Scans ALL relevant source files for violations
4. Reports findings with severity and reference to the specific pattern file

### Scanning Strategy per Knowledge Pack

| Knowledge Pack         | Scan Targets                                       | Key Checks                                                                           |
| ---------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `architecture-patterns`| Package structure, imports, class design            | Missing saga/outbox for event-driven, missing ACL at boundaries, CQRS violations     |
| `database-patterns`    | Entities, repositories, migrations, config, queries | Cache-aside violations, missing indexes, N+1 queries, missing audit columns          |
| `{framework}-patterns` | CDI/DI beans, config classes, REST resources        | Wrong annotations, missing native-build compat, blocking in reactive, config issues  |
| `layer-templates`      | All layers (domain, adapter, application)           | Deviations from reference templates, missing mandatory components per layer          |
| `dockerfile`           | Dockerfiles, .dockerignore                          | Multi-stage missing, running as root, missing health check, debug tools in prod      |
| `k8s-deployment`       | K8s manifests (YAML)                                | Missing probes, no resource limits, no security context, wrong labels                |
| `k8s-kustomize`        | Kustomize overlays                                  | Missing overlays, hardcoded values in base, environment-specific in base             |
| `infra-*`              | IaC files (Terraform, Crossplane)                   | Missing state backend, no locking, hardcoded credentials, missing modules            |

### Knowledge Pack Agent Instructions

Each knowledge pack agent MUST:

1. **Read the SKILL.md** — Understand the pack's scope and cross-references
2. **Read ALL reference files** — Build a mental model of expected patterns and anti-patterns
3. **Focus on Anti-Patterns sections** — These are the most actionable violations
4. **Check "When to Use" criteria** — Only flag missing patterns when the project context requires them (e.g., don't flag missing saga if `event_driven=false`)
5. **Cross-reference with rules** — If a violation is already covered by a rule, skip it to avoid duplicates. Knowledge pack findings should be ADDITIONAL to rule findings.
6. **Be precise** — Include file path, line number, concrete violation description, and which reference file documents the expected pattern

### Severity for Knowledge Pack Violations

| Severity | Knowledge Pack Signal |
|----------|-----------------------|
| CRITICAL | Anti-pattern from FORBIDDEN section actively present in code |
| HIGH     | Required pattern missing when project context demands it (e.g., no outbox with event_driven=true) |
| MEDIUM   | Deviation from recommended pattern without clear justification |
| LOW      | Improvement opportunity based on pattern best practices |

## Phase 4: Report Format

```markdown
# Codebase Compliance Report

**Date:** YYYY-MM-DD
**Branch:** {current branch}
**Scope:** rules + patterns | rules only | patterns only

## Executive Summary

| Source                  | Type            | Violations | Critical | High | Medium | Low | Status    |
| ----------------------- | --------------- | ---------- | -------- | ---- | ------ | --- | --------- |
| Rule 01 — Clean Code    | Rule            | N          | N        | N    | N      | N   | PASS/FAIL |
| Rule 02 — SOLID         | Rule            | N          | N        | N    | N      | N   | PASS/FAIL |
| ...                     | Rule            | ...        | ...      | ...  | ...    | ... | ...       |
| architecture-patterns   | Knowledge Pack  | N          | N        | N    | N      | N   | PASS/FAIL |
| database-patterns       | Knowledge Pack  | N          | N        | N    | N      | N   | PASS/FAIL |
| quarkus-patterns        | Knowledge Pack  | N          | N        | N    | N      | N   | PASS/FAIL |
| ...                     | Knowledge Pack  | ...        | ...      | ...  | ...    | ... | ...       |

**Overall:** X sources PASS, Y sources FAIL, Z total violations
**Breakdown:** A from rules, B from knowledge packs

---

## Section 1: Rule Findings

### Rule NN — Rule Name

**Status:** PASS/FAIL | Violations: N

#### CRITICAL
- `path/file:42` — Description [Rule NN, Section X]

#### HIGH
- `path/file:10` — Description [Rule NN, Section Y]

#### MEDIUM
- `path/file:25` — Description [Rule NN, Section Z]

(repeat for each rule with findings)

---

## Section 2: Knowledge Pack Findings

### architecture-patterns

**Status:** PASS/FAIL | Violations: N

#### CRITICAL
- `path/file:42` — Anti-pattern: direct event publishing without outbox [outbox-pattern.md, FORBIDDEN section]

#### HIGH
- `path/file:10` — Missing anti-corruption layer at external integration boundary [anti-corruption-layer.md]

#### MEDIUM
- `path/file:25` — Repository returns ORM entity instead of domain model [repository-pattern.md]

### database-patterns

**Status:** PASS/FAIL | Violations: N

#### HIGH
- `path/file:15` — Missing index for query pattern in WHERE clause [indexing reference]

(repeat for each knowledge pack with findings)

---

## Suggested Stories

### Story Group: "Rule NN Violations"
**Type:** Rule compliance
**Estimated effort:** S/M/L
**Violations addressed:** N
- Fix description 1
- Fix description 2

### Story Group: "architecture-patterns Violations"
**Type:** Pattern compliance
**Estimated effort:** S/M/L
**Violations addressed:** N
- Fix description 1
- Fix description 2
```

## Phase 5: Story Creation (Optional)

When `--fix` is provided and user approves:

1. Find highest existing story number
2. Create one story per source (rule or knowledge pack) with CRITICAL/HIGH violations
3. Group MEDIUM/LOW into consolidated cleanup stories
4. Update implementation map with new stories

### Story Grouping Rules

1. One story per rule with CRITICAL or HIGH violations
2. One story per knowledge pack with CRITICAL or HIGH violations
3. One consolidated story for all MEDIUM/LOW if total < 10
4. Separate stories per source for MEDIUM/LOW if > 10 in one source
5. Max ~15 violations per story
6. Tag stories with source type: `[Rule]` or `[Pattern]`

## Deduplication Rules

Knowledge pack scanning may overlap with rule scanning. To avoid duplicate findings:

1. Rules take precedence — if a violation is reportable under both a rule and a knowledge pack, report it under the RULE only
2. Knowledge pack agents MUST check if their finding is already covered by a rule's anti-pattern section
3. Knowledge packs add VALUE by catching violations that rules don't cover: missing patterns, wrong pattern usage, pattern anti-patterns not in any rule
4. When in doubt, report under the knowledge pack with a note: `(related to Rule NN)`

## Anti-Patterns

- Do NOT report false positives (read code carefully, understand context)
- Do NOT flag test code for production rules (magic numbers in fixtures are OK)
- Do NOT flag generated or third-party code
- Do NOT create stories for violations that already have an open story
- Do NOT create empty stories
- Do NOT flag missing patterns when the project context does not require them (check `event_driven`, `domain_driven`, `architecture.style` in project identity)
- Do NOT duplicate findings between rules and knowledge packs
- Do NOT scan knowledge packs that have no reference files

## Integration Notes

- Can be run at any time, independently of the feature lifecycle
- Useful before starting a new phase of development to assess technical debt
- Stories created by this skill can be implemented via `feature-lifecycle` or `implement-story`
- Complements `/review` (diff-based) with full codebase scanning
- Run `/audit-rules --scope patterns` after adding new knowledge packs to verify adoption
