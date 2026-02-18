---
name: feature-lifecycle
description: "Skill: Feature Lifecycle (Authorizer Simulator) — Orchestrates the complete implementation cycle of a story, from planning through PR, with specialized roles and parallelized reviews."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Skill, TodoWrite
argument-hint: "[STORY-NNN]"
context: fork
agent: general-purpose
disable-model-invocation: true
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Feature Lifecycle (Authorizer Simulator)

## Description

Orchestrates the complete implementation cycle of a story, from planning through PR.

## Roles and Models (Adaptive)

| Role                   | Agent                     | Model                          | Phase                     |
| ---------------------- | ------------------------- | ------------------------------ | ------------------------- |
| Architect              | architect.md              | **Opus 4.6**                   | Phase 1 (Planning)        |
| Database Engineer      | database-engineer.md      | **Opus 4.6**                   | Phase 1 (Schema Design)   |
| Task Decomposer        | (skill: task-decomposer)  | **Sonnet**                     | Phase 1C (Decomposition)  |
| Java Developer (Haiku) | java-developer.md         | **Haiku**                      | Phase 2 (Junior tasks)    |
| Java Developer (Sonnet)| java-developer.md         | **Sonnet**                     | Phase 2 (Mid tasks)       |
| Java Developer (Opus)  | java-developer.md         | **Opus 4.6**                   | Phase 2 (Senior tasks)    |
| Security Reviewer      | security-reviewer.md      | **Adaptive** (max task tier)   | Phase 3 (Review)          |
| QA Reviewer            | qa-reviewer.md            | **Adaptive** (max task tier)   | Phase 3 (Review)          |
| Performance Reviewer   | performance-reviewer.md   | **Adaptive** (max task tier)   | Phase 3 (Review)          |
| Database Reviewer      | database-reviewer.md      | **Adaptive** (max task tier)   | Phase 3 (Review)          |
| Observability Engineer | observability-engineer.md | **Adaptive** (max task tier)   | Phase 3 (Review)          |
| DevOps Engineer        | devops-engineer.md        | **Adaptive** (max task tier)   | Phase 3 (Review)          |
| API Designer           | api-designer.md           | **Adaptive** (max task tier)   | Phase 3 (Review, if REST) |
| Tech Lead              | tech-lead.md              | **Adaptive** (story max tier)  | Phase 6 (PR Review)       |

### Adaptive Model Assignment

Model tiers are assigned based on the **Layer Task Catalog** (see `task-decomposer` skill):

| Tier        | Model       | Layer Examples                                    |
| ----------- | ----------- | ------------------------------------------------- |
| Junior      | **Haiku**   | Migration, Domain Models, Ports, DTOs, Mappers    |
| Mid         | **Sonnet**  | Repository, Use Case, REST Resource, Tests        |
| Senior      | **Opus**    | TCP Handler, Complex Domain Engine                |

Reviewer models are determined by the **highest task tier** in their review domain.
Tech Lead model = **story max task tier** (highest tier across ALL tasks).

## CRITICAL EXECUTION RULE

**The lifecycle has 8 phases (0 through 7). ALL are mandatory. NEVER stop before Phase 7.**

After EACH phase, print the progress and CONTINUE to the next:

```
>>> Phase N/7 completed. Proceeding to Phase N+1...
```

**The PR (Phase 5) is NOT the end.** After the PR, you MUST execute: Phase 5.5 -> Phase 6 -> Phase 7.
**Phase 7 (DoD + Cleanup) is the ONLY legitimate stopping point of the lifecycle.**

---

## Complete Flow

```prompt
Phase 0: Preparation
    |
    v
Phase 1: PLANNING (Architect + DB Engineer) <- Opus 4.6
    |   |-- Architect creates Implementation Plan (Sections 1-10)
    |   +-- DB Engineer designs Schema + Migration
    |
    v
Phase 1B: Test Planning <- Opus 4.6
    |   +-- Test Scenario Planner defines all scenarios
    |
    v
Phase 1C: TASK DECOMPOSITION (Task Decomposer Skill) <- Sonnet
    |   |-- Reads Architect's plan + story
    |   |-- Applies Layer Task Catalog (fixed mapping: layer → tier/model/group)
    |   |-- Produces: docs/plans/STORY-NNN-tasks.md
    |   +-- Output: Task Table + Parallelism Groups + Model Distribution
    |
    v
Phase 2: GROUP-BASED IMPLEMENTATION (Adaptive Multi-Agent) <- Haiku/Sonnet/Opus
    |   |-- 2.0: Pre-Flight (read task decomposition, build group plan)
    |   |-- 2.1: Execute Groups G1 → G7 sequentially
    |   |       |-- G1: Foundation (Migration + Domain Models) — PARALLEL, Haiku
    |   |       |       +-- group-verifier: mvn compile → commit
    |   |       |-- G2: Contracts (Ports + DTOs + Engine) — PARALLEL, Haiku/Sonnet/Opus
    |   |       |       +-- group-verifier: mvn compile → commit
    |   |       |-- G3: Outbound Adapters (Entity + Mapper + Repository) — PARALLEL, Haiku/Sonnet
    |   |       |       +-- group-verifier: mvn compile → commit
    |   |       |-- G4: Orchestration (Use Case) — SEQUENTIAL, Sonnet
    |   |       |       +-- group-verifier: mvn compile → commit
    |   |       |-- G5: Inbound Adapters (REST + TCP + Config) — PARALLEL, Sonnet/Opus
    |   |       |       +-- group-verifier: mvn compile → commit
    |   |       |-- G6: Observability (OTel) — SEQUENTIAL, Sonnet
    |   |       |       +-- group-verifier: mvn compile → commit
    |   |       +-- G7: Tests — PARALLEL (max 4), Sonnet
    |   |               +-- group-verifier: mvn verify → commit
    |   |-- 2.2: Coverage report
    |   +-- 2.3: Escalation tracking (retries + tier escalations)
    |
    v
Phase 3: PARALLEL REVIEW (7-8 Reviewers) <- Adaptive (per reviewer domain)
    |   |-- Security Reviewer     <- model = max tier of (Engine, TCP, Repository)
    |   |-- QA Reviewer           <- model = max tier of test tasks
    |   |-- Performance Reviewer  <- model = max tier of (Engine, TCP, Repository)
    |   |-- Database Reviewer     <- model = max tier of (Migration, Entity, Repository)
    |   |-- Observability Engineer <- model = tier of OTel task
    |   |-- DevOps Engineer       <- model = tier of Config task
    |   |-- API Designer          <- model = max tier of (DTOs, REST Resource)
    |   +-- [All in PARALLEL via Task tool]
    |
    v
Phase 4: FIXES + FEEDBACK
    |   |-- Java Developer fixes critical issues (model = tier of affected task)
    |   |-- mvn compile -Xlint:all + mvn verify + self-review
    |   +-- Update common-mistakes.md with newly found errors
    |
    v
Phase 5: COMMIT & PR
    |   |-- Push commits (already atomic from Phase 2 group commits)
    |   +-- PR via gh CLI
    |
    v
Phase 5.5: SMOKE TESTS (On Demand)
    |   |-- Newman (REST API) — if story involves REST
    |   +-- Socket Client (ISO 8583) — if story involves TCP
    |
    v
Phase 6: TECH LEAD REVIEW (on the PR) <- Adaptive (story max tier)
    |   |-- Review of the consolidated PR diff (holistic view)
    |   |-- 40-point checklist on the final PR
    |   |-- GO -> merge
    |   +-- NO-GO -> fixes + push (no new PR)
    |
    v
Phase 7: FINAL VERIFICATION + CLEANUP
    |   |-- 7.1: Update README.md (if needed) -> commit + push
    |   |-- 7.2: Update IMPLEMENTATION-MAP -> commit + push
    |   |-- 7.3: DoD Checklist (24 checks: phases + quality + git + artifacts)
    |   |-- 7.4: Report result (PASS/FAIL by category)
    |   |-- 7.5: git checkout main && git pull origin main
    |   +-- 7.6: Final Lifecycle Output
    |
    v
    DONE — Ready for next story
```

