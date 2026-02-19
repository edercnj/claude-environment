---
name: run-contract-tests
description: "Skill: Contract Tests — Runs consumer-driven contract tests (Pact, Spring Cloud Contract) to verify API compatibility between services."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[--provider | --consumer | --all]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Contract Tests

## Description

Runs consumer-driven contract tests to verify API compatibility between services. Supports both consumer-side (pact generation) and provider-side (pact verification) workflows using Pact or Spring Cloud Contract.

**Condition**: This skill applies when `testing.contract_tests == true`.

## Prerequisites

- Contract testing framework installed:
  - Java: Pact JVM or Spring Cloud Contract
  - TypeScript: Pact JS
  - Python: Pact Python
  - Go: Pact Go
- Consumer and/or provider test files exist
- Build tool configured for contract test execution

## Arguments

| Argument     | Description                                          |
| ------------ | ---------------------------------------------------- |
| `--consumer` | Generate pact files from consumer tests              |
| `--provider` | Verify provider against published pacts              |
| `--all`      | Run both consumer generation and provider verification |
| (none)       | Shows usage/help                                     |

## Execution Flow

1. **Verify framework** — Check contract testing framework installed:
   - Scan build file for Pact/Spring Cloud Contract dependencies
   - Verify framework version compatibility

2. **Determine mode** — Based on argument:
   - `--consumer`: generate pact files
   - `--provider`: verify against pacts
   - `--all`: both in sequence

3. **Run tests** — Execute appropriate test suite

4. **Report results** — Generate structured output

## Consumer Side

1. Discover consumer test files (scan for `@PactTest`, `Pact`, `pact.describe`)
2. Run consumer tests: generate pact files (JSON contracts)
3. Verify pact files generated in `target/pacts/` or `pacts/` directory
4. Validate pact content: interactions defined, request/response match expectations

## Provider Side

1. Discover provider verification configuration
2. Start provider application (or use test server)
3. Run provider verification against published pacts
4. Report: which interactions passed/failed
5. Publish verification results (if pact broker configured)

## Usage Examples

```
/run-contract-tests --consumer     # Generate pact files
/run-contract-tests --provider     # Verify against pacts
/run-contract-tests --all          # Both consumer + provider
```

## Contract Checklist (10 points)

1. Consumer defines explicit expectations (request headers, body, status code)
2. Provider states defined for each interaction (setup test data)
3. Pact files versioned and published to broker (or committed to repo)
4. Provider verification runs in CI pipeline
5. Breaking changes detected before deployment
6. Contract covers happy path AND error responses
7. Contract includes required headers (Content-Type, Authorization pattern)
8. No sensitive data in pact files (use example data)
9. Consumer version tagged (branch, commit SHA)
10. Can-I-Deploy check integrated in CI (if using Pact Broker)

## Review Checklist

- [ ] Contract testing framework configured
- [ ] Consumer tests generate valid pact files
- [ ] Provider verification passes all interactions
- [ ] Pact files published to broker or committed
- [ ] No sensitive data in pact files
- [ ] Happy path and error responses covered
- [ ] Can-I-Deploy integrated in CI pipeline
- [ ] Breaking changes detected pre-deployment

## Output Format

```
## Contract Test Results — [Mode: Consumer/Provider]

### Summary
- Interactions tested: [N]
- Passed: [N]
- Failed: [N]

### Failed Interactions
1. [Consumer → Provider: interaction description, expected vs actual]

### Checklist Results
[Items that passed / failed / not applicable]

### Verdict: PASS / FAIL
```

## Rules
- FAIL if any consumer-provider interaction verification fails
- FAIL if pact files contain sensitive data
- Warn if pact broker not configured (local-only contracts are fragile)
- Warn if provider states not defined (tests may pass with wrong data)
- Verify both happy path and error scenarios are covered
