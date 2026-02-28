---
name: x-test-run
description: "Runs tests with coverage reporting and threshold validation. Use whenever writing, running, or analyzing tests. Triggers on: test, coverage, TDD, unit test, integration test, test failure, coverage gap, or Definition of Done validation."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[ClassName or package or --coverage]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Run Tests

## Purpose

Testing is critical in {{PROJECT_NAME}}. The project enforces strict coverage thresholds (line >= 95%, branch >= 90%). This skill guides test execution, coverage analysis, and gap identification.

## Test Execution Commands

```bash
# All tests
{{TEST_COMMAND}}

# With coverage report
{{COVERAGE_COMMAND}}

# Specific test class (adapt to your build tool)
# Example: mvn test -Dtest=ClassName
# Example: ./gradlew test --tests ClassName
```

## Coverage Thresholds

| Metric          | Minimum |
| --------------- | ------- |
| Line Coverage   | >= 95%  |
| Branch Coverage | >= 90%  |

## Test Structure

For full testing philosophy (8 test categories, data uniqueness, fixture patterns), read `skills/testing/references/testing-philosophy.md`.

### Naming Convention

```
[methodUnderTest]_[scenario]_[expectedBehavior]
```

Examples:
- `processTransaction_approvedAmount_returnsSuccess`
- `findById_nonExistent_returnsEmpty`
- `validate_nullInput_throwsException`

### Test Pattern (Arrange-Act-Assert)

Every test method follows AAA with clear separation:

```
// Arrange -- setup objects and data
// Act -- execute the method under test
// Assert -- verify the outcome
```

## Test Categories

| Category        | When to Use                                    | Tools                     |
| --------------- | ---------------------------------------------- | ------------------------- |
| Unit            | Domain logic, engines, mappers                 | Test framework + assertions|
| Integration     | DB interactions, framework features            | Framework test support     |
| API             | REST endpoints                                 | HTTP test client           |
| E2E             | Full flow (request -> process -> persist -> response) | Integration framework |
| Contract        | Protocol/format compliance                     | Parametrized tests         |
| Performance     | Latency SLAs, throughput                       | Load testing framework     |

## Coverage Analysis

After running `{{COVERAGE_COMMAND}}`, analyze the coverage report.

### Common Coverage Gaps and Solutions

| Gap                           | Solution                                         |
| ----------------------------- | ------------------------------------------------ |
| Uncovered `else` branch       | Add test for the negative case                   |
| Uncovered exception path      | Test error paths with exception assertions        |
| Uncovered `default` in switch | Add test with unexpected input                   |
| Uncovered record accessor     | Usually covered indirectly; add direct test if not|
| Uncovered validation          | Test with invalid inputs                         |

### Per-Class Coverage Report Format

```
+--------------------------+-------+--------+
|          Class           | Line  | Branch |
+--------------------------+-------+--------+
| ClassA                   | 100%  | 95.0%  |
+--------------------------+-------+--------+
| ClassB                   | 97.3% | 88.5%  |
+--------------------------+-------+--------+

Tests: XX passing, XX failing, XX errors, XX skipped
Global Coverage: XX% line / XX% branch
```

## Assertion Rules

Read `skills/testing/references/testing-conventions.md` for {{LANGUAGE}}-specific test frameworks and assertion libraries.

- Use the project's standard assertion library (e.g., AssertJ, Hamcrest)
- NEVER use basic assertEquals/assertTrue if a fluent assertion library is available
- Test exception paths with `assertThatThrownBy` or equivalent
- Test Optional results with `isPresent()`/`isEmpty()`

## Test Data

### Fixture Pattern

Centralize test data in utility classes:
- `final class` + `private` constructor + `static` methods
- Naming: `a{Entity}()` or `a{Entity}With{Variation}()`
- Constants for default values
- Domain fixtures separate from protocol/format fixtures

### Data Uniqueness

Tests that create resources (POST/INSERT) MUST generate unique identifiers to avoid conflicts between test runs.

## Integration Notes

- Invoked by `x-dev-lifecycle` during Phase 2 (G7) and Phase 4
- Invoked by `x-dev-implement` during Step 4
- Coverage report consumed by `x-review` skill (QA engineer)
- Thresholds enforced by `x-lib-group-verifier` in G7 verification