---

## Phase 0 — Preparation

**Executor:** Claude (direct, no agent)
**Model:** Any

### Actions

**STEP 0.1 — Parallel Context Reading:**

Read ALL context files IN PARALLEL (multiple Read calls in a single message):

| #   | File                                | Independent |
| --- | ----------------------------------- | ----------- |
| 1   | `stories/STORY-NNN.md`              | Yes         |
| 2   | `stories/EPIC-001.md`               | Yes         |
| 3   | `docs/adr/` (relevant ADRs)         | Yes         |
| 4   | `.claude/rules/` (applicable rules) | Yes         |

**STEP 0.2 — Verifications (after reading):**

5. Check dependencies: are predecessor stories complete?
6. Create branch: `git checkout -b feat/STORY-NNN-description`

### Phase 0 Exit Criteria

- Story and EPIC read
- Dependencies satisfied
- Branch created
- Print: `>>> Phase 0/7 completed. Proceeding to Phase 1 (Planning)...`

---

## Phase 1 — Planning (Architect + DB Engineer)

**Executor:** Task tool with agent `architect.md`
**Model:** Opus 4.6

### Prompt Template for the Architect

```prompt
You are the Architect of the authorizer-simulator project.

STEP 1 — Read ALL these files IN PARALLEL (multiple Read calls in a single message):
- stories/STORY-NNN.md
- stories/EPIC-001.md
- .claude/rules/05-architecture.md
- .claude/rules/02-java-coding.md
- .claude/rules/16-database-design.md (if involves DB)
- .claude/rules/17-api-design.md (if involves REST)
- .claude/rules/18-observability.md
- .claude/rules/24-resilience.md (if involves error handling, timeouts, circuit breakers)

STEP 2 — After reading all files, read the relevant ADRs:
- docs/adr/ (ADRs mentioned in the story)

STEP 3 — Produce an IMPLEMENTATION PLAN following the format defined in architect.md.
Save the plan to: docs/plans/STORY-NNN-plan.md
```

### If the Story Involves a Database

**Additional executor:** Task tool with agent `database-engineer.md`
**Model:** Opus 4.6

```prompt
You are the Database Engineer of the authorizer-simulator project.

Read:
- docs/plans/STORY-NNN-plan.md (Architect's plan)
- .claude/rules/16-database-design.md
- .claude/skills/database-patterns/SKILL.md

Produce:
1. Detailed schema design
2. Flyway migration (V{N}__{description}.sql)
3. Recommended indexes
4. Example queries for the Repository

Save to: docs/plans/STORY-NNN-database.md
```

### Phase 1 Exit Criteria

- `docs/plans/STORY-NNN-plan.md` created
- `docs/plans/STORY-NNN-database.md` created (if applicable)
- Plan reviewed and complete
- Architect's plan includes Section 10 (Layers Affected checklist)
- Print: `>>> Phase 1/7 completed. Proceeding to Phase 1B (Test Planning)...`

---

## Phase 1B — Test Planning

**Executor:** Task tool with skill `plan-tests`
**Model:** Opus 4.6

### Phase 1B Prompt Template

```prompt
Read:
- stories/STORY-NNN.md
- docs/plans/STORY-NNN-plan.md
- .claude/rules/03-testing.md

Produce a test plan covering the 8 categories:
- Happy path (1 test per public method)
- Error path (1 test per exception)
- Boundary tests
- Parametrized tests (cents, MCCs, etc.)
- Integration tests (@QuarkusTest + Testcontainers)
- API tests (REST Assured, if applicable)
- Socket tests (if applicable)
- Performance tests (Gatling scenarios with SLAs)
- E2E tests (full flow TCP -> Parse -> DB -> Response)
- Persistent connection tests (multi-message, idle, timeout, backpressure)

Save to: docs/plans/STORY-NNN-tests.md
```

### Phase 1B Exit Criteria

- `docs/plans/STORY-NNN-tests.md` created
- Print: `>>> Phase 1B/7 completed. Proceeding to Phase 1C (Task Decomposition)...`

