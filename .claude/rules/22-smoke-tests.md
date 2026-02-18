# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 22 — Smoke Tests (External Validation)

## Principles
- **Black-box testing:** Smoke test treats the application as a black box
- **Real environment:** Tests run against a Kubernetes environment (local Minikube or remote cluster)
- **Complementary:** Does not replace unit tests or integration tests — it is an additional layer
- **Idempotent:** Each execution creates its own test data and cleans up at the end
- **Fail-fast:** If health check does not respond, abort immediately

## When to Run

| Moment | Mandatory | Responsible |
|--------|-----------|-------------|
| Before merge (post `mvn verify`) | On demand | Developer (via skill) |
| CI/CD pipeline | Recommended | Automatic pipeline |
| Pre-deploy to staging | Recommended | DevOps |
| Post-deploy to production | Optional (health checks only) | DevOps |

> **Note:** Initially smoke tests are executed on demand. As maturity increases, promote to mandatory in feature lifecycle.

## Smoke Tests REST API (Newman)

### Structure
```
smoke-tests/
└── api/
    ├── authorizer-simulator.postman_collection.json
    ├── environment.local.json
    ├── environment.minikube.json
    ├── environment.staging.json
    └── run-smoke-api.sh
```

### Execution
```bash
# Prerequisite: npm install -g newman

# Run against local environment (already running on port 8080)
./smoke-tests/api/run-smoke-api.sh

# Run against Minikube with automatic port-forward
./smoke-tests/api/run-smoke-api.sh --k8s

# Run against staging
./smoke-tests/api/run-smoke-api.sh --env staging

# Via dev-setup.sh (requires Minikube running)
./scripts/dev-setup.sh --smoke
```

### Mandatory Scenarios (REST API)

| Scenario | Endpoint | Expected Status | Criticality |
|----------|----------|-----------------|-------------|
| Liveness probe | `GET /q/health/live` | 200 | CRITICAL |
| Readiness probe | `GET /q/health/ready` | 200 | CRITICAL |
| Create merchant | `POST /api/v1/merchants` | 201 | CRITICAL |
| List merchants | `GET /api/v1/merchants` | 200 | HIGH |
| Fetch merchant | `GET /api/v1/merchants/{id}` | 200 | HIGH |
| Update merchant | `PUT /api/v1/merchants/{id}` | 200 | HIGH |
| Delete merchant | `DELETE /api/v1/merchants/{id}` | 204 | HIGH |
| Create terminal | `POST /api/v1/merchants/{id}/terminals` | 201 | CRITICAL |
| List terminals | `GET /api/v1/merchants/{id}/terminals` | 200 | HIGH |
| Fetch terminal | `GET /api/v1/terminals/{tid}` | 200 | HIGH |
| Update terminal | `PUT /api/v1/terminals/{tid}` | 200 | HIGH |
| Duplicate MID | `POST /api/v1/merchants` | 409 | MEDIUM |
| Nonexistent merchant | `GET /api/v1/merchants/999999` | 404 | MEDIUM |
| Invalid payload | `POST /api/v1/merchants` | 400 | MEDIUM |
| Duplicate TID | `POST /api/v1/merchants/{id}/terminals` | 409 | MEDIUM |
| Nonexistent terminal | `GET /api/v1/terminals/NOTEXIST` | 404 | MEDIUM |

### Success Criteria
- **100% of CRITICAL scenarios** must pass
- **100% of HIGH scenarios** must pass
- **≥ 80% of MEDIUM scenarios** must pass
- **Exit code 0** from Newman

## Smoke Tests Socket ISO 8583 (STORY-014)

### Structure
```
smoke-tests/
└── socket/
    ├── pom.xml                                     # Build of client (fat JAR)
    ├── run-smoke-socket.sh                         # Script with --k8s support
    └── src/main/java/com/bifrost/smoke/
        ├── SmokeTestRunner.java                    # Main: arg parsing, dispatch, results
        ├── SmokeSocketClient.java                  # TCP client: 2-byte framing, send/receive
        └── scenario/
            ├── SmokeScenario.java                  # Sealed interface for scenarios
            ├── ScenarioResult.java                 # Record: pass/fail + message
            ├── IsoMessageHelper.java               # Packer/unpacker b8583 (package-private)
            ├── EchoTestScenario.java               # 1804 → 1814, RC=00
            ├── DebitApprovedScenario.java           # 1200 → 1210, RC=00 (cents .00)
            ├── DebitDeniedScenario.java             # 1200 → 1210, RC=51 (cents .51)
            ├── ReversalScenario.java                # 1420 → 1430, RC=00
            ├── TimeoutScenario.java                 # REST setup + 1200 → 1210 (delay ≥30s)
            ├── MalformedMessageScenario.java        # Garbage bytes → RC=96, connection alive
            └── PersistentConnectionScenario.java    # 5 msgs on same TCP socket
```

