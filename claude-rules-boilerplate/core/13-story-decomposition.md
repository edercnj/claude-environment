# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 13 — Story Decomposition Principles

## Principles
Story decomposition is the bridge between system design and implementation. A well-decomposed spec produces stories that are independently implementable, testable, and correctly ordered. These rules are **mandatory** when breaking down specifications into work items.

## SD-01: Layer-by-Layer Decomposition

Every system specification MUST be decomposed following five mandatory layers:

| Layer | Name | Purpose | Signal |
|-------|------|---------|--------|
| 0 | Foundation | Infrastructure that other stories depend on | Stack rows, configuration CRUD, protocol setup |
| 1 | Core Domain | The single operation that establishes architectural patterns | Story that blocks the most others |
| 2 | Extensions | New operations reusing patterns from Layer 1 | Independent journeys in the spec |
| 3 | Compositions | Flows combining 2+ extension capabilities | Journeys referencing multiple other journeys |
| 4 | Cross-Cutting | Quality, observability, security, tech debt | Metrics, platform specs, DoD requirements |

**FORBIDDEN**: Skipping layers. A spec with 6 journeys that produces only 3 stories (one per layer 0-2) is under-decomposed.

## SD-02: Story Self-Containment

Each story MUST be implementable without consulting the original system specification. This requires:

- **Data contracts** with every field: name, type, format, mandatory/optional flag, derivation rule
- **Gherkin acceptance criteria** with concrete values (not abstractions)
- **Mermaid sequence diagrams** using real component names from the spec
- **Sub-tasks** individually estimable at 2-4 hours, tagged `[Dev]`, `[Test]`, or `[Doc]`

```
// BAD — forces developer back to the spec
"Implementar a operação principal conforme a especificação"

// GOOD — developer has everything needed
"Implementar endpoint POST /api/v1/operations"
+ Data contract table with all fields
+ 6 Gherkin scenarios (happy path + 3 errors + 2 edge cases)
+ Sequence diagram showing Client → Controller → Service → Repository → DB
+ 6 sub-tasks: [Dev] Controller, [Dev] Service, [Dev] Repository, [Dev] Migration, [Test] Unit, [Test] Integration
```

## SD-03: Dependency DAG

Story dependencies MUST form a Directed Acyclic Graph (DAG):

- **No circular dependencies**: If A → B → C → A exists, at least two of those are actually one story
- **All extensions depend on core**: Every Layer 2 story depends on the Layer 1 story
- **Bidirectional consistency**: If A's "Blocks" lists B, then B's "Blocked By" MUST list A
- **Hard dependencies only**: Soft dependencies (where a mock suffices) are NOT declared in Blocked By

**Dependency types:**

| Type | Signal | Example |
|------|--------|---------|
| Structural | Story B uses a class/table created by Story A | Handler depends on server setup |
| Data | Story B needs data produced by Story A | Operation depends on configuration CRUD |
| Pattern | Story B reuses patterns established by Story A | Second handler depends on first handler |

**FORBIDDEN**: Circular dependencies. If detected, merge the stories or redesign the boundary.

## SD-04: Cross-Cutting Rule Extraction

Business rules that appear in 2+ journeys MUST be extracted into the Epic's rules table:

- Each rule gets a unique sequential ID: `RULE-001`, `RULE-002`, ...
- Rule description must be **implementation-ready** (a developer can build it without asking questions)
- Stories reference rules by ID — creating a single source of truth

```
// BAD — too vague, developer must ask for clarification
RULE-001: "Validar entidade"

// GOOD — implementation-ready
RULE-001: "Entidade deve estar ativa (status=ACTIVE) consultando cache L1 → L2 → DB.
           Se inativa, retornar HTTP 400 com código ENTITY_INACTIVE.
           TTL do cache: 5min L1, 30min L2."
```

Rules that apply to **only one** journey stay in that journey's story, not in the Epic.

## SD-05: Story Sizing

A well-sized story is implementable by one developer in 1-3 sprints.

**MAXIMUM per story:**

| Metric | Limit | Action if exceeded |
|--------|-------|--------------------|
| Endpoints | 2 | Split into separate stories |
| Protocol flows | 1 | Split by flow type |
| Gherkin scenarios | 8 | Split by capability or error category |
| Sub-tasks | 10 | Split into smaller stories |

**MINIMUM per story:**

| Metric | Minimum | Action if below |
|--------|---------|-----------------|
| Testable endpoint/flow | 1 | Merge with another story |
| Gherkin scenarios | 2 | Merge — too small to be a story |

**Split signal**: "AND" in the title (e.g., "Operation X AND Operation Y").
**Merge signal**: "Helper" or "Utility" in the title — likely a sub-task, not a story.

## SD-06: Phase Computation

Implementation phases derive automatically from the dependency DAG:

1. **Phase 0**: Stories with no dependencies (DAG roots)
2. **Phase 1**: Stories whose ALL dependencies are in Phase 0
3. **Phase N**: Stories whose ALL dependencies are in Phase 0..N-1

**Rules:**
- Stories within the same phase CAN be implemented in parallel
- **Critical path** = longest chain of phases (not stories) from root to leaf
- Any delay in a critical-path story directly delays final delivery
- **Leaf stories** (no dependents) can absorb schedule variance — good for junior developers or parallel streams

## SD-07: Generated Content Language

All decomposition artifacts (Epics, Stories, Implementation Maps) follow these language rules:

| Content | Language | Example |
|---------|----------|---------|
| Artifact body text | pt-BR | "Como **Operador**, eu quero..." |
| Industry-standard terms | English | cache, handler, endpoint, timeout, state machine |
| Code identifiers and field names | English | `merchant_id`, `response_code` |
| Rule IDs | English format | RULE-001, RULE-002 |
| Story IDs | English format | STORY-001, STORY-002 |
| Epic IDs | English format | EPIC-001 |
| Gherkin keywords | Portuguese | DADO, QUANDO, ENTÃO, E, MAS |
| Mermaid node IDs and classDef | English | `S001["STORY-001<br/>Title"]` |

## SD-08: Template-Driven Generation

All artifacts MUST be generated by reading templates from `.claude/templates/` at runtime:

- `_TEMPLATE-EPIC.md` → Epic structure
- `_TEMPLATE-STORY.md` → Story structure
- `_TEMPLATE-IMPLEMENTATION-MAP.md` → Map structure

**FORBIDDEN**: Hardcoding template structure in skills or agent instructions. Templates may evolve independently — always read fresh from disk.

Reference examples set the quality bar:
- `EPIC-001.md`, `STORY-001.md`, `IMPLEMENTATION-MAP.md`

## Anti-Patterns (FORBIDDEN)

- Story that says "implement X" without a data contract → **FORBIDDEN**
- Gherkin with "um valor qualquer" instead of concrete value → **FORBIDDEN**
- Cross-cutting rule duplicated across multiple stories instead of extracted to Epic → **FORBIDDEN**
- Circular dependency between stories → **FORBIDDEN**
- Story with 2+ protocol flows → **MUST SPLIT**
- Epic without DoR/DoD → **FORBIDDEN**
- Story without Mermaid sequence diagram → **FORBIDDEN**
- Rule in Epic that applies to only one journey → **MOVE TO STORY**
- Dependency declared in one direction only (A blocks B but B doesn't list A) → **FORBIDDEN**
- Hardcoded template structure (not reading from `.claude/templates/`) → **FORBIDDEN**