---

## Phase 1C — Task Decomposition (Layer-Based)

**Executor:** Orchestrator (applies the `task-decomposer` skill logic in-context — no subagent fork)

### Purpose

Transforms the Architect's plan into granular, single-layer tasks using the **Layer Task Catalog**. Each task is assigned an adaptive model tier (Haiku/Sonnet/Opus), context budget, and parallelism group based on its hexagonal layer.

### Phase 1C Actions

1. Read `docs/plans/STORY-NNN-plan.md` (Section 10: Layers Affected)
2. Read `stories/STORY-NNN.md`
3. Apply the Layer Task Catalog from `task-decomposer` skill:
   - For each active layer, create ONE task with fixed tier/model/group
   - For Domain Engine tasks, evaluate complexity (Sonnet vs Opus)
   - Assign context budget (S/M/L) per tier
4. Generate the Parallelism Execution Plan (G1 → G7)
5. Determine reviewer model assignments (max task tier per domain)
6. Save to: `docs/plans/STORY-NNN-tasks.md` (using template from task-decomposer)

### Phase 1C Exit Criteria

- `docs/plans/STORY-NNN-tasks.md` created with:
  - Task Table (ID, Layer, Tier, Model, Budget, Group, Dependencies, Files, Commit)
  - Parallelism Execution Plan (G1-G7 with task assignments)
  - Model Distribution Summary (Haiku/Sonnet/Opus percentages)
  - Review Tier Assignment (model per reviewer domain)
  - Tech Lead Tier (story max tier)
- Print: `>>> Phase 1C/7 completed. Proceeding to Phase 2 (Implementation)...`

---

## Phase 2 — Group-Based Implementation (Adaptive Multi-Agent)

**Executor:** Claude direct (orchestrator) + Task tool with agent `java-developer.md` per task (adaptive model)
**Principle:** Tasks from `docs/plans/STORY-NNN-tasks.md` are organized into parallelism groups (G1-G7). Within each group, tasks run in PARALLEL with the model tier assigned by the Layer Task Catalog. Between groups, the `group-verifier` skill validates compilation before proceeding. Each group produces an atomic commit.

### Step 2.0: Pre-Flight (orchestrator direct)

**Parallel reading** — Read ALL these files IN PARALLEL:

| #   | File                            | Extract                                   |
| --- | ------------------------------- | ----------------------------------------- |
| 1   | `docs/plans/STORY-NNN-tasks.md` | Task Table + Parallelism Execution Plan   |
| 2   | `docs/plans/STORY-NNN-plan.md`  | Relevant sections for dependency context  |
| 3   | `docs/common-mistakes.md`       | Summarize in 5 bullet points              |

**After reading:** Build group execution plan from the Parallelism Execution Plan section.

### Step 2.1: Execute Groups G1 → G7 Sequentially

For each group G{N}, execute ALL tasks in the group in PARALLEL, then run the `group-verifier`.

#### Group Execution Loop

```
FOR each group G{N} in [G1, G2, G3, G4, G5, G6, G7]:
  IF group has tasks:
    1. Read dependency outputs from previous groups (file contents)
    2. Launch ALL tasks in G{N} in PARALLEL (one Task tool call per task)
       - Each task uses its assigned MODEL from the Task Table
       - Each task receives its TIER-APPROPRIATE context (S/M/L budget)
    3. Wait for all tasks to complete
    4. Run group-verifier: mvn compile (or mvn verify for G7)
       - If PASS: commit group, extract outputs, proceed to G{N+1}
       - If FAIL: classify errors, retry/escalate per group-verifier rules
```

#### Prompt Templates by Tier

**Haiku Tasks (S budget — ~100-200 lines):**

```prompt
You are a Java Developer implementing a single layer task.

## TEMPLATE
[Full content from layer-templates/references/{layer}.md]

## YOUR TASK
- Task ID: T{N}
- Files to create: [list]
- Files to modify: [list]

## PLAN SECTION
[Only the relevant section from the Architect's plan (~30-50 lines)]

## CRITICAL RULES (memorize)
1. Method signatures on 1 line (only break if > 120 chars)
2. Constructor injection with @Inject (never field injection)
3. Optional<T> for search returns (never null)
4. Records for DTOs, VOs, Events
5. Named constants (never magic numbers/strings)
6. Methods <= 25 lines, do ONE thing
7. Classes <= 250 lines, ONE responsibility

## INSTRUCTIONS
1. Follow the TEMPLATE exactly, replacing CHANGE THESE sections
2. Implement ONLY the files listed above
3. Do NOT commit (the orchestrator handles that)
```

**Sonnet Tasks (M budget — ~250-400 lines):**

```prompt
You are the SR Java Developer of the authorizer-simulator project.

## CRITICAL RULES (memorize)
1. Method signatures on 1 line (only break if > 120 chars)
2. Constructor injection with @Inject (never field injection)
3. Optional<T> for search returns (never null)
4. Records for DTOs, VOs, Events
5. Named constants (never magic numbers/strings)
6. Methods <= 25 lines, do ONE thing
7. Classes <= 250 lines, ONE responsibility

## COMMON MISTAKES (avoid)
[5 summarized bullet points from common-mistakes.md]

## YOUR TASK
- Task ID: T{N}
- Files to create: [list]
- Files to modify: [list]
- Commit message (for reference): [message]

## PLAN SECTION
[Task section + adjacent context (~80-150 lines)]

## DEPENDENCY OUTPUTS
[Code from dependency tasks — actual file contents from previous groups]

## REFERENCE RULES
[Content of 2-3 relevant rule files]

## INSTRUCTIONS
1. Implement ONLY the files listed above
2. Run `mvn compile -Xlint:all` at the end
3. Do NOT commit (the orchestrator handles that)
```

**Opus Tasks (L budget — ~500-800 lines):**

