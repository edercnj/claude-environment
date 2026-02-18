---
name: review
description: "Use this skill to run a parallel code review with 7 specialist reviewers (Clean Code, Architecture, Quarkus, Testing, Security, ISO 8583, QA). This is the standalone version of Phase 3 from the feature-lifecycle. Triggers include: /review, code review, review code, specialist review, parallel review, or when you want feedback on code quality before creating a PR."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Task
argument-hint: "[STORY-NNN or --scope reviewer1,reviewer2]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Review (Specialist Parallel Review)

Use this skill to run a parallel code review with 7 specialist reviewers.
This is the standalone version of Phase 3 from the feature-lifecycle — usable independently on any branch/story.

## Triggers

- `/review` — review current branch
- `/review STORY-NNN` — review specific story
- `/review --scope security,qa` — run only specific reviewers

## Prerequisites

- Code must be committed (reviewers analyze committed code, not working tree changes)
- Branch should have changes relative to master (the diff is what gets reviewed)

## Workflow

### Step 1 — Detect Context

Determine what to review:

1. If argument is `STORY-NNN`, use that story number
2. If no argument, extract story number from current branch name (`feat/STORY-NNN-*`)
3. If `--scope` flag provided, run only the listed reviewers (comma-separated)
4. If no story number found, ask user

```bash
# Get current branch
git branch --show-current

# Get diff stats against master
git diff master --stat

# List modified files
git diff master --name-only
```

If no changes found relative to master, abort with message:

```
No changes found relative to master. Nothing to review.
```

### Step 2 — Determine Applicable Reviewers

Default: ALL 7 reviewers run in parallel.

| #   | Reviewer      | Agent File                | Output File                | Condition                  |
| --- | ------------- | ------------------------- | -------------------------- | -------------------------- |
| 1   | Security      | security-reviewer.md      | STORY-NNN-security.md      | Always                     |
| 2   | QA            | qa-reviewer.md            | STORY-NNN-qa.md            | Always                     |
| 3   | Performance   | performance-reviewer.md   | STORY-NNN-performance.md   | Always                     |
| 4   | Database      | database-reviewer.md      | STORY-NNN-database.md      | Always                     |
| 5   | Observability | observability-engineer.md | STORY-NNN-observability.md | Always                     |
| 6   | DevOps        | devops-engineer.md        | STORY-NNN-devops.md        | Always                     |
| 7   | API Design    | api-designer.md           | STORY-NNN-api.md           | Only if REST files changed |

To check if REST files are involved:

```bash
git diff master --name-only | grep -E '(Resource|rest|Rest|api)' || echo "NO_REST"
```

If `--scope` flag is provided, run ONLY the listed reviewers. Valid scope values:
`security`, `qa`, `performance`, `database`, `observability`, `devops`, `api`

### Step 3 — Launch Parallel Reviews

**CRITICAL: ALL Task calls MUST be in a SINGLE message for true parallelism.**

Each Task receives this prompt template (substitute `[AGENT_FILE]`, `[OUTPUT_FILE]`, `[STORY_ID]`):

```prompt
Read the file .claude/agents/[AGENT_FILE] to understand your role, checklist, and which rules to read.

IMPORTANT: The agent file contains a "Step 1" that lists the rules you MUST read before reviewing.
Read ALL rules listed in Step 1 of the agent file. They are your quality grading rubric.

Review the code implemented for [STORY_ID].

Context:
- Story: docs/stories/[STORY_ID].md (if exists)
- Plan: docs/plans/[STORY_ID]-plan.md (if exists)
- Code: src/main/java/com/bifrost/simulator/
- Tests: src/test/java/com/bifrost/simulator/
- Migrations: src/main/resources/db/migration/
- Config: src/main/resources/application.properties
- Rules: .claude/rules/ (as listed in Step 1 of the agent file)
- Diff: Run `git diff master` to see all changes

Produce your report in the format defined in the agent file.
Save to: docs/reviews/[OUTPUT_FILE]
```

All Tasks use `subagent_type: general-purpose` and `model: haiku`.

### Step 4 — Consolidate Results

After ALL agents return, read each report from `docs/reviews/STORY-NNN-*.md` and:

1. Extract from each report: **score**, **status**, and **failed items**
2. Print consolidated table:

```
+---------------+-------+--------------------+
|    Review     | Score |      Status        |
+---------------+-------+--------------------+
| Security      | XX/20 | Approved           |
+---------------+-------+--------------------+
| QA            | XX/24 | Approved           |
+---------------+-------+--------------------+
| Performance   | XX/26 | Adequate           |
+---------------+-------+--------------------+
| Database      | XX/16 | Approved           |
+---------------+-------+--------------------+
| Observability | XX/18 | Needs Work         |
+---------------+-------+--------------------+
| DevOps        | XX/20 | Approved           |
+---------------+-------+--------------------+
| API Design    | XX/16 | (if applicable)    |
+---------------+-------+--------------------+
Total: XXX/YYY (XX%)
```

3. List failed items grouped by reviewer:

```
Issues Found:

  Security (N issues):
    - [ID]: [description] (CRITICAL|MEDIUM|LOW)

  Performance (N issues):
    - [ID]: [description] (MEDIUM)

  Observability (N issues):
    - [ID]: [description] (CRITICAL)

  Database: No issues
  QA: No issues
  DevOps: No issues
```

4. Count by severity: `CRITICAL: N | MEDIUM: N | LOW: N`

### Step 5 — Summary

Print final summary:

```
Review complete for [STORY_ID].
Reports saved to docs/reviews/[STORY_ID]-*.md

CRITICAL: N | MEDIUM: N | LOW: N

If CRITICAL > 0: Corrections required before merge.
If only MEDIUM/LOW: Evaluate whether to fix now or in the next iteration.
```

## Scope Filter Reference

| Scope Value   | Reviewer               | Agent File                |
| ------------- | ---------------------- | ------------------------- |
| security      | Security Reviewer      | security-reviewer.md      |
| qa            | QA Reviewer            | qa-reviewer.md            |
| performance   | Performance Reviewer   | performance-reviewer.md   |
| database      | Database Reviewer      | database-reviewer.md      |
| observability | Observability Engineer | observability-engineer.md |
| devops        | DevOps Engineer        | devops-engineer.md        |
| api           | API Designer           | api-designer.md           |

## Output Artifacts

- `docs/reviews/STORY-NNN-security.md`
- `docs/reviews/STORY-NNN-qa.md`
- `docs/reviews/STORY-NNN-performance.md`
- `docs/reviews/STORY-NNN-database.md`
- `docs/reviews/STORY-NNN-observability.md`
- `docs/reviews/STORY-NNN-devops.md`
- `docs/reviews/STORY-NNN-api.md` (if applicable)

## Integration with Feature Lifecycle

This skill produces the SAME artifacts as Phase 3 of the feature-lifecycle.
If you run `/review` standalone and later run the full lifecycle, Phase 3 can be skipped
if the review reports already exist and the code hasn't changed since.
