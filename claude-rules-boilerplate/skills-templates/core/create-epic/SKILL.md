---
name: create-epic
description: >
  Generate an Epic document from a system specification file. This skill reads a technical spec
  (following the _TEMPLATE.md format) and produces an Epic file with cross-cutting business rules,
  global quality definitions (DoR/DoD), and a complete story index with dependency declarations.
  Use this skill whenever the user asks to create an epic, generate an epic from a spec, extract
  business rules from a system document, decompose a specification into an epic, build a story index,
  or any variation of "read this spec and create an epic". Also trigger when the user mentions
  extracting cross-cutting rules, defining quality gates for a project, or building a story backlog
  from a technical document — even if they don't use the word "epic" explicitly.
---

# Create Epic from System Specification

This skill reads a system specification document and generates an Epic file — the top-level
artifact that defines the scope, cross-cutting rules, quality criteria, and story index for
a development effort.

## Why This Matters

The Epic is the single source of truth for a decomposition. It captures rules that span multiple
stories (so they don't get duplicated or contradicted), defines quality gates that every story
must meet, and provides the complete story index with dependency relationships. Getting the Epic
right makes story generation and implementation planning straightforward.

## Prerequisites

Read the following files before starting:

**Template (output structure):**
- `.claude/templates/_TEMPLATE-EPIC.md` — The exact structure to follow

**Decomposition philosophy (how to identify stories and rules):**
- `.claude/skills/create-epic-and-story/references/decomposition-guide.md`

If any template file is missing, stop and tell the user. The templates define the output structure
and must be read fresh from disk every time (never hardcode the structure).

## Workflow

### Step 1: Read the Input Spec

Read the entire system specification file provided by the user. This file follows the `_TEMPLATE.md`
format with sections like Overview, Business Rules, Platform Specs, Data Contracts, Journeys,
Sync Journeys, Dependencies, and Interfaces.

Understand the full scope before starting extraction.

### Step 2: Extract Cross-Cutting Business Rules

Scan the spec for business rules that apply to more than one journey or operation. These become
the Epic's Rules table with unique IDs (RULE-001, RULE-002, ...).

**What qualifies as a cross-cutting rule:**
- A decision logic that affects multiple journeys (e.g., "cents-based approval applies to all transaction types")
- A platform-wide constraint (e.g., "idempotency key required on all mutations")
- A behavioral policy (e.g., "timeout handling: N seconds sleep before response")
- A validation that gates multiple operations (e.g., "entity must be active for any operation")

**What stays in individual stories:**
- Rules that apply to only one journey (e.g., "bulk import only allowed via async endpoint")
- Implementation details specific to one handler

Each rule gets a description detailed enough that a developer can implement it without going
back to the spec. Use `<br>` for line breaks within table cells. Include priority/precedence
when rules can conflict.

### Step 3: Identify Stories

Read the decomposition guide (`create-epic-and-story/references/decomposition-guide.md`) for
the layer-by-layer approach. In summary:

1. **Foundation (Layer 0):** Infrastructure stories — servers, schemas, base APIs, protocol adapters
2. **Core Domain (Layer 1):** The central operation that establishes architectural patterns
3. **Extensions (Layer 2):** Additional operations reusing core patterns
4. **Compositions (Layer 3):** Stories combining multiple extension capabilities
5. **Cross-Cutting (Layer 4):** Testing, observability, security, tech debt

For each story, determine:
- **Title**: Concise, action-oriented (e.g., "Infraestrutura Socket e Echo Test (1804)")
- **Blocked By**: Which stories must be done first (structural, data, or pattern dependencies)
- **Blocks**: Which stories depend on this one

Validate the dependency graph: no circular dependencies, every extension depends on the core,
compositions depend on their constituent extensions.

### Step 4: Define Quality Criteria

**Global Definition of Ready (DoR):**
Extract from the spec's quality requirements, or derive sensible defaults:
- Technical specifications validated
- Dependencies resolved
- Data contracts reviewed

**Global Definition of Done (DoD):**
Extract from the spec, or derive from the tech stack:
- Coverage targets (line, branch)
- Required test types (unit, integration, E2E)
- Documentation requirements
- Performance SLOs
- Persistence/data integrity criteria

### Step 5: Generate the Epic File

Write the Epic following the `_TEMPLATE-EPIC.md` structure exactly:

1. **Header**: Title, author, date, version, status
2. **Section 1 — Visão Geral**: Scope derived from the spec's Overview section
3. **Section 2 — Anexos e Referências**: Links to the input spec and related documents
4. **Section 3 — Definições de Qualidade Globais**: DoR and DoD from Step 4
5. **Section 4 — Regras de Negócio Transversais**: Rules table from Step 2
6. **Section 5 — Índice de Histórias**: Story index from Step 3, with links and dependencies

**File naming**: `EPIC-NNN.md` where NNN is sequential. Ask the user if unsure.

### Step 6: Save and Report

Save the file to the same directory as the input spec (or where the user specifies).
Report: number of rules extracted, number of stories identified, dependency structure summary.

## Language Rules

- All generated content must be in **Brazilian Portuguese (pt-BR)**
- Technical terms that are industry-standard in English stay in English (cache, timeout, circuit breaker, handler, endpoint, state machine)
- Code identifiers, field names, enum values stay in English
- Rule IDs use the format RULE-NNN (English)
- Story IDs use the format STORY-NNN (English)

## Common Mistakes

- **Missing rules**: If a validation appears in 3+ journeys, it's cross-cutting — extract it
- **Rules too vague**: "Validar entidade" is useless. "Entidade deve estar ativa (status=ACTIVE) no cache L1/L2 → DB. Se inativa, retornar 400 ENTITY_INACTIVE" is useful
- **Dependency gaps**: If Story B uses a table created by Story A, declare the dependency
- **Circular dependencies**: If A blocks B and B blocks A, they're probably one story
- **Story count too low**: A spec with 8 journeys typically generates 12-20 stories (infrastructure + journeys + cross-cutting). If you have fewer than 8 stories, you're probably bundling too much