```prompt
You are a Senior Java Developer implementing a complex task for the authorizer-simulator.

## CRITICAL RULES (memorize)
1. Method signatures on 1 line (only break if > 120 chars)
2. Constructor injection with @Inject (never field injection)
3. Optional<T> for search returns (never null)
4. Records for DTOs, VOs, Events
5. Named constants (never magic numbers/strings)
6. Methods <= 25 lines, do ONE thing
7. Classes <= 250 lines, ONE responsibility

## COMMON MISTAKES (avoid)
[5 summarized bullet points from common-mistakes.md]

## STORY CONTEXT
[Full story content]

## ARCHITECTURAL CONTEXT
[Affected packages, patterns, ADRs]

## YOUR TASK
- Task ID: T{N}
- Files to create: [list]
- Files to modify: [list]
- Why this is complex: [brief explanation]

## PLAN SECTION
[Extended: task section + data flow + all related sections]

## DEPENDENCY OUTPUTS
[Code from dependency tasks — actual file contents from previous groups]

## REFERENCE RULES
[ALL relevant rule files — full content]

## EXISTING CODE
[Similar existing implementations to study]

## INSTRUCTIONS
1. Implement ONLY the files listed above
2. Run `mvn compile -Xlint:all` at the end
3. Do NOT commit (the orchestrator handles that)
```

### Step 2.2: Group Verification (after each group)

Apply the `group-verifier` skill procedure:

1. **Compile:** `mvn compile -Xlint:all -q 2>&1` (or `mvn verify` for G7)
2. **Analyze:** If exit code != 0, classify errors
3. **Decide:** Retry same tier (max 2) or escalate (Haiku→Sonnet→Opus)
4. **Extract:** Read all created/modified files for dependency injection into next group
5. **Commit:** `git add {group files} && git commit -m "{group commit message}"`
6. **Report:** Print verification result

Group commit messages follow the pattern from `group-verifier` skill:
- G1: `feat(domain): add foundation models and migration for STORY-NNN`
- G2: `feat(domain): add ports, DTOs, and engine for STORY-NNN`
- G3: `feat(persistence): add entity, mapper, and repository for STORY-NNN`
- G4: `feat(application): add use case for STORY-NNN`
- G5: `feat(adapter): add REST resource, TCP handler, and config for STORY-NNN`
- G6: `feat(observability): add tracing and metrics for STORY-NNN`
- G7: `test: add tests for STORY-NNN`

### Step 2.3: Coverage Report

After G7 passes `mvn verify`, generate the **Per-Class Coverage Report**:

1. Identify modified classes: `git diff main --name-only -- '*.java' | grep -v 'src/test/'`
2. Parse the JaCoCo XML report: `target/site/jacoco/jacoco.xml`
3. For each modified class, extract:
   - **Line Coverage %**: `<counter type="LINE" missed="X" covered="Y"/>` -> `Y/(X+Y) * 100`
   - **Branch Coverage %**: `<counter type="BRANCH" missed="X" covered="Y"/>` -> `Y/(X+Y) * 100` (or `-` if no branches)
4. Parse test results from Surefire/Failsafe:
   - `target/surefire-reports/*.xml` and `target/failsafe-reports/*.xml`
   - Count: tests, failures, errors, skipped

#### Coverage Report Format

```
+--------------------------+-------+--------+
|          Class           | Line  | Branch |
+--------------------------+-------+--------+
| CentsDecisionEngine      | 100%  | 95.0%  |
+--------------------------+-------+--------+
| DebitAuthorizationHandler | 97.3% | 88.5% |
+--------------------------+-------+--------+
| TransactionRepository    | 92.1% | -      |
+--------------------------+-------+--------+

Tests: XX passing, XX failing, XX errors, XX skipped
Global Coverage: XX% line / XX% branch
```

Save report to: `docs/reports/STORY-NNN-coverage.md`

### Error Handling and Escalation

- **Within a group:** If a task fails compilation, retry at same tier (max 2 retries)
- **After 2 retries:** Escalate: Haiku → Sonnet → Opus → Manual intervention
- **MISSING_DEPENDENCY:** Halt pipeline, flag previous group regression
- **BUILD_ERROR:** Halt pipeline, report missing Maven dependency
- Committed groups are preserved in git (rollback point per group)
- **Resumption**: if group commits are detected on the current branch, ask the user "Resume from G{N}?"
- Target: < 15% of tasks should escalate. If consistently > 15%, review the Layer Task Catalog tier assignments.

### Phase 2 Exit Criteria

- All groups (G1-G7) completed with group commits
- ZERO warnings in `mvn compile -Xlint:all`
- `mvn verify` passing
- Coverage >= 95% line, >= 90% branch
- Coverage report generated at `docs/reports/STORY-NNN-coverage.md`
- Escalation summary: N tasks retried, N tasks escalated
- Print: `>>> Phase 2/7 completed. Proceeding to Phase 3 (Parallel Review)...`

---

## Phase 3 — Parallel Review (7-8 Reviewers, Adaptive Models)

**Executor:** Task tool x 7-8 agents in PARALLEL
**Model:** Adaptive — each reviewer's model is determined by the **highest task tier** in their review domain (from `docs/plans/STORY-NNN-tasks.md`, "Review Tier Assignment" section).

### CRITICAL INSTRUCTION — Mandatory Parallelization

**YOU MUST send ALL Task tool calls in ONE SINGLE message.**
One assistant message containing 7-8 simultaneous Task invocation blocks.
Do NOT send one Task, wait for the result, and then send another — that is SEQUENTIAL and FORBIDDEN in this phase.

**Golden Rule:**

- 7-8 Task calls in ONE message = PARALLEL (correct)
- 1 Task call per message = SEQUENTIAL (wrong, forbidden)

### Reviewer Model Assignment

Before launching reviewers, read the "Review Tier Assignment" section from `docs/plans/STORY-NNN-tasks.md`:

