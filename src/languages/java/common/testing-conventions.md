# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java — Testing Conventions

> Common testing patterns for all Java versions.

## Testing Frameworks

| Framework | Use |
|-----------|-----|
| JUnit 5 (5.11+) | Base framework |
| AssertJ (3.26+) | Assertions (ONLY permitted — NEVER JUnit assertions) |
| JaCoCo (0.8+) | Coverage |
| Testcontainers (1.19+) | Real DB for integration tests (when lightweight DB is insufficient) |
| Awaitility (4.2+) | Asynchronous tests (socket, timeout) |

## Coverage Thresholds (JaCoCo)

| Metric | Minimum |
|--------|---------|
| Line Coverage | ≥ 95% |
| Branch Coverage | ≥ 90% |

## Prohibitions

- ❌ **NEVER** use `assertEquals`, `assertTrue`, `assertFalse` from JUnit — ALWAYS use AssertJ
- ❌ **NEVER** use Mockito for domain logic — only for external services, network, clock
- ❌ **NEVER** use Hamcrest, JUnit 4 assertions, or PowerMock

## Naming Convention

```
[methodUnderTest]_[scenario]_[expectedBehavior]
```

Examples:
- `processDebit_approvedAmount_returnsRC00`
- `parseReversal_missingOriginalData_throwsException`
- `findMerchant_nonExistentMid_returnsEmpty`

## Test Categories

### Unit Tests (domain + engine)

```java
@Test
void authorizeTransaction_approvedCents_returnsResponseCode00() {
    var engine = new CentsDecisionEngine();
    var amount = new BigDecimal("100.00");

    var result = engine.decide(amount);

    assertThat(result.responseCode()).isEqualTo("00");
    assertThat(result.isApproved()).isTrue();
}
```

### Contract Tests (Parametrized)

```java
@ParameterizedTest
@CsvSource({
    "100.00, 00, APPROVED",
    "100.51, 51, INSUFFICIENT_FUNDS",
    "100.05, 05, GENERIC_ERROR",
    "100.14, 14, INVALID_CARD"
})
void pricingRule_variousInputs_correctOutput(String amount, String expectedRc, String description) {
    var result = engine.decide(new BigDecimal(amount));
    assertThat(result.responseCode()).isEqualTo(expectedRc);
}
```

## Test Fixture Pattern

```java
public final class MerchantFixture {

    private MerchantFixture() {}

    public static final String VALID_TAX_ID = "12345678000190";

    public static Merchant aMerchant(String mid) {
        return new Merchant(mid, "Test Store LTDA", "TestStore", VALID_TAX_ID,
            List.of("5411"), MerchantStatus.ACTIVE);
    }

    public static Merchant aMerchantWithTimeout(String mid) {
        return new Merchant(mid, "Timeout Store", "TimeoutStore", VALID_TAX_ID,
            List.of("5411"), MerchantStatus.ACTIVE, new MerchantConfiguration(true, 35));
    }
}
```

**Fixture Rules:**
- `final class` + `private` constructor (never instantiate)
- All methods `static`
- Naming: `a{Entity}()` or `a{Entity}With{Variation}()`
- Constants for default values
- Domain fixtures separate from protocol fixtures

## Data Uniqueness in Tests

```java
private String uniqueId() {
    return String.valueOf(System.nanoTime() % 1_000_000_000L);
}
```

- NEVER use fixed identifiers in tests that perform POST — causes conflicts on re-run
- Tests validating duplicity should create resource before attempting duplicate

## Awaitility for Async Resources

```java
@BeforeEach
void waitForServer() {
    await().atMost(10, SECONDS).until(() -> server.isListening());
}
```

- NEVER use `Thread.sleep()` to wait for resources — use Awaitility
- Exception: `Thread.sleep()` permitted in tests validating timeout behavior

## Test Directory Structure

```
src/test/java/com/{project}/
├── domain/                # Domain unit tests
├── engine/                # Decision engine tests
├── adapter/
│   ├── inbound/
│   │   ├── socket/        # TCP socket tests
│   │   └── rest/          # REST API tests
│   └── outbound/
│       └── persistence/   # Repository tests
├── fixture/               # Test fixtures and builders
└── integration/           # End-to-end tests
```

## Performance Tests (Gatling)

```
src/test/gatling/
├── simulations/
│   ├── BaselineSimulation.scala
│   ├── NormalLoadSimulation.scala
│   ├── PeakLoadSimulation.scala
│   └── SustainedLoadSimulation.scala
├── protocol/
│   └── CustomProtocol.scala
└── feeders/
    └── DataFeeder.scala
```

**Mandatory Scenarios:**
- **Baseline:** 1 connection, 100 sequential messages — p99 < 100ms
- **Normal Load:** 10 connections, 1000 msgs/connection — p95 < 150ms, throughput > 500 TPS
- **Peak:** 50 concurrent connections — no errors, p99 < 500ms
- **Sustained:** 10 connections, 30 minutes continuous — no memory leak, stable latency
