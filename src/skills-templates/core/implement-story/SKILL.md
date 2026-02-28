---
name: implement-story
description: "Implements a feature/story following project conventions. Delegates preparation to a subagent that reads architecture and coding KPs, then implements layer-by-layer with intermediate compilation checks."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[STORY-ID or feature-description]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Implement Story (Orchestrator)

## When to Use This vs `/feature-lifecycle`

| Scenario | Use |
|----------|-----|
| Quick implementation (single class, small fix) | This skill |
| Full story with multi-persona review | `/feature-lifecycle` |
| Coding without the review phases | This skill |
| Complete lifecycle: code → review → fix → PR | `/feature-lifecycle` |

## Execution Flow (Orchestrator Pattern)

```
1. PREPARE + UNDERSTAND  -> Subagent reads KPs, produces implementation plan
2. IMPLEMENT             -> Orchestrator writes code layer-by-layer (inline)
3. TEST + VALIDATE       -> Orchestrator runs tests, checks coverage (inline)
4. COMMIT                -> Orchestrator commits following conventions (inline)
```

## Step 1: Prepare + Understand (Subagent via Task)

Launch a **single** `general-purpose` subagent:

> You are a **Senior Developer** preparing an implementation plan for {{PROJECT_NAME}}.
>
> **Step 1 — Read the story/requirements:** `{STORY_PATH_OR_DESCRIPTION}`
> Extract: acceptance criteria, sub-tasks, test scenarios, dependencies.
>
> **Step 2 — Read project conventions:**
> - `skills/architecture/references/architecture-principles.md` — layer structure, dependency direction
> - `skills/coding-standards/references/coding-conventions.md` — {{LANGUAGE}} coding conventions
> - `skills/coding-standards/references/version-features.md` — {{LANGUAGE}} {{LANGUAGE_VERSION}} idioms
> - `skills/layer-templates/SKILL.md` — code templates per architecture layer (defines implementation order)
>
> **Step 3 — Review existing code** in the target packages to identify patterns to follow.
>
> **Step 4 — Produce implementation plan:**
> 1. Layer-by-layer implementation order (from layer-templates)
> 2. For each layer: classes to create/modify, package location, key patterns
> 3. Test classes needed (one per production class)
> 4. Key conventions to follow (naming, immutability, injection style)
> 5. Dependencies to verify before starting
>
> Also create feature branch if not already on one:
> ```bash
> git checkout main && git pull origin main
> git checkout -b feat/STORY-ID-short-description
> ```

## Step 2: Implement (Orchestrator — Inline)

Using the plan returned by the subagent, implement layer-by-layer.

**Implementation order** follows the layer-templates knowledge pack. General principle: dependencies point inward toward the domain — implement inner layers first.

Typical order (verify against subagent's plan):
1. **Domain layer** (models, enums, value objects, ports, engines/rules)
2. **Outbound adapters** (persistence entities, mappers, repositories)
3. **Application layer** (use cases / orchestration)
4. **Inbound adapters** (REST, gRPC, TCP, configuration)
5. **Tests** (written alongside or test-first)

**After each layer:** `{{COMPILE_COMMAND}}`

**Code conventions** (from subagent's plan):
- Named constants (never magic numbers/strings)
- Methods ≤ 25 lines, classes ≤ 250 lines
- Self-documenting code (comments only for "why")
- Never return null — use Optional/empty types
- Constructor/initializer injection
- Immutable DTOs, value objects, events

## Step 3: Test + Validate (Orchestrator — Inline)

1. Write tests alongside code (ideally test-first)
2. One test class per production class
3. Cover all acceptance criteria
4. Parametrized tests for data-driven scenarios
5. Exception tests for every error path

```bash
{{TEST_COMMAND}}
{{COVERAGE_COMMAND}}
```

**Definition of Done:**

| Criterion | Verification |
|-----------|-------------|
| All AC have tests | Compare criteria vs test methods |
| Line coverage ≥ 95% | Coverage report |
| Branch coverage ≥ 90% | Coverage report |
| Code compiles cleanly | `{{COMPILE_COMMAND}}` with no warnings |
| All tests pass | `{{TEST_COMMAND}}` |
| Thread-safe (if applicable) | No mutable static state |

## Step 4: Commit (Orchestrator — Inline)

Make atomic commits per layer/feature following git conventions:

```bash
git add src/main/path/to/Feature.{{FILE_EXTENSION}}
git add src/test/path/to/FeatureTest.{{FILE_EXTENSION}}
git commit -m "feat(scope): add feature description"
```

## Integration Notes

- For the full lifecycle with reviews, use `feature-lifecycle` instead
- Invokes patterns from `run-tests` and `commit-and-push` skills
- Works with any {{FRAMEWORK}} project following layered/hexagonal architecture
