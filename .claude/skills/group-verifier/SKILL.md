---
name: group-verifier
description: "Build gate verification between parallelism groups. Compiles, classifies errors, decides retry/escalate, extracts outputs for next group."
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

### STEP 1 — COMPILE

```bash
mvn compile -Xlint:all -q 2>&1
```

Capture: exit code + stderr output.

### STEP 2 — ANALYZE

- If exit code = 0 → Go to STEP 5 (success)
- If exit code != 0 → Parse error output, go to STEP 3

### STEP 3 — CLASSIFY ERRORS

For each compilation error, classify as one of:

| Error Pattern | Classification | Meaning |
|--------------|----------------|---------|
| `cannot find symbol` referencing a type from a PREVIOUS group | MISSING_DEPENDENCY | Previous group regression or incomplete output |
| `cannot find symbol` referencing a type from the CURRENT group | TASK_ERROR | Current task produced incorrect code |
| `incompatible types` / `type mismatch` | TASK_ERROR | Current task has wrong types |
| `package does not exist` for a dependency package | MISSING_DEPENDENCY | Previous group didn't create expected package |
| `package does not exist` for an external lib | BUILD_ERROR | Missing Maven dependency |
| `method does not override` | TASK_ERROR | Interface mismatch in current task |
| `unreported exception` | TASK_ERROR | Missing try-catch or throws |
| Any other error | UNKNOWN | Needs investigation |

### STEP 4 — DECIDE

| Classification | Attempt | Action |
|----------------|---------|--------|
| TASK_ERROR | 1st | RETRY same tier, add error message to prompt |
| TASK_ERROR | 2nd | RETRY same tier, add error + previous error to prompt |
| TASK_ERROR | 3rd | ESCALATE to next tier (Haiku→Sonnet, Sonnet→Opus) |
| MISSING_DEPENDENCY | any | HALT pipeline, flag previous group regression |
| BUILD_ERROR | any | HALT pipeline, report missing dependency |
| UNKNOWN | 1st | ESCALATE immediately to next tier |
| UNKNOWN | 2nd (after escalation) | HALT pipeline, flag for manual intervention |

**Escalation path:**
- Haiku → Sonnet → Opus → Manual intervention
- Each escalation keeps the same task scope but provides richer context

**When retrying a task:**
1. Re-read the output from the failed subagent
2. Add to the retry prompt: `## COMPILATION ERROR\n{error message}\n## FIX INSTRUCTIONS\nThe previous attempt produced this error. Fix it.`
3. Re-launch the subagent with the same model (or escalated model)

### STEP 5 — EXTRACT OUTPUTS

For each task in the completed group:
1. Read all files listed in `task.files_created`
2. Read all files listed in `task.files_modified`
3. Store content for use as dependency inputs in subsequent groups

**How to extract:**
```
For each task T in completed group:
  For each file F in T.files_created + T.files_modified:
    Read F content
    Store as: outputs[T.id][F] = content
```

### STEP 6 — COMMIT

After successful compilation:
```bash
git add {all files from this group}
git commit -m "{group commit message}

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Group commit messages follow the pattern:
- G1: `feat(domain): add foundation models and migration for STORY-NNN`
- G2: `feat(domain): add ports, DTOs, and engine for STORY-NNN`
- G3: `feat(persistence): add entity, mapper, and repository for STORY-NNN`
- G4: `feat(application): add use case for STORY-NNN`
- G5: `feat(adapter): add REST resource, TCP handler, and config for STORY-NNN`
- G6: `feat(observability): add tracing and metrics for STORY-NNN`
- G7: `test: add tests for STORY-NNN`

### STEP 7 — REPORT

Print verification result:

```
Group G{N} verified: {PASS|FAIL}
  Tasks: {N} completed, {N} retried, {N} escalated
  Files: {N} created, {N} modified
  Warnings: {N}
  {If escalation: "ESCALATION: T{X} from {tier} -> {next_tier} (reason: {error})"}
```

---

## For G7 (Tests Group) — Extended Verification

G7 uses `mvn verify` instead of `mvn compile`:

```bash
mvn verify 2>&1
```

Additional checks:
1. Parse test results from `target/surefire-reports/*.xml`
2. Count: tests, failures, errors, skipped
3. Parse JaCoCo from `target/site/jacoco/jacoco.xml`
4. Verify: line coverage >= 95%, branch coverage >= 90%

If tests fail:
- Classify failing tests by the task that created them
- Retry the test task with the failure message
- If test depends on production code from another task, check if production code is correct first

---

## Error Patterns Reference

See `references/error-patterns.md` for common compilation errors and resolution strategies specific to this project.
