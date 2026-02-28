---
name: feature-lifecycle
description: "Orchestrates the complete feature implementation cycle: branch creation, planning, task decomposition, implementation, parallel review, fixes, PR creation, and final verification. Delegates heavy phases to subagents for context efficiency."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Skill
argument-hint: "[STORY-ID or feature-name]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Feature Lifecycle (Orchestrator)

## When to Use

- Full story/feature implementation with review cycle
- End-to-end development workflow (plan → code → review → PR)

## CRITICAL EXECUTION RULE

**8 phases (0-7). ALL mandatory. NEVER stop before Phase 7.**

After EACH phase: `>>> Phase N/7 completed. Proceeding to Phase N+1...`

## Complete Flow

```
Phase 0: Preparation          (orchestrator — inline)
Phase 1: Planning              (subagent — reads architecture KPs)
Phase 1B-1E: Parallel Planning (up to 4 subagents — SINGLE message)
Phase 2: Implementation        (subagent — reads coding + layer KPs)
Phase 3: Review                (invoke /review skill — launches its own subagents)
Phase 4-5: Fixes + PR          (orchestrator — inline)
Phase 6: Tech Lead Review      (invoke /review-pr skill)
Phase 7: Verification          (orchestrator — inline)
```

---

## Phase 0 — Preparation (Orchestrator — Inline)

1. Read story file and extract acceptance criteria, sub-tasks, dependencies
2. Verify dependencies (predecessor stories complete)
3. Create branch: `git checkout -b feat/STORY-ID-description`

## Phase 1 — Architecture Planning (Subagent via Task)

Launch a **single** `general-purpose` subagent:

> You are a **Senior Architect** planning feature implementation for {{PROJECT_NAME}}.
>
> **Step 1 — Read context:**
> - Read story file: `{STORY_PATH}`
> - Read `skills/architecture/references/architecture-principles.md` — layer structure, dependency direction
> - Read `skills/layer-templates/SKILL.md` — code templates per architecture layer
> - Read any relevant ADRs in `docs/adr/`
>
> **Step 2 — Produce implementation plan** with these sections:
> 1. Affected layers and components
> 2. New classes/interfaces to create (with package locations)
> 3. Existing classes to modify
> 4. Dependency direction validation
> 5. Integration points
> 6. Database changes (if applicable)
> 7. API changes (if applicable)
> 8. Event changes (if applicable)
> 9. Configuration changes
> 10. Risk assessment
>
> Save to `docs/plans/STORY-ID-plan.md`.

## Phases 1B-1E — Parallel Planning (Subagents via Task — SINGLE message)

**CRITICAL: ALL planning subagents MUST be launched in a SINGLE message.**

### 1B: Test Planning
Invoke skill `plan-tests` → produces `docs/plans/STORY-ID-tests.md`

### 1C: Task Decomposition
Invoke skill `task-decomposer` → produces `docs/plans/STORY-ID-tasks.md`

### 1D: Event Schema Design (if event_driven)
Launch `general-purpose` subagent:

> You are an **Event Engineer** designing event schemas.
> Read `skills/protocols/references/event-driven-conventions.md` for standards.
> Read the implementation plan at `docs/plans/STORY-ID-plan.md`.
> Produce event schema design: event names (past tense), CloudEvents envelope, topic naming, partition key, producer/consumer contracts.
> Save to `docs/plans/STORY-ID-events.md`.

### 1E: Compliance Assessment (if compliance active)
Launch `general-purpose` subagent:

> You are a **Security Engineer** assessing compliance impact.
> Read `skills/security/SKILL.md` → then read its references.
> Read `skills/compliance/SKILL.md` → then read its references.
> Read the implementation plan at `docs/plans/STORY-ID-plan.md`.
> Produce compliance impact assessment: data classification, encryption requirements, audit logging needs, regulatory considerations.
> Save to `docs/plans/STORY-ID-compliance.md`.

## Phase 2 — Group-Based Implementation (Subagent via Task)

Launch a **single** `general-purpose` subagent for implementation:

> You are a **Developer** implementing story {STORY_ID} for {{PROJECT_NAME}}.
>
> **Step 1 — Read context:**
> - Read implementation plan: `docs/plans/STORY-ID-plan.md`
> - Read task breakdown: `docs/plans/STORY-ID-tasks.md`
> - Read `skills/coding-standards/references/coding-conventions.md` — {{LANGUAGE}} conventions
> - Read `skills/coding-standards/references/version-features.md` — {{LANGUAGE}} {{LANGUAGE_VERSION}} features
> - Read `skills/layer-templates/SKILL.md` — code templates per layer
> - Read `skills/architecture/references/architecture-principles.md` — layer boundaries
>
> **Step 2 — Implement groups G1-G7** following the task breakdown:
> - For each group: implement all tasks, then compile: `{{COMPILE_COMMAND}}`
> - If compilation fails: fix errors before proceeding
> - After G7: run `{{TEST_COMMAND}}` and `{{COVERAGE_COMMAND}}`
> - Coverage targets: line ≥ 95%, branch ≥ 90%
>
> **Step 3 — Commit each group** atomically following git conventions.
>
> Report: groups completed, tests passed/failed, coverage numbers.

## Phase 3 — Parallel Review

Invoke skill `/review` for the current story. The review skill launches its own parallel subagents (one per specialist engineer), each reading their own knowledge pack.

Collect the consolidated review report with scores and severity counts.

## Phase 4 — Fixes + Feedback (Orchestrator — Inline)

1. Fix CRITICAL issues from Phase 3 review
2. Run `{{COMPILE_COMMAND}}` + `{{TEST_COMMAND}}`
3. Update common-mistakes document with newly found errors

## Phase 5 — Commit & PR (Orchestrator — Inline)

1. Push: `git push -u origin feat/STORY-ID-description`
2. Create PR via `gh pr create` with review summary in body

## Phase 6 — Tech Lead Review

Invoke skill `review-pr` for holistic 40-point review. If NO-GO, fix and re-review (max 2 cycles).

## Phase 7 — Final Verification + Cleanup (Orchestrator — Inline)

1. Update README if needed
2. Update IMPLEMENTATION-MAP
3. Run DoD checklist (24+ checks across phases, quality, git, artifacts)
4. Conditional DoD items:
   - Contract tests pass (if testing.contract_tests == true)
   - Event schemas registered (if event_driven)
   - Compliance requirements met (if security.compliance active)
   - Gateway configuration updated (if api_gateway != none)
   - gRPC proto backward compatible (if interfaces contain grpc)
   - GraphQL schema backward compatible (if interfaces contain graphql)
5. Report PASS/FAIL result
6. `git checkout main && git pull origin main`

**Phase 7 is the ONLY legitimate stopping point.**

## Roles and Models (Adaptive)

| Role | Phase | Tier |
|------|-------|------|
| Architect | Phase 1 | Senior |
| Task Decomposer | Phase 1C | Mid |
| Developer | Phase 2 | Adaptive (per Layer Task Catalog) |
| Specialist Reviews | Phase 3 | Adaptive (max task tier in domain) |
| Tech Lead | Phase 6 | Adaptive (story max tier) |

## Integration Notes

- Invokes: `plan-tests`, `task-decomposer`, `group-verifier`, `commit-and-push`, `review`, `review-pr`
- All placeholders (`{{BUILD_COMMAND}}`, `{{TEST_COMMAND}}`, etc.) resolved from project configuration
