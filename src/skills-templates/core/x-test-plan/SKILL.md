---
name: x-test-plan
description: "Generates a comprehensive test plan before implementation. Delegates KP reading to a context-gathering subagent, then produces structured test scenarios covering unit, integration, API, E2E, contract, and performance tests."
allowed-tools: Read, Grep, Glob
argument-hint: "[STORY-ID]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Plan Tests (Orchestrator)

## Purpose

Produces a comprehensive, actionable test plan BEFORE any test code is written. With 95% line / 90% branch coverage enforced, upfront planning avoids coverage whack-a-mole.

## Input

**Story to plan tests for:** `$ARGUMENTS`

If no story provided, ask which story to plan.

## Execution Flow (Orchestrator Pattern)

```
1. GATHER CONTEXT  -> Subagent reads testing + architecture KPs, story, existing code
2. PLAN TESTS      -> Orchestrator generates scenarios using returned context (inline)
3. ESTIMATE        -> Orchestrator estimates coverage and validates completeness (inline)
```

## Step 1: Gather Context (Subagent via Task)

Launch a **single** `general-purpose` subagent:

> You are a **Test Planning Assistant** gathering context for test plan generation.
>
> **Read these knowledge packs:**
> - `skills/testing/references/testing-philosophy.md` — 8 test categories, fixture patterns, data uniqueness, async handling, real vs in-memory DB decisions
> - `skills/testing/references/testing-conventions.md` — {{LANGUAGE}}-specific test frameworks, naming conventions, directory structure, assertion libraries
> - `skills/architecture/references/architecture-principles.md` — exception hierarchy, layer boundaries (unit vs integration), dependency direction
>
> **Read the story:** `{STORY_PATH}`
> Extract: acceptance criteria, sub-tasks, business rules, dependencies.
>
> **Scan existing code:**
> - List existing classes in target packages
> - List existing test classes and patterns established
>
> **Return a structured context summary:**
> 1. **Test categories applicable** to this story (from the 8 categories in testing-philosophy)
> 2. **Naming convention:** `[method]_[scenario]_[expected]` pattern with {{LANGUAGE}}-specific format
> 3. **Test frameworks and assertion libraries** to use (from testing-conventions)
> 4. **Fixture pattern:** `final class` + `private constructor` + `static methods`, naming `a{Entity}()`
> 5. **Acceptance criteria** extracted from story (each becomes ≥1 test)
> 6. **Business rules** extracted (each maps to parametrized tests)
> 7. **Exception types** in scope (each needs error path test)
> 8. **Layer boundaries** — which classes need unit vs integration tests
> 9. **Existing patterns** found in current test codebase
> 10. **Contract tests applicable** (if testing.contract_tests == true)
> 11. **Chaos tests applicable** (if testing.chaos_tests == true)

## Step 2: Generate Test Scenarios (Orchestrator — Inline)

Using the context returned by the subagent, generate scenarios by category:

### 2.1 Happy Path
For every public method, at least one scenario with valid input → expected result.

### 2.2 Error Path
Map each exception to: trigger condition → test method name. Verify: exception type + message + context data.

### 2.3 Boundary Tests
Triplet pattern per boundary: at-min, at-max, past-max.

### 2.4 Parametrized Tests
Identify data matrices. Use CSV source for simple type/value/expected. Use method source for complex objects. Estimate row count.

### 2.5 Integration Tests
Scenarios requiring framework context (DB, HTTP, messaging): CRUD, transactions, concurrent access.

### 2.6 API Tests (if applicable)
Valid → expected status, Invalid → 400, Not found → 404, Conflict → 409, Rate limited → 429.

### 2.7 E2E Tests (if applicable)
Full flow: entry point → processing → persistence → response.

### 2.8 Contract Tests (if testing.contract_tests == true)
Consumer contracts, provider verification, schema compatibility.

### 2.9 Chaos Tests (if testing.chaos_tests == true)
Network partition, latency injection, resource exhaustion, dependency failure.

## Step 3: Estimate & Validate (Orchestrator — Inline)

### Coverage Estimation Table

| Class | Public Methods | Branches | Est. Tests | Line % | Branch % |
|-------|---------------|----------|-----------|--------|----------|
| [Name] | [count] | [count] | [count] | [%] | [%] |

Flag any class where estimated coverage < 95% line / 90% branch.

### Quality Checks

1. Every acceptance criterion maps to ≥1 test
2. Every exception has ≥1 error path test
3. All applicable test categories represented
4. Boundary values use triplet pattern
5. Parametrized matrices are complete
6. Estimated coverage meets thresholds
7. Test naming follows convention

## Output

Save to: `docs/plans/STORY-ID-tests.md`

```markdown
# Test Plan -- STORY-ID: [Title]

## Summary
- Total test classes: X
- Total test methods: ~Y (estimated)
- Categories covered: [list]
- Estimated line coverage: ~Z%

## Test Class 1: [ClassNameTest]

### Happy Path
| # | Method | Test Name | Description |

### Error Path
| # | Exception | Test Name | Trigger |

### Boundary
| # | Boundary | Test Name | Values Tested |

### Parametrized
| # | Matrix | Test Name | Source | Rows |

## Coverage Estimation
[table]

## Risks and Gaps
- [Hard-to-test scenarios]
- [Coverage gaps needing attention]
```

## Anti-Patterns

- Do NOT write test code — only plan scenarios
- Do NOT skip error paths
- Do NOT forget boundary values (0, -1, max, empty, null)
- Do NOT plan tests for trivial getters/setters
- Do NOT ignore existing test patterns
- Do NOT create redundant tests covering the same branch

## Integration Notes

- Invoked by `x-dev-lifecycle` during Phase 1B
- Output consumed by Phase 2 (developers) and Phase 3 (QA engineer validates coverage)
- Can be used standalone before any implementation task
