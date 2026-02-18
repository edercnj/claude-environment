# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Spring Boot — Testing Patterns

> Extends: `core/03-testing-philosophy.md`

## Testing Frameworks

| Framework | Use |
|-----------|-----|
| JUnit 5 (5.11+) | Base framework |
| AssertJ (3.26+) | Assertions (ONLY permitted — NEVER JUnit assertions) |
| Testcontainers | PostgreSQL for integration tests (when H2 is insufficient) |
| MockMvc | Controller-layer REST API tests (sliced context) |
| TestRestTemplate | Full integration REST API tests |
| Spring Test | `@SpringBootTest`, `@DataJpaTest`, `@WebMvcTest` |
| JaCoCo (0.8+) | Coverage (>= 95% line, >= 90% branch) |
| Awaitility | Asynchronous tests (socket, timeout) |

## Prohibitions

- **NEVER** use `assertEquals`, `assertTrue`, `assertFalse` from JUnit — ALWAYS use AssertJ
- **NEVER** use Mockito or any mocking framework for domain logic
- Mockito PERMITTED only for: external clients, network services, clock
- `@MockBean` PERMITTED for replacing infrastructure beans in sliced tests
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

## Repository Tests (@DataJpaTest)

`@DataJpaTest` auto-configures an in-memory database, scans `@Entity` classes, and configures Spring Data JPA repositories. No full application context needed.

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class MerchantRepositoryTest {

    @Autowired
    private MerchantRepository repository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void findByMid_existingMerchant_returnsMerchant() {
        var entity = MerchantEntityFixture.aMerchantEntity("MID000000000001");
        entityManager.persistAndFlush(entity);

        var result = repository.findByMid("MID000000000001");

        assertThat(result).isPresent();
        assertThat(result.get().getMid()).isEqualTo("MID000000000001");
    }

    @Test
    void findByMid_nonExistent_returnsEmpty() {
        var result = repository.findByMid("NONEXISTENT");

        assertThat(result).isEmpty();
    }
}
```

**Rules:**
- Use `@DataJpaTest` for repository-only tests — faster than `@SpringBootTest`
- Use `TestEntityManager` for setup data (JPA-aware, auto-flush)
- Each test runs in a `@Transactional` context and auto-rolls back

## Controller Tests (@WebMvcTest + MockMvc)

`@WebMvcTest` loads only the web layer (controllers, filters, advice). All service dependencies must be mocked with `@MockBean`.

```java
@WebMvcTest(MerchantController.class)
class MerchantControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private MerchantService merchantService;

    @Test
    void createMerchant_validPayload_returns201() throws Exception {
        var merchant = MerchantFixture.aMerchant("MID000000000001");
        when(merchantService.create(any())).thenReturn(merchant);

        mockMvc.perform(post("/api/v1/merchants")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"mid": "MID000000000001", "name": "Test", "document": "12345678000190", "mcc": "5411"}
                    """))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.mid").value("MID000000000001"));
    }

    @Test
    void createMerchant_invalidPayload_returns400() throws Exception {
        mockMvc.perform(post("/api/v1/merchants")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"mid": "", "name": "", "document": "123", "mcc": ""}
                    """))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.title").value("Validation Error"));
    }

    @Test
    void findById_nonExistent_returns404() throws Exception {
        when(merchantService.findById(999L)).thenThrow(new MerchantNotFoundException("999"));

        mockMvc.perform(get("/api/v1/merchants/999"))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.title").value("Not Found"));
    }
}
```

## Full Integration Tests (@SpringBootTest)

`@SpringBootTest` loads the complete application context. Use `TestRestTemplate` for real HTTP calls.

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Transactional
class MerchantIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void createAndFetchMerchant_fullFlow_succeeds() {
        var request = """
            {"mid": "%s", "name": "Test Store", "document": "12345678000190", "mcc": "5411"}
            """.formatted(uniqueMid());

        var createResponse = restTemplate.postForEntity(
            "/api/v1/merchants", jsonEntity(request), MerchantResponse.class);

        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(createResponse.getBody()).isNotNull();
        assertThat(createResponse.getBody().mid()).isNotNull();

        var fetchResponse = restTemplate.getForEntity(
            createResponse.getHeaders().getLocation(), MerchantResponse.class);

        assertThat(fetchResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private HttpEntity<String> jsonEntity(String json) {
        var headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        return new HttpEntity<>(json, headers);
    }

    private String uniqueMid() {
        return String.valueOf(System.nanoTime() % 1_000_000_000L);
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
void centsRule_variousAmounts_correctResponseCode(String amount, String expectedRc, String expectedDescription) {
    var result = engine.decide(new BigDecimal(amount));
    assertThat(result.responseCode()).isEqualTo(expectedRc);
}
```

