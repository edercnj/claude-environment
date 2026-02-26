---
name: coding-standards
description: "Complete coding conventions: Clean Code rules (CC-01 to CC-10), SOLID principles, {{LANGUAGE}} {{LANGUAGE_VERSION}} idioms, naming patterns, constructor injection, mapper conventions, version-specific features, and approved libraries. Read before writing any code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Coding Standards

## Purpose

Provides the complete coding conventions for {{LANGUAGE}} {{LANGUAGE_VERSION}} with {{FRAMEWORK}}. Includes Clean Code rules, SOLID principles, language-specific idioms, formatting rules, and library guidelines.

## Quick Reference (always in context)

See `rules/03-coding-standards.md` for the essential cheat sheet (hard limits, naming, SOLID one-liners, forbidden patterns).

## Detailed References

Read these files for the full conventions:

| Reference | Content |
|-----------|---------|
| `references/clean-code.md` | CC-01 to CC-10: naming, functions, SRP, magic values, DRY, error handling, documentation, formatting, Law of Demeter, class organization |
| `references/solid-principles.md` | SRP, OCP, LSP, ISP, DIP with examples and violation detection |
| `references/coding-conventions.md` | {{LANGUAGE}}-specific naming, injection patterns, mapper pattern, domain exceptions, formatting |
| `references/version-features.md` | {{LANGUAGE}} {{LANGUAGE_VERSION}}-specific features (records, sealed types, pattern matching, etc.) |
| `references/libraries.md` | Mandatory, recommended, and prohibited libraries for {{LANGUAGE}} |
| `references/testing-conventions.md` | {{LANGUAGE}}-specific testing frameworks, fixture patterns, directory structure |
