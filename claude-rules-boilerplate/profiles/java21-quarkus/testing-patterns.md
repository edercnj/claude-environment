# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Quarkus — Testing Patterns

> Extends: `core/03-testing-philosophy.md`

## Testing Frameworks

| Framework | Use |
|-----------|-----|
| JUnit 5 (5.11+) | Base framework |
| AssertJ (3.26+) | Assertions (ONLY permitted — NEVER JUnit assertions) |
| Testcontainers | PostgreSQL for integration tests (when H2 is insufficient) |
| REST Assured | REST API tests |
| Quarkus Test | `@QuarkusTest`, `@QuarkusIntegrationTest` |
| JaCoCo (0.8+) | Coverage (>= 95% line, >= 90% branch) |
| Awaitility | Asynchronous tests (socket, timeout) |

## Prohibitions

- **NEVER** use `assertEquals`, `assertTrue`, `assertFalse` from JUnit — ALWAYS use AssertJ
- **NEVER** use Mockito or any mocking framework for domain logic
- Mockito PERMITTED only for: external clients, network services, clock
- Testcontainers for real PostgreSQL in integration tests (when H2 is insufficient)

## Unit Tests (domain + engine)

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

## Integration Tests (Quarkus + DB)

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

## REST API Tests

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

## TCP Socket Tests

```java
@QuarkusTest
class EchoTestIntegrationTest {

    @ConfigProperty(name = "simulator.socket.port")
    int port;

    @Test
    void echoTest_validMessage1804_returns1814() {
        try (var client = new TcpTestClient("localhost", port)) {
            byte[] request = buildEchoRequest();
            byte[] response = client.sendAndReceive(request);

            var isoResponse = unpack(response);
            assertThat(isoResponse.getMti()).isEqualTo("1814");
        }
    }
}
```

## Contract Tests (Parametrized)

```java
@ParameterizedTest
@CsvSource({
    "100.00, 00, APPROVED",
    "100.51, 51, INSUFFICIENT_FUNDS",
    "100.05, 05, GENERIC_ERROR",
    "100.14, 14, INVALID_CARD"
})
void pricingRule_variousInputs_correctOutput(String amount, String expectedRc, String expectedDescription) {
    var result = engine.decide(new BigDecimal(amount));
    assertThat(result.responseCode()).isEqualTo(expectedRc);
}
```

## H2 MODE=PostgreSQL Configuration

Standard for integration tests — eliminates Docker/Testcontainers dependency for most tests.

**`application-test.properties`:**
```properties
quarkus.datasource.db-kind=h2
quarkus.datasource.jdbc.url=jdbc:h2:mem:testdb;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH
quarkus.datasource.username=sa
quarkus.datasource.password=

quarkus.hibernate-orm.database.generation=drop-and-create
quarkus.hibernate-orm.database.default-schema=simulator
quarkus.flyway.enabled=false

# Random port to avoid CI conflicts
simulator.socket.port=0

quarkus.swagger-ui.always-include=false
```

### When to Use H2 vs Testcontainers

| Scenario | Database |
|----------|----------|
| Repository unit tests | H2 (default) |
| REST API tests (`@QuarkusTest`) | H2 (default) |
| TCP socket tests (`@QuarkusTest`) | H2 (default) |
| Flyway migrations validation | Testcontainers (real PostgreSQL) |
| Queries with PostgreSQL-exclusive features | Testcontainers (real PostgreSQL) |
| Performance/volume (EXPLAIN ANALYZE) | Testcontainers (real PostgreSQL) |

## TcpTestClient Pattern

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
        out.writeShort(isoMessage.length);
        out.write(isoMessage);
        out.flush();

        int responseLength = in.readUnsignedShort();
        byte[] response = new byte[responseLength];
        in.readFully(response);
        return response;
    }

    public void send(byte[] isoMessage) { ... }
    public byte[] receive() { ... }
    public boolean isConnected() { return socket.isConnected() && !socket.isClosed(); }

    @Override
    public void close() { socket.close(); }
}
```

## Test Fixture Pattern

```java
public final class MerchantFixture {

    private MerchantFixture() {}

    public static final String VALID_TAX_ID = "12345678000190";
    public static final String VALID_SHORT_TAX_ID = "12345678901";

    public static Merchant aMerchant(String mid) {
        return new Merchant(mid, "Test Store LTDA", "TestStore", VALID_TAX_ID, List.of("5411"),
            new Address("Test St", "100", null, "Test City", "SP", "01000000"),
            new MerchantConfiguration(false, 0), MerchantStatus.ACTIVE);
    }

    public static Terminal aTerminalWithTimeout(String tid, Long merchantId) {
        return new Terminal(tid, merchantId, "PAX-A920", "SN123456",
            new TerminalConfiguration(true, 35), TerminalStatus.ACTIVE);
    }
}
```

**Fixture Rules:**
- `final class` + `private` constructor (never instantiate)
- All methods `static`
- Naming: `a{Entity}()` or `a{Entity}With{Variation}()`
- Constants for default values (test identifiers such as merchant/terminal IDs — MID/TID)
- Domain fixtures separate from protocol fixtures

## Data Uniqueness in REST Tests

```java
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
- `System.nanoTime() % 1_000_000_000L` generates unique values within identifier field size constraints
- NEVER use fixed identifiers (for example MIDs/TIDs) in tests that perform POST — causes `409 Conflict` on re-run
- Tests validating duplicity (409) should create resource in own test before attempting duplicate

## Awaitility for Asynchronous Resources

```java
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
            // test safe, socket guaranteed ready
        }
    }
}
```

**Rules:**
- `await().atMost(10, SECONDS)` as default timeout for resource startup
- Use in `@BeforeEach` to guarantee precondition before each test
- NEVER use `Thread.sleep()` to wait for resources — use Awaitility with condition
- Exception: `Thread.sleep()` is permitted in tests validating timeout behavior

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
    └── TransactionFeeder.scala
```

**Execution:**
```bash
mvn gatling:test -Dgatling.simulationClass=BaselineSimulation
mvn gatling:test -Dgatling.simulationClass=NormalLoadSimulation
```

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
