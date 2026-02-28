# Rule 03 — Coding Standards (Quick Reference)

> **Full reference:** Read `skills/coding-standards/SKILL.md` before writing code.

## Hard Limits

| Constraint | Limit |
|-----------|-------|
| Method/function length | ≤ 25 lines |
| Class/module length | ≤ 250 lines |
| Parameters per function | ≤ 4 (use parameter object if more) |
| Line width | ≤ 120 characters |

## Naming

- Intent-revealing: `elapsedTimeInMs` not `d`
- Verbs for methods: `processTransaction()`, `extractAmount()`
- Nouns for types: `TransactionHandler`, `DecisionEngine`
- Named constants: never magic numbers or strings

## SOLID (one-liners)

- **SRP**: One class = one reason to change
- **OCP**: New behavior = new class, never modify existing handlers
- **LSP**: Every implementation must fulfill its interface contract
- **ISP**: Small focused interfaces; no empty method implementations
- **DIP**: Depend on abstractions (ports), not concrete implementations

## Error Handling

- NEVER return null — use Optional, empty collection, or Result type
- NEVER pass null as argument
- Exceptions MUST carry context (values that caused the error)
- Catch at the right level, not where convenient

## Forbidden

- Boolean flags as function parameters
- Comments that repeat what code says
- Mutable global state
- God classes / train wrecks (chained calls across objects)
- Wildcard imports
- `sleep()` for synchronization (use condition-based polling)

## Language-Specific Conventions

> Read `skills/coding-standards/SKILL.md` for {{LANGUAGE}} {{LANGUAGE_VERSION}}-specific idioms, constructor injection patterns, mapper conventions, and formatting rules.
