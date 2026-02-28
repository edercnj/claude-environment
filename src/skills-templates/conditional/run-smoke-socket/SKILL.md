---
name: run-smoke-socket
description: "Skill: TCP Socket Smoke Tests — Runs automated smoke tests against the TCP socket server using a standalone Java client with message framing and protocol validation."
allowed-tools: Read, Bash
argument-hint: "[--scenario echo|all] [--k8s] [--host <host>] [--port <port>]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: TCP Socket Smoke Tests

## Description

Orchestrates black-box smoke tests against the application's TCP socket server using a standalone Java client. The client speaks the real wire protocol with proper message framing (length-prefix header). Tests validate that the server correctly receives messages, processes them, and returns valid responses over persistent TCP connections.

**Condition**: This skill applies when smoke_tests is enabled AND "tcp-custom" is in protocols.

## Prerequisites

- Java 21+ installed
- Client JAR built: `cd smoke-tests/socket && {{BUILD_COMMAND}}`
- Application deployed and accessible (local or {{ORCHESTRATOR}})
- TCP socket listening on configured port

## Available Scenarios

| Scenario               | Flag               | Description                                  |
| ---------------------- | ------------------ | -------------------------------------------- |
| Echo/Ping              | `echo`             | Basic connectivity and response validation   |
| Request Approved       | `request-approved` | Standard request with successful response    |
| Request Denied         | `request-denied`   | Request triggering a denial/error response   |
| Malformed Message      | `malformed`        | Invalid bytes, expects error response        |
| Persistent Connection  | `persistent`       | Multiple messages on same TCP connection     |
| All                    | `all`              | Runs all scenarios sequentially              |

## Execution Flow

1. **Verify prerequisites**:
   - Check Java version: `java --version`
   - Check client JAR exists in `smoke-tests/socket/target/`
   - If JAR missing, suggest build command

2. **Setup networking** (if --k8s):
   - Create port-forward for both HTTP (health) and TCP (socket) ports
   - Register cleanup via trap EXIT

3. **Wait for health check** — Poll HTTP health endpoint:
   - Retry up to 30 times with 2s interval
   - Abort with exit code 2 if health check fails

4. **Run scenarios** — Execute Java client JAR:
   - Pass `--scenario` flag (default: `all`)
   - Pass `--host` and `--port` for target server
   - Each scenario: connect, send message, validate response, report

5. **Collect and report results**:
   - Per-scenario: PASS / FAIL with details
   - CRITICAL scenarios: all must pass
   - HIGH scenarios: all must pass
   - Overall exit code: 0 (success), 1 (test failure), 2 (setup failure), 3 (JAR not found)

6. **Cleanup** — Automatic via trap EXIT:
   - Stop port-forwards if started

## Usage Examples

```
# All scenarios against local environment
/run-smoke-socket

# With automatic port-forward (orchestrator)
/run-smoke-socket --k8s

# Specific scenario
/run-smoke-socket --k8s --scenario echo

# Custom host/port
/run-smoke-socket --host 10.0.0.1 --port 8583
```

## Artifacts

| File                                        | Description                       |
| ------------------------------------------- | --------------------------------- |
| `smoke-tests/socket/pom.xml`               | Client build file (executable JAR)|
| `smoke-tests/socket/src/`                  | Java client source code           |
| `smoke-tests/socket/run-smoke-socket.sh`   | Execution script                  |

## Client Architecture

- `SmokeTestRunner` — Main class: arg parsing, scenario dispatch, result aggregation
- `SmokeSocketClient` — TCP client wrapper with length-prefix framing (send/receive)
- `SmokeScenario` — Sealed interface for scenario implementations
- `ScenarioResult` — Record: pass/fail + message

## Troubleshooting

| Problem                       | Likely Cause                 | Solution                                     |
| ----------------------------- | ---------------------------- | -------------------------------------------- |
| JAR not found                 | Client not built             | `cd smoke-tests/socket && {{BUILD_COMMAND}}` |
| Connection refused (TCP)      | Port-forward not active      | Use `--k8s` or start app manually            |
| Connection refused (HTTP)     | HTTP port-forward not active | Check orchestrator service status             |
| Unexpected response           | Protocol or logic bug        | Check application logs                        |
| Message parse failure         | Framing or encoding mismatch | Verify length-prefix and encoding config      |
