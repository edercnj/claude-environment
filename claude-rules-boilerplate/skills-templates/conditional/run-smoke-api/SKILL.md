---
name: run-smoke-api
description: "Skill: REST API Smoke Tests — Runs automated smoke tests against the REST API using Newman/Postman. Supports local, container-orchestrated, and staging environments."
allowed-tools: Read, Bash
argument-hint: "[--env local|k8s|staging] [--k8s]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: REST API Smoke Tests (Newman)

## Description

Orchestrates black-box smoke tests against the application's REST API using Newman (Postman CLI). Tests run against a deployed environment to validate that critical endpoints respond correctly. Idempotent: each execution creates its own test data and cleans up after.

**Condition**: This skill applies when smoke_tests is enabled AND "rest" is in protocols.

## Prerequisites

- Newman installed: `npm install -g newman`
- Application deployed and accessible (local, {{ORCHESTRATOR}}, or remote)
- Health endpoint responding at `/health` or equivalent
- Postman collection file exists in `smoke-tests/api/`

## Execution Flow

1. **Verify prerequisites** — Check that Newman is installed:
   - Run `newman --version`
   - If missing, suggest: `npm install -g newman`

2. **Setup networking** (if --k8s):
   - Create port-forward to the application service
   - Register cleanup via trap EXIT

3. **Wait for health check** — Poll health endpoint:
   - Retry up to 30 times with 2s interval
   - If health check fails after retries, abort with exit code 2

4. **Run Newman collection** — Execute smoke tests:
   - Load Postman collection from `smoke-tests/api/`
   - Load environment file matching `--env` flag
   - Execute all requests in order
   - Capture results (pass/fail per scenario)

5. **Collect and report results**:
   - Total scenarios: passed / failed / skipped
   - CRITICAL scenarios: all must pass
   - HIGH scenarios: all must pass
   - MEDIUM scenarios: >= 80% must pass
   - Overall exit code: 0 (success), 1 (test failure), 2 (setup failure)

6. **Cleanup** — Automatic via trap EXIT:
   - Stop port-forward if started
   - Report final status

## Mandatory Scenarios

| Scenario           | Method | Expected Status | Criticality |
| ------------------ | ------ | --------------- | ----------- |
| Health/liveness    | GET    | 200             | CRITICAL    |
| Health/readiness   | GET    | 200             | CRITICAL    |
| Create resource    | POST   | 201             | CRITICAL    |
| List resources     | GET    | 200             | HIGH        |
| Get resource by ID | GET    | 200             | HIGH        |
| Update resource    | PUT    | 200             | HIGH        |
| Delete resource    | DELETE | 204             | HIGH        |
| Duplicate (409)    | POST   | 409             | MEDIUM      |
| Not found (404)    | GET    | 404             | MEDIUM      |
| Invalid payload    | POST   | 400             | MEDIUM      |

## Usage Examples

```
# Against local environment (already running on default port)
/run-smoke-api

# With automatic port-forward (orchestrator)
/run-smoke-api --k8s

# Against staging environment
/run-smoke-api --env staging
```

## Artifacts

| File                                          | Description                |
| --------------------------------------------- | -------------------------- |
| `smoke-tests/api/*.postman_collection.json`   | Newman test collection     |
| `smoke-tests/api/environment.local.json`      | Local environment config   |
| `smoke-tests/api/environment.*.json`          | Per-environment configs    |
| `smoke-tests/api/run-smoke-api.sh`            | Execution script           |

## Troubleshooting

| Problem                     | Likely Cause                   | Solution                            |
| --------------------------- | ------------------------------ | ----------------------------------- |
| `newman: command not found` | Newman not installed           | `npm install -g newman`             |
| Health check timeout        | App not started                | Check application logs              |
| 500 Internal Server Error   | Application bug                | Check application logs              |
| Unexpected 409              | Data from previous run         | Clean database or use unique IDs    |
| Connection refused          | Port-forward not active        | Use `--k8s` or start app manually   |