| Reviewer              | Review Domain (Task Types)                    | Model = Max Tier In Domain |
| --------------------- | --------------------------------------------- | -------------------------- |
| Security Reviewer     | Domain Engine, TCP Handler, Repository        | Max tier of those tasks    |
| QA Reviewer           | All test tasks                                | Max tier of test tasks     |
| Performance Reviewer  | Domain Engine, TCP Handler, Repository        | Max tier of those tasks    |
| Database Reviewer     | Migration, Entity, Repository                 | Max tier of those tasks    |
| Observability Engineer| OTel task                                     | Tier of OTel task          |
| DevOps Engineer       | Config task                                   | Tier of Config task        |
| API Designer          | DTOs, REST Resource                           | Max tier of those tasks    |

**Tier → Model mapping:** Junior = Haiku, Mid = Sonnet, Senior = Opus

### Base prompt for ALL reviewers

Each Task receives the prompt below, replacing `[AGENT_FILE]`, `[OUTPUT_FILE]`, and using the assigned `[MODEL]`:

```prompt
STEP 1 — Read the file .claude/agents/[AGENT_FILE] to understand your role, checklist, and which rules to read.

STEP 2 — MANDATORY PARALLELISM: Read ALL the files below IN PARALLEL (multiple Read calls in a single message):
- ALL rules listed in Step 1 of the agent file (your quality reference)
- stories/STORY-NNN.md
- docs/plans/STORY-NNN-plan.md

STEP 3 — After reading all files, review the code implemented for STORY-NNN.

Code and artifacts to review:
- Code: src/main/java/com/bifrost/simulator/
- Tests: src/test/java/com/bifrost/simulator/
- Migrations: src/main/resources/db/migration/
- Config: src/main/resources/application.properties

Produce your report in the format defined in the agent file.
Save to: docs/reviews/[OUTPUT_FILE]
```

### List of Tasks to launch (ALL in the same message)

| #   | Agent File                | Output File                | Model (from task-decomposer) | Description                                     |
| --- | ------------------------- | -------------------------- | ---------------------------- | ----------------------------------------------- |
| 1   | security-reviewer.md      | STORY-NNN-security.md      | [from Review Tier Assignment]| Security: sensitive data, PAN masking, validation|
| 2   | qa-reviewer.md            | STORY-NNN-qa.md            | [from Review Tier Assignment]| Tests: coverage, quality, scenarios              |
| 3   | performance-reviewer.md   | STORY-NNN-performance.md   | [from Review Tier Assignment]| Performance: latency, concurrency, native build  |
| 4   | database-reviewer.md      | STORY-NNN-database.md      | [from Review Tier Assignment]| Database: schema, migrations, indexes, queries   |
| 5   | observability-engineer.md | STORY-NNN-observability.md | [from Review Tier Assignment]| Observability: spans, metrics, logging, health   |
| 6   | devops-engineer.md        | STORY-NNN-devops.md        | [from Review Tier Assignment]| Infra: Docker, K8S, config, resilience           |
| 7   | api-designer.md           | STORY-NNN-api.md           | [from Review Tier Assignment]| REST API: design, contracts (if REST involved)   |

All Tasks use `subagent_type: general-purpose` with the model from the Review Tier Assignment.

### Step 3.2: Review Consolidation (MANDATORY)

After ALL agents return, the orchestrator MUST:

1. Read each report generated at `docs/reviews/STORY-NNN-*.md`
2. Extract from each report: **score**, **status**, and **failed items** (checklist items with X or score 0)
3. Print the consolidated table in the format below:

```
+---------------+-------+--------------------+
|    Review     | Score |      Status        |
+---------------+-------+--------------------+
| Security      | XX/20 | Approved           |
+---------------+-------+--------------------+
| QA            | XX/24 | Approved           |
+---------------+-------+--------------------+
| Performance   | XX/26 | Adequate           |
+---------------+-------+--------------------+
| Database      | XX/16 | Approved           |
+---------------+-------+--------------------+
| Observability | XX/18 | Needs Work         |
+---------------+-------+--------------------+
| DevOps        | XX/20 | Approved           |
+---------------+-------+--------------------+
| API Design    | XX/16 | (if applicable)    |
+---------------+-------+--------------------+
Total: XXX/YYY (XX%)
```

4. List the items that DID NOT pass, grouped by reviewer:

```
Issues Found:

  Security (N issues):
    - [ID]: [description] (CRITICAL|MEDIUM|LOW)
    - [ID]: [description] (CRITICAL|MEDIUM|LOW)

  Performance (N issues):
    - [ID]: [description] (MEDIUM)

  Observability (N issues):
    - [ID]: [description] (CRITICAL)
    - [ID]: [description] (CRITICAL)
    ...

  Database: No issues
  QA: No issues
  DevOps: No issues
```

5. Count issues by severity: `CRITICAL: N | MEDIUM: N | LOW: N`

**Rule:** If there are CRITICAL issues, Phase 4 is mandatory. If only MEDIUM/LOW, Phase 4 can focus on them or justify the skip.

### Phase 3 Exit Criteria

- 7-8 review reports collected
- Consolidated table printed with scores and status
- Issues listed by reviewer with severity
- Issues categorized: CRITICAL (blocking) | MEDIUM | LOW
- Print: `>>> Phase 3/7 completed. Proceeding to Phase 4 (Fixes)...`

---

## Phase 4 — Fixes + Feedback Loop

### Step 4.1 — Fixes (Java Developer)

**Model:** Sonnet

```prompt
Fix the CRITICAL issues identified by the reviewers:
[list of critical issues extracted from the reports]

After fixing:
1. mvn compile -Xlint:all (ZERO warnings)
2. mvn verify (tests + coverage)
3. Redo self-review on the fixed files
```

### Step 4.2 — Feedback Loop (Update Institutional Memory)

**Executor:** Claude direct (no agent)
**MANDATORY** — Always execute after fixes.

```prompt
Analyze ALL Phase 3 review reports (docs/reviews/STORY-NNN-*.md).

For each issue found (CRITICAL, MEDIUM, or LOW):
1. Check if it already exists in docs/common-mistakes.md
2. If it does NOT exist -> add it with a CONCRETE example from this story's code
3. If it already exists -> increment frequency if necessary

Update the "Update Log" table at the end of the file with:
- Date
- Story (STORY-NNN)
- Number of errors added
- Added by (Feedback Loop)

This ensures the next developer will NOT repeat the same mistakes.
```