### Execution
```bash
# Prerequisite: JAR built (cd smoke-tests/socket && mvn package -DskipTests)

# Run against local environment (already running on ports 8080 and 8583)
./smoke-tests/socket/run-smoke-socket.sh

# Run against Minikube with automatic port-forward
./smoke-tests/socket/run-smoke-socket.sh --k8s

# Run specific scenario
./smoke-tests/socket/run-smoke-socket.sh --k8s --scenario echo

# Run against custom host/port
./smoke-tests/socket/run-smoke-socket.sh --host 10.0.0.1 --port 8583

# Via dev-setup.sh (requires Minikube running)
./scripts/dev-setup.sh --smoke-socket
```

### Mandatory Scenarios (Socket)

| Scenario | MTI | Expected Response | Criticality |
|----------|-----|-------------------|-------------|
| Echo test | 1804 → 1814 | RC 00 | CRITICAL |
| Debit purchase approved (.00) | 1200 → 1210 | RC 00 | CRITICAL |
| Debit purchase denied (.51) | 1200 → 1210 | RC 51 | CRITICAL |
| Reversal | 1420 → 1430 | RC 00 | HIGH |
| Timeout (RULE-002) | 1200 → 1210 | RC 00 (after delay) | HIGH |
| Malformed message | — | RC 96 | MEDIUM |
| Multiple messages (same connection) | Various | All responded | HIGH |

### Implementation (STORY-014)

**Architecture:**
- `SmokeScenario` is a **sealed interface** with 7 implementations (one per scenario)
- `IsoMessageHelper` encapsulates `IsoPacker`/`IsoUnpacker` from lib `b8583` (BASE_1993)
- `SmokeSocketClient` is a wrapper around `Socket` with 2-byte big-endian framing
- `SmokeTestRunner` is the main class: parses CLI args, dispatches scenarios, aggregates results
- The `timeout` scenario creates merchant/terminal via REST API (`HttpClient`) with `forceTimeout=true`
- The `malformed` scenario sends invalid bytes and verifies that the connection stays open
- The `persistent` scenario sends 5 messages alternating echo/debit on the same TCP connection

**Build:**
```bash
cd smoke-tests/socket && mvn package -DskipTests
# Produces: smoke-tests/socket/target/smoke-socket.jar (fat JAR with b8583)
```

**Scenario `--scenario` flags:**
`echo`, `debit-approved`, `debit-denied`, `reversal`, `timeout`, `malformed`, `persistent`, `all`

## Newman — Conventions

### Collection
- One collection per functional domain (REST API, future APIs)
- Requests grouped in folders by functionality
- Each request has `test` scripts with assertions
- Dynamic data generated via `pre-request` scripts
- Collection variables to chain requests (IDs created in POST used in GET/PUT/DELETE)

### Environments
- One `.json` file per environment
- Only `baseUrl` as environment variable (others are collection variables)
- Naming: `environment.{name}.json`

### Execution Scripts
- Naming: `run-smoke-{type}.sh`
- Support flags: `--k8s`, `--env {name}`, `--timeout {seconds}`
- `--k8s` automatically creates port-forward for local K8s cluster (Minikube)
- Socket script: `--k8s` creates port-forward for **both** ports (8080 HTTP + 8583 ISO)
- Socket script: `--scenario {name}` allows running specific scenario
- Standardized exit codes: 0 (success), 1 (test failure), 2 (setup failure), 3 (JAR not found, socket only)
- Always wait for health check before running
- Automatic port-forward cleanup via `trap EXIT`

## Resilience Scenarios (Rule 24)

When resilience patterns are implemented, the following smoke tests MUST be added:

| Scenario | Channel | Expected Response | Criticality |
|----------|---------|-------------------|-------------|
| Rate limit exceeded (TCP) | Socket | RC 96 | HIGH |
| Rate limit exceeded (REST) | REST | 429 Too Many Requests | HIGH |
| Circuit breaker open (DB down) | Socket | RC 96 (fail secure) | CRITICAL |
| Circuit breaker open (DB down) | REST | 503 Service Unavailable | CRITICAL |
| EMERGENCY degradation | Socket | Echo only (1804→1814), others RC 96 | HIGH |

> See **Rule 24 — Application Resilience** for details on each pattern.

## Anti-Patterns
- ❌ Smoke tests that depend on pre-existing data in database
- ❌ Running smoke tests without waiting for health check
- ❌ Smoke tests that modify production data without cleanup
- ❌ Fragile assertions (validate exact fields that change, like timestamps)
- ❌ Using smoke tests as substitute for unit tests
- ❌ Collection with interdependent requests without explicit order
