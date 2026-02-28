# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot — Testing Implementation

> Extends: `core/03-testing-philosophy.md`
> All coverage thresholds, naming conventions, AssertJ requirements, and fixture patterns apply.

## Test Slices

Spring Boot provides test slices to load only the relevant context:

| Annotation | Loads | Use Case |
|-----------|-------|----------|
| `@SpringBootTest` | Full application context | Integration, E2E tests |
| `@WebMvcTest` | Web layer only (controllers, filters, advisors) | Controller unit tests |
| `@DataJpaTest` | JPA layer only (repositories, entities) | Repository tests |
| `@JdbcTest` | JDBC layer only | Raw SQL tests |
| None (plain JUnit 5) | Nothing (no Spring context) | Domain unit tests |

## 1. Domain Unit Tests (No Spring)

Domain logic tests require NO Spring context. Use plain JUnit 5 + AssertJ:

```java
class CentsDecisionEngineTest {

    private final CentsDecisionEngine engine = new CentsDecisionEngine();

    @ParameterizedTest
    @CsvSource({
        "100.00, 00, Approved",
        "100.50, 00, Approved",
        "100.51, 51, Insufficient funds",
        "100.05, 05, Generic error",
        "100.14, 14, Invalid card",
        "100.43, 43, Stolen card",
        "100.57, 57, Transaction not allowed",
        "100.96, 96, System error"
    })
    void decide_variousAmounts_correctResponseCode(String amount, String expectedRc, String description) {
        var result = engine.decide(new BigDecimal(amount));
        assertThat(result).isEqualTo(expectedRc);
    }

    @Test
    void decide_zeroAmount_returnsApproved() {
        var result = engine.decide(BigDecimal.ZERO);
        assertThat(result).isEqualTo("00");
    }

    @Test
    void decide_negativeAmount_throwsException() {
        assertThatThrownBy(() -> engine.decide(new BigDecimal("-100.00")))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("Amount must be non-negative");
    }
}
```

## 2. Controller Tests with @WebMvcTest + MockMvc

`@WebMvcTest` loads only the web layer. External dependencies are mocked with `@MockBean`:

```java
@WebMvcTest(MerchantController.class)
class MerchantControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private MerchantService merchantService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void createMerchant_validPayload_returns201() throws Exception {
        var request = new CreateMerchantRequest(
            "123456789012345", "Test Store LTDA", "TestStore",
            "12345678000190", "5411");
        var merchant = MerchantFixture.aMerchant("123456789012345");

        when(merchantService.createMerchant(any(CreateMerchantRequest.class)))
            .thenReturn(merchant);

        mockMvc.perform(post("/api/v1/merchants")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())
            .andExpect(header().exists("Location"))
            .andExpect(jsonPath("$.mid").value("123456789012345"))
            .andExpect(jsonPath("$.name").value("Test Store LTDA"));
    }

    @Test
    void createMerchant_missingMid_returns400() throws Exception {
        var request = """
            {"name": "Test Store", "document": "12345678000190", "mcc": "5411"}
            """;

        mockMvc.perform(post("/api/v1/merchants")
                .contentType(MediaType.APPLICATION_JSON)
                .content(request))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.type").value("/errors/validation-error"))
            .andExpect(jsonPath("$.extensions.violations.mid").exists());
    }

    @Test
    void getMerchant_existingId_returns200() throws Exception {
        var merchant = MerchantFixture.aMerchant("123456789012345");

        when(merchantService.findById(1L)).thenReturn(merchant);

        mockMvc.perform(get("/api/v1/merchants/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.mid").value("123456789012345"));
    }

    @Test
    void getMerchant_nonExistentId_returns404() throws Exception {
        when(merchantService.findById(999L))
            .thenThrow(new MerchantNotFoundException("999"));

        mockMvc.perform(get("/api/v1/merchants/999"))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.type").value("/errors/not-found"));
    }

    @Test
    void createMerchant_duplicateMid_returns409() throws Exception {
        var request = new CreateMerchantRequest(
            "123456789012345", "Test Store LTDA", "TestStore",
            "12345678000190", "5411");

        when(merchantService.createMerchant(any()))
            .thenThrow(new MerchantAlreadyExistsException("123456789012345"));

        mockMvc.perform(post("/api/v1/merchants")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.type").value("/errors/conflict"))
            .andExpect(jsonPath("$.extensions.existingMid").value("123456789012345"));
    }

    @Test
    void listMerchants_withPagination_returns200() throws Exception {
        var merchants = List.of(MerchantFixture.aMerchant("MID1"), MerchantFixture.aMerchant("MID2"));
        var page = new PageImpl<>(merchants, PageRequest.of(0, 20), 2);

        when(merchantService.listMerchants(0, 20)).thenReturn(page);

        mockMvc.perform(get("/api/v1/merchants")
                .param("page", "0")
                .param("limit", "20"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data").isArray())
            .andExpect(jsonPath("$.data.length()").value(2))
            .andExpect(jsonPath("$.pagination.total").value(2));
    }
}
```

