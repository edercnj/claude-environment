# Story Decomposition Guide

This guide explains how to break a system specification into implementable stories. The goal is to produce stories that are independently implementable, testable, and correctly ordered by dependencies.

## Table of Contents

1. [Decomposition Philosophy](#decomposition-philosophy)
2. [Layer-by-Layer Approach](#layer-by-layer-approach)
3. [Identifying Story Boundaries](#identifying-story-boundaries)
4. [Dependency Mapping](#dependency-mapping)
5. [Phase Computation](#phase-computation)
6. [Rule Extraction](#rule-extraction)
7. [Sizing and Granularity](#sizing-and-granularity)
8. [Worked Example](#worked-example)

---

## Decomposition Philosophy

A system spec describes **what** a service does. Stories describe **how to build it** in increments. The decomposition must respect two constraints:

1. **Each story delivers a testable capability.** After implementing a story, you can write a test that exercises the new capability end-to-end. If you can't, the story is either too abstract (missing implementation detail) or too coupled (depends on another unfinished story).

2. **Dependencies form a DAG (directed acyclic graph).** No circular dependencies. The graph flows from infrastructure to domain to extensions to compositions.

## Layer-by-Layer Approach

Decompose the spec into five layers. Each layer maps to one or more phases in the Implementation Map.

### Layer 0: Foundation

Stories that build infrastructure other stories depend on. Look at the spec's **Stack**, **Data Model**, and **Interfaces** sections.

Typical foundation stories:
- Server/runtime setup (project structure, framework bootstrap, protocol listeners)
- Database schema and migrations (tables, constraints, indexes)
- Base API skeleton (CRUD for configuration entities referenced by the domain)
- External adapter setup (third-party connectors, message broker consumers, protocol adapters)
- Testing infrastructure (test client, fixtures, container setup)

**Signal**: If the spec has a "Stack" table, each row is a candidate for a foundation story. If the spec has CRUD endpoints for configuration entities, those are foundation stories.

### Layer 1: Core Domain

The single most important story that establishes the architectural patterns all other stories reuse. This is the "Marco de Validação Arquitetural" (architectural validation milestone).

Look at the spec's **Journeys** section. The core story is usually:
- The simplest complete journey (fewest edge cases, minimal conditional logic)
- The one that most other journeys depend on
- The one that establishes the processing pipeline (receive → validate → process → persist → respond)

**This story should implement:**
- The decision/routing engine (even if simple at first)
- The persistence pipeline
- The handler/processor pattern (so extensions plug in cleanly)
- The error handling strategy
- The base test patterns

**Signal**: The story that blocks the most other stories is the core story. If a spec has 12 journeys and one blocks 6 others, that's the core.

### Layer 2: Extensions

Stories that add new capabilities by extending patterns established in Layer 1. Each extension is a new journey, operation type, or processing variant.

Look at the spec's **Journeys** section. Each journey that isn't the core gets its own story (or sometimes a group if they're very similar and always ship together).

**Signal**: Independent journeys = independent stories. If two journeys share an endpoint but have different business rules, they're separate stories.

### Layer 3: Compositions

Stories that combine capabilities from multiple Layer 2 stories. These have dependencies on **multiple** extension stories.

**Signal**: A journey that references two or more other journeys' capabilities. For example, a flow that requires both "scheduling" and "notification" to work together.

### Layer 4: Cross-Cutting

Stories that don't deliver business features but improve quality, observability, or operability.

Typical cross-cutting stories:
- Smoke tests / integration test suites
- Observability (OpenTelemetry spans, custom metrics, dashboards)
- Security hardening (mTLS, RBAC, audit)
- Infrastructure (Docker, K8s manifests, CI/CD)
- Tech debt (refactoring, code cleanup, DRY violations)
- Performance (backpressure, connection pooling, batch processing)

**Signal**: These often emerge from the spec's **Metrics**, **Dependencies**, and **Platform Specs** sections. Also look for quality requirements in the DoD that imply dedicated work (e.g., "95% coverage" might need a dedicated testing story).

## Identifying Story Boundaries

Use these heuristics to decide where one story ends and another begins:

### One endpoint = one story (usually)
If the spec defines separate endpoints for distinct operations with different rules, they're separate stories.

### One protocol flow = one story
If a journey involves a specific message type or protocol exchange pattern, it's a story.

### One state transition = one story (sometimes)
If the spec defines a state machine with transitions that each have their own endpoint or trigger, each distinct transition is a story candidate.

### Shared infrastructure = foundation story
If multiple journeys need the same infrastructure (e.g., a lookup table, a routing engine, a connection pool), that infrastructure is a foundation story that blocks the journeys.

### Variations on a theme = separate stories
Similar operations might look alike, but if they have different validation rules, different data mappings, and different error scenarios, they're separate stories. The implementation reuses patterns from the core story, but the business logic is distinct.

## Dependency Mapping

For each story, ask: **"What must exist before a developer can start this story?"**

### Types of dependencies:

1. **Structural**: Story B uses a class/interface/table created by Story A. Example: a handler depends on the server setup because the handler needs the router to register with.

2. **Data**: Story B needs data produced by Story A. Example: a domain operation depends on configuration CRUD because the operation needs entity configuration to function.

3. **Pattern**: Story B reuses an architectural pattern established by Story A. Example: the second operation type depends on the first because the first establishes the handler interface and processing engine that the second extends.

### Dependency rules:

- All Layer 2 stories depend on the Layer 1 core story.
- Layer 3 stories depend on the specific Layer 2 stories they compose.
- Layer 0 stories typically have no dependencies (they're roots).
- Layer 4 stories may depend on any layer, depending on what they test/observe.
- If a dependency is optional (the story can be implemented with a mock), it's a **soft** dependency. Only declare **hard** dependencies in the story's Blocked By.

## Phase Computation

Phases are computed from the dependency graph:

1. **Phase 0**: All stories with no dependencies (roots of the DAG).
2. **Phase 1**: All stories whose dependencies are all in Phase 0.
3. **Phase N**: All stories whose dependencies are all in Phase 0..N-1.

Within each phase, stories can be implemented in parallel.

The **critical path** is the longest chain from any root to any leaf. Count the phases, not the stories. The critical path determines the minimum calendar time for the project.

## Rule Extraction

Cross-cutting business rules go into the Epic's Rules table. A rule is cross-cutting if:

- It applies to more than one journey (e.g., "idempotency key required on all mutations")
- It's a platform-wide constraint (e.g., "all monetary values stored in cents")
- It's a behavioral policy (e.g., "timeout handling: configurable per operation type")

Each rule gets a unique ID (RULE-001, RULE-002, ...) and is referenced in stories by that ID. This creates a single source of truth — if a rule changes, you update it in one place.

Rules that apply to only one journey stay in that journey's story, not in the Epic's rules table.

## Sizing and Granularity

A well-sized story takes **1-3 sprints** for one developer. Use these signals:

**Too big** (split it):
- More than 2 endpoints
- More than 1 protocol flow
- More than 8 Gherkin scenarios
- More than 10 sub-tasks
- "And" in the title (e.g., "Operation X AND Operation Y")

**Too small** (merge it):
- No testable endpoint or flow
- Less than 2 Gherkin scenarios
- Could be a sub-task of another story
- "Helper" or "Utility" in the title

**Just right**:
- One clear capability
- 4-8 Gherkin scenarios covering happy path + errors
- 4-8 sub-tasks
- Produces testable artifacts (endpoint, handler, migration)

## Worked Example

Given a hypothetical spec for any service with multiple operations, here's how the decomposition would look:

**Assume a spec describes:**
- A server that exposes an API (REST, gRPC, TCP, or any protocol)
- CRUD endpoints for configuration entities
- 6 distinct operation types with variations
- Reversal/cancellation/undo operations for some of them
- A lookup/rules engine shared across operations
- Event publishing to an external broker
- A contingency/fallback mode

**Decomposition:**

| Layer | Stories | Rationale |
| :--- | :--- | :--- |
| 0 (Foundation) | Server bootstrap + connectivity test, Configuration entity CRUD API | Infrastructure everything else builds on |
| 1 (Core) | Simplest operation type (establishes pipeline) | Builds processing engine, handler pattern, persistence, routing |
| 2 (Extensions) | Each remaining operation type, reversal, cancellation, undo | Each adds a new flow using patterns from the core |
| 3 (Compositions) | Flows that combine 2+ extension capabilities | Combine capabilities requiring multiple extension stories |
| 4 (Cross-cutting) | Integration tests, observability instrumentation, containerization, tech debt | Quality and operational stories |

**Dependency graph highlights:**
- Foundation stories are parallel roots → Phase 0
- Core story depends on all foundation stories → Phase 1, sole story, biggest bottleneck
- Extension stories depend on the core → Phase 2, maximum parallelism
- Composition stories depend on specific Phase 2 pairs → Phase 3
- Cross-cutting stories can start whenever their minimal deps are met → transversal

This decomposition typically produces ~15-20 stories across 4 phases, with a critical path of 4-5 stories. The exact numbers depend on the spec's complexity and how many distinct operation types it defines.
