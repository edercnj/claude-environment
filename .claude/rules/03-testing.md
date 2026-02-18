# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 03 — Testing Patterns

## Coverage Thresholds (JaCoCo)
| Metric | Minimum |
|--------|---------|
| Line Coverage | ≥ 95% |
| Branch Coverage | ≥ 90% |

## Testing Frameworks
| Framework | Use |
|-----------|-----|
| JUnit 5 (5.11+) | Base framework |
| AssertJ (3.26+) | Assertions (ONLY permitted) |
| Testcontainers | PostgreSQL for integration tests |
| REST Assured | REST API tests |
| Quarkus Test | @QuarkusTest, @QuarkusIntegrationTest |
| JaCoCo (0.8+) | Coverage |
| Awaitility | Asynchronous tests (socket, timeout) |

> **Resilience Tests:** For testing circuit breaker, rate limiting, bulkhead, retry and degradation, follow **Rule 24 — Application Resilience** (section "Resilience Tests").

## Prohibitions
- ❌ **NEVER** use `assertEquals`, `assertTrue`, `assertFalse` from JUnit — ALWAYS use AssertJ
- ❌ **NEVER** use Mockito or any mocking framework for domain logic
- ✅ Mockito PERMITTED only for: external clients, network services, clock
- ✅ Testcontainers for real PostgreSQL in integration tests

## Test Categories

### 1. Unit Tests (domain + engine)
```java
@Test
void authorizeTransaction_approvedCents_returnsResponseCode00() {
    // Arrange
    var engine = new CentsDecisionEngine();
    var amount = new BigDecimal("100.00"); // cents .00 = approved

    // Act
    var result = engine.decide(amount);

    // Assert
    assertThat(result.responseCode()).isEqualTo("00");
    assertThat(result.isApproved()).isTrue();
}
```

### 2. Integration Tests (Quarkus + DB)
```java
@QuarkusTest
@TestTransaction
class TransactionRepositoryTest {

    @Inject
    TransactionRepository repository;

    @Test
    void persist_validTransaction_savesToDatabase() {
        var entity = TransactionEntityFixture.aDebitSale();
        repository.persist(entity);

        assertThat(repository.findById(entity.getId())).isNotNull();
    }
}
```

### 3. REST API Tests
```java
@QuarkusTest
class MerchantResourceTest {

    @Test
    void createMerchant_validPayload_returns201() {
        given()
            .contentType(ContentType.JSON)
            .body(MerchantFixture.validCreateRequest())
        .when()
            .post("/api/v1/merchants")
        .then()
            .statusCode(201)
            .body("mid", notNullValue());
    }
}
```

### 4. TCP Socket Tests
```java
@QuarkusTest
class EchoTestIntegrationTest {

    @ConfigProperty(name = "simulator.socket.port")
    int port;

    @Test
    void echoTest_validMessage1804_returns1814() {
        try (var client = new TcpTestClient("localhost", port)) {
            byte[] request = buildEchoRequest(); // MTI 1804
            byte[] response = client.sendAndReceive(request);

            var isoResponse = unpack(response);
            assertThat(isoResponse.getMti()).isEqualTo("1814");
        }
    }
}
```

### 5. ISO 8583 Contract Tests
```java
@ParameterizedTest
@CsvSource({
    "100.00, 00, APPROVED",
    "100.51, 51, INSUFFICIENT_FUNDS",
    "100.05, 05, GENERIC_ERROR",
    "100.14, 14, INVALID_CARD"
})
void centsRule_variousAmounts_correctResponseCode(
        String amount, String expectedRc, String expectedDescription) {
    var result = engine.decide(new BigDecimal(amount));
    assertThat(result.responseCode()).isEqualTo(expectedRc);
}
```

## Naming Convention
```
[methodUnderTest]_[scenario]_[expectedBehavior]
```
Examples:
- `processDebit_approvedAmount_returnsRC00`
- `parseReversal_missingOriginalData_throwsException`
- `findMerchant_nonExistentMid_returnsEmpty`