## 3. Repository Tests with @DataJpaTest

`@DataJpaTest` loads only the JPA layer with H2 by default:

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class MerchantJpaRepositoryTest {

    @Autowired
    private MerchantJpaRepository repository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void findByMid_existingMerchant_returnsMerchant() {
        var entity = MerchantEntityFixture.anActiveMerchant("MID123");
        entityManager.persistAndFlush(entity);

        var result = repository.findByMid("MID123");

        assertThat(result).isPresent();
        assertThat(result.get().getMid()).isEqualTo("MID123");
        assertThat(result.get().getLegalName()).isEqualTo(entity.getLegalName());
    }

    @Test
    void findByMid_nonExistent_returnsEmpty() {
        var result = repository.findByMid("NONEXISTENT");
        assertThat(result).isEmpty();
    }

    @Test
    void existsByMid_existingMerchant_returnsTrue() {
        var entity = MerchantEntityFixture.anActiveMerchant("MID456");
        entityManager.persistAndFlush(entity);

        assertThat(repository.existsByMid("MID456")).isTrue();
        assertThat(repository.existsByMid("UNKNOWN")).isFalse();
    }

    @Test
    void findByStatus_multipleResults_orderedByCreatedAt() {
        entityManager.persistAndFlush(MerchantEntityFixture.anActiveMerchant("MID1"));
        entityManager.persistAndFlush(MerchantEntityFixture.anActiveMerchant("MID2"));
        entityManager.persistAndFlush(MerchantEntityFixture.anInactiveMerchant("MID3"));

        var activeList = repository.findByStatusOrderByCreatedAtDesc(MerchantStatus.ACTIVE);

        assertThat(activeList).hasSize(2);
        assertThat(activeList).extracting(MerchantEntity::getStatus)
            .containsOnly(MerchantStatus.ACTIVE);
    }
}
```

## 4. H2 MODE=PostgreSQL Configuration

Standard database for tests. Eliminates Docker/Testcontainers dependency:

```yaml
# application-test.yml
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
```

### When H2 vs Testcontainers

| Scenario | Database |
|----------|----------|
| Repository unit tests | H2 (default) |
| Controller integration tests | H2 (default) |
| TCP socket tests | H2 (default) |
| Flyway migration validation | Testcontainers (real PostgreSQL) |
| PostgreSQL-exclusive features (JSONB, arrays) | Testcontainers |
| Performance/volume (EXPLAIN ANALYZE) | Testcontainers |

## 5. Testcontainers with @DynamicPropertySource

For tests requiring real PostgreSQL:

```java
@SpringBootTest
@Testcontainers
class TransactionRepositoryIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("authorizer_test")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.flyway.enabled", () -> "true");
    }

    @Autowired
    private TransactionJpaRepository repository;

    @Test
    @Transactional
    void persist_validTransaction_savesToDatabase() {
        var entity = TransactionEntityFixture.aDebitSale();
        var saved = repository.save(entity);

        assertThat(saved.getId()).isNotNull();
        assertThat(repository.findById(saved.getId())).isPresent();
    }

    @Test
    @Transactional
    void flyway_migrations_applyCleanly() {
        // If we reached this point, all Flyway migrations applied successfully
        assertThat(repository.count()).isGreaterThanOrEqualTo(0);
    }
}
```

## 6. Full Integration Tests with @SpringBootTest

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class MerchantIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void fullCrudLifecycle_merchant() {
        var mid = String.valueOf(System.nanoTime() % 1_000_000_000L);

        // Create
        var createRequest = new CreateMerchantRequest(
            mid, "Integration Test Store", "IntTest", "12345678000190", "5411");
        var createResponse = restTemplate.postForEntity(
            "/api/v1/merchants", createRequest, MerchantResponse.class);
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(createResponse.getBody()).isNotNull();
        var merchantId = createResponse.getBody().id();

        // Read
        var getResponse = restTemplate.getForEntity(
            "/api/v1/merchants/" + merchantId, MerchantResponse.class);
        assertThat(getResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(getResponse.getBody().mid()).isEqualTo(mid);

        // Update
        var updateRequest = new UpdateMerchantRequest("Updated Name", "Updated", "5412");
        restTemplate.put("/api/v1/merchants/" + merchantId, updateRequest);

        var updatedResponse = restTemplate.getForEntity(
            "/api/v1/merchants/" + merchantId, MerchantResponse.class);
        assertThat(updatedResponse.getBody().name()).isEqualTo("Updated Name");

        // Delete
        restTemplate.delete("/api/v1/merchants/" + merchantId);

        var deletedResponse = restTemplate.getForEntity(
            "/api/v1/merchants/" + merchantId, MerchantResponse.class);
        assertThat(deletedResponse.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
```

