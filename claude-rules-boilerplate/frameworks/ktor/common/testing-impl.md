# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Ktor — Testing Patterns

## testApplication

```kotlin
class MerchantRoutesTest {

    @Test
    fun `POST merchants should create and return 201`() = testApplication {
        application {
            install(ContentNegotiation) { json() }
            install(Koin) {
                modules(module {
                    single<MerchantService> { FakeMerchantService() }
                })
            }
            configureRouting()
        }

        val response = client.post("/api/v1/merchants") {
            contentType(ContentType.Application.Json)
            setBody("""{"mid":"123456789012345","name":"Test","document":"12345678000190","mcc":"5411"}""")
        }

        assertEquals(HttpStatusCode.Created, response.status)
        val body = response.body<MerchantResponse>()
        assertEquals("123456789012345", body.mid)
    }

    @Test
    fun `GET merchants by id should return 404 when not found`() = testApplication {
        application {
            install(ContentNegotiation) { json() }
            install(StatusPages) { configureStatusPages() }
            install(Koin) {
                modules(module {
                    single<MerchantService> { FakeMerchantService() }
                })
            }
            configureRouting()
        }

        val response = client.get("/api/v1/merchants/99999")

        assertEquals(HttpStatusCode.NotFound, response.status)
    }
}
```

## MockK for Service Tests

```kotlin
class MerchantServiceTest {

    private val repository: MerchantRepository = mockk()
    private val service = MerchantServiceImpl(repository)

    @Test
    fun `findByMid returns merchant when exists`() = runTest {
        val merchant = Merchant(1, "123", "Store", "12345678000190", "5411", "ACTIVE")
        coEvery { repository.findByMid("123") } returns merchant

        val result = service.findByMid("123")

        assertEquals("123", result.mid)
        coVerify(exactly = 1) { repository.findByMid("123") }
    }

    @Test
    fun `findByMid throws NotFoundException when not exists`() = runTest {
        coEvery { repository.findByMid("unknown") } returns null

        assertThrows<NotFoundException> {
            service.findByMid("unknown")
        }
    }

    @Test
    fun `create throws ConflictException when mid already exists`() = runTest {
        coEvery { repository.findByMid("123") } returns Merchant(1, "123", "Existing", "doc", "5411", "ACTIVE")

        assertThrows<ConflictException> {
            service.create(CreateMerchantRequest("123", "New", "12345678000190", "5411"))
        }
    }
}
```

## Kotest Style (Alternative)

```kotlin
class MerchantServiceSpec : FunSpec({
    val repository = mockk<MerchantRepository>()
    val service = MerchantServiceImpl(repository)

    test("findByMid returns merchant when exists") {
        coEvery { repository.findByMid("123") } returns Merchant(1, "123", "Store", "doc", "5411", "ACTIVE")

        val result = service.findByMid("123")

        result.mid shouldBe "123"
    }

    test("findByMid throws when not found") {
        coEvery { repository.findByMid("unknown") } returns null

        shouldThrow<NotFoundException> {
            service.findByMid("unknown")
        }
    }
})
```

## Fake Implementations for Integration Tests

```kotlin
class FakeMerchantService : MerchantService {
    private val merchants = mutableMapOf<Long, Merchant>()
    private var nextId = 1L

    override suspend fun create(request: CreateMerchantRequest): MerchantResponse {
        val merchant = Merchant(nextId++, request.mid, request.name, request.document, request.mcc, "ACTIVE")
        merchants[merchant.id] = merchant
        return merchant.toResponse()
    }

    override suspend fun findById(id: Long): MerchantResponse {
        return merchants[id]?.toResponse() ?: throw NotFoundException("Merchant not found: $id")
    }
}
```

## Naming Convention

```
`[method] [scenario] [expected behavior]`
```

Examples: `findByMid returns merchant when exists`, `create throws ConflictException when mid already exists`

## Anti-Patterns

- Do NOT use real databases in unit tests -- use MockK or fake implementations
- Do NOT skip StatusPages installation in test applications -- exceptions will leak
- Do NOT forget `runTest` or `runBlocking` for suspend function tests
- Do NOT test Ktor framework internals -- test your routes and services