## Test Directory Structure
```
src/test/java/com/bifrost/simulator/
├── domain/          # Domain unit tests
├── engine/          # Decision engine tests
├── adapter/
│   ├── inbound/
│   │   ├── socket/  # TCP socket tests
│   │   └── rest/    # REST API tests
│   └── outbound/
│       └── persistence/  # Repository tests
├── fixture/         # Test fixtures and builders
└── integration/     # End-to-end tests
```

### 6. Performance Tests (Gatling)

Framework: Gatling 3.x (Scala DSL or Java DSL)
Objective: Validate latency SLAs and throughput under load.

**Mandatory Scenarios:**
- **Baseline:** 1 connection, 100 sequential messages — p99 < 100ms
- **Normal Load:** 10 connections, 1000 msgs/connection — p95 < 150ms, throughput > 500 TPS
- **Peak:** 50 concurrent connections, 100 msgs/connection — no errors, p99 < 500ms
- **Sustained:** 10 connections, 30 minutes continuous — no memory leak, stable latency
- **Timeout:** Connections with timeout scenario (RULE-002) — does not block others

**Collected Metrics:**
- Latency: p50, p75, p95, p99
- Throughput: transactions per second (TPS)
- Errors: error rate < 0.1%
- Memory: RSS should not grow > 10% during sustained test
- Connections: all should be reused (persistent)

**Directory Structure:**
```
src/test/gatling/
├── simulations/
│   ├── BaselineSimulation.scala
│   ├── NormalLoadSimulation.scala
│   ├── PeakLoadSimulation.scala
│   └── SustainedLoadSimulation.scala
├── protocol/
│   └── Iso8583Protocol.scala    # Custom Gatling protocol for TCP/ISO
└── feeders/
    └── TransactionFeeder.scala  # ISO 8583 data generator
```

**Execution:**
```bash
mvn gatling:test -Dgatling.simulationClass=BaselineSimulation
mvn gatling:test -Dgatling.simulationClass=NormalLoadSimulation
```

### 7. Database Integration Tests

#### Current Standard: H2 MODE=PostgreSQL (since STORY-015)

The project uses **H2 in PostgreSQL mode** as the standard for integration tests. This eliminates the need for Docker/Testcontainers and significantly speeds up the test cycle.

**Configuration in `application-test.properties`:**
```properties
quarkus.datasource.db-kind=h2
quarkus.datasource.jdbc.url=jdbc:h2:mem:testdb;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH
quarkus.datasource.username=sa
quarkus.datasource.password=
quarkus.hibernate-orm.database.generation=drop-and-create
quarkus.hibernate-orm.database.default-schema=simulator
quarkus.flyway.enabled=false
```

**When to use H2 vs Testcontainers:**
| Scenario | Database |
|----------|----------|
| Repository unit tests | H2 (default) |
| REST API tests (`@QuarkusTest`) | H2 (default) |
| TCP socket tests (`@QuarkusTest`) | H2 (default) |
| Flyway migrations validation | Testcontainers (real PostgreSQL) |
| Queries with PostgreSQL-exclusive features | Testcontainers (real PostgreSQL) |
| Performance/volume (EXPLAIN ANALYZE) | Testcontainers (real PostgreSQL) |

#### Alternative: Testcontainers (When Needed)

Framework: Testcontainers 1.19+ with PostgreSQL
Objective: Validate REAL database integration when H2 is insufficient.

**Base Configuration:**
```java
@QuarkusTest
@TestProfile(TestcontainersProfile.class)
class TransactionRepositoryIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("authorizer_test")
        .withUsername("test")
        .withPassword("test")
        .withInitScript("db/init-test.sql");

    // Quarkus DevServices can manage this automatically
    // but explicit ensures full control
}
```

**Mandatory Scenarios:**
- **Full CRUD:** Create, read, update, delete transactions
- **Concurrency:** Concurrent transactions on same merchant — no deadlock
- **Migration:** Flyway migrations execute without error on clean database
- **Rollback:** Migration with error does rollback correctly
- **Volume:** Insert 10,000 transactions — query by merchant < 50ms
- **Indexes:** Queries use planned indexes (EXPLAIN ANALYZE)
- **Constraints:** Violations of unique/FK/check return appropriate error

