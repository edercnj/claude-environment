# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Kotlin Testing Conventions

## Framework

- **JUnit 5** as test runner
- **kotest** or **assertk** for Kotlin-idiomatic assertions
- **MockK** for mocking

## Coverage Thresholds

| Metric          | Minimum |
| --------------- | ------- |
| Line Coverage   | >= 95%  |
| Branch Coverage | >= 90%  |

## Naming Convention

Use backtick function names for readable test descriptions.

```kotlin
class MerchantServiceTest {
    @Test
    fun `createMerchant should return merchant with active status`() { ... }

    @Test
    fun `findByMid should return null for nonexistent MID`() { ... }

    @Test
    fun `createMerchant should throw AlreadyExistsException for duplicate MID`() { ... }
}
```

## Test Structure (Arrange-Act-Assert)

```kotlin
@Test
fun `createMerchant should create merchant with valid payload`() {
    // Arrange
    val request = CreateMerchantRequest(
        mid = "MID000000000001",
        name = "Test Store",
        document = "12345678000190",
        mcc = "5411",
    )
    val service = MerchantService(repository = InMemoryMerchantRepository())

    // Act
    val result = service.createMerchant(request)

    // Assert
    assertThat(result.mid).isEqualTo("MID000000000001")
    assertThat(result.status).isEqualTo(MerchantStatus.ACTIVE)
}
```

## Assertions with Assertk

```kotlin
import assertk.assertThat
import assertk.assertions.*

@Test
fun `findAll should return paginated merchants`() {
    val result = service.findAll(page = 0, limit = 10)

    assertThat(result.data).hasSize(5)
    assertThat(result.pagination.total).isEqualTo(5)
    assertThat(result.data).each {
        it.prop(MerchantResponse::status).isEqualTo("ACTIVE")
    }
}

@Test
fun `createMerchant should throw for duplicate MID`() {
    assertThat {
        service.createMerchant(duplicateRequest)
    }.isFailure()
        .isInstanceOf(MerchantAlreadyExistsException::class)
        .hasMessage("Merchant with MID 'MID001' already exists")
}
```

## Assertions with Kotest

```kotlin
import io.kotest.matchers.shouldBe
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull

@Test
fun `findByMid should return merchant for existing MID`() {
    val result = service.findByMid("MID001")

    result.shouldNotBeNull()
    result.mid shouldBe "MID001"
    result.status shouldBe MerchantStatus.ACTIVE
}

@Test
fun `findByMid should return null for nonexistent MID`() {
    val result = service.findByMid("NONEXISTENT")
    result.shouldBeNull()
}
```

## MockK

```kotlin
import io.mockk.*

class MerchantServiceTest {
    private val repository = mockk<MerchantRepository>()
    private val service = MerchantService(repository)

    @BeforeEach
    fun setup() {
        clearMocks(repository)
    }

    @Test
    fun `createMerchant should save to repository`() {
        // Arrange
        every { repository.findByMid("MID001") } returns null
        every { repository.save(any()) } returnsArgument 0

        // Act
        val result = service.createMerchant(validRequest)

        // Assert
        verify(exactly = 1) { repository.save(any()) }
        assertThat(result.mid).isEqualTo("MID001")
    }

    @Test
    fun `processOrder should call gateway with correct amount`() {
        val gateway = mockk<PaymentGateway>()
        coEvery { gateway.charge(any(), any()) } returns PaymentResult(success = true)

        val service = OrderService(gateway)
        runBlocking { service.process(order) }

        coVerify { gateway.charge(order.amount, order.currency) }
    }
}
```

## Coroutine Testing

```kotlin
import kotlinx.coroutines.test.runTest

class TransactionServiceTest {
    @Test
    fun `processTransaction should return approved for valid amount`() = runTest {
        val service = TransactionService(
            repository = mockk(relaxed = true),
            engine = CentsDecisionEngine(),
        )

        val result = service.processTransaction(validRequest)

        assertThat(result).isInstanceOf(TransactionResult.Approved::class)
    }
}
```

## Parametrized Tests

```kotlin
@ParameterizedTest
@CsvSource(
    "100.00, 00, APPROVED",
    "100.51, 51, DENIED",
    "100.05, 05, ERROR",
    "100.14, 14, INVALID_CARD",
)
fun `centsRule should return correct response code`(
    amount: String,
    expectedRc: String,
    expectedStatus: String,
) {
    val result = engine.decide(BigDecimal(amount))
    assertThat(result.responseCode).isEqualTo(expectedRc)
}
```

## Test Fixtures

```kotlin
object MerchantFixture {
    fun aMerchant(
        mid: String = "MID000000000001",
        name: String = "Test Store",
        status: MerchantStatus = MerchantStatus.ACTIVE,
    ) = Merchant(
        id = 1L,
        mid = mid,
        name = name,
        document = "12345678000190",
        mcc = "5411",
        status = status,
        createdAt = Instant.parse("2026-01-01T00:00:00Z"),
    )

    fun aCreateRequest(
        mid: String = "MID000000000001",
    ) = CreateMerchantRequest(
        mid = mid,
        name = "Test Store",
        document = "12345678000190",
        mcc = "5411",
    )
}
```

## Anti-Patterns

- Using Java assertion libraries without Kotlin extensions
- `Thread.sleep()` in coroutine tests (use `advanceTimeBy`)
- Tests depending on execution order
- Mocking data classes (they are trivially constructible)
- `@Suppress("UNCHECKED_CAST")` in tests
- Tests without assertions