### Phase 4 Exit Criteria

- Critical issues from reviewers fixed
- `mvn compile -Xlint:all` with ZERO warnings
- `mvn verify` passing with coverage >= 95% line, >= 90% branch
- `docs/common-mistakes.md` updated with newly found errors
- Print: `>>> Phase 4/7 completed. Proceeding to Phase 5 (Commit & PR)...`

---

## Phase 5 — Commit & PR

**Executor:** Claude direct
**Model:** Any

### Push and PR Actions

> **Note:** Atomic commits were already made in Phase 2 (one per task). This phase only pushes and creates the PR.

1. Push: `git push -u origin feat/STORY-NNN-description`
2. PR: `gh pr create --title "feat(scope): description" --body "..."`

### PR Body Format

```markdown
## Summary

- [bullet points of changes]

## Story

STORY-NNN: [title]

## Specialist Reviews (Phase 3)

| Reviewer      | Score       | Status          | Issues |
| ------------- | ----------- | --------------- | ------ |
| Security      | XX/20       | Approved        | 0      |
| QA            | XX/24       | Approved        | 0      |
| Performance   | XX/26       | Adequate        | N      |
| Database      | XX/16       | Approved        | 0      |
| Observability | XX/18       | Needs Work      | N      |
| DevOps        | XX/20       | Approved        | 0      |
| API Design    | XX/16       | (if applicable) | 0      |
| **Total**     | **XXX/YYY** | **XX%**         | **N**  |

<details>
<summary>Issues found (N CRITICAL, N MEDIUM, N LOW)</summary>

**Reviewer A (N issues):**

- [ID]: [description] (CRITICAL|MEDIUM|LOW)

**Reviewer B (N issues):**

- [ID]: [description] (MEDIUM)

_Reviewers with no issues omitted._

</details>

## Coverage Report

| Class      | Line    | Branch  |
| ---------- | ------- | ------- |
| ClassA     | XX.X%   | XX.X%   |
| ClassB     | XX.X%   | XX.X%   |
| **Global** | **XX%** | **XX%** |

## Test Results

- Tests: XX passing, 0 failing, 0 errors, 0 skipped

## Checklist

- [ ] `mvn verify` passing
- [ ] Coverage >= 95% line / >= 90% branch
- [ ] ZERO warnings in `mvn compile -Xlint:all`
- [ ] Self-review completed
- [ ] Awaiting Tech Lead review
```

### Phase 5 Exit Criteria

- PR created with URL
- Print: `>>> Phase 5/7 completed. Proceeding to Phase 5.5 (Smoke Tests)...`

**WARNING: The PR is NOT the end of the lifecycle. CONTINUE MANDATORILY to Phase 5.5.**

---

## Phase 5.5 — Smoke Tests (Conditional Skip)

**Executor:** Claude direct (via skill `run-smoke-api` and/or `run-smoke-socket`)
**Model:** Any

> **Note:** This phase is executed on demand. As maturity increases, it will be promoted to mandatory.

### Skip Logic

Evaluate whether smoke tests apply. If they do NOT apply (e.g., Minikube infrastructure not available),
print the message below and **PROCEED IMMEDIATELY to Phase 6**:

```
>>> Phase 5.5 skipped (smoke tests not applicable). Proceeding to Phase 6...
```

**NEVER stop the lifecycle because smoke tests don't apply. Skip and continue.**

### When to Execute

- **If the story involves REST API:** Execute Newman smoke tests (`run-smoke-api`)
- **If the story involves TCP Socket:** Execute Socket smoke tests (`run-smoke-socket`)
- **If the story involves both:** Execute both **IN PARALLEL** (see below)

### Actions

**If REST only:**

```bash
npm list -g newman || npm install -g newman
./smoke-tests/api/run-smoke-api.sh --k8s
```

**If Socket only:**

```bash
./smoke-tests/socket/run-smoke-socket.sh --k8s
```

**If both — MANDATORY PARALLEL:**

Launch both smoke tests IN PARALLEL via Task tool (2 calls in a single message):

| #   | Task         | Command                                          | Model |
| --- | ------------ | ------------------------------------------------ | ----- |
| 1   | Smoke REST   | `./smoke-tests/api/run-smoke-api.sh --k8s`       | haiku |
| 2   | Smoke Socket | `./smoke-tests/socket/run-smoke-socket.sh --k8s` | haiku |

Both use `subagent_type: general-purpose` and `run_in_background: true`.
Collect results after both finish.

### Phase 5.5 Exit Criteria

- Smoke tests executed with exit code 0, OR phase skipped with justification
- If executed and failed: investigate and fix before proceeding to Tech Lead Review
- Result reported in the PR body (Smoke Tests section)
- Print: `>>> Phase 5.5/7 completed. Proceeding to Phase 6 (Tech Lead Review)...`

---

## Phase 6 — Tech Lead Review (on the PR)

**Executor:** Task tool with agent `tech-lead.md`
**Model:** Adaptive — story max task tier (from `docs/plans/STORY-NNN-tasks.md`, "Tech Lead Tier" section). If all tasks are Junior → Haiku. If any Mid task → Sonnet. If any Senior task → Opus.

### Why the Tech Lead Reviews on the PR (not before)

The PR is the consolidated, final view of the code: complete diff, grouped files, context
between changes. Issues that escape individual file reviews become visible in the
holistic PR view. Furthermore, Phase 4 fixes may introduce new problems
that would only be detected in this final review.

### Tech Lead Prompt Template