**Isolation:**
- `@TestTransaction` for automatic per-test rollback
- Each test class can have setup data in `@BeforeEach`
- Testcontainers reuses container between tests of same class

**Naming:**
```
[repository/entity]_[operation]_[scenario]
transactionRepository_findByMerchant_returnsPagedResults
flyway_migration_appliesAllVersionsCleanly
```

### 8. End-to-End Tests (E2E)

Framework: @QuarkusIntegrationTest + TcpTestClient + Testcontainers
Objective: Validate complete flow: TCP → Parse → Process → DB → Response

**Complete E2E Scenario:**
```
Client TCP → [2-byte header + ISO msg] → Server
    → RecordParser (framing)
    → Unpack ISO 8583
    → Validate fields
    → Decision Engine (cents rule)
    → Persist transaction (real PostgreSQL)
    → Pack ISO 8583 response
    → [2-byte header + ISO resp] → Client TCP
```

**Mandatory Scenarios:**
- **Happy Path:** 0200 approved purchase (cents=00) → 0210 with RC=00 + transaction in DB
- **Refusal:** 0200 with cents=51 → 0210 with RC=51 + transaction in DB with DECLINED status
- **Full Reversal:** 0200 approved → 0400 reversal → both in DB
- **Echo:** 0800 → 0810 (no persistence)
- **Multiple Messages:** 5 transactions on same TCP connection
- **Persistent Connection:** Send msg, wait, send another — connection maintained
- **Timeout:** Message with timeout flag → response after 35s, connection maintained
- **Parse Error:** Malformed message → error response, connection maintained
- **Multi-version:** Same scenario with ISO 1987, 1993, 2021

**Structure:**
```
src/test/java/.../integration/
├── e2e/
│   ├── PurchaseE2ETest.java         # Complete purchase flow
│   ├── ReversalE2ETest.java         # Cancellation flow
│   ├── NetworkManagementE2ETest.java # Echo test
│   ├── PersistentConnectionE2ETest.java # Multi-msg, idle, timeout
│   └── MultiVersionE2ETest.java     # Same scenario, 3 ISO versions
├── fixture/
│   ├── TcpTestClient.java          # TCP client with framing
│   ├── IsoMessageBuilder.java      # Builder for test messages
│   └── TestTransactionData.java    # Centralized test data
└── config/
    └── TestcontainersProfile.java   # Profile with PostgreSQL container
```

**TcpTestClient for E2E:**
```java
public class TcpTestClient implements AutoCloseable {
    private final Socket socket;
    private final DataInputStream in;
    private final DataOutputStream out;

    public TcpTestClient(String host, int port) {
        this.socket = new Socket(host, port);
        this.socket.setKeepAlive(true);
        this.in = new DataInputStream(socket.getInputStream());
        this.out = new DataOutputStream(socket.getOutputStream());
    }

    public byte[] sendAndReceive(byte[] isoMessage) {
        // Write: 2-byte length + message
        out.writeShort(isoMessage.length);
        out.write(isoMessage);
        out.flush();

        // Read: 2-byte length + response
        int responseLength = in.readUnsignedShort();
        byte[] response = new byte[responseLength];
        in.readFully(response);
        return response;
    }

    // Allows sending without receiving (for pipeline tests)
    public void send(byte[] isoMessage) { ... }
    public byte[] receive() { ... }

    // Keeps connection open between calls (persistent)
    public boolean isConnected() { return socket.isConnected() && !socket.isClosed(); }

    @Override
    public void close() { socket.close(); }
}
```

## Test Fixtures

### Fixture Pattern — Static Utility Classes

Centralize test data in `final` classes with private constructor and `static` methods:

```java
// ✅ CORRECT — Domain fixture (domain data)
public final class MerchantFixture {

    private MerchantFixture() {}

    public static final String VALID_CNPJ = "12345678000190";
    public static final String VALID_CPF = "12345678901";

    public static Merchant aMerchant(String mid) {
        return new Merchant(mid, "Test Store LTDA", "TestStore", VALID_CNPJ, List.of("5411"),
            new Address("Test St", "100", null, "Test City", "SP", "01000000"),
            new MerchantConfiguration(false, 0), MerchantStatus.ACTIVE);
    }

    public static Terminal aTerminal(String tid, Long merchantId) {
        return new Terminal(tid, merchantId, "PAX-A920", "SN123456",
            new TerminalConfiguration(false, 0), TerminalStatus.ACTIVE);
    }

    public static Terminal aTerminalWithTimeout(String tid, Long merchantId) {
        return new Terminal(tid, merchantId, "PAX-A920", "SN123456",
            new TerminalConfiguration(true, 35), TerminalStatus.ACTIVE);
    }
}
```

```java
// ✅ CORRECT — ISO fixture (ISO 8583 messages)
public final class IsoMessageFixture {

    private IsoMessageFixture() {}

    private static final String DEFAULT_PAN = "4111111111111111";
    private static final String DEFAULT_TID = "TERM0001";
    private static final String DEFAULT_MID = "MID000000000001";

    // Overloads with increasing specificity
    public static byte[] anEchoRequest() { ... }
    public static byte[] anEchoRequestWithStan(String stan) { ... }
    public static byte[] anEchoRequestWithFields(Map<Integer, String> fields) { ... }

    public static byte[] aDebitSaleRequest() { ... }
    public static byte[] aDebitSaleRequestWithAmount(String amount) { ... }
    public static byte[] aDebitSaleRequestWithAmountAndStan(String amount, String stan) { ... }
    public static byte[] aDebitSaleRequestWithAmountAndMerchant(String amount, String tid, String mid) { ... }
}
```

**Fixture Rules:**
- `final class` + `private` constructor (never instantiate)
- All methods `static`
- Naming: `a{Entity}()` or `a{Entity}With{Variation}()`
- Constants for default values (PAN, TID, MID, CNPJ)
- Domain fixtures in `fixture/` test package
- ISO fixtures separate from domain fixtures

## Data Uniqueness in REST Tests

REST tests that create resources (POST) MUST generate unique identifiers to avoid conflicts between tests:

```java
// ✅ CORRECT — Unique MID/TID per execution
private String uniqueMid() {
    return String.valueOf(System.nanoTime() % 1_000_000_000L);
}

@Test
void createMerchant_validPayload_returns201() {
    var mid = uniqueMid();
    given()
        .contentType(ContentType.JSON)
        .body("""
            {"mid": "%s", "name": "Test", "document": "12345678000190", "mcc": "5411"}
            """.formatted(mid))
    .when()
        .post("/api/v1/merchants")
    .then()
        .statusCode(201);
}
```

**Rules:**
- `System.nanoTime() % 1_000_000_000L` generates unique values within MID (15 chars) and TID (8 chars) size
- NEVER use fixed MIDs/TIDs in tests that do POST — causes `409 Conflict` on re-run
- Tests validating duplicity (409) should create resource in own test before attempting duplicate

## Awaitility for Asynchronous Resources

Tests depending on asynchronous resources (TCP socket, connections) MUST use Awaitility:

```java
// ✅ CORRECT — Wait for socket to be listening before connecting
@QuarkusTest
class SocketIntegrationTest {

    @Inject
    TcpServer server;

    @ConfigProperty(name = "simulator.socket.port")
    int port;

    @BeforeEach
    void waitForServer() {
        await().atMost(10, SECONDS).until(() -> server.isListening());
    }

    @Test
    void echoTest_validMessage_returnsResponse() {
        try (var client = new TcpTestClient("localhost", port)) {
            // ... test safe, socket guaranteed ready
        }
    }
}
```

**Rules:**
- `await().atMost(10, SECONDS)` as default timeout for resource startup
- Use in `@BeforeEach` to guarantee precondition before each test
- NEVER use `Thread.sleep()` to wait for resources — use Awaitility with condition
- Exception: `Thread.sleep()` is permitted in tests validating timeout (RULE-002)
