# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Ktor — Dependency Injection Patterns (Koin)

## Koin Module Declaration

```kotlin
val appModule = module {
    single<AppConfig> { loadConfig() }

    // Database
    single { DatabaseFactory.create(get<AppConfig>().database) }
    single<MerchantRepository> { MerchantRepositoryImpl(get()) }
    single<TerminalRepository> { TerminalRepositoryImpl(get()) }

    // Services
    single<MerchantService> { MerchantServiceImpl(get(), get()) }
}
```

## Ktor Integration

```kotlin
fun Application.module() {
    install(Koin) {
        modules(appModule)
    }

    configureSerialization()
    configureRouting()
}
```

## Injection in Routes

```kotlin
fun Route.merchantRoutes() {
    val service by inject<MerchantService>()

    route("/api/v1/merchants") {
        get {
            val page = call.parameters["page"]?.toIntOrNull() ?: 0
            val limit = call.parameters["limit"]?.toIntOrNull() ?: 20
            call.respond(service.list(page, limit))
        }

        post {
            val request = call.receive<CreateMerchantRequest>()
            val merchant = service.create(request)
            call.respond(HttpStatusCode.Created, merchant)
        }

        get("/{id}") {
            val id = call.parameters["id"]?.toLongOrNull()
                ?: throw BadRequestException("Invalid ID")
            call.respond(service.findById(id))
        }
    }
}
```

## Scopes

| Scope       | Koin Function    | Lifetime                     |
| ----------- | ---------------- | ---------------------------- |
| Singleton   | `single { }`     | Application lifetime         |
| Factory     | `factory { }`    | New instance per injection   |
| Scoped      | `scope { }`      | Bound to a defined scope     |

## Interface-Based Injection

```kotlin
// Define interface
interface MerchantRepository {
    suspend fun findById(id: Long): Merchant?
    suspend fun findByMid(mid: String): Merchant?
    suspend fun create(merchant: Merchant): Merchant
}

// Register implementation
single<MerchantRepository> { MerchantRepositoryImpl(get()) }
```

## Testing Override

```kotlin
@Test
fun `should create merchant`() = testApplication {
    application {
        install(Koin) {
            modules(module {
                single<MerchantService> { mockk(relaxed = true) }
            })
        }
        configureRouting()
    }

    val response = client.post("/api/v1/merchants") {
        contentType(ContentType.Application.Json)
        setBody("""{"mid":"123","name":"Test","document":"12345678000190","mcc":"5411"}""")
    }
    assertEquals(HttpStatusCode.Created, response.status)
}
```

## Anti-Patterns

- Do NOT use `get()` outside of Koin module definitions or Ktor routes -- inject via constructor
- Do NOT create circular dependencies between modules
- Do NOT use `single` for stateful request-scoped objects -- use `factory` or `scope`
- Do NOT mix Koin and manual instantiation for the same dependency graph
