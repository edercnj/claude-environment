---
name: story-planning
description: "Story decomposition and planning: layer-by-layer decomposition (foundation, core domain, extensions, compositions, cross-cutting), story self-containment (data contracts, acceptance criteria), dependency DAG, sizing rules, and phase computation."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Story Planning

## Purpose

Provides story decomposition and planning patterns for translating system specifications into independently implementable work items. Enables layered decomposition, dependency management, sizing consistency, and phased delivery planning. Ensures each story is self-contained with all required context, making it actionable without constant specification reference.

## Quick Reference (always in context)

See `references/story-decomposition.md` for the essential story decomposition summary (5 layers: foundation, core domain, extensions, compositions, cross-cutting; self-containment rules; dependency DAG; sizing).

## Detailed References

Read these files for comprehensive story planning guidance:

| Reference | Content |
|-----------|---------|
| `patterns/story-planning/layer-decomposition.md` | 5-layer breakdown (Layer 0: foundation infrastructure, Layer 1: core domain pattern establishment, Layer 2: extensions reusing Layer 1, Layer 3: compositions combining multiple capabilities, Layer 4: cross-cutting quality/observability), signal patterns per layer, blockers and dependencies |
| `patterns/story-planning/story-self-containment.md` | Data contracts (all fields with type, mandatory/optional, derivation rules), Gherkin acceptance criteria (concrete values, not abstractions), Mermaid sequence diagrams (real component names), sub-tasks (individually estimable at 2-4 hours, tagged [Dev]/[Test]/[Doc]) |
| `patterns/story-planning/dependency-dag.md` | Directed acyclic graph construction, circular dependency detection and resolution, dependency types (structural, data, pattern), bidirectional consistency (A blocks B ↔ B blocked by A), hard vs soft dependencies |
| `patterns/story-planning/cross-cutting-rules.md` | Rule extraction patterns, unique sequential IDs (RULE-001, RULE-002), implementation-ready descriptions (developer can build without asking), rule vs story-specific logic separation |
| `patterns/story-planning/story-sizing.md` | Sizing metrics (endpoints per story: max 2, protocol flows: max 1, Gherkin scenarios: 2-8, sub-tasks: max 10), split signals ("AND" in title), merge signals ("Helper"/"Utility"), minimum testable scope |
| `patterns/story-planning/phase-computation.md` | Automatic phase derivation from DAG, critical path identification (longest dependency chain), phase parallelization, schedule variance absorption, leaf story selection for risk distribution |
| `patterns/story-planning/template-generation.md` | Reading templates from `.claude/templates/` at runtime, _TEMPLATE-EPIC.md, _TEMPLATE-STORY.md, _TEMPLATE-IMPLEMENTATION-MAP.md, forbidden hardcoding of template structure |