```prompt
You are the Tech Lead of the authorizer-simulator project.

STEP 1 — Read these 2 files IN PARALLEL (2 Read calls in a single message):
- .claude/agents/tech-lead.md (your complete 40-point checklist)
- .claude/rules/02-java-coding.md (your primary reference)

STEP 2 — After reading both, review the STORY-NNN PR by doing:

1. List ALL files in the PR:
   git diff main --name-only

2. View the COMPLETE PR diff (consolidated view):
   git diff main

3. For EACH .java file, read the COMPLETE content and apply the 40-point checklist.

4. Pay special attention to:
   - Issues BETWEEN files (inconsistencies, cross imports, repeated patterns)
   - Code from Phase 4 FIXES (may have introduced new issues)
   - Holistic view: does the whole thing make sense as a cohesive unit?

5. Compile and verify:
   mvn compile -Xlint:all
   mvn verify

6. Read Phase 3 reviewer reports (docs/reviews/STORY-NNN-*.md)
   to verify all CRITICAL issues were actually fixed.

Context:
- Story: docs/stories/STORY-NNN.md
- Plan: docs/plans/STORY-NNN-plan.md
- Reviews: docs/reviews/STORY-NNN-*.md
- Coverage: docs/reports/STORY-NNN-coverage.md

Decision: GO (merge) or NO-GO (list required fixes)
Save to: docs/reviews/STORY-NNN-tech-lead.md
```

### If NO-GO: Correction Cycle

```prompt
If the Tech Lead returns NO-GO:

1. Java Developer (Sonnet) fixes the issues listed by the Tech Lead
2. git add + git commit + git push (updates the existing PR, does NOT create a new one)
3. Tech Lead reviews AGAIN (only the fixed files + incremental diff)
4. Repeat until GO

Maximum 2 correction cycles. If after 2 cycles it's still NO-GO, escalate for manual review.
```

### Phase 6 Exit Criteria

- Tech Lead: GO (>= 34/40 points, zero critical)
- Review saved at `docs/reviews/STORY-NNN-tech-lead.md`
- PR approved and ready for merge
- Print: `>>> Phase 6/7 completed. Proceeding to Phase 7 (Final Verification + Cleanup)...`

**WARNING: Phase 7 (DoD + Cleanup) is still remaining. CONTINUE MANDATORILY.**

---

## Phase 7 — Final Verification + Cleanup

**MANDATORY** — Always execute at the end of the lifecycle, regardless of the outcome.
**NEVER** end the lifecycle without executing Step 7.3 (DoD Checklist — 24 checks).

### Step 7.1: Update README.md (If Needed)

**Executor:** Claude direct (no agent)
**Model:** Any

Evaluate whether the story's changes impact `README.md`. If YES, update and commit.
If NO, print `>>> README.md: no update needed` and proceed.

**Impact checklist — check if the story changed something that affects these sections:**

| README Section                          | Update Trigger                                          |
| --------------------------------------- | ------------------------------------------------------- |
| Supported MTIs                          | New MTI implemented or changed                          |
| Transaction Types / RULE-001 / RULE-002 | New business rule or change to existing ones            |
| REST API (Merchants / Terminals)        | New endpoint, request/response field, status code       |
| Key Data Elements                       | New Data Element processed by the simulator             |
| Configuration (Properties)              | New configurable property or default change             |
| Database (Key Tables / Migrations)      | New table, column, or Flyway migration                  |
| Testing (Frameworks)                    | New test framework added                                |
| Smoke Tests                             | New smoke test scenario                                 |
| Deployment (Docker / K8s)               | Changes to Dockerfiles, K8s manifests, or health checks |
| Observability                           | New metric, span, or logging change                     |
| Architecture (diagrams)                 | New adapter, port, or package structure change          |
| ADR table                               | New ADR created                                         |
| Project Status                          | Story count (automatically updated in Step 7.2)         |

**Procedure:**

1. Read `README.md` and the files modified by the story (`git diff main --name-only`)
2. Cross-reference with the table above to identify sections that need updating
3. If there are updates:
   - Edit `README.md` with the necessary changes
   - Keep Mermaid diagrams up to date (hexagonal, transaction flow, dependency rules)
   - Commit: `docs(readme): update for STORY-NNN`
   - Push: `git push`
4. If nothing changed: proceed without committing

**Rules:**

- NEVER add internal implementation details — README is for project users
- Maintain the concise and objective tone of the existing README
- Tables, Mermaid diagrams, and code examples should reflect the CURRENT state of the project
- Update story count in "Project Status" only in Step 7.2 (IMPLEMENTATION-MAP)

### Step 7.2: Update IMPLEMENTATION-MAP

**MANDATORY** — Mark the story as complete in the implementation map:

1. Open `docs/stories/IMPLEMENTATION-MAP.md`
2. In the **Dependency Matrix**, change the story's Status from `Pending` to `Done`
3. If the story doesn't exist in the matrix, add a new row in the correct position

```
| STORY-NNN | Story Title | Blocked By | Blocks | Done |
```

4. Update the count in `README.md` under the "Project Status" section (Completed / Pending)

### Step 7.3: DoD Checklist (Definition of Done)

The orchestrator checks each item and reports PASS/FAIL.

**PARALLELISM STRATEGY:** Group independent checks into parallel batches to speed up verification.

**Batch 1 — File Existence Checks (PARALLEL):**
Verify existence of ALL artifacts in ONE message (multiple simultaneous Glob/Read calls):

- `docs/plans/STORY-NNN-plan.md`
- `docs/plans/STORY-NNN-tests.md`
- `docs/plans/STORY-NNN-tasks.md`
- `docs/reviews/STORY-NNN-security.md`
- `docs/reviews/STORY-NNN-qa.md`
- `docs/reviews/STORY-NNN-performance.md`
- `docs/reviews/STORY-NNN-database.md`
- `docs/reviews/STORY-NNN-observability.md`
- `docs/reviews/STORY-NNN-devops.md`
- `docs/reviews/STORY-NNN-tech-lead.md`
- `docs/reports/STORY-NNN-coverage.md`

**Batch 2 — Git + PR Checks (PARALLEL):**
Execute in ONE message (multiple simultaneous Bash calls):

- `git branch --list 'feat/STORY-NNN*'`
- `git log main..HEAD --oneline`
- `gh pr list --head feat/STORY-NNN`
- `gh pr view`

**Batch 3 — Build Checks (SEQUENTIAL, depends on compilation):**

- `mvn compile -Xlint:all` -> verify ZERO warnings
- `mvn verify` -> verify ZERO failures
- Parse `target/site/jacoco/jacoco.xml` -> verify thresholds

