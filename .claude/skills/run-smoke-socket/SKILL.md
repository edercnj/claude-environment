---
name: run-smoke-socket
description: "Skill: Smoke Test Socket (ISO 8583) — Runs automated smoke tests against the simulator's TCP socket using a standalone Java client with the b8583 library."
allowed-tools: Read, Bash, TodoWrite
argument-hint: "[--scenario echo|debit-approved|debit-denied|reversal|timeout|malformed|persistent|all] [--k8s]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Smoke Test Socket (ISO 8583)

## Description

Orchestrates the execution of smoke tests against the simulator's ISO 8583 TCP socket using a standalone Java client that speaks the real protocol (2-byte framing + ISO 8583 messages via the b8583 library). Tests run against a Kubernetes environment (local Minikube or remote cluster).

## Prerequisites

- Java 21+ installed
- Client JAR built: `cd smoke-tests/socket && mvn package -DskipTests`
- Kubernetes (Minikube) running with the simulator deployed
- kubectl installed (if using `--k8s`)
- TCP socket implemented (STORY-001)
- Decision Engine implemented (STORY-002)

## Available Scenarios

| Scenario       | Flag             | MTI       | Validation                |
| -------------- | ---------------- | --------- | ------------------------- |
| Echo Test      | `echo`           | 1804→1814 | RC=00, fields echoed      |
| Debit Approved | `debit-approved` | 1200→1210 | RC=00, DE-38 present      |
| Debit Denied   | `debit-denied`   | 1200→1210 | RC=51 (cents .51)         |
| Reversal       | `reversal`       | 1420→1430 | RC=00                     |
| Timeout        | `timeout`        | 1200→1210 | Response after ~35s       |
| Malformed      | `malformed`      | —         | RC=96, connection open    |
| Persistent     | `persistent`     | Various   | 5 msgs on same connection |
| All            | `all`            | All       | All scenarios             |

## How to Use

### Build the Client

```bash
cd smoke-tests/socket
mvn package -DskipTests
```

### Execution

```bash
# All scenarios, environment already running (port-forward active)
./smoke-tests/socket/run-smoke-socket.sh

# With automatic K8s port-forward (Minikube)
./smoke-tests/socket/run-smoke-socket.sh --k8s

# Specific scenario with K8s
./smoke-tests/socket/run-smoke-socket.sh --k8s --scenario echo

# Custom host/port (remote cluster)
./smoke-tests/socket/run-smoke-socket.sh --host 10.0.0.1 --port 8583

# Via dev-setup.sh (requires Minikube running)
./scripts/dev-setup.sh --smoke-socket
```

## Integration with Feature Lifecycle

This skill is invoked in **Phase 5.5** of the feature lifecycle for stories involving the TCP socket:

```prompt
After creating the PR and before the Tech Lead Review:

1. Build the client (if not already built):
   cd smoke-tests/socket && mvn package -DskipTests

2. Run smoke tests (with automatic port-forward):
   ./smoke-tests/socket/run-smoke-socket.sh --k8s

3. Report result in the PR body (Smoke Tests section)
```

## Artifacts

| File                                        | Description                                                          |
| ------------------------------------------- | -------------------------------------------------------------------- |
| `smoke-tests/socket/pom.xml`                | Client build (executable JAR)                                        |
| `smoke-tests/socket/src/`                   | Java client source code                                              |
| `smoke-tests/socket/run-smoke-socket.sh`    | Execution script (supports `--k8s`)                                  |
| `.claude/rules/22-smoke-tests.md`           | Rule with contract                                                   |
| `.claude/rules/24-resilience.md`            | Resilience patterns (rate limiting → RC 96, circuit breaker → RC 96) |
| `.claude/skills/run-smoke-socket/SKILL.md` | This file                                                            |

## Troubleshooting

| Problem                       | Likely Cause                 | Solution                                                                                                    |
| ----------------------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `smoke-socket.jar not found`  | Client not built             | `cd smoke-tests/socket && mvn package`                                                                      |
| `Connection refused` (8583)   | Port-forward not active      | Use `--k8s` or `./scripts/dev-setup.sh --start`                                                             |
| `Connection refused` (8080)   | HTTP port-forward not active | Check `kubectl -n bifrost-simulator get pods`                                                               |
| Timeout on `timeout` scenario | Normal if > 35s              | Verify it does not exceed 60s                                                                               |
| Unexpected RC                 | Decision Engine bug          | Check RULE-001 and logs: `kubectl -n bifrost-simulator logs -l app.kubernetes.io/name=authorizer-simulator` |
| Message does not parse        | Dialect incompatibility      | Check ISO version and encoding config                                                                       |
