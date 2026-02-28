# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 03 — Testing Philosophy

## Coverage Thresholds

| Metric | Minimum |
|--------|---------|
| Line Coverage | >= 95% |
| Branch Coverage | >= 90% |

These thresholds are enforced by the coverage tool and are non-negotiable. Untested code does not ship.

## Naming Convention

```
[methodUnderTest]_[scenario]_[expectedBehavior]
```

Examples:
- `processDebit_approvedAmount_returnsRC00`
- `parseReversal_missingOriginalData_throwsException`
- `findMerchant_nonExistentId_returnsEmpty`
- `createMerchant_validPayload_returns201`

## Test Categories

### 1. Unit Tests (domain + business logic)
- Test domain models, decision engines, business rules
- No mocking of domain logic — use real objects
- Mocking PERMITTED only for: external clients, network services, clock/time
- Parametrized tests for business rules with multiple inputs/outputs

### 2. Integration Tests (application + database)
- Test real database interactions
- Use in-memory database for speed when compatible (e.g., H2 with PostgreSQL mode, SQLite)
- Use real database (via containers) when in-memory is insufficient
- Each test should be isolated — automatic rollback per test

### 3. API Tests (REST / GraphQL / gRPC)
- Test HTTP endpoints end-to-end within the framework
- Validate: status codes, response bodies, headers, error formats
- Use framework-provided test utilities (not raw HTTP clients)

### 4. Protocol Tests (TCP / WebSocket / custom)
- Test protocol-level communication (framing, encoding, handshake)
- Use test client utilities that mirror real protocol behavior
- Verify: connection persistence, error recovery, timeout handling

### 5. Contract Tests (parametrized)
- Test business rules exhaustively via parametrized inputs
- Example: cents-based decisions, pricing tiers, validation rules
- Each row in the parameter table represents a documented business scenario

### 6. End-to-End Tests (full flow)
- Test complete flow from external input to database and back
- Use real database (containers)
- Validate: data persisted correctly, response matches, side effects occur

### 7. Performance Tests (load / stress)
- Validate latency SLAs and throughput under load
- Mandatory scenarios: baseline, normal load, peak, sustained
- Collected metrics: p50, p75, p95, p99 latency, TPS, error rate, memory

### 8. Smoke Tests (external validation)
- Black-box tests against a running environment
- Validate health checks, critical endpoints, basic flows
- Idempotent: create own test data, clean up after
- See dedicated smoke test rules for scenarios and execution

## Test Directory Structure

```
tests/
├── unit/              # Domain unit tests
├── integration/       # Database + framework integration
├── api/               # REST/GraphQL/gRPC endpoint tests
├── protocol/          # TCP/WebSocket protocol tests
├── e2e/               # End-to-end flow tests
├── performance/       # Load and stress tests
└── fixtures/          # Test fixtures, builders, helpers
```

> Adapt directory naming to your language convention (e.g., `src/test/java/...` for Java, `__tests__/` for JS/TS, `tests/` for Python).

## Test Fixtures — Static Utility Pattern

Centralize test data in utility classes/modules with static/module-level factory functions:

```
// Pattern: final class + private constructor + static methods
class MerchantFixture:
    VALID_DOCUMENT = "12345678000190"

    static function aMerchant(id):
        return Merchant(id, "Test Store", VALID_DOCUMENT, "ACTIVE")

    static function aMerchantWithTimeout(id):
        return Merchant(id, "Timeout Store", VALID_DOCUMENT, "ACTIVE", timeout=true)
```

**Fixture Rules:**
- Utility class: never instantiate directly
- All methods static / module-level
- Naming: `a{Entity}()` or `a{Entity}With{Variation}()`
- Constants for default values
- Domain fixtures separate from protocol fixtures

## Data Uniqueness in Tests

Tests that create resources MUST generate unique identifiers to avoid conflicts:

```
function uniqueId():
    return String(currentTimeNanos() % 1_000_000_000)
```

**Rules:**
- NEVER use fixed IDs in tests that create resources
- Tests validating duplicate detection should create the resource first, then attempt duplicate
- Each test run must be independent of previous runs

## Asynchronous Resource Handling

Tests depending on asynchronous resources (servers, connections) MUST use polling with timeout:

```
// GOOD — poll until ready
awaitUntil(timeout=10s, condition=() -> server.isListening())

// BAD — sleep and hope
sleep(5000)
```

**Rules:**
- Use dedicated polling utilities (Awaitility, polling loops with backoff)
- Default timeout: 10 seconds for resource startup
- Use in setup/beforeEach to guarantee preconditions
- NEVER use `sleep()` for waiting on resources — use condition-based polling
- Exception: `sleep()` is permitted in tests that validate timeout behavior

## Prohibitions

- NEVER use framework-default assertions (`assertEquals`, `assertTrue`) when richer assertion libraries are available
- NEVER mock domain logic — test with real domain objects
- Mocking PERMITTED only for: external clients, network services, clock/time
- NEVER use production data in tests
- NEVER depend on test execution order
- NEVER skip tests to make CI pass

## When to Use Real Database vs In-Memory

| Scenario | Database |
|----------|----------|
| Repository unit tests | In-memory (default) |
| API endpoint tests | In-memory (default) |
| Protocol tests | In-memory (default) |
| Migration validation | Real database (containers) |
| DB-specific features (JSON, full-text, etc.) | Real database (containers) |
| Performance / volume testing | Real database (containers) |
| EXPLAIN ANALYZE / query plan validation | Real database (containers) |