#### Phase Execution Checks (CRITICAL)

| #   | Check                   | Verification                                                           |
| --- | ----------------------- | ---------------------------------------------------------------------- |
| 1   | Phase 0 — Branch        | Branch `feat/STORY-NNN` exists (`git branch --list 'feat/STORY-NNN*'`) |
| 2   | Phase 1 — Plan          | `docs/plans/STORY-NNN-plan.md` exists                                  |
| 3   | Phase 1B — Tests        | `docs/plans/STORY-NNN-tests.md` exists                                 |
| 4   | Phase 1C — Tasks        | `docs/plans/STORY-NNN-tasks.md` exists                                 |
| 5   | Phase 2 — Commits       | `git log main..HEAD --oneline` shows story commits                     |
| 6   | Phase 3 — Security      | `docs/reviews/STORY-NNN-security.md` exists                            |
| 7   | Phase 3 — QA            | `docs/reviews/STORY-NNN-qa.md` exists                                  |
| 8   | Phase 3 — Performance   | `docs/reviews/STORY-NNN-performance.md` exists                         |
| 9   | Phase 3 — Database      | `docs/reviews/STORY-NNN-database.md` exists                            |
| 10  | Phase 3 — Observability | `docs/reviews/STORY-NNN-observability.md` exists                       |
| 11  | Phase 3 — DevOps        | `docs/reviews/STORY-NNN-devops.md` exists                              |
| 12  | Phase 4 — Feedback      | `docs/common-mistakes.md` updated (check timestamp or git log)         |
| 13  | Phase 5 — PR            | PR exists (`gh pr list --head feat/STORY-NNN`)                         |
| 14  | Phase 6 — Tech Lead     | `docs/reviews/STORY-NNN-tech-lead.md` exists with GO                   |

#### Quality Gate Checks (CRITICAL)

| #   | Check           | Verification                                          |
| --- | --------------- | ----------------------------------------------------- |
| 15  | Compilation     | `mvn compile -Xlint:all` -> ZERO warnings             |
| 16  | Tests           | `mvn verify` -> ZERO failures                         |
| 17  | Line coverage   | JaCoCo >= 95% (parse `target/site/jacoco/jacoco.xml`) |
| 18  | Branch coverage | JaCoCo >= 90% (parse `target/site/jacoco/jacoco.xml`) |

#### Git & PR Checks (CRITICAL)

| #   | Check                | Verification                                                       |
| --- | -------------------- | ------------------------------------------------------------------ |
| 19  | Push                 | `git remote show origin` confirms tracking configured              |
| 20  | PR URL               | `gh pr view` returns URL                                           |
| 21  | Conventional Commits | `git log main..HEAD --oneline` follows `type(scope): desc` pattern |

#### Artifact Checks (MEDIUM)

| #   | Check              | Verification                                                      |
| --- | ------------------ | ----------------------------------------------------------------- |
| 22  | Coverage report    | `docs/reports/STORY-NNN-coverage.md` exists                       |
| 23  | IMPLEMENTATION-MAP | STORY-NNN marked as Done in `docs/stories/IMPLEMENTATION-MAP.md`  |
| 24  | README updated     | `README.md` reflects current project state (verified in Step 7.1) |

### Step 7.4: Report Result

Print report in the format:

```
============================================================
 DEFINITION OF DONE — STORY-NNN
============================================================
 PHASE CHECKS     [14/14 PASS]
 QUALITY GATES    [4/4 PASS]
 GIT & PR         [3/3 PASS]
 ARTIFACTS        [3/3 PASS]
------------------------------------------------------------
 TOTAL            [24/24 PASS]
 RESULT: COMPLETE
============================================================
 PR: https://github.com/org/repo/pull/NNN
 Tech Lead: GO (XX/40)
 Coverage: XX.X% line / XX.X% branch
 Commits: N (Conventional Commits)
------------------------------------------------------------
 SPECIALIST REVIEWS:
  Security      XX/20  Approved
  QA            XX/24  Approved
  Performance   XX/26  Adequate   (N issues)
  Database      XX/16  Approved
  Observability XX/18  Needs Work (N issues)
  DevOps        XX/20  Approved
  TOTAL         XXX/YYY (XX%)
  Issues: N CRITICAL | N MEDIUM | N LOW
============================================================
```

If any CRITICAL check fails -> `RESULT: INCOMPLETE` with action items listing what needs to be fixed.

### Step 7.5: Cleanup

```bash
git checkout main
git pull origin main
```

Confirm:

```bash
git branch --show-current
# Should print: main
```

### Step 7.6: Final Lifecycle Output

**This is the ONLY legitimate final output.** Print AFTER the DoD:

```prompt
Feature Lifecycle Complete — STORY-NNN

PR: https://github.com/org/repo/pull/NNN
Branch: feat/STORY-NNN-description
Tests: XX passing, 0 failing, 0 errors
Tech Lead: GO (XX/40)

Coverage Report:
+--------------------------+-------+--------+
|          Class           | Line  | Branch |
+--------------------------+-------+--------+
| ClassA                   | XX.X% | XX.X%  |
+--------------------------+-------+--------+
| ClassB                   | XX.X% | XX.X%  |
+--------------------------+-------+--------+
| ClassC                   | XX.X% | -      |
+--------------------------+-------+--------+
Global: XX% line / XX% branch

Specialist Reviews (Phase 3):
- Security: XX/20
- QA: XX/24
- Performance: XX/26
- Database: XX/16
- Observability: XX/18
- DevOps: XX/20
- API Design: XX/16

Tech Lead Review (Phase 6): XX/40 — GO

Total review points: XXX/180 (XX%)

DoD: 24/24 PASS
IMPLEMENTATION-MAP: STORY-NNN -> Done

Story STORY-NNN completed.
Current branch: main (clean for next story)
PR: https://github.com/org/repo/pull/NNN — awaiting merge
```

**END OF LIFECYCLE. Only HERE may the agent stop.**

**NEVER** end the lifecycle without executing Step 7.3.
