---
name: run-smoke-api
description: "Skill: Smoke Test API (Newman) — Runs automated smoke tests against the simulator's REST API using Newman/Postman in a Kubernetes environment."
allowed-tools: Read, Bash, TodoWrite
argument-hint: "[--env local|minikube|staging] [--k8s]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Smoke Test API (Newman)

## Description

Orchestrates the execution of smoke tests against the simulator's REST API using Newman (Postman CLI).
Validates that the application works correctly in a Kubernetes environment (local Minikube or remote cluster).

## Prerequisites

- Newman installed: `npm install -g newman`
- Kubernetes (Minikube) running with the simulator deployed
- kubectl installed (if using `--k8s`)
- REST endpoints implemented (STORY-009)

## Execution Flow

```
1. Verify prerequisites (newman, kubectl)
2. Setup K8s port-forward (if --k8s)
3. Wait for health check (/q/health/ready)
4. Run Newman with the collection
5. Collect and report results
6. Cleanup port-forward (automatic via trap EXIT)
7. Report exit code
```

## How to Use

### Standard Execution (port-forward already active)

```bash
cd /path/to/authorizer-simulator
./smoke-tests/api/run-smoke-api.sh
```

### With Automatic Port-Forward (Minikube)

```bash
./smoke-tests/api/run-smoke-api.sh --k8s
```

### Against Staging

```bash
./smoke-tests/api/run-smoke-api.sh --env staging
```

### Via dev-setup.sh

```bash
./scripts/dev-setup.sh --smoke
```

## Integration with Feature Lifecycle

This skill can be invoked after Phase 5 (Commit & PR) of the feature lifecycle
to validate that the application works in a real environment before the Tech Lead review.

### Invocation in Lifecycle (Phase 5.5 — Smoke Test)

```prompt
After creating the PR and before the Tech Lead Review:

1. Verify Newman is installed:
   npm list -g newman || npm install -g newman

2. Run smoke tests (with automatic port-forward):
   ./smoke-tests/api/run-smoke-api.sh --k8s

3. Report result:
   - If exit code 0 → Smoke tests passed, proceed to Tech Lead Review
   - If exit code 1 → Tests failed, investigate and fix before review
   - If exit code 2 → Environment didn't start, check pods: kubectl -n bifrost-simulator get pods
```

## Artifacts

| File                                                           | Description                                                      |
| -------------------------------------------------------------- | ---------------------------------------------------------------- |
| `smoke-tests/api/authorizer-simulator.postman_collection.json` | Newman collection with all scenarios                             |
| `smoke-tests/api/environment.local.json`                       | Environment for localhost                                        |
| `smoke-tests/api/environment.minikube.json`                    | Environment for Minikube (port-forward)                          |
| `smoke-tests/api/environment.staging.json`                     | Environment for staging K8S                                      |
| `smoke-tests/api/run-smoke-api.sh`                             | Execution script (supports `--k8s`)                              |
| `.claude/rules/22-smoke-tests.md`                              | Rule with smoke test contract                                    |
| `.claude/rules/24-resilience.md`                               | Resilience patterns (rate limiting → 429, circuit breaker → 503) |

## Covered Scenarios

| Group           | Scenarios                                    | Criticality   |
| --------------- | -------------------------------------------- | ------------- |
| Health Checks   | Liveness, Readiness                          | CRITICAL      |
| Merchants CRUD  | Create, List, Find, Update, Delete           | CRITICAL/HIGH |
| Terminals CRUD  | Create, List, Find, Update                   | CRITICAL/HIGH |
| Error Scenarios | 409 Duplicate, 404 Not Found, 400 Validation | MEDIUM        |
| Cleanup         | Delete + Verify Deletion                     | HIGH          |

## Troubleshooting

| Problem                     | Likely Cause                             | Solution                                                                                       |
| --------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `newman: command not found` | Newman not installed                     | `npm install -g newman`                                                                        |
| Health check timeout        | App not started or port-forward inactive | Check pods: `kubectl -n bifrost-simulator get pods`                                            |
| 500 Internal Server Error   | Application bug                          | Check logs: `kubectl -n bifrost-simulator logs -l app.kubernetes.io/name=authorizer-simulator` |
| Unexpected 409              | Data from previous run                   | Clean database or use unique IDs (already done)                                                |
| Connection refused          | Port-forward not active                  | Use `--k8s` or `./scripts/dev-setup.sh --start`                                                |
