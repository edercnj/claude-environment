---
name: troubleshoot
description: "Diagnoses errors, stacktraces, build failures, and unexpected behavior. Systematic approach: reproduce, locate, understand, fix, verify. Use whenever something fails: compilation errors, test failures, runtime exceptions, coverage gaps, or performance issues."
allowed-tools: Read, Bash, Grep, Glob
argument-hint: "[error-description or test-name]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Troubleshoot

## Purpose

Provides a systematic approach to diagnose and fix issues in {{PROJECT_NAME}}. Covers compilation errors, test failures, build failures, runtime exceptions, and domain-specific bugs.

## Debug Workflow

```
1. REPRODUCE  -> Get the exact error (stacktrace, build log, test output)
2. LOCATE     -> Find where the error originates
3. UNDERSTAND -> Why is it failing? Expected vs actual behavior?
4. FIX        -> Write a test that reproduces the bug, then fix the code
5. VERIFY     -> Run the full test suite to ensure no regressions
```

Always follow this order. Never skip step 4's "write a test first" -- the bug-reproducing test prevents regressions.

## Common Error Categories

### 1. Compilation Errors

```bash
{{COMPILE_COMMAND}}
```

The error patterns below are {{LANGUAGE}}-specific. Adapt to the actual compiler/interpreter messages for your project:

| Error Category               | Likely Cause                        | Fix                                         |
| ---------------------------- | ----------------------------------- | ------------------------------------------- |
| Missing symbol/type          | Missing import, typo in class name  | Check package structure, verify imports      |
| Type mismatch                | Wrong type in assignment/return     | Check type inference, explicit cast if needed|
| Sealed type error            | Missing permits/implementations     | Add implementing class to sealed hierarchy   |
| Missing package/module       | Wrong package or missing dependency | Verify directory matches package, check deps |
| Interface mismatch           | Signature mismatch with interface   | Compare method signature with interface def  |

### 2. Test Failures

```bash
{{TEST_COMMAND}}
```

| Failure Type                    | Diagnosis                      | Fix                                       |
| ------------------------------- | ------------------------------ | ----------------------------------------- |
| Assertion error (expected X got Y)| Logic bug in production code | Compare expected vs actual, trace the logic|
| NullPointerException in test    | Missing setup                  | Initialize all objects test needs          |
| Test passes alone, fails in suite| Shared mutable state          | Ensure fresh objects per test              |
| Timeout in test                 | Async issue or infinite loop   | Check for blocking calls, add timeouts    |

### 3. Build Failures

```bash
{{BUILD_COMMAND}}
```

| Error                        | Cause                    | Fix                                         |
| ---------------------------- | ------------------------ | ------------------------------------------- |
| Coverage threshold failure   | Coverage below threshold | Write more tests, check coverage report     |
| Dependency resolution failure| Missing or conflicting dep| Check build file, resolve conflicts         |
| Out of memory                | Memory issue in test/build | Increase memory limits, check for leaks    |

### 4. Runtime Errors

The error patterns below are {{LANGUAGE}}-specific. Adapt to the actual runtime error messages for your project:

| Error Category               | Likely Cause                    | Fix                                         |
| ---------------------------- | ------------------------------- | ------------------------------------------- |
| Missing class/module at runtime | Missing dependency at runtime | Check classpath/module path, add dependency |
| Method/function not found    | Version mismatch                | Align dependency versions                   |
| Connection refused            | Service not running             | Start required services, check ports        |
| Circuit breaker open          | Downstream service failure      | Check downstream health, wait for recovery  |

### 5. Performance Issues

| Symptom                 | Likely Cause                   | Fix                                      |
| ----------------------- | ------------------------------ | ---------------------------------------- |
| Slow response           | N+1 queries, missing indexes   | Add indexes, optimize queries            |
| Memory growing          | Object leak, missing cleanup   | Profile memory, fix resource management  |
| Thread starvation       | Blocking on event loop         | Use async patterns, offload to workers   |

## The Fix-First-Test Pattern

For every bug found:

1. Write a test that reproduces the bug (it should FAIL)
2. Fix the code
3. Verify the test PASSES
4. Run full test suite for regressions

```
// This test was added for bug #NNN
// Previously [describe the bug]
```

## Quick Diagnosis Checklist

When something fails, check in this order:

1. **Is it a compilation error?** -> Read the error message carefully
2. **Is it a test failure?** -> Read expected vs actual, run test in isolation
3. **Is it a coverage failure?** -> Check coverage report, find uncovered branches
4. **Is it a dependency issue?** -> Check build file, verify versions
5. **Is it a configuration issue?** -> Check properties, environment variables
6. **Is it intermittent?** -> Suspect shared mutable state, race conditions

## Error Classification for Group Verifier

When troubleshooting within the feature lifecycle, classify errors for the `group-verifier`:

| Classification     | When                                        | Action              |
| ------------------ | ------------------------------------------- | ------------------- |
| TASK_ERROR         | Error in current group's code               | Retry same tier     |
| MISSING_DEPENDENCY | Missing type from previous group            | Halt, flag regression|
| BUILD_ERROR        | Missing external dependency                 | Halt, fix build file|
| UNKNOWN            | Unrecognized error pattern                  | Escalate tier       |

## Integration Notes

- Referenced by `group-verifier` when compilation fails
- Referenced by `feature-lifecycle` during Phase 4 (fixes)
- Can be used standalone for any debugging task
