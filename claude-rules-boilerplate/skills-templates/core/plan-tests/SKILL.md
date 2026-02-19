---
name: plan-tests
description: "Generates a comprehensive test plan before implementation. Covers unit, integration, API, E2E, contract, performance, and boundary tests. Produces a structured test scenarios document that serves as a blueprint for the implementation phase."
allowed-tools: Read, Grep, Glob
argument-hint: "[STORY-ID]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Plan Tests (Test Scenario Planner)

## Purpose

Produces a comprehensive, actionable test plan BEFORE any test code is written. In a project where 95% line coverage and 90% branch coverage are enforced, planning is the difference between hitting thresholds on the first pass vs. playing whack-a-mole.

## Input

**Story to plan tests for:** `$ARGUMENTS`

If no story was provided, ask which story to plan.

---

## Step 1: Gather Context

Read these sources IN PARALLEL:

### 1.1 The Story/Requirements

Extract:
- **Acceptance criteria** -- become the test skeleton
- **Sub-tasks** -- each implies at least one test class
- **Business rules** -- each maps to parametrized tests
- **Dependencies** -- affects what APIs are available to test

### 1.2 The Testing Rules

Read the project's testing rules to understand:
- Mandatory test categories
- Naming conventions
- Coverage thresholds
- Assertion standards

### 1.3 Architecture Context

Read architecture rules to understand:
- Exception hierarchy (every exception needs at least one test)
- Layer boundaries (affects test type: unit vs integration)

### 1.4 Existing Code

Scan existing source and test files to understand:
- What interfaces/classes already exist
- What test patterns are already established

---

## Step 2: Identify Test Classes

For each production class the story will create, define a test class:

```
Production class -> Test class
  Feature.ext -> FeatureTest.ext
```

Also identify cross-cutting test classes:
- Integration/E2E tests
- Shared test data/fixtures

---

## Step 3: Generate Scenarios by Category

### 3.1 Happy Path

For every public method, at least one scenario with valid input producing the expected result.

### 3.2 Error Path

Map each applicable exception to a concrete scenario:

```
Exception type -> Trigger condition -> Test method name
```

Verify each error test checks: exception type, message content, and context data.

### 3.3 Boundary Tests

Identify boundary values. For each boundary, generate a triplet:
- At minimum value
- At maximum value
- Past maximum value (should fail)

### 3.4 Parametrized Tests

Identify data sets for multi-variant testing:
- Use CSV source for simple type/value/expected matrices
- Use method source for complex objects
- Estimate row count per matrix

### 3.5 Integration Tests

Scenarios requiring framework context (DB, HTTP, messaging):
- CRUD operations
- Transaction boundaries
- Concurrent access

### 3.6 API Tests (if applicable)

- Valid request -> expected response + status code
- Invalid request -> 400 with validation errors
- Not found -> 404
- Conflict -> 409
- Rate limited -> 429

### 3.7 E2E Tests (if applicable)

Full flow from entry point through processing to persistence and response.

---

## Step 4: Estimate Test Data

For each test class, list the test data constants needed:

```
Constant name -> Type -> Value -> Used by
```

Identify whether constants should be local to the test class or shared.

---

## Step 5: Coverage Estimation

| Class       | Public Methods | Branches | Est. Tests | Line % | Branch % |
| ----------- | -------------- | -------- | ---------- | ------ | -------- |
| [ClassName] | [count]        | [count]  | [count]    | [%]    | [%]      |

Flag any class where estimated coverage < 95% line / 90% branch and suggest additional scenarios.

---

## Output Format

Save to: `docs/plans/STORY-ID-tests.md`

```markdown
# Test Plan -- STORY-ID: [Title]

## Summary
- Total test classes: X
- Total test methods: ~Y (estimated)
- Categories covered: Unit, Integration, API, E2E, Contract, Performance
- Estimated line coverage: ~Z%

## Test Class 1: [ClassNameTest]

### Happy Path
| # | Method  | Test Name                          | Description |
|---|---------|------------------------------------| ------------|
| 1 | methodA | methodA_validInput_returnsExpected | Tests...    |

### Error Path
| # | Exception     | Test Name                            | Trigger      |
|---|---------------|--------------------------------------| -------------|
| 1 | SomeException | methodA_invalidX_throwsSomeException | When X is... |

### Boundary
| # | Boundary   | Test Name                  | Values Tested |
|---|------------|----------------------------| --------------|
| 1 | Max length | methodA_maxLength_succeeds | 99, 100       |

### Parametrized
| # | Matrix         | Test Name                      | Source     | Rows |
|---|----------------|--------------------------------|-----------|------|
| 1 | Type x charset | validate_allTypes_charsetRules | CsvSource | ~26  |

## Coverage Estimation
| Class | Methods | Branches | Tests | Line % | Branch % |
|-------|---------|----------|-------|--------|----------|

## Risks and Gaps
- [Hard-to-test scenarios]
- [Coverage gaps needing attention]
```

---

## Quality Checks Before Delivering

1. Every acceptance criterion maps to at least one test
2. Every exception in scope has at least one error path test
3. All applicable test categories are represented or explicitly excluded
4. Boundary values use the triplet pattern (at-min, at-max, past-max)
5. Parametrized matrices are complete
6. Estimated coverage meets thresholds
7. Test naming follows `method_scenario_expected` convention

## Anti-Patterns

- Do NOT write test code -- only plan scenarios
- Do NOT skip error paths -- they often have the most bugs
- Do NOT forget boundary values (0, -1, max, empty, null)
- Do NOT plan tests for trivial getters/setters
- Do NOT ignore existing test patterns in the project
- Do NOT create redundant tests that cover the same branch

## Integration Notes

- Invoked by `feature-lifecycle` during Phase 1B
- Output consumed by Phase 2 (developers follow the plan) and Phase 3 (QA engineer validates coverage)
- Can be used standalone before any implementation task
