---
name: task-decomposer
description: "Layer-based task decomposition for the feature lifecycle. Reads the Architect's plan and applies a fixed Layer Task Catalog to produce granular implementation tasks with model tier, context budget, and parallelism groups."
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.

# Skill: Task Decomposer (Layer-Based)

## Purpose

Decomposes an Architect's implementation plan into granular, single-layer tasks using a **fixed Layer Task Catalog**. Each task is assigned a model tier (Haiku/Sonnet/Opus), context budget, and parallelism group based on its hexagonal layer — not dynamic scoring.

## When to Use

- **Feature Lifecycle Phase 1C**: After the Architect produces the plan, BEFORE implementation
- **Standalone**: When you need to break down a plan into implementable tasks

## Inputs Required

1. `docs/plans/STORY-NNN-plan.md` — Architect's design (Sections 1-9)
2. `stories/STORY-NNN.md` — Story requirements

## Procedure

### STEP 1 — Read Context

Read these files:
- `docs/plans/STORY-NNN-plan.md` (Architect's plan — Sections 1-9)
- `stories/STORY-NNN.md` (story requirements)

### STEP 2 — Identify Affected Layers

For each section in the Architect's plan, check which hexagonal layers are involved. Mark each layer as active or inactive.

### STEP 3 — Apply the Layer Task Catalog

For each active layer, create ONE task using the fixed catalog below. Assign tier, model, budget, and group.

### STEP 4 — Variable Tier Decision (Domain Engine Only)

For Domain Engine tasks, read the Architect's plan Section 2 carefully:
- **Simple mapping/lookup** (1 decision, no state) → Sonnet
- **Multi-branch logic** (sealed interfaces 3+ impls, resilience patterns) → Opus

### STEP 5 — Generate Output

Save to: `docs/plans/STORY-NNN-tasks.md` using the template in `references/task-template.md`.

---

## Layer Task Catalog (Fixed)

| Task Type | Hexagonal Layer | Tier | Model | Budget | Group |
|-----------|----------------|------|-------|--------|-------|
| Flyway Migration | db/migration | Junior | Haiku | S | G1 |
| Domain Models (Records, Enums, VOs) | domain.model | Junior | Haiku | S | G1 |
| Ports (Inbound Interfaces) | domain.port.inbound | Junior | Haiku | S | G2 |
| Ports (Outbound Interfaces) | domain.port.outbound | Junior | Haiku | S | G2 |
| DTOs (Request/Response) | adapter.inbound.rest.dto | Junior | Haiku | S | G2 |
| Domain Engine / Rules (simple) | domain.engine / domain.rule | Mid | Sonnet | M | G2 |
| Domain Engine / Rules (complex) | domain.engine / domain.rule | Senior | **Opus** | L | G2 |
| JPA Entity | adapter.outbound.persistence.entity | Junior | Haiku | S | G3 |
| Entity Mapper | adapter.outbound.persistence.mapper | Junior | Haiku | S | G3 |
| DTO Mapper (Inbound) | adapter.inbound.rest.mapper | Junior | Haiku | S | G3 |
| Repository (Panache) | adapter.outbound.persistence.repository | Mid | Sonnet | M | G3 |
| Use Case (Application) | application | Mid | Sonnet | M | G4 |
| REST Resource | adapter.inbound.rest | Mid | Sonnet | M | G5 |
| Exception Mapper / ProblemDetail | adapter.inbound.rest | Mid | Sonnet | M | G5 |
| TCP Handler | adapter.inbound.socket | Senior | **Opus** | L | G5 |
| Configuration (properties) | config | Junior | Haiku | S | G5 |
| OpenTelemetry (Spans/Metrics) | cross-cutting | Mid | Sonnet | M | G6 |
| Unit Tests (Domain) | test | Follows tested layer | Follows tested layer | Follows | G7 |
| Integration Tests (@QuarkusTest) | test | Mid | Sonnet | M | G7 |
| REST API Tests (REST Assured) | test | Mid | Sonnet | M | G7 |
| TCP Socket Tests | test | Senior | Sonnet | M | G7 |
| E2E Tests | test | Senior | Sonnet | M | G7 |

### Domain Engine Tier Decision

The Domain Engine / Rules task has two possible tiers. Choose based on complexity:

| Criteria | Tier | Model |
|----------|------|-------|
| Simple lookup/mapping logic (e.g., CentsDecisionEngine with table-driven rules) | Mid | Sonnet |
| Complex logic involving thread safety, resilience, state machines, or ISO 8583 wire format | Senior | Opus |

If unsure, default to **Sonnet (Mid)**. Escalation to Opus happens automatically via group-verifier if Sonnet fails.

### Context Budget Sizes

| Size | Token Range | What's Included |
|------|-------------|-----------------|
| S (Small) | 100-200 lines | Plan section + 7 inline rules + 1 template |
| M (Medium) | 250-400 lines | Plan section + rules files + dependency outputs |
| L (Large) | 500-800 lines | Story + plan sections + rules + dependency outputs + existing code |

---

## Layer Dependency Graph (Fixed)

```
G1: FOUNDATION
  Migration, Domain Models, Enums
  → All tasks in G1 run in PARALLEL
  → After: mvn compile

G2: CONTRACTS
  Ports (Inbound/Outbound), DTOs, Domain Engine
  → Depends on G1
  → All tasks in G2 run in PARALLEL
  → After: mvn compile

G3: OUTBOUND ADAPTERS
  JPA Entity, Entity Mapper, DTO Mapper, Repository
  → Depends on G1, G2
  → All tasks in G3 run in PARALLEL
  → After: mvn compile

G4: ORCHESTRATION
  Use Case(s)
  → Depends on G2, G3
  → Sequential (usually 1 task)
  → After: mvn compile

G5: INBOUND ADAPTERS
  REST Resource, Exception Mapper, TCP Handler, Configuration
  → Depends on G4
  → All tasks in G5 run in PARALLEL
  → After: mvn compile

G6: OBSERVABILITY
  OpenTelemetry Spans/Metrics
  → Depends on G4, G5
  → Sequential (usually 1 task)
  → After: mvn compile

G7: TESTS
  Unit, Integration, REST API, TCP Socket, E2E
  → Depends on ALL previous groups
  → All tasks in G7 run in PARALLEL (max 4 concurrent)
  → After: mvn verify
```

---

## Context Composition per Tier

### Haiku Tasks (S budget)

Include in prompt:
1. `## TEMPLATE` — Full content from `/layer-templates/references/{layer}.md`
2. `## YOUR TASK` — Files to create, fields to change
3. `## PLAN SECTION` — Only the relevant section (~30-50 lines)
4. `## CRITICAL RULES` — 7 inline rules (same as current lifecycle)

Do NOT include: full story, full rule files, dependency outputs beyond direct inputs

### Sonnet Tasks (M budget)

Include in prompt:
1. `## CRITICAL RULES` — 7 inline rules
2. `## COMMON MISTAKES` — 5 bullets from common-mistakes.md
3. `## YOUR TASK` — Files to create/modify, commit message
4. `## PLAN SECTION` — Task section + adjacent context (~80-150 lines)
5. `## DEPENDENCY OUTPUTS` — Code from dependency tasks (actual file contents)
6. `## REFERENCE RULES` — Content of 2-3 relevant rule files

### Opus Tasks (L budget)

Include in prompt:
1. `## CRITICAL RULES` — 7 inline rules
2. `## COMMON MISTAKES` — 5 bullets
3. `## STORY CONTEXT` — Full story content
4. `## ARCHITECTURAL CONTEXT` — Affected packages, patterns, ADRs
5. `## YOUR TASK` — Files to create/modify, why this is complex
6. `## PLAN SECTION` — Extended (task section + data flow + all related)
7. `## DEPENDENCY OUTPUTS` — Code from dependency tasks
8. `## REFERENCE RULES` — ALL relevant rule files (full content)
9. `## EXISTING CODE` — Similar existing implementations to study

---

## Stories That Don't Use All Layers

Not every story activates all layers. Common patterns:

| Story Type | Active Layers | Active Groups |
|------------|--------------|---------------|
| Full transaction type | ALL | G1-G7 |
| REST CRUD endpoint | DTOs, Resource, ExceptionMapper, Entity, Repository, Mappers, Migration, Tests | G1, G3, G5, G7 |
| Business rule only | Domain Engine, Use Case, Unit Tests | G2, G4, G7 |
| Infrastructure change | Config, Migration, K8S manifests | G1, G5 |
| Bug fix (single layer) | Varies (1-2 tasks) | Only affected group |

If a layer is NOT affected by the story, skip it entirely. Do NOT create empty tasks.

---

## Review Tier Assignment

When `/review` is invoked, each reviewer's model is determined by the **highest task tier** in their domain:

| Reviewer | Relevant Task Types | Model = Max Tier In Domain |
|----------|-------------------|---------------------------|
| Security | Domain Engine, TCP Handler, Repository | Max tier of those tasks |
| QA | All test tasks | Max tier of test tasks |
| Performance | Domain Engine, TCP Handler, Repository | Max tier of those tasks |
| Database | Migration, Entity, Repository | Max tier of those tasks |
| Observability | OTel task | Tier of OTel task |
| DevOps | Config task | Tier of Config task |
| API Designer | DTOs, REST Resource | Max tier of those tasks |

**Tech Lead** model = story max task tier (highest tier across ALL tasks).

---

## Escalation Rules

When a task fails compilation after 2 retries at its assigned tier:
- Haiku → Sonnet (escalate)
- Sonnet → Opus (escalate)
- Opus → Flag for manual intervention

Target: < 15% of tasks escalate. If consistently > 15%, the catalog tiers need adjustment.
