---
name: x-lib-audit-rules
description: "Audits compliance of all project rules AND knowledge packs against source code. Launches parallel subagents (one per rule/knowledge-pack) for scanning, then aggregates into a unified report with severity classification and story suggestions."
allowed-tools: Read, Bash, Grep, Glob, Write
argument-hint: "[--scope all|rules|patterns] [--rules 01,02,03] [--fix]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Audit Rules & Patterns (Codebase Compliance Review)

## Input

**Arguments:** `$ARGUMENTS`

- `--scope all` (default): Review rules + knowledge packs
- `--scope rules`: Review rules only
- `--scope patterns`: Review knowledge packs only
- `--rules all` (default when scope includes rules): Review all rules
- `--rules 01,02,03`: Review specific rules only
- `--fix`: After report, prompt user to create stories

## Execution Flow (Orchestrator Pattern)

```
1. DISCOVER   -> List rules + knowledge packs (inline, lightweight)
2. SCAN       -> Launch N parallel subagents (one per rule + one per KP) in SINGLE message
3. AGGREGATE  -> Collect results, deduplicate, generate report + stories (inline)
```

## Phase 1: Discovery (Orchestrator — Inline)

### 1a. Discover Rules

```bash
ls -1 .claude/rules/*.md
```

Filter by `--rules` argument if provided. Parse each filename to extract rule number and name.

### 1b. Discover Knowledge Packs

```bash
find .claude/skills/*/references -name "*.md" 2>/dev/null | sort
```

Group by knowledge pack (parent directory). Skip packs with no reference files.

### 1c. Build Scan Plan

```
Scan Plan:
  Rules: [01, 02, 03, ...] (N rules)
  Knowledge Packs:
    - architecture-patterns (N refs)
    - database-patterns (N refs)
    - ...
  Total subagents to launch: N
```

## Phase 2: Parallel Scanning (Subagents via Task Tool)

**CRITICAL: ALL subagents MUST be launched in a SINGLE message for true parallelism.**

Launch one `general-purpose` subagent per rule and one per knowledge pack, all in the same message.

### Subagent: Rule Scanner

**Launch:** One per rule file discovered in Phase 1a.
**Type:** `general-purpose`

**Prompt template (substitute `{RULE_PATH}` and `{RULE_NAME}`):**

> You are a codebase compliance auditor. Your task is to audit source code against a single project rule.
>
> **Rule to audit:** Read `{RULE_PATH}` completely.
>
> **Scan targets based on rule type:**
> - Coding/SOLID/Clean Code → `src/main/`, `src/test/` source files
> - Testing → `src/test/`, build config (coverage thresholds)
> - Architecture → Package imports, dependency directions
> - Git → Recent commit messages (`git log --oneline -20`)
> - Infrastructure → Dockerfiles, K8s manifests, build files
> - Database → Migrations, entity classes, repository queries
> - API Design → REST controllers, DTOs, error handlers
> - Security → Logging statements, error responses, data masking
> - Observability → Span attributes, metric definitions, log format
>
> **For each violation found, report:**
> - File path and line number
> - Violation description (1 sentence)
> - Severity: CRITICAL (blocks build/deploy), HIGH (quality/security risk), MEDIUM (convention), LOW (improvement)
> - Rule section reference
>
> **Anti-patterns:** Do NOT flag test fixtures for production rules. Do NOT flag generated/third-party code. Be precise — no false positives.
>
> **Output format (strict):**
> ```
> RULE: {RULE_NAME}
> STATUS: PASS|FAIL
> VIOLATIONS: N
> ---
> [SEVERITY] path/file:line — Description [Section X]
> [SEVERITY] path/file:line — Description [Section Y]
> ```
> If no violations, output STATUS: PASS and VIOLATIONS: 0.

### Subagent: Knowledge Pack Scanner

**Launch:** One per knowledge pack with reference files, discovered in Phase 1b.
**Type:** `general-purpose`

**Prompt template (substitute `{KP_NAME}`, `{KP_SKILL_PATH}`, `{KP_REF_FILES}`):**

