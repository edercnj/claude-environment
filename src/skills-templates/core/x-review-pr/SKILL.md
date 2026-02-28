---
name: x-review-pr
description: "Tech Lead holistic review with 40-point checklist covering Clean Code, SOLID, architecture, framework conventions, tests, security, and cross-file consistency. Produces GO/NO-GO decision. Use for final review before merge."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[PR-number or STORY-ID]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Review PR (Tech Lead Review)

## Description

Senior-level holistic review with a 40-point rubric. This is the standalone version of Phase 6 from the x-dev-lifecycle. The Tech Lead reviews the consolidated PR diff for cross-file consistency and overall quality.

## Triggers

- `/x-review-pr` -- review current branch against main
- `/x-review-pr NNN` -- review PR #NNN
- `/x-review-pr STORY-ID` -- review by story ID

## Prerequisites

- Code must be committed
- Branch should have changes relative to main
- Ideally, specialist reviews (`/x-review`) have already been run

## Workflow

### Step 1 -- Detect Context

Determine what to review and set `[BASE_BRANCH]`:

- **PR number:** `gh pr view NNN --json title,body,baseRefName,headRefName,files`
- **STORY reference:** Find and checkout the branch
- **No argument:** Use current branch, `BASE_BRANCH=main`

Validate diff exists:
```bash
git diff [BASE_BRANCH] --stat
git diff [BASE_BRANCH] --name-only
```

### Step 2 -- Gather Context

Read knowledge packs to calibrate the review:
- `skills/coding-standards/references/coding-conventions.md` — {{LANGUAGE}} naming, injection, mapper conventions
- `skills/architecture/references/architecture-principles.md` — layer boundaries, dependency direction
- `rules/05-quality-gates.md` — coverage thresholds, merge checklist

Check for existing artifacts:
- Specialist review reports (`docs/reviews/STORY-ID-*.md`)
- Implementation plan (`docs/plans/STORY-ID-plan.md`)
- Test plan (`docs/plans/STORY-ID-tests.md`)
- Common mistakes document

### Step 3 -- Execute Tech Lead Review

The Tech Lead review covers:

1. List ALL modified files: `git diff [BASE_BRANCH] --name-only`
2. View FULL diff: `git diff [BASE_BRANCH]`
3. For EACH source file, read FULL content and apply 40-point checklist
4. Focus on CROSS-FILE issues (inconsistencies, cross imports, repeated patterns)
5. Compile and verify: `{{COMPILE_COMMAND}}` + `{{BUILD_COMMAND}}`
6. If specialist reports exist, verify CRITICAL issues were fixed

## 40-Point Rubric

| Section                  | Points | What it checks                                                      |
| ------------------------ | ------ | ------------------------------------------------------------------- |
| A. Code Hygiene          | 8      | Unused imports/vars, dead code, warnings, method signatures, magic  |
| B. Naming                | 4      | Intention-revealing, no disinformation, meaningful distinctions      |
| C. Functions             | 5      | Single responsibility, size <= 25 lines, max 4 params, no flags     |
| D. Vertical Formatting   | 4      | Blank lines between concepts, Newspaper Rule, class size <= 250     |
| E. Design                | 3      | Law of Demeter, CQS, DRY                                           |
| F. Error Handling        | 3      | Rich exceptions, no null returns, no generic catch                  |
| G. Architecture          | 5      | SRP, DIP, architecture layer boundaries (per project rules), follows plan |
| H. Framework & Infra     | 4      | DI, externalized config, native-compatible, observability           |
| I. Tests                 | 3      | Coverage thresholds, scenarios covered, test quality                |
| J. Security & Production | 1      | Sensitive data protected, thread-safe                               |

## Decision Criteria

| Condition                   | Decision        |
| --------------------------- | --------------- |
| Zero critical + >= 34/40    | GO              |
| Zero critical + 30-33/40    | CONDITIONAL GO  |
| Any critical OR < 30/40     | NO-GO           |

### Step 4 -- Process Result

```
============================================================
 TECH LEAD REVIEW -- [STORY_ID]
============================================================
 Decision:  GO | CONDITIONAL GO | NO-GO
 Score:     XX/40
 Critical:  N issues
 Medium:    N issues
 Low:       N issues
------------------------------------------------------------
 Report: docs/reviews/[STORY_ID]-tech-lead.md
============================================================
```

### Step 5 -- Handle NO-GO

If NO-GO, offer options:
1. Fix critical issues now
2. View the full report
3. Skip -- handle manually

If fixing: apply corrections, commit, re-run review (max 2 cycles).

## Output Artifacts

- `docs/reviews/STORY-ID-tech-lead.md`

## Integration Notes

- This skill produces the SAME artifact as Phase 6 of `x-dev-lifecycle`
- Recommended workflow: `/x-review` first (breadth), then `/x-review-pr` (depth)
- `/x-review` = specialist engineers (7 agents, parallel) -- breadth
- `/x-review-pr` = Tech Lead (1 agent, holistic) -- depth
