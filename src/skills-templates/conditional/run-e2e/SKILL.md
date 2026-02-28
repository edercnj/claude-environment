---
name: run-e2e
description: "Skill: End-to-End Tests — Runs integration tests that validate the complete flow from request through all application layers to response, using a real database."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[scenario: happy-path|error|timeout|persistent|all]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: End-to-End Tests (E2E)

## Description

Runs or implements end-to-end tests that validate the complete application flow: inbound request -> parsing -> validation -> business logic -> persistence -> response. Tests use a real database (or in-memory equivalent) and exercise all layers of the architecture.

**Condition**: This skill applies to all projects with integration test infrastructure.

## Prerequisites

- {{FRAMEWORK}} test extension configured
- Database available for tests (in-memory or containerized via {{DB_TYPE}})
- Test dependencies in {{BUILD_FILE}}: assertion library, async utilities
- E2E test classes exist in the test source tree

## Knowledge Pack References

Before writing or running E2E tests, read:
- `skills/testing/references/testing-philosophy.md` — real vs in-memory DB decisions, fixture patterns, data uniqueness
- `skills/testing/references/testing-conventions.md` — {{LANGUAGE}}-specific test framework, assertion library, directory structure

## Execution Flow

1. **Verify test infrastructure** — Check that required dependencies exist:
   - Framework test extension (e.g., `@QuarkusTest`, `@SpringBootTest`)
   - Database for tests configured in test profile
   - Assertion library available

2. **Run E2E tests** — Execute with:
   ```
   {{TEST_COMMAND}}
   ```
   - Filter by scenario tag if a specific scenario was requested
   - Ensure test profile is active (in-memory DB, random ports, etc.)

3. **Validate test results**:
   - All tests pass (exit code 0)
   - No test pollution (each test is independent)
   - Database state verified after operations

4. **Report results**:
   - Total: passed / failed / skipped
   - Duration per test class
   - Failed tests with error details and stack traces
   - Coverage report location (if generated)

## Mandatory E2E Scenarios

| Scenario              | Description                                             | Priority |
| --------------------- | ------------------------------------------------------- | -------- |
| Happy path            | Standard request processed successfully, persisted      | CRITICAL |
| Validation error      | Invalid input rejected with proper error response       | CRITICAL |
| Not found             | Request for non-existent resource returns proper error  | HIGH     |
| Duplicate/conflict    | Duplicate creation attempt returns conflict response    | HIGH     |
| Persistent connection | Multiple requests on same connection (if applicable)    | HIGH     |
| Concurrent requests   | Multiple simultaneous requests processed independently  | HIGH     |
| Malformed input       | Garbage input handled gracefully without crash          | MEDIUM   |
| Timeout behavior      | Slow operations handled per configured timeouts         | MEDIUM   |
| Error recovery        | Server continues operating after encountering errors    | MEDIUM   |

## Test Patterns

### Test Isolation
- Each test creates its own data, never depends on other tests
- Use unique identifiers per test execution to avoid conflicts
- Automatic cleanup via transaction rollback or explicit teardown

### Async Resource Readiness
- Wait for server/socket to be listening before connecting
- Use async polling (not `Thread.sleep`) for resource readiness
- Default timeout: 10 seconds for resource startup

### Assertion Style
- Use fluent assertion library (AssertJ, Chai, etc.)
- Verify both response content AND database state
- Check response status codes, headers, and body

## Usage Examples

```
/run-e2e
/run-e2e happy-path
/run-e2e persistent
/run-e2e all
```

## Review Checklist

- [ ] Tests exercise the complete flow (input -> all layers -> output)
- [ ] Real or realistic database used (not mocked)
- [ ] Each test is independent and idempotent
- [ ] Unique identifiers generated per test run
- [ ] Async resources awaited with polling (not sleep)
- [ ] Both response and database state verified
- [ ] Error scenarios covered (validation, not-found, conflict)
- [ ] Connection persistence tested (if applicable)
- [ ] Concurrent request handling validated
- [ ] No test pollution between test classes
