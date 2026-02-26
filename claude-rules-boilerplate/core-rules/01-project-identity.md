# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 01 — Project Identity

## Identity

| Attribute | Value |
|-----------|-------|
| Project | {{PROJECT_NAME}} |
| Type | {{PROJECT_TYPE}} |
| Purpose | {{PROJECT_PURPOSE}} |
| Language | {{LANGUAGE}} {{LANGUAGE_VERSION}} |
| Framework | {{FRAMEWORK}} {{FRAMEWORK_VERSION}} |
| Architecture | {{ARCHITECTURE}} ({{ARCH_STYLE}}) |
| Database | {{DB_TYPE}} (migrations: {{DB_MIGRATION}}) |
| Build Tool | {{BUILD_TOOL}} |

## Source of Truth Hierarchy

1. **Project rules** (this file and `.claude/rules/`) — highest priority
2. **Knowledge packs** (`skills/`) — detailed reference material
3. **Architecture Decision Records** (ADRs) — design decisions
4. **External documentation** — framework/language docs
5. **General knowledge** — lowest priority

## Technology Stack

Populated at setup time. See `skills/coding-standards/` for language-specific conventions and `skills/architecture/` for architecture patterns.

## Domain

> Detailed domain rules are in `rules/02-domain.md`. Read it before any domain-related work.