## 7. @Transactional Rollback in Tests

`@DataJpaTest` and `@Transactional` on tests automatically roll back after each test:

```java
@DataJpaTest
@ActiveProfiles("test")
class MerchantRepositoryRollbackTest {

    @Autowired
    private MerchantJpaRepository repository;

    @Test
    @Transactional  // Rolls back automatically after test
    void save_merchant_rolledBackAfterTest() {
        var entity = MerchantEntityFixture.anActiveMerchant("ROLLBACK_TEST");
        repository.save(entity);

        assertThat(repository.findByMid("ROLLBACK_TEST")).isPresent();
        // After this test, the record is rolled back
    }

    @Test
    void verify_previousTestRolledBack() {
        assertThat(repository.findByMid("ROLLBACK_TEST")).isEmpty();
    }
}
```

## 8. @MockBean for External Services

Use `@MockBean` to replace Spring beans in the test context:

```java
@WebMvcTest(TransactionController.class)
class TransactionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private TransactionService transactionService;

    @MockBean
    private CentsDecisionEngine decisionEngine;

    @Test
    void getTransaction_existingId_returns200() throws Exception {
        var transaction = TransactionFixture.anApprovedDebit();
        when(transactionService.findById(1L)).thenReturn(transaction);

        mockMvc.perform(get("/api/v1/transactions/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.responseCode").value("00"));
    }
}
```

**Rules for Mocking:**
- `@MockBean` ONLY for external services, clocks, and infrastructure adapters
- NEVER mock domain logic (use real instances)
- NEVER mock repositories in integration tests (use H2 or Testcontainers)
- Prefer `@WebMvcTest` + `@MockBean` over `@SpringBootTest` for controller-only tests

## 9. Test Fixtures

```java
public final class MerchantFixture {

    private MerchantFixture() {}

    public static final String VALID_CNPJ = "12345678000190";

    public static Merchant aMerchant(String mid) {
        return new Merchant(1L, mid, "Test Store LTDA", "TestStore", VALID_CNPJ,
            "5411", MerchantStatus.ACTIVE, false, OffsetDateTime.now(), OffsetDateTime.now());
    }
}

public final class MerchantEntityFixture {

    private MerchantEntityFixture() {}

    public static MerchantEntity anActiveMerchant(String mid) {
        var entity = new MerchantEntity();
        entity.setMid(mid);
        entity.setLegalName("Test Store LTDA");
        entity.setTradeName("TestStore");
        entity.setDocument("12345678000190");
        entity.setMcc("5411");
        entity.setStatus(MerchantStatus.ACTIVE);
        entity.setTimeoutEnabled(false);
        return entity;
    }

    public static MerchantEntity anInactiveMerchant(String mid) {
        var entity = anActiveMerchant(mid);
        entity.setStatus(MerchantStatus.INACTIVE);
        return entity;
    }
}
```

## 10. Data Uniqueness

REST tests creating resources MUST generate unique identifiers:

```java
private String uniqueMid() {
    return String.valueOf(System.nanoTime() % 1_000_000_000L);
}

private String uniqueTid() {
    return "T" + String.valueOf(System.nanoTime() % 10_000_000L);
}
```

## Naming Convention

```
[methodUnderTest]_[scenario]_[expectedBehavior]
```

Examples:
- `createMerchant_validPayload_returns201`
- `createMerchant_duplicateMid_returns409`
- `findByMid_nonExistent_returnsEmpty`
- `decide_approvedCents_returnsRC00`

## Anti-Patterns (FORBIDDEN)

```java
// FORBIDDEN — assertEquals (use AssertJ)
assertEquals("00", result.responseCode());  // Use assertThat(result.responseCode()).isEqualTo("00")

// FORBIDDEN — @SpringBootTest for controller-only tests
@SpringBootTest  // Loads EVERYTHING, use @WebMvcTest instead
class MerchantControllerTest { ... }

// FORBIDDEN — Mocking domain logic
@MockBean
private CentsDecisionEngine engine;  // Use real instance for domain tests

// FORBIDDEN — Thread.sleep for async waits
Thread.sleep(5000);  // Use Awaitility

// FORBIDDEN — Fixed MIDs in POST tests
.body("{\"mid\": \"FIXED_MID_123\", ...}")  // Use uniqueMid()

// FORBIDDEN — Testcontainers when H2 suffices
@Testcontainers  // Use H2 MODE=PostgreSQL for simple repository tests

// FORBIDDEN — No @ActiveProfiles("test")
@SpringBootTest  // Missing @ActiveProfiles("test") — uses wrong DB config
class SomeTest { ... }
```
