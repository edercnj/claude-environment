---
name: review
description: "Parallel code review with specialist engineers (Security, QA, Performance, Database, Observability, DevOps, API, Event). Launches parallel subagents, each reading their own knowledge pack, then consolidates into a scored report. Use for pre-PR quality validation."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[STORY-ID or --scope reviewer1,reviewer2]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Review (Specialist Parallel Review)

## Triggers

- `/review` -- review current branch
- `/review STORY-ID` -- review specific story
- `/review --scope security,qa` -- run only specific reviewers

## Execution Flow (Orchestrator Pattern)

```
1. DETECT     -> Identify branch, diff, applicable engineers (inline)
2. REVIEW     -> Launch N parallel subagents, one per engineer (SINGLE message)
3. CONSOLIDATE -> Collect reports, score, summarize (inline)
```

## Phase 1: Detect Context (Orchestrator — Inline)

1. Extract story ID from argument or branch name
2. Get diff against main:
   ```bash
   git branch --show-current
   git diff main --stat
   git diff main --name-only
   ```
3. If no changes, abort: `No changes found relative to main.`
4. Determine applicable engineers:

**Always active:** Security, QA, Performance

**Conditional:**

| Engineer | Condition |
|----------|-----------|
| Database | database/cache != none |
| Observability | observability != none |
| DevOps | container/orchestrator/iac != none |
| API | interfaces contain protocol types |
| Event | event_driven or event interfaces |

If `--scope` provided, filter to listed engineers only.

## Phase 2: Parallel Reviews (Subagents via Task Tool)

**CRITICAL: ALL review subagents MUST be launched in a SINGLE message for true parallelism.**

Launch one `general-purpose` subagent per applicable engineer.

### Subagent: Specialist Engineer Review

**Prompt template (substitute `{ENGINEER}`, `{KP_PATHS}`, `{DIFF}`, `{STORY_ID}`, `{CHECKLIST}`):**

> You are a **{ENGINEER} Engineer** performing a specialist code review.
>
> **Step 1 — Read Knowledge Pack:**
> Read these files to understand the standards: {KP_PATHS}
>
> **Step 2 — Review the Diff:**
> Run `git diff main` and review all changes against the standards you just read.
>
> **Step 3 — Score & Report:**
> Apply the following checklist and score each item (0 = fail, 1 = partial, 2 = pass):
>
> {CHECKLIST}
>
> **Output format (strict):**
> ```
> ENGINEER: {ENGINEER}
> STORY: {STORY_ID}
> SCORE: XX/YY
> STATUS: Approved | Request Changes
> ---
> PASSED:
> - [ID] Description (2/2)
> FAILED:
> - [ID] Description (0/2) — file:line — Fix: suggestion [CRITICAL|MEDIUM|LOW]
> PARTIAL:
> - [ID] Description (1/2) — file:line — Improvement: suggestion [MEDIUM|LOW]
> ```

### Engineer → Knowledge Pack Mapping

| Engineer | KP Paths to Read |
|----------|-----------------|
| Security | `skills/security/SKILL.md` → then read `references/application-security.md`, `references/cryptography.md` |
| QA | `skills/testing/references/testing-philosophy.md`, `skills/testing/references/testing-conventions.md` |
| Performance | `skills/resilience/references/resilience-principles.md` |
| Database | `skills/database-patterns/SKILL.md` → then read files listed in references/ |
| Observability | `skills/observability/references/observability-principles.md` |
| DevOps | `skills/infrastructure/references/infrastructure-principles.md` |
| API | `skills/api-design/references/api-design-principles.md` + relevant protocol ref from `skills/protocols/references/` |
| Event | `skills/protocols/references/event-driven-conventions.md` |

### Engineer Checklists (include in subagent prompt)

**Security (10 items, /20):** Input validation, output encoding, authentication checks, authorization checks, sensitive data masking, error handling (no stack traces), cryptography usage, dependency vulnerabilities, CORS/CSP headers, audit logging.

**QA (12 items, /24):** Test exists for each AC, line coverage ≥95%, branch coverage ≥90%, test naming convention, AAA pattern, parametrized tests for data-driven, exception paths tested, no test interdependency, fixtures centralized, unique test data, edge cases, integration tests for DB/API.

**Performance (13 items, /26):** No N+1 queries, connection pool sized, async where applicable, pagination on collections, caching strategy, no unbounded lists, timeout on external calls, circuit breaker on external, thread safety, resource cleanup, lazy loading, batch operations, index usage.

**Database (8 items, /16):** Migration reversible, indexes for query patterns, no SELECT *, audit columns, entity lifecycle callbacks, optimistic locking, connection pool config, query performance.

**Observability (9 items, /18):** Root span per request, child spans for sub-ops, mandatory span attributes, metrics (counter+histogram+gauge), structured JSON logging, trace-log correlation, health checks (liveness+readiness+startup), no sensitive data in traces/logs, sampling configured.

**DevOps (10 items, /20):** Multi-stage Dockerfile, non-root user, health check in container, resource limits in K8s, security context, probes configured, config externalized, secrets via vault/sealed-secrets, CI pipeline passing, image scanning.

**API (8 items, /16):** RESTful URLs (nouns, versioned), correct status codes, RFC 7807 errors, pagination on lists, request validation, response DTOs (no entities), OpenAPI documented, rate limiting.

**Event (14 items, /28):** Past tense event names, CloudEvents envelope, schema registered, idempotent consumer, dead letter topic, no sensitive data in payload, event after business op, trace context in headers, consumer lag monitored, graceful shutdown, outbox or at-least-once, offset commit after processing, deserialization error handling, processing timeout.

## Phase 3: Consolidation (Orchestrator — Inline)

### 3a. Collect & Score

Parse each subagent's output. Build consolidated table:

```
+---------------+-------+--------------------+
|    Review     | Score |      Status        |
+---------------+-------+--------------------+
| Security      | XX/20 | Approved           |
| QA            | XX/24 | Request Changes    |
| ...           | ...   | ...                |
+---------------+-------+--------------------+
Total: XXX/YYY (XX%)
```

### 3b. Issue Summary

Group by severity: `CRITICAL: N | MEDIUM: N | LOW: N`

```
CRITICAL > 0 → Corrections required before merge.
Only MEDIUM/LOW → Evaluate whether to fix now or defer.
```

### 3c. Save Artifacts

Save each engineer's report to `docs/reviews/{STORY_ID}-{engineer}.md`.

## Integration Notes

- Produces the SAME artifacts as Phase 3 of `feature-lifecycle`
- If run standalone, Phase 3 of lifecycle can be skipped if reports exist and code unchanged
- Recommended flow: `/review` → fix criticals → `/review-pr` for final holistic review
