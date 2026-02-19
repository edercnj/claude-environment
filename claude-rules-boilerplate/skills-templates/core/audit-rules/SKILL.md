---
name: audit-rules
description: "Audits compliance of all project rules against source code. Scans for violations in parallel (one agent per rule), generates a detailed audit report grouped by rule with severity classification, and suggests stories for fixes."
allowed-tools: Read, Bash, Grep, Glob, Write
argument-hint: "[--rules all|01,02,03] [--fix]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Audit Rules (Codebase Compliance Review)

## Purpose

Automates codebase compliance review by:

1. Reading each rule file from the project's rules directory
2. Scanning the source code for violations IN PARALLEL (one agent per rule)
3. Aggregating findings into a single report
4. Suggesting story creation for non-trivial fixes
5. Optionally creating fix stories if the user approves

## Input

**Arguments:** `$ARGUMENTS`

- `--rules all` (default): Review all rules
- `--rules 01,02,03`: Review specific rules only
- `--fix`: After report, prompt user to create stories

If no arguments provided, default to `--rules all`.

## Execution Flow

```
1. DISCOVER    -> List all rule files
2. SCAN        -> Launch parallel agents (one per rule) to check compliance
3. AGGREGATE   -> Collect findings from all agents
4. REPORT      -> Present detailed report grouped by rule
5. SUGGEST     -> Propose stories for non-trivial violations
6. CREATE      -> If --fix and user approves, write story files
```

## Phase 1: Discovery

List all rule files in the project's rules directory. Identify which rules to check based on arguments.

## Phase 2: Parallel Scanning

**CRITICAL: ALL scan tasks MUST be launched in a SINGLE message for true parallelism.**

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

## Phase 3: Report Format

```markdown
# Codebase Compliance Report

**Date:** YYYY-MM-DD
**Branch:** {current branch}

## Summary

| Rule | Violations | Critical | High | Medium | Low | Status    |
| ---- | ---------- | -------- | ---- | ------ | --- | --------- |
| 01   | N          | N        | N    | N      | N   | PASS/FAIL |
| ...  | ...        | ...      | ...  | ...    | ... | ...       |

**Overall:** X rules PASS, Y rules FAIL, Z total violations

## Detailed Findings

### Rule NN -- Rule Name

**Status:** PASS/FAIL | Violations: N

#### CRITICAL
- `path/file:42` -- Description [Rule NN, Section X]

#### HIGH
- `path/file:10` -- Description [Rule NN, Section Y]

(repeat for each rule)

## Suggested Stories

### Story Group: "Rule NN Violations"
**Estimated effort:** S/M/L
**Violations addressed:** N
- Fix description 1
- Fix description 2
```

## Phase 4: Story Creation (Optional)

When `--fix` is provided and user approves:

1. Find highest existing story number
2. Create one story per rule with CRITICAL/HIGH violations
3. Group MEDIUM/LOW into consolidated cleanup stories
4. Update implementation map with new stories

### Story Grouping Rules

1. One story per rule with CRITICAL or HIGH violations
2. One consolidated story for MEDIUM/LOW if total < 10
3. Separate stories per rule for MEDIUM/LOW if > 10 in one rule
4. Max ~15 violations per story

## Anti-Patterns

- Do NOT report false positives (read code carefully)
- Do NOT flag test code for production rules (magic numbers in fixtures are OK)
- Do NOT flag generated or third-party code
- Do NOT create stories for violations that already have an open story
- Do NOT create empty stories

## Integration Notes

- Can be run at any time, independently of the feature lifecycle
- Useful before starting a new phase of development to assess technical debt
- Stories created by this skill can be implemented via `feature-lifecycle` or `implement-story`
