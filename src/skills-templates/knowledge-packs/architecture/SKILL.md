---
name: architecture
description: "Full architecture reference: {{ARCHITECTURE}} principles, package structure, dependency rules, thread-safety, mapper patterns, persistence rules, and architecture variants. Read before designing or implementing features."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Architecture

## Purpose

Provides the complete architecture principles for {{ARCHITECTURE}} ({{ARCH_STYLE}}). Includes package structure, dependency rules, layer responsibilities, mapper patterns, persistence rules, and architecture variants.

## Quick Reference (always in context)

See `rules/04-architecture-summary.md` for the essential cheat sheet (dependency direction, package structure, layer rules).

## Detailed References

| Reference | Content |
|-----------|---------|
| `references/architecture-principles.md` | Full hexagonal/clean architecture rules, package structure, dependency matrix, thread-safety, mapper pattern, persistence rules |
| `references/architecture-patterns.md` | Architecture patterns selected for this project (hexagonal, CQRS, event sourcing, etc.) |

## Related Knowledge Packs

- `skills/layer-templates/` — code templates per architecture layer
- `skills/architecture-patterns/references/` — detailed pattern implementations (20+ patterns)