## H2 MODE=PostgreSQL Configuration

Standard for integration tests — eliminates Docker/Testcontainers dependency for most tests.

**`application-test.yml`:**
```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH
    username: sa
    password:
    driver-class-name: org.h2.Driver
  jpa:
    hibernate:
      ddl-auto: create-drop
    properties:
      hibernate:
        default_schema: simulator
  flyway:
    enabled: false

server:
  port: 0
```

### When to Use H2 vs Testcontainers

| Scenario | Database |
|----------|----------|
| Repository unit tests (`@DataJpaTest`) | H2 (default) |
| Controller tests (`@WebMvcTest`) | N/A (no DB) |
| Full integration tests (`@SpringBootTest`) | H2 (default) |
| Flyway migrations validation | Testcontainers (real PostgreSQL) |
| Queries with PostgreSQL-exclusive features | Testcontainers (real PostgreSQL) |
| Performance/volume (EXPLAIN ANALYZE) | Testcontainers (real PostgreSQL) |

### Testcontainers Integration (When Needed)

```java
@SpringBootTest
@Testcontainers
class TransactionRepositoryIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("test_db")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
}
```

## Test Fixture Pattern

```java
public final class MerchantFixture {

    private MerchantFixture() {}

    public static final String VALID_CNPJ = "12345678000190";
    public static final String VALID_CPF = "12345678901";

    public static Merchant aMerchant(String mid) {
        return new Merchant(mid, "Test Store LTDA", "TestStore", VALID_CNPJ, List.of("5411"),
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
- Constants for default values (PAN, TID, MID, CNPJ)
- Domain fixtures separate from protocol fixtures

## Data Uniqueness in REST Tests

```java
private String uniqueMid() {
    return String.valueOf(System.nanoTime() % 1_000_000_000L);
}

@Test
void createMerchant_validPayload_returns201() throws Exception {
    var mid = uniqueMid();
    mockMvc.perform(post("/api/v1/merchants")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"mid": "%s", "name": "Test", "document": "12345678000190", "mcc": "5411"}
                """.formatted(mid)))
        .andExpect(status().isCreated());
}
```

**Rules:**
- `System.nanoTime() % 1_000_000_000L` generates unique values within MID (15 chars) and TID (8 chars) size
- NEVER use fixed MIDs/TIDs in tests that do POST — causes `409 Conflict` on re-run
- Tests validating duplicity (409) should create resource in own test before attempting duplicate

## Awaitility for Asynchronous Resources

```java
@SpringBootTest
class SocketIntegrationTest {

    @Autowired
    private TcpServer server;

    @Value("${simulator.socket.port}")
    private int port;

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

## Transaction Rollback in Tests

Spring Boot uses `@Transactional` on test classes for automatic per-test rollback:

```java
@SpringBootTest
@Transactional
class MerchantServiceTest {

    @Autowired
    private MerchantService service;

    @Test
    void create_validMerchant_persistsSuccessfully() {
        var merchant = service.create(MerchantFixture.aCreateRequest("MID001"));

        assertThat(merchant.id()).isNotNull();
        // Transaction will be rolled back after test
    }
}
```

**Rules:**
- `@Transactional` on test class = automatic rollback after each test (replaces Quarkus `@TestTransaction`)
- Use `@Commit` annotation on individual tests if you need to persist for downstream assertions
- `@DataJpaTest` includes `@Transactional` by default

## Test Directory Structure

```
src/test/java/com/{project}/
├── domain/                # Domain unit tests
├── engine/                # Decision engine tests
├── adapter/
│   ├── inbound/
│   │   ├── socket/        # TCP socket tests
│   │   └── rest/          # Controller tests (MockMvc)
│   └── outbound/
│       └── persistence/   # Repository tests (@DataJpaTest)
├── fixture/               # Test fixtures and builders
└── integration/           # Full integration tests (@SpringBootTest)
```

## Spring Boot Test Slice Summary

| Annotation | Context | Use Case | DB |
|------------|---------|----------|-----|
| None (plain JUnit) | No Spring | Domain unit tests | No |
| `@WebMvcTest` | Web layer only | Controller + validation tests | No |
| `@DataJpaTest` | JPA layer only | Repository + entity tests | H2 (auto) |
| `@SpringBootTest` | Full context | Integration / E2E tests | H2 or Testcontainers |
| `@SpringBootTest(RANDOM_PORT)` | Full context + real HTTP | REST integration tests | H2 or Testcontainers |
