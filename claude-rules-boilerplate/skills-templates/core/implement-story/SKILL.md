---
name: implement-story
description: "Implements a feature/story following project conventions. Test-first approach with layer-by-layer implementation and intermediate compilation checks. Use for any coding task from single class to full story implementation."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[STORY-ID or feature-description]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Implement Story

## When to Use This vs `/feature-lifecycle`

| Scenario                                       | Use                    |
| ---------------------------------------------- | ---------------------- |
| Quick implementation (single class, small fix)  | This skill             |
| Full story with multi-persona review            | `/feature-lifecycle`   |
| Coding without the review phases                | This skill             |
| Complete lifecycle: code -> review -> fix -> PR  | `/feature-lifecycle`   |

## Purpose

Implementation skill for {{PROJECT_NAME}}. Covers the coding cycle: read requirements -> check dependencies -> create branch -> implement -> test -> validate -> commit.

## The Implementation Workflow

```
1. PREPARE    -> Read story, check dependencies, create branch
2. UNDERSTAND -> Read relevant architecture docs, understand context
3. IMPLEMENT  -> Write code following patterns and conventions
4. TEST       -> Write tests, run them, check coverage
5. VALIDATE   -> Verify Definition of Done checklist
6. COMMIT     -> Atomic commits following conventions
```

## Step 1: PREPARE

### 1a. Read the Story/Requirements

Extract:
- **Acceptance criteria** -- define "done"
- **Sub-tasks** -- become the implementation plan
- **Test scenarios** -- become test cases
- **Dependencies** -- must be implemented first

### 1b. Verify Dependencies

Check that all prerequisite stories/features are already implemented.

### 1c. Create Feature Branch

```bash
git checkout main
git pull origin main
git checkout -b feat/STORY-ID-short-description
```

## Step 2: UNDERSTAND

### 2a. Read Architecture Context

Read relevant architecture rules, ADRs, and existing code in the affected packages.

### 2b. Review Existing Code

```bash
# List existing classes in the target package
# Review existing tests for patterns to follow
```

## Step 3: IMPLEMENT

### Implementation Order (Layer by Layer)

Follow the hexagonal architecture layer order:

1. **Domain Models** (Records, Enums, Value Objects)
2. **Ports** (Inbound/Outbound Interfaces)
3. **Domain Engine/Rules** (Business Logic)
4. **Persistence** (Entity, Mapper, Repository)
5. **Application** (Use Cases)
6. **Inbound Adapters** (REST, TCP, Config)
7. **Tests** (written alongside or test-first)

### Intermediate Compilation

After each layer, verify compilation:

```bash
{{COMPILE_COMMAND}}
```

### Code Conventions

- Follow all project coding rules (naming, formatting, patterns)
- Constructor injection (never field injection)
- `Optional<T>` for search returns (never null)
- Records for DTOs, Value Objects, Events
- Named constants (never magic numbers/strings)
- Methods <= 25 lines, classes <= 250 lines
- Self-documenting code (comments only for "why", never "what")

## Step 4: TEST

1. **Write tests alongside code** -- ideally test-first (TDD)
2. **One test class per production class**
3. **Cover all acceptance criteria** -- each criterion = at least one test
4. **Parametrized tests** for data-driven scenarios
5. **Exception tests** -- every error path must be tested

```bash
{{TEST_COMMAND}}
{{COVERAGE_COMMAND}}
```

## Step 5: VALIDATE (Definition of Done)

| Criterion                         | How to verify                          |
| --------------------------------- | -------------------------------------- |
| All acceptance criteria have tests | Compare criteria vs test methods       |
| Line coverage >= 95%              | Coverage report                        |
| Branch coverage >= 90%            | Coverage report                        |
| Code compiles cleanly             | `{{COMPILE_COMMAND}}` with no warnings |
| All tests pass                    | `{{TEST_COMMAND}}`                     |
| Thread-safe (if applicable)       | No mutable static state, immutable     |

## Step 6: COMMIT

Follow the `commit-and-push` skill. Make atomic commits:

```bash
git add src/main/path/to/Feature.{{LANGUAGE}}
git add src/test/path/to/FeatureTest.{{LANGUAGE}}
git commit -m "feat(scope): add feature description"
```

## Integration Notes

- For the full lifecycle with reviews, use `feature-lifecycle` instead
- Invokes patterns from `run-tests` and `commit-and-push` skills
- Works with any {{FRAMEWORK}} project following layered/hexagonal architecture
