---
name: group-verifier
description: "Build gate verification between parallelism groups. Compiles code, classifies errors, decides retry vs escalate, extracts outputs for next group. Used between each implementation group in Phase 2."
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[G1|G2|G3|G4|G5|G6|G7]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.

# Skill: Group Verifier (Build Gate)

## Purpose

Runs between each parallelism group (G1-G7) during Phase 2 of the feature lifecycle. Compiles the code, classifies any errors, decides whether to retry or escalate, and extracts created file contents for the next group's dependency inputs.

## When to Use

- **Feature Lifecycle Phase 2**: After each group completes, BEFORE starting the next group
- Callable via: `Skill(group-verifier)` or inline by the orchestrator

## Procedure

### STEP 1 -- COMPILE

```bash
{{COMPILE_COMMAND}}
```

Capture: exit code + stderr output.

For G7 (Tests group), use the full build command instead:

```bash
{{BUILD_COMMAND}}
```

### STEP 2 -- ANALYZE

- If exit code = 0 -> Go to STEP 5 (success)
- If exit code != 0 -> Parse error output, go to STEP 3

### STEP 3 -- CLASSIFY ERRORS

| Error Pattern                                         | Classification     | Meaning                           |
| ----------------------------------------------------- | ------------------ | --------------------------------- |
| `cannot find symbol` referencing a PREVIOUS group type | MISSING_DEPENDENCY | Previous group regression         |
| `cannot find symbol` referencing a CURRENT group type  | TASK_ERROR         | Current task produced bad code    |
| `incompatible types` / `type mismatch`                | TASK_ERROR         | Wrong types in current task       |
| `package does not exist` for dependency package        | MISSING_DEPENDENCY | Previous group incomplete         |
| `package does not exist` for external lib              | BUILD_ERROR        | Missing dependency in build file  |
| `method does not override`                            | TASK_ERROR         | Interface mismatch                |
| `unreported exception`                                | TASK_ERROR         | Missing error handling            |
| Any other error                                       | UNKNOWN            | Needs investigation               |

### STEP 4 -- DECIDE

| Classification     | Attempt | Action                                            |
| ------------------ | ------- | ------------------------------------------------- |
| TASK_ERROR         | 1st     | RETRY same tier, add error message to prompt      |
| TASK_ERROR         | 2nd     | RETRY same tier, add both errors to prompt        |
| TASK_ERROR         | 3rd     | ESCALATE to next tier (Junior->Mid, Mid->Senior)  |
| MISSING_DEPENDENCY | any     | HALT pipeline, flag previous group regression     |
| BUILD_ERROR        | any     | HALT pipeline, report missing dependency          |
| UNKNOWN            | 1st     | ESCALATE immediately to next tier                 |
| UNKNOWN            | 2nd     | HALT pipeline, flag for manual intervention       |

**Escalation path:** Junior -> Mid -> Senior -> Manual intervention

**When retrying a task:**
1. Re-read the output from the failed attempt
2. Add to the retry prompt: `## COMPILATION ERROR\n{error message}\n## FIX INSTRUCTIONS\nThe previous attempt produced this error. Fix it.`
3. Re-launch with the same tier (or escalated tier)

### STEP 5 -- EXTRACT OUTPUTS

For each task in the completed group:
1. Read all files listed in `task.files_created`
2. Read all files listed in `task.files_modified`
3. Store content for use as dependency inputs in subsequent groups

### STEP 6 -- COMMIT

After successful compilation:

```bash
git add {all files from this group}
git commit -m "{group commit message}"
```

Group commit messages follow the pattern:
- G1: `feat(domain): add foundation models and migration for STORY-ID`
- G2: `feat(domain): add ports, DTOs, and engine for STORY-ID`
- G3: `feat(persistence): add entity, mapper, and repository for STORY-ID`
- G4: `feat(application): add use case for STORY-ID`
- G5: `feat(adapter): add inbound adapters and config for STORY-ID`
- G6: `feat(observability): add tracing and metrics for STORY-ID`
- G7: `test: add tests for STORY-ID`

### STEP 7 -- REPORT

```
Group G{N} verified: {PASS|FAIL}
  Tasks: {N} completed, {N} retried, {N} escalated
  Files: {N} created, {N} modified
  Warnings: {N}
  {If escalation: "ESCALATION: T{X} from {tier} -> {next_tier} (reason: {error})"}
```

---

## G7 Extended Verification

G7 uses `{{BUILD_COMMAND}}` instead of `{{COMPILE_COMMAND}}`:

Additional checks:
1. Parse test results from build reports
2. Count: tests, failures, errors, skipped
3. Parse coverage report
4. Verify: line coverage >= 95%, branch coverage >= 90%

If tests fail:
- Classify failing tests by the task that created them
- Retry the test task with the failure message
- If test depends on production code from another task, check production code first

## Integration Notes

- Invoked by `feature-lifecycle` during Phase 2 after each group
- Uses `{{COMPILE_COMMAND}}` for G1-G6, `{{BUILD_COMMAND}}` for G7
- Produces atomic commits per group (rollback points)
