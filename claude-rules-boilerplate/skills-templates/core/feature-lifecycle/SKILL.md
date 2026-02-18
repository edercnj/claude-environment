---
name: feature-lifecycle
description: "Orchestrates the complete feature implementation cycle: branch creation, planning, task decomposition, implementation, parallel review, fixes, PR creation, and final verification. Use for any full story/feature implementation."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Skill
argument-hint: "[STORY-ID or feature-name]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Feature Lifecycle

## Description

Orchestrates the complete implementation cycle of a story/feature, from planning through PR, with specialized roles and parallelized reviews. This is the top-level orchestrator that coordinates all other skills.

## When to Use

- Full story/feature implementation with review cycle
- Any request for "implement and review", "full lifecycle", or "complete implementation"
- When the user wants the end-to-end development workflow

## Roles and Models (Adaptive)

| Role              | Phase                   | Tier Assignment                          |
| ----------------- | ----------------------- | ---------------------------------------- |
| Architect         | Phase 1 (Planning)      | Senior                                   |
| Task Decomposer   | Phase 1C (Decomposition)| Mid                                      |
| Developer (Junior) | Phase 2 (Simple tasks) | Junior (from Layer Task Catalog)         |
| Developer (Mid)   | Phase 2 (Mid tasks)     | Mid (from Layer Task Catalog)            |
| Developer (Senior)| Phase 2 (Complex tasks) | Senior (from Layer Task Catalog)         |
| Specialist Review | Phase 3 (Review)        | Adaptive (max task tier in domain)       |
| Tech Lead         | Phase 6 (PR Review)     | Adaptive (story max tier)                |

## CRITICAL EXECUTION RULE

**The lifecycle has 8 phases (0 through 7). ALL are mandatory. NEVER stop before Phase 7.**

After EACH phase, print progress and CONTINUE to the next:

```
>>> Phase N/7 completed. Proceeding to Phase N+1...
```

---

## Complete Flow

```
Phase 0: Preparation (read context, create branch)
    |
Phase 1: Planning (Architect produces implementation plan)
    |
Phase 1B: Test Planning (test scenarios before code)
    |
Phase 1C: Task Decomposition (apply Layer Task Catalog)
    |
Phase 2: Group-Based Implementation (G1-G7 with group-verifier gates)
    |   G1: Foundation (Migration + Domain Models)
    |   G2: Contracts (Ports + DTOs + Engine)
    |   G3: Outbound Adapters (Entity + Mapper + Repository)
    |   G4: Orchestration (Use Case)
    |   G5: Inbound Adapters (REST + TCP + Config)
    |   G6: Observability
    |   G7: Tests
    |
Phase 3: Parallel Review (7+ specialist reviewers)
    |
Phase 4: Fixes + Feedback Loop
    |
Phase 5: Commit & PR
    |
Phase 6: Tech Lead Review (40-point checklist, GO/NO-GO)
    |
Phase 7: Final Verification + Cleanup (DoD checklist)
```

---

## Phase 0 -- Preparation

1. Read story file, project rules, and relevant context IN PARALLEL
2. Verify dependencies (predecessor stories complete)
3. Create branch: `git checkout -b feat/STORY-ID-description`

## Phase 1 -- Planning

1. Architect reads story + rules + ADRs
2. Produces implementation plan saved to `docs/plans/STORY-ID-plan.md`
3. If DB involved: Database Engineer produces schema design

## Phase 1B -- Test Planning

Invoke skill `plan-tests` to produce `docs/plans/STORY-ID-tests.md`.

## Phase 1C -- Task Decomposition

Invoke skill `task-decomposer` to produce `docs/plans/STORY-ID-tasks.md`.

## Phase 2 -- Group-Based Implementation

For each group G1 through G7:

1. Launch all tasks in the group IN PARALLEL (model per Layer Task Catalog)
2. Run group-verifier: `{{COMPILE_COMMAND}}` (or `{{BUILD_COMMAND}}` for G7)
3. If PASS: commit group, extract outputs, proceed to next group
4. If FAIL: classify errors, retry/escalate per group-verifier rules

After G7, generate coverage report from `{{COVERAGE_COMMAND}}`.

## Phase 3 -- Parallel Review

Launch ALL specialist reviewers IN PARALLEL (one message, multiple Task calls):

| Reviewer      | Focus Area                                  |
| ------------- | ------------------------------------------- |
| Security      | Sensitive data, validation, fail-secure      |
| QA            | Test coverage, quality, scenarios            |
| Performance   | Latency, concurrency, resource usage         |
| Database      | Schema, migrations, indexes, queries         |
| Observability | Spans, metrics, logging, health checks       |
| DevOps        | Docker, K8S, config, deployment              |
| API Design    | REST design, contracts (if REST involved)    |

Consolidate results into scores table with severity classification.

## Phase 4 -- Fixes + Feedback

1. Fix CRITICAL issues from reviewers
2. Run `{{COMPILE_COMMAND}}` + `{{TEST_COMMAND}}`
3. Update common-mistakes document with newly found errors

## Phase 5 -- Commit & PR

1. Push: `git push -u origin feat/STORY-ID-description`
2. Create PR via `gh pr create` with review summary in body

## Phase 6 -- Tech Lead Review

Invoke skill `review-pr` for holistic 40-point review. If NO-GO, fix and re-review (max 2 cycles).

## Phase 7 -- Final Verification + Cleanup

1. Update README if needed
2. Update IMPLEMENTATION-MAP
3. Run DoD checklist (24 checks across phases, quality, git, artifacts)
4. Report PASS/FAIL result
5. `git checkout main && git pull origin main`

**Phase 7 is the ONLY legitimate stopping point.**

## Integration Notes

- Invokes: `plan-tests`, `task-decomposer`, `group-verifier`, `commit-and-push`, `review`, `review-pr`
- Produces: plan, test plan, task breakdown, review reports, coverage report, PR
- All placeholders (`{{BUILD_COMMAND}}`, `{{TEST_COMMAND}}`, `{{COMPILE_COMMAND}}`, `{{COVERAGE_COMMAND}}`) must be resolved from project configuration
