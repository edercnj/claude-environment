---
name: task-decomposer
description: "Decomposes an architect's implementation plan into parallelizable tasks by layer. Uses the Layer Task Catalog to assign model tiers, context budgets, and parallelism groups. Produces a task breakdown document."
allowed-tools: Read, Write, Grep, Glob
argument-hint: "[STORY-ID]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.

# Skill: Task Decomposer (Layer-Based)

## Purpose

Decomposes an implementation plan into granular, single-layer tasks using a **fixed Layer Task Catalog**. Each task is assigned a model tier (Junior/Mid/Senior), context budget, and parallelism group based on its architectural layer.

## When to Use

- **Feature Lifecycle Phase 1C**: After the Architect produces the plan, BEFORE implementation
- **Standalone**: When you need to break down a plan into implementable tasks

## Inputs Required

1. `docs/plans/STORY-ID-plan.md` -- Architect's design
2. Story requirements file

## Procedure

### STEP 0 -- Read Architecture Context

Before decomposing, read the project's architecture and layer definitions:
- `rules/05-architecture-principles.md` — layer structure, dependency direction, package organization
- `skills/layer-templates/SKILL.md` — complete layer catalog with package locations, code templates, and checklist per layer

These files define the available layers for YOUR project. The Layer Task Catalog below is derived from them.

### STEP 1 -- Read Story Context

Read these files:
- `docs/plans/STORY-ID-plan.md` (Architect's plan)
- Story requirements file

### STEP 2 -- Identify Affected Layers

For each section in the Architect's plan, check which architectural layers are involved. Mark each layer as active or inactive.

### STEP 3 -- Apply the Layer Task Catalog

For each active layer, create ONE task using the fixed catalog below.

### STEP 4 -- Variable Tier Decision

For complex domain logic tasks, read the Architect's plan carefully:
- **Simple mapping/lookup** (1 decision, no state) -> Mid tier
- **Multi-branch logic** (type hierarchies with 3+ implementations, resilience patterns) -> Senior tier

### STEP 5 -- Generate Output

Save to: `docs/plans/STORY-ID-tasks.md`

---

## Layer Task Catalog

Derive the task catalog from the **layer-templates knowledge pack** (`skills/layer-templates/SKILL.md`). Each section in the knowledge pack corresponds to one task type. The table below shows the **generic structure** — adapt layer names and packages to match YOUR project's architecture rules (`rules/05-architecture-principles.md`).

| Task Type                     | Architecture Layer      | Tier   | Budget | Group |
| ----------------------------- | ----------------------- | ------ | ------ | ----- |
| Database Migration            | migration               | Junior | S      | G1    |
| Domain Models                 | domain model            | Junior | S      | G1    |
| Ports (Inbound Interfaces)    | domain port inbound     | Junior | S      | G2    |
| Ports (Outbound Interfaces)   | domain port outbound    | Junior | S      | G2    |
| DTOs (Request/Response)       | inbound adapter dto     | Junior | S      | G2    |
| Domain Engine/Rules (simple)  | domain engine           | Mid    | M      | G2    |
| Domain Engine/Rules (complex) | domain engine           | Senior | L      | G2    |
| Persistence Entity            | outbound adapter entity | Junior | S      | G3    |
| Entity Mapper                 | outbound adapter mapper | Junior | S      | G3    |
| DTO Mapper (Inbound)          | inbound adapter mapper  | Junior | S      | G3    |
| Repository                    | outbound adapter repo   | Mid    | M      | G3    |
| Use Case (Application)        | application             | Mid    | M      | G4    |
| REST Resource/Controller      | inbound adapter rest    | Mid    | M      | G5    |
| Exception Mapper              | inbound adapter rest    | Mid    | M      | G5    |
| Protocol Handler              | inbound adapter protocol| Senior | L      | G5    |
| Configuration                 | config                  | Junior | S      | G5    |
| Observability (Spans/Metrics) | cross-cutting           | Mid    | M      | G6    |
| Unit Tests                    | test                    | Follows tested layer | G7 |
| Integration Tests             | test                    | Mid    | M      | G7    |
| API Tests                     | test                    | Mid    | M      | G7    |
| E2E Tests                     | test                    | Mid    | M      | G7    |

> **Note:** The exact package names (e.g., `domain.model`, `adapter.outbound.entity`) are defined in `rules/05-architecture-principles.md`. Consult that file for your project's specific package structure.

## Layer Dependency Graph

The dependency direction follows the architecture rule: `adapter.inbound → application → domain ← adapter.outbound`. Groups are derived from this dependency chain:

```
G1: FOUNDATION (Migration + Domain Models) -- PARALLEL
G2: CONTRACTS (Ports + DTOs + Engine) -- PARALLEL, depends on G1
G3: OUTBOUND ADAPTERS (Entity + Mapper + Repository) -- PARALLEL, depends on G1, G2
G4: ORCHESTRATION (Use Case) -- SEQUENTIAL, depends on G2, G3
G5: INBOUND ADAPTERS (Controllers + Protocol Handlers + Config) -- PARALLEL, depends on G4
G6: OBSERVABILITY -- SEQUENTIAL, depends on G4, G5
G7: TESTS -- PARALLEL (max 4 concurrent), depends on ALL previous
```

> **Note:** Group contents may vary by project architecture. The principle is: **inner layers first, then outer layers**. Verify against `rules/05-architecture-principles.md` for your project.

## Context Budget Sizes

| Size | Range        | Includes                                              |
| ---- | ------------ | ----------------------------------------------------- |
| S    | 100-200 lines| Plan section + inline rules + 1 template              |
| M    | 250-400 lines| Plan section + rules files + dependency outputs        |
| L    | 500-800 lines| Story + plan + rules + dependency outputs + existing code |

## Review Tier Assignment

Each engineer's model tier = highest task tier in their review domain:

| Engineer      | Relevant Task Types                    |
| ------------- | -------------------------------------- |
| Security      | Domain Engine, TCP Handler, Repository |
| QA            | All test tasks                         |
| Performance   | Domain Engine, TCP Handler, Repository |
| Database      | Migration, Entity, Repository          |
| Observability | Observability task                     |
| DevOps        | Config task                            |
| API           | DTOs, REST Resource                    |

**Tech Lead** tier = story max task tier (highest across ALL tasks).

## Escalation Rules

When a task fails compilation after 2 retries at its assigned tier:
- Junior -> Mid (escalate)
- Mid -> Senior (escalate)
- Senior -> Flag for manual intervention

Target: < 15% of tasks escalate.

## Integration Notes

- Invoked by `feature-lifecycle` during Phase 1C
- Output consumed by Phase 2 (group-based implementation)
- Works with any layered architecture (hexagonal, clean, onion) — layer names derived from project rules
