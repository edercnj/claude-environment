---
name: audit-rules
description: "Codebase compliance reviewer that validates all project rules (.claude/rules/) against the current source code. Triggers include: 'review codebase', 'validate rules', 'check compliance', 'rule violations', 'codebase audit', 'quality gate', 'standards check'. Produces a detailed report grouped by rule with story suggestions for fixes."
allowed-tools: Read, Bash, Grep, Glob, Task, AskUserQuestion, Write
argument-hint: "[--rules all|01,02,03] [--fix]"
context: fork
agent: general-purpose
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Review Codebase Skill — Authorizer Simulator

You are a **Senior Staff Engineer** performing a comprehensive codebase audit.
Your job is to validate that the source code complies with ALL project rules defined in `.claude/rules/`.

## Purpose

This skill automates codebase compliance review by:

1. Reading each rule file from `.claude/rules/`
2. Scanning the source code for violations IN PARALLEL (one agent per rule)
3. Aggregating findings into a single report
4. Suggesting story creation for non-trivial fixes (grouped by rule)
5. Optionally creating the story files if the user approves

## Input

**Arguments:** $ARGUMENTS

- `--rules all` (default): Review all rules
- `--rules 01,02,03`: Review specific rules only
- `--fix`: After report, prompt user to create stories

If no arguments provided, default to `--rules all --fix`.

## Execution Flow

```
1. DISCOVER    → List all rule files in .claude/rules/
2. SCAN        → Launch parallel agents (one per rule) to check compliance
3. AGGREGATE   → Collect findings from all agents
4. REPORT      → Present detailed report grouped by rule
5. SUGGEST     → Propose stories for non-trivial violations
6. ASK         → Prompt user: "Create stories? [Yes/No]"
7. CREATE      → If yes, write STORY-NNN.md files
8. MAP         → Update IMPLEMENTATION-MAP.md with new stories, dependencies, and status
```

## Phase 1: Discovery

```bash
# List all rules
ls .claude/rules/*.md
```

Identify which rules to check based on `$ARGUMENTS`.

## Phase 2: Parallel Scanning

### CRITICAL INSTRUCTION — Mandatory Parallelization

**You MUST send ALL Task tool calls in a SINGLE message.**
One assistant message containing N simultaneous Task invocation blocks (one per rule).
Do NOT send one Task, wait for the result, then send another — that is SEQUENTIAL and FORBIDDEN in this phase.

**Golden Rule:**

- N Task calls in ONE message = PARALLEL (correct)
- 1 Task call per message = SEQUENTIAL (wrong, forbidden)

For EACH rule, launch a parallel agent (Task tool with subagent_type=Explore) that:

1. Reads the rule file completely
2. Scans ALL relevant source files (src/main/java, src/test/java, src/main/resources, k8s/, smoke-tests/, pom.xml, Dockerfile\*, etc.)
3. Identifies EVERY violation with:
   - **File path and line number**
   - **Violation description**
   - **Severity:** CRITICAL (blocks build/deploy), HIGH (quality/security risk), MEDIUM (convention violation), LOW (improvement opportunity)
   - **Rule reference** (which specific section of the rule is violated)

### Rule-Specific Scanning Strategies

**Rule 01 (Project):** Check pom.xml coordinates, stack compliance, language conventions in code/commits
**Rule 02 (Java Coding):** Check for Lombok, null returns, magic numbers, field injection, method length, class length, naming conventions, CC-01 to CC-10
**Rule 03 (Testing):** Check JaCoCo thresholds, AssertJ usage (no JUnit assertEquals), test naming, fixture patterns, H2 config
**Rule 04 (ISO 8583):** Check multi-version support, RULE-001/002 implementation, sensitive data handling
**Rule 05 (Architecture):** Check hexagonal boundaries (domain importing adapter?), package structure
**Rule 06 (Git Workflow):** Check recent commit messages against Conventional Commits
**Rule 07 (Infrastructure):** Check Docker multi-stage, K8S manifests, non-root user
**Rule 08 (Configuration):** Check @ConfigMapping usage, profile separation, no duplicated properties
**Rule 16 (Database):** Check Flyway naming, column types, index naming, PAN masking
**Rule 17 (API Design):** Check REST endpoints, DTOs with @RegisterForReflection, @Schema, ProblemDetail usage, ExceptionMapper
**Rule 18 (Observability):** Check OTel config, span attributes, sensitive data in spans/logs, health checks
**Rule 19 (DevOps):** Check Dockerfile, K8S manifests, Kustomize structure
**Rule 20 (TCP Connections):** Check framing, connection management, thread safety, error handling
**Rule 21 (Security):** Check PAN masking, no PIN/CVV logging, fail-secure, input validation
**Rule 22 (Smoke Tests):** Check smoke test structure, scripts, scenarios
**Rule 23 (Kubernetes):** Check labels, security context, probes, resources, NetworkPolicy

## Phase 3: Report Format

Generate a report in this exact format:

```markdown
# Codebase Compliance Report

**Date:** YYYY-MM-DD
**Branch:** {current branch}
**Commit:** {current commit SHA}

## Summary

| Rule | Violations | Critical | High | Medium | Low | Status    |
| ---- | ---------- | -------- | ---- | ------ | --- | --------- |
| 01   | N          | N        | N    | N      | N   | PASS/FAIL |
| ...  | ...        | ...      | ...  | ...    | ... | ...       |

**Overall:** X rules PASS, Y rules FAIL, Z total violations

---

## Detailed Findings

### Rule 01 — Project Identity

**Status:** PASS/FAIL | Violations: N

#### CRITICAL

- `path/file.java:42` — Description of violation [Rule 01, Section X]

#### HIGH

- `path/file.java:10` — Description [Rule 01, Section Y]

#### MEDIUM

- ...

#### LOW

- ...

---

### Rule 02 — Java Coding

...

(repeat for each rule)

---

## Suggested Stories

### Story Group: "Rule 02 — Java Coding Violations"

**Estimated effort:** S/M/L
**Violations addressed:** N

- Fix method length violations in XClass, YClass
- Extract magic numbers to constants in ZClass
- Replace field injection with constructor injection in WClass

### Story Group: "Rule 05 — Architecture Boundary Violations"

...
```

## Phase 4: Story Template

When the user approves story creation, use this template (adapted from the project's existing story format):

````markdown
# Story: {Descriptive title of the fix}

**ID:** STORY-{NNN}

## 1. Dependencies

| Blocked By | Blocks |
| :--------- | :----- |
| -          | -      |

## 2. Applicable Cross-Cutting Rules

| ID       | Title                   |
| :------- | :---------------------- |
| RULE-{N} | {Name of violated rule} |

## 3. Description

As a **Software Engineer**, I want to fix the violations of {Rule N — Name}
identified in the codebase review, ensuring that the source code complies
with the project standards.

### 3.1 Identified Violations

{Detailed list of each violation with file, line, and description}

### 3.2 Required Fixes

{List of concrete actions to fix each violation}

## 4. Local Quality Definitions

### Local DoR (Definition of Ready)

- [ ] Violations documented with file and line
- [ ] Reference rule read and understood
- [ ] Change impact assessed (breaking changes?)

### Local DoD (Definition of Done)

- [ ] All listed violations fixed
- [ ] No new violations introduced
- [ ] Existing tests still passing (mvn verify)
- [ ] Coverage maintained >= 95% line, >= 90% branch

### Global Definition of Done (DoD)

- **Coverage:** >= 95% Line Coverage, >= 90% Branch Coverage (JaCoCo).
- **Automated Tests:** Unit, integration (@QuarkusTest),
  API (REST Assured), TCP Socket, and E2E covering Success, Business Error, and Timeout flows.
- **Coverage Report:** Per-class report with Line/Branch Coverage percentages
  and test counts (passing/failing/errors/skipped).
- **Performance:** < 1s (except forced timeouts).

## 5. Acceptance Criteria (Gherkin)

```gherkin
Scenario: Code compliant with {Rule N}
  Given that violations were identified in the codebase review
  When I apply the fixes listed in section 3.2
  Then the code should comply with {Rule N}
  And no new violations should be introduced
  And all existing tests should continue passing
  And test coverage should be maintained above thresholds
```
````

## 6. Sub-tasks

{List of sub-tasks generated from the violations}

```

### Story Numbering

- Read existing stories from `docs/stories/` to find the highest STORY-NNN
- New stories start from STORY-{max+1}
- Each rule group with CRITICAL or HIGH violations gets its own story
- MEDIUM/LOW violations can be grouped into a single "cleanup" story per rule

### Story Grouping Rules

1. **One story per rule** that has CRITICAL or HIGH violations
2. **One consolidated story** for all MEDIUM/LOW violations across rules (if total < 10 violations)
3. **Separate stories per rule** for MEDIUM/LOW if > 10 violations in a single rule
4. Stories MUST NOT exceed reasonable scope (max ~15 violations per story)

## Phase 5: Update Implementation Map

After creating stories, you MUST update the Implementation Map at `docs/stories/IMPLEMENTATION-MAP.md`.

### What to Update

1. **Dependency Matrix (Section 1):** Add ALL new stories with:
   - Story ID and title
   - Blocked By (from story's dependency table)
   - Blocks (from story's dependency table)
   - Status: `Pending`

2. **Implementation Phases (Section 2):** Add a new phase block for the compliance stories:
   - Group stories by dependency chains
   - Independent stories can be parallel within the phase

3. **Dependency Graph (Section 4):** Add new story nodes to the Mermaid graph:
   - Use a new `classDef` for compliance stories (e.g., `faseCompliance`)
   - Draw dependency arrows between stories

4. **Phase Summary (Section 5):** Add the new phase to the summary table

### Implementation Map Update Rules

- New stories get status `Pending`
- Preserve ALL existing entries (never remove or change status of existing stories)
- Dependency arrows must match the `Blocked By` / `Blocks` fields in the story files
- If a new story depends on an existing story, add it to the existing story's `Blocks` column
- Group compliance stories as a new phase (e.g., "Compliance Phase" or "CR Phase")

## Anti-Patterns

- Do NOT report false positives (read the code carefully before flagging)
- Do NOT flag test code for production rules (e.g., magic numbers in test fixtures are OK)
- Do NOT flag generated code or third-party code
- Do NOT create stories for violations that already have an open story (check existing STORY files)
- Do NOT create empty stories (no violations = no story)
- Do NOT mix violations from different rules in the same story
- Do NOT forget to update the Implementation Map after creating stories
- Do NOT change status of existing stories in the Implementation Map
```
