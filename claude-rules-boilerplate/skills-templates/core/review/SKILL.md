---
name: review
description: "Parallel code review with specialist engineers (Security, QA, Performance, Database, Observability, DevOps, API). Produces a consolidated review report with scores and severity classification. Use for pre-PR quality validation."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[STORY-ID or --scope reviewer1,reviewer2]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Review (Specialist Parallel Review)

## Description

Runs a parallel code review with 7 specialist engineers. This is the standalone version of Phase 3 from the feature-lifecycle -- usable independently on any branch/story.

## Triggers

- `/review` -- review current branch
- `/review STORY-ID` -- review specific story
- `/review --scope security,qa` -- run only specific reviewers

## Prerequisites

- Code must be committed (reviewers analyze committed code)
- Branch should have changes relative to main

## Workflow

### Step 1 -- Detect Context

1. If argument is `STORY-ID`, use that
2. If no argument, extract story ID from current branch name
3. If `--scope` flag provided, run only listed reviewers

```bash
git branch --show-current
git diff main --stat
git diff main --name-only
```

If no changes found, abort: `No changes found relative to main. Nothing to review.`

### Step 2 -- Determine Applicable Engineers

Default: ALL 7 engineers run in parallel.

| # | Engineer      | Focus Area                                 | Condition    |
|---|---------------|--------------------------------------------|--------------|
| 1 | Security      | Sensitive data, validation, fail-secure     | Always       |
| 2 | QA            | Test coverage, quality, scenarios           | Always       |
| 3 | Performance   | Latency, concurrency, resource usage        | Always       |
| 4 | Database      | Schema, migrations, indexes, queries        | Always       |
| 5 | Observability | Spans, metrics, logging, health checks      | Always       |
| 6 | DevOps        | Docker, K8S, config, deployment             | Always       |
| 7 | API           | REST design, contracts                      | If REST changed|

Valid `--scope` values: `security`, `qa`, `performance`, `database`, `observability`, `devops`, `api`

### Step 3 -- Launch Parallel Reviews

**CRITICAL: ALL review tasks MUST be launched in a SINGLE message for true parallelism.**

Each engineer:
1. Reads the project rules relevant to their domain
2. Reviews the diff against main
3. Applies their checklist
4. Produces a scored report with findings

### Step 4 -- Consolidate Results

Read each report and produce:

```
+---------------+-------+--------------------+
|    Review     | Score |      Status        |
+---------------+-------+--------------------+
| Security      | XX/20 | Approved           |
| QA            | XX/24 | Approved           |
| Performance   | XX/26 | Adequate           |
| Database      | XX/16 | Approved           |
| Observability | XX/18 | Needs Work         |
| DevOps        | XX/20 | Approved           |
| API Design    | XX/16 | (if applicable)    |
+---------------+-------+--------------------+
Total: XXX/YYY (XX%)
```

List failed items grouped by engineer with severity:

```
Issues Found:

  Security (N issues):
    - [ID]: [description] (CRITICAL|MEDIUM|LOW)

  Performance (N issues):
    - [ID]: [description] (MEDIUM)

  Database: No issues
  QA: No issues
```

Count by severity: `CRITICAL: N | MEDIUM: N | LOW: N`

### Step 5 -- Summary

```
Review complete for [STORY_ID].
Reports saved to docs/reviews/[STORY_ID]-*.md

CRITICAL: N | MEDIUM: N | LOW: N

If CRITICAL > 0: Corrections required before merge.
If only MEDIUM/LOW: Evaluate whether to fix now or defer.
```

## Output Artifacts

- `docs/reviews/STORY-ID-security.md`
- `docs/reviews/STORY-ID-qa.md`
- `docs/reviews/STORY-ID-performance.md`
- `docs/reviews/STORY-ID-database.md`
- `docs/reviews/STORY-ID-observability.md`
- `docs/reviews/STORY-ID-devops.md`
- `docs/reviews/STORY-ID-api.md` (if applicable)

## Integration Notes

- This skill produces the SAME artifacts as Phase 3 of `feature-lifecycle`
- If run standalone before the lifecycle, Phase 3 can be skipped if reports exist and code unchanged
- Recommended flow: `/review` first, fix criticals, then `/review-pr` for final holistic review
