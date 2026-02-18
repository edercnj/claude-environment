---
name: review-pr
description: "Use this skill to run a Tech Lead code review on a Pull Request or branch. Holistic 40-point rubric covering Clean Code, SOLID, Hexagonal Architecture, Quarkus conventions, tests, security, and cross-file consistency. Triggers include: /review-pr, tech lead review, PR review, final review, or when you need a senior-level holistic review before merge."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Task
argument-hint: "[PR-number or STORY-NNN]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Review PR (Tech Lead Review)

Use this skill to run a Tech Lead code review on a Pull Request or branch.
This is the standalone version of Phase 6 from the feature-lifecycle — usable independently.

The Tech Lead review is a holistic, senior-level review with a 40-point rubric covering:
Clean Code, SOLID, Hexagonal Architecture, Quarkus conventions, tests, security, and cross-file consistency.

## Triggers

- `/review-pr` — review current branch against master
- `/review-pr NNN` — review PR #NNN
- `/review-pr STORY-NNN` — review by story number

## Prerequisites

- Code must be committed
- Branch should have changes relative to master
- Ideally, specialist reviews (`/review`) have already been run (Tech Lead reads them for context)

## Workflow

### Step 1 — Detect Context

Determine what to review and set `[BASE_BRANCH]`:

#### Case A: PR number (e.g., `/review-pr 123`)

```bash
# Get PR metadata including base branch and head branch
gh pr view 123 --json title,body,baseRefName,headRefName,files

# Checkout the PR branch locally
gh pr checkout 123

# Set BASE_BRANCH from the PR's base ref (usually master, but read from PR metadata)
# e.g., BASE_BRANCH=master
```

#### Case B: STORY reference (e.g., `/review-pr STORY-015`)

```bash
# Find the branch by story number
git branch -a | grep -i 'STORY-015'

# Checkout the branch
git checkout feat/STORY-015-description

# BASE_BRANCH=master
```

#### Case C: No argument (current branch)

```bash
# Use current branch
git branch --show-current

# BASE_BRANCH=master
```

#### Validate diff exists

```bash
# Get diff stats against the resolved base
git diff [BASE_BRANCH] --stat

# List modified files
git diff [BASE_BRANCH] --name-only
```

If no changes found relative to `[BASE_BRANCH]`, abort with:

```
No changes found relative to [BASE_BRANCH]. Nothing to review.
```

Extract story number from branch name if possible (e.g., `feat/STORY-015-foo` → `STORY-015`).

### Step 2 — Gather Context (Pre-Read)

Before launching the Tech Lead agent, gather context files that exist:

```bash
# Check for specialist review reports
ls docs/reviews/STORY-NNN-*.md 2>/dev/null

# Check for plan
ls docs/plans/STORY-NNN-plan.md 2>/dev/null

# Check for common mistakes
ls docs/common-mistakes.md 2>/dev/null

# Check for test plan
ls docs/plans/STORY-NNN-tests.md 2>/dev/null
```

### Step 3 — Launch Tech Lead Review

Launch a **single** Task with `subagent_type: general-purpose` and `model: sonnet`.

Prompt template (substitute `[STORY_ID]`, `[BASE_BRANCH]`):

```prompt
You are the Tech Lead of the authorizer-simulator project.

Read the file .claude/agents/tech-lead.md to understand your complete 40-point checklist.

IMPORTANT: Read `.claude/rules/02-java-coding.md` IN FULL — it is your grading rubric.

Review the code for [STORY_ID] by doing:

1. List ALL modified files:
   git diff [BASE_BRANCH] --name-only

2. View the FULL diff (consolidated view):
   git diff [BASE_BRANCH]

3. For EACH .java file, read the FULL content and apply the 40-point checklist.

4. Pay special attention to:
   - CROSS-FILE issues (inconsistencies, cross imports, repeated patterns)
   - Holistic view: does the set make sense as a whole?

5. Compile and verify:
   mvn compile -Xlint:all
   mvn verify

6. If Phase 3 reviewer reports exist (docs/reviews/[STORY_ID]-*.md),
   read them for additional context. Verify that CRITICAL issues were fixed.

Context:
- Story: docs/stories/[STORY_ID].md (if exists)
- Plan: docs/plans/[STORY_ID]-plan.md (if exists)
- Reviews: docs/reviews/[STORY_ID]-*.md (if exist)
- Coverage: docs/reports/[STORY_ID]-coverage.md (if exists)
- Common mistakes: docs/common-mistakes.md (if exists)

Decision: GO (merge) or NO-GO (list required corrections)
Save to: docs/reviews/[STORY_ID]-tech-lead.md
```

### Step 4 — Process Result

After the Tech Lead agent returns:

1. Read the report from `docs/reviews/STORY-NNN-tech-lead.md`
2. Extract: **decision** (GO/CONDITIONAL GO/NO-GO), **score** (XX/40), **critical issues count**
3. Print summary:

```
============================================================
 TECH LEAD REVIEW — [STORY_ID]
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

### Step 5 — Handle NO-GO (Interactive)

If the result is NO-GO, ask the user:

```
Tech Lead returned NO-GO with N critical issues.

Options:
1. Fix critical issues now (I'll apply the corrections)
2. View the full report
3. Skip — I'll handle it manually
```

If user chooses to fix:

1. Read the critical issues from the report
2. Apply corrections to the code
3. Commit the fixes
4. Re-run the Tech Lead review (max 2 cycles)

## Rubric Summary (40 points)

| Section                  | Points | What it checks                                                            |
| ------------------------ | ------ | ------------------------------------------------------------------------- |
| A. Code Hygiene          | 8      | Unused imports/vars, dead code, warnings, method signatures, magic values |
| B. Naming                | 4      | Intention-revealing names, no disinformation, meaningful distinctions     |
| C. Functions             | 5      | Single responsibility, size <= 25 lines, max 4 params, no side effects    |
| D. Vertical Formatting   | 4      | Blank lines between concepts, Newspaper Rule, class size <= 250 lines     |
| E. Design                | 3      | Law of Demeter, CQS, DRY                                                  |
| F. Error Handling        | 3      | Rich exceptions, no null returns, no generic catch                        |
| G. SOLID + Architecture  | 5      | SRP, DIP, Hexagonal, follows plan, follows ADRs                           |
| H. Quarkus & Infra       | 4      | CDI, externalized config, native-compatible, OpenTelemetry                |
| I. Tests                 | 3      | Coverage thresholds, story scenarios covered, test quality                |
| J. Security & Production | 1      | Sensitive data protected, thread-safe                                     |

## Decision Criteria

| Condition                | Decision       |
| ------------------------ | -------------- |
| Zero critical + >= 34/40 | GO             |
| Zero critical + 30-33/40 | CONDITIONAL GO |
| Any critical OR < 30/40  | NO-GO          |

## Output Artifacts

- `docs/reviews/STORY-NNN-tech-lead.md`

## Integration with Feature Lifecycle

This skill produces the SAME artifact as Phase 6 of the feature-lifecycle.
If you run `/review-pr` standalone and later run the full lifecycle, Phase 6 can be skipped
if the tech lead report already exists with GO and the code hasn't changed since.

## Relationship with /review

- `/review` = specialist reviewers (7 agents, Haiku, parallel) — breadth
- `/review-pr` = Tech Lead (1 agent, Sonnet, holistic) — depth

Recommended workflow:

1. Run `/review` first to catch domain-specific issues
2. Fix critical issues found by specialists
3. Run `/review-pr` for final holistic review