> You are a codebase pattern compliance auditor. Your task is to audit source code against a knowledge pack's patterns and anti-patterns.
>
> **Knowledge Pack:** `{KP_NAME}`
>
> **Step 1:** Read the SKILL.md at `{KP_SKILL_PATH}` to understand scope.
> **Step 2:** Read ALL reference files: {KP_REF_FILES}
> **Step 3:** From the references, extract:
> - Concrete implementation patterns (GOOD examples)
> - Anti-patterns (FORBIDDEN sections)
> - "When to Use" criteria
> **Step 4:** Scan relevant source files for violations.
>
> **Scan targets by pack type:**
> - `architecture-patterns` → Package structure, imports, class design
> - `database-patterns` → Entities, repositories, migrations, queries
> - `{framework}-patterns` → DI beans, config classes, REST resources
> - `layer-templates` → All layers (domain, adapter, application)
> - `dockerfile` → Dockerfiles, .dockerignore
> - `k8s-*` → K8s manifests (YAML)
> - `infra-*` → IaC files (Terraform, Crossplane)
>
> **Severity:**
> - CRITICAL: Anti-pattern from FORBIDDEN section actively present
> - HIGH: Required pattern missing when project context demands it
> - MEDIUM: Deviation from recommended pattern without justification
> - LOW: Improvement opportunity
>
> **Important:** Only flag missing patterns when project context requires them (check project identity for `event_driven`, `domain_driven`, etc.). Skip findings already covered by project rules (rules take precedence).
>
> **Output format (strict):**
> ```
> KNOWLEDGE_PACK: {KP_NAME}
> STATUS: PASS|FAIL
> VIOLATIONS: N
> ---
> [SEVERITY] path/file:line — Description [reference-file.md, Section]
> [SEVERITY] path/file:line — Description [reference-file.md]
> ```
> If no violations, output STATUS: PASS and VIOLATIONS: 0.

## Phase 3: Aggregation & Report (Orchestrator — Inline)

### 3a. Collect & Deduplicate

1. Collect all subagent outputs
2. Deduplicate: if same file:line appears in both rule and KP findings, keep the rule finding only
3. Count totals per source, per severity

### 3b. Generate Report

```markdown
# Codebase Compliance Report

**Date:** YYYY-MM-DD
**Branch:** {current branch}
**Scope:** rules + patterns | rules only | patterns only

## Executive Summary

| Source | Type | Violations | Critical | High | Medium | Low | Status |
|--------|------|-----------|----------|------|--------|-----|--------|
| Rule 01 — Name | Rule | N | N | N | N | N | PASS/FAIL |
| ... | ... | ... | ... | ... | ... | ... | ... |
| kp-name | Knowledge Pack | N | N | N | N | N | PASS/FAIL |

**Overall:** X PASS, Y FAIL, Z violations (A rules, B patterns)

## Section 1: Rule Findings
(group by rule, then by severity descending)

## Section 2: Knowledge Pack Findings
(group by pack, then by severity descending)

## Suggested Stories
(group by source, estimate effort S/M/L)
```

### 3c. Story Creation (if `--fix`)

When `--fix` and user approves:
1. One story per source with CRITICAL/HIGH violations
2. Consolidated story for MEDIUM/LOW (if < 10 total) or per-source (if > 10)
3. Max ~15 violations per story
4. Tag: `[Rule]` or `[Pattern]`

## Anti-Patterns

- Do NOT report false positives (read code carefully, understand context)
- Do NOT flag test code for production rules (magic numbers in fixtures are OK)
- Do NOT flag generated or third-party code
- Do NOT create stories for violations that already have an open story
- Do NOT flag missing patterns when project context does not require them
- Do NOT duplicate findings between rules and knowledge packs
- Do NOT scan knowledge packs that have no reference files

## Integration Notes

- Can be run independently of the feature lifecycle
- Stories can be implemented via `x-dev-lifecycle` or `x-dev-implement`
- Complements `/x-review` (diff-based) with full codebase scanning
- Run `/x-lib-audit-rules --scope patterns` after adding new knowledge packs
