---
name: layer-templates
description: "Hexagonal layer templates: concrete file examples for each architecture layer (entity, repository, port, use case, REST resource, TCP handler, etc.). Critical for Haiku sub-agents to produce correct code by pattern replication."
user-invocable: false
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.

# Skill: Layer Templates (Hexagonal Architecture)

## Purpose

Provides concrete, copy-and-adapt templates for every hexagonal layer in the authorizer-simulator. Each template is a real-world example that sub-agents (especially Haiku) can replicate by changing names, fields, and logic while preserving the structural pattern.

## When to Use

- **Feature Lifecycle Phase 2**: The orchestrator loads templates for Haiku tasks
- **Standalone /implement-story**: When implementing a single layer component
- **Any implementation**: When you need a structural reference for a specific layer

## Template Catalog

| Template | File | Layer | Tier | Key Patterns |
|----------|------|-------|------|-------------|
| DTO Request | `references/dto-request.md` | adapter.inbound.rest | Junior | `@RegisterForReflection`, `@Schema`, Bean Validation |
| DTO Response | `references/dto-response.md` | adapter.inbound.rest | Junior | `@RegisterForReflection`, `@Schema`, masking |
| Domain Model | `references/domain-model.md` | domain.model | Junior | Records, sealed interfaces, enums |
| Port Inbound | `references/port-inbound.md` | domain.port.inbound | Junior | Interface, domain types only |
| Port Outbound | `references/port-outbound.md` | domain.port.outbound | Junior | Interface, Optional returns |
| JPA Entity | `references/entity.md` | adapter.outbound.persistence.entity | Junior | `@Entity`, `@Table`, mandatory columns |
| Entity Mapper | `references/entity-mapper.md` | adapter.outbound.persistence.mapper | Junior | `final class`, private constructor, static methods |
| DTO Mapper | `references/dto-mapper.md` | adapter.inbound.rest.mapper | Junior | `final class`, private constructor, static methods, masking |
| Repository | `references/repository.md` | adapter.outbound.persistence.repository | Mid | PanacheRepository, Optional returns |
| Flyway Migration | `references/migration.md` | db/migration | Junior | `V{N}__`, BEGIN/COMMIT, IF NOT EXISTS |
| Use Case | `references/usecase.md` | application | Mid | `@ApplicationScoped`, constructor injection, orchestration |
| REST Resource | `references/rest-resource.md` | adapter.inbound.rest | Mid | `@Path`, CRUD, pagination, `@Schema` |
| Exception Mapper | `references/exception-mapper.md` | adapter.inbound.rest | Mid | Pattern matching switch, ProblemDetail factory |
| TCP Handler | `references/tcp-handler.md` | adapter.inbound.socket | Senior | Vert.x, framing, error handling, backpressure |
| Configuration | `references/config-properties.md` | config | Junior | `@ConfigMapping`, profiles, env vars |
| OTel Instrumentation | `references/otel-instrumentation.md` | cross-cutting | Mid | Spans, metrics, attributes, masking |

## How to Use (For Orchestrator)

### For Haiku Tasks (Junior Tier)

1. Read the appropriate `references/{layer}.md` file
2. Include the template content VERBATIM in the Haiku prompt under `## TEMPLATE`
3. Add a `## YOUR TASK` section listing what to change (names, fields, types)
4. Haiku copies the pattern, replacing marked sections

### For Sonnet Tasks (Mid Tier)

1. Templates are OPTIONAL — Sonnet can reason from rules
2. Include template only if the layer has complex structural requirements
3. Prefer including relevant rule file sections instead

### For Opus Tasks (Senior Tier)

1. Templates are NOT needed — Opus reasons from first principles
2. Include existing similar code as reference instead of templates
3. Focus on providing full rules, story, and architectural context

## Template Structure Convention

Each template file follows this structure:

```markdown
# Template: {Layer Name}

## Pattern
[Concrete Java file example — a REAL implementation]

## CHANGE THESE
[Highlighted list of what varies per story]

## Critical Rules (memorize)
[3-5 most important rules for this specific layer]

## Checklist
[Must-have items that Haiku should verify before finishing]
```
