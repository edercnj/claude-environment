---
name: ktor-patterns
description: "Ktor-specific patterns: plugin installation, routing DSL, Exposed ORM, Koin DI, HOCON config, testApplication testing, StatusPages error handling. Internal reference for agents producing Ktor code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Ktor Patterns

## Purpose

Provides Ktor-specific implementation patterns that supplement the generic layer templates. Agents reference this pack when generating code for a Kotlin + Ktor project.

---

## 1. Ktor Plugins

### Application Module Setup

```kotlin
fun Application.module() {
    install(ContentNegotiation) {
        json(Json {
            prettyPrint = false
            isLenient = false
            ignoreUnknownKeys = true
            encodeDefaults = true
        })
    }

    install(CallLogging) {
        level = Level.INFO
        filter { call -> call.request.path().startsWith("/api") }
        format { call ->
            val status = call.response.status()
            val method = call.request.httpMethod.value
            val path = call.request.path()
            "$method $path -> $status"
        }
    }

    install(StatusPages) {
        exception<MerchantNotFoundException> { call, cause ->
            call.respond(HttpStatusCode.NotFound, ProblemDetail(
                type = "https://api.example.com/errors/not-found",
                title = "Merchant Not Found",
                status = 404,
                detail = cause.message ?: "Resource not found",
                instance = call.request.path()
            ))
        }
        exception<ValidationException> { call, cause ->
            call.respond(HttpStatusCode.BadRequest, ProblemDetail(
                type = "https://api.example.com/errors/validation",
                title = "Validation Error",
                status = 400,
                detail = cause.message ?: "Invalid request",
                instance = call.request.path()
            ))
        }
        exception<Throwable> { call, cause ->
            application.log.error("Unhandled exception", cause)
            call.respond(HttpStatusCode.InternalServerError, ProblemDetail(
                type = "https://api.example.com/errors/internal",
                title = "Internal Server Error",
                status = 500,
                detail = "An unexpected error occurred",
                instance = call.request.path()
            ))
        }
    }

    install(CORS) {
        allowMethod(HttpMethod.Get)
        allowMethod(HttpMethod.Post)
        allowMethod(HttpMethod.Put)
        allowMethod(HttpMethod.Delete)
        allowHeader(HttpHeaders.Authorization)
        allowHeader(HttpHeaders.ContentType)
        anyHost() // restrict in production
    }

    install(Authentication) {
        jwt("auth-jwt") {
            realm = environment.config.property("jwt.realm").getString()
            verifier(
                JWT.require(Algorithm.HMAC256(environment.config.property("jwt.secret").getString()))
                    .withIssuer(environment.config.property("jwt.issuer").getString())
                    .build()
            )
            validate { credential ->
                if (credential.payload.getClaim("userId").asString() != null) {
                    JWTPrincipal(credential.payload)
                } else null
            }
        }
    }

    configureRouting()
}
```

### Plugin Installation Order

| Order | Plugin | Purpose |
|-------|--------|---------|
| 1 | `CallLogging` | Log all incoming requests |
| 2 | `ContentNegotiation` | Serialize/deserialize JSON |
| 3 | `StatusPages` | Map exceptions to HTTP responses |
| 4 | `CORS` | Cross-origin resource sharing |
| 5 | `Authentication` | JWT/OAuth verification |

---

## 2. Routing DSL

### Route Definition

```kotlin
fun Application.configureRouting() {
    routing {
        route("/api/v1") {
            healthRoutes()

            authenticate("auth-jwt") {
                merchantRoutes()
            }
        }
    }
}

fun Route.healthRoutes() {
    get("/health") {
        call.respond(HttpStatusCode.OK, mapOf("status" to "UP"))
    }
}

fun Route.merchantRoutes() {
    val merchantService by inject<MerchantService>()

    route("/merchants") {
        get {
            val page = call.request.queryParameters["page"]?.toIntOrNull() ?: 0
            val limit = call.request.queryParameters["limit"]?.toIntOrNull() ?: 20
            val status = call.request.queryParameters["status"]

            val result = merchantService.findAll(page, limit, status)
            call.respond(HttpStatusCode.OK, result)
        }

        post {
            val request = call.receive<CreateMerchantRequest>()
            request.validate()

            val merchant = merchantService.create(request)
            call.respond(HttpStatusCode.Created, merchant.toResponse())
        }

        get("/{id}") {
            val id = call.parameters["id"]?.toLongOrNull()
                ?: throw ValidationException("Invalid merchant ID")

            val merchant = merchantService.findById(id)
            call.respond(HttpStatusCode.OK, merchant.toResponse())
        }

        delete("/{id}") {
            val id = call.parameters["id"]?.toLongOrNull()
                ?: throw ValidationException("Invalid merchant ID")

            merchantService.delete(id)
            call.respond(HttpStatusCode.NoContent)
        }
    }
}
```

### Request/Response DTOs

```kotlin
@Serializable
data class CreateMerchantRequest(
    val mid: String,
    val name: String,
    val type: MerchantType
) {
    fun validate() {
        require(mid.isNotBlank() && mid.length <= 15) { "MID must be 1-15 characters" }
        require(name.isNotBlank() && name.length <= 100) { "Name must be 1-100 characters" }
    }
}

@Serializable
data class MerchantResponse(
    val id: Long,
    val mid: String,
    val name: String,
    val type: MerchantType,
    val status: String,
    val createdAt: String
)

@Serializable
data class ProblemDetail(
    val type: String,
    val title: String,
    val status: Int,
    val detail: String,
    val instance: String
)

@Serializable
enum class MerchantType { PHYSICAL, ONLINE }
```

---

## 3. Data Access (Exposed ORM)

### Table Definitions

```kotlin
object Merchants : LongIdTable("merchants") {
    val mid = varchar("mid", 15).uniqueIndex()
    val name = varchar("name", 100)
    val type = enumerationByName<MerchantType>("type", 20)
    val status = varchar("status", 20).default("active")
    val createdAt = timestamp("created_at").defaultExpression(CurrentTimestamp)
    val updatedAt = timestamp("updated_at").defaultExpression(CurrentTimestamp)
}

object AuditLogs : LongIdTable("audit_logs") {
    val entityType = varchar("entity_type", 50)
    val entityId = long("entity_id")
    val action = varchar("action", 20)
    val createdAt = timestamp("created_at").defaultExpression(CurrentTimestamp)
}
```

### DAO Pattern

```kotlin
class MerchantEntity(id: EntityID<Long>) : LongEntity(id) {
    companion object : LongEntityClass<MerchantEntity>(Merchants)

    var mid by Merchants.mid
    var name by Merchants.name
    var type by Merchants.type
    var status by Merchants.status
    var createdAt by Merchants.createdAt
    var updatedAt by Merchants.updatedAt

    fun toDomain() = Merchant(
        id = id.value,
        mid = mid,
        name = name,
        type = type,
        status = status,
        createdAt = createdAt,
        updatedAt = updatedAt
    )
}
```

### Repository Implementation

```kotlin
class MerchantRepositoryImpl(private val database: Database) : MerchantRepository {

    override suspend fun findById(id: Long): Merchant? = dbQuery {
        MerchantEntity.findById(id)?.toDomain()
    }

    override suspend fun findAll(page: Int, limit: Int, status: String?): PaginatedResult<Merchant> = dbQuery {
        val query = Merchants.selectAll()
        status?.let { query.andWhere { Merchants.status eq it } }

        val total = query.count()
        val merchants = query
            .orderBy(Merchants.createdAt to SortOrder.DESC)
            .limit(limit, offset = (page * limit).toLong())
            .map { MerchantEntity.wrapRow(it).toDomain() }

        PaginatedResult(data = merchants, total = total, page = page, limit = limit)
    }

    override suspend fun create(merchant: Merchant): Merchant = dbQuery {
        MerchantEntity.new {
            mid = merchant.mid
            name = merchant.name
            type = merchant.type
            status = "active"
        }.toDomain()
    }

    override suspend fun delete(id: Long): Boolean = dbQuery {
        MerchantEntity.findById(id)?.let {
            it.status = "inactive"
            it.updatedAt = Clock.System.now().toJavaInstant()
            true
        } ?: false
    }

    private suspend fun <T> dbQuery(block: () -> T): T =
        newSuspendedTransaction(Dispatchers.IO, database) { block() }
}
```

### Flyway Migrations

```kotlin
fun Application.configureFlyway() {
    val dataSource = HikariDataSource(HikariConfig().apply {
        jdbcUrl = environment.config.property("database.url").getString()
        username = environment.config.property("database.user").getString()
        password = environment.config.property("database.password").getString()
        maximumPoolSize = 10
    })

    Flyway.configure()
        .dataSource(dataSource)
        .locations("classpath:db/migration")
        .load()
        .migrate()
}
```

### Schema Initialization (Development)

```kotlin
fun Application.initDatabase() {
    val database = Database.connect(
        url = environment.config.property("database.url").getString(),
        driver = "org.postgresql.Driver",
        user = environment.config.property("database.user").getString(),
        password = environment.config.property("database.password").getString()
    )

    transaction(database) {
        SchemaUtils.create(Merchants, AuditLogs)
    }
}
```

---

## 4. Dependency Injection (Koin)

### Module Definition

```kotlin
val appModule = module {
    // Database
    single<Database> {
        Database.connect(
            url = get<ApplicationConfig>().property("database.url").getString(),
            driver = "org.postgresql.Driver",
            user = get<ApplicationConfig>().property("database.user").getString(),
            password = get<ApplicationConfig>().property("database.password").getString()
        )
    }

    // Repositories
    single<MerchantRepository> { MerchantRepositoryImpl(get()) }
    single<AuditRepository> { AuditRepositoryImpl(get()) }

    // Services
    single<MerchantService> { MerchantServiceImpl(get(), get()) }
    single<AuthService> { AuthServiceImpl(get()) }

    // Factories (new instance per injection)
    factory<RequestValidator> { RequestValidatorImpl() }
}

val testModule = module {
    single<MerchantRepository> { MockMerchantRepository() }
    single<AuditRepository> { MockAuditRepository() }
    single<MerchantService> { MerchantServiceImpl(get(), get()) }
}
```

### Koin Installation in Application

```kotlin
fun Application.module() {
    install(Koin) {
        slf4jLogger()
        modules(appModule)
    }

    install(ContentNegotiation) { json() }
    install(StatusPages) { /* ... */ }

    configureRouting()
}
```

### Inject in Routes

```kotlin
fun Route.merchantRoutes() {
    val merchantService by inject<MerchantService>()

    route("/merchants") {
        get {
            val merchants = merchantService.findAll()
            call.respond(HttpStatusCode.OK, merchants)
        }
    }
}
```

### Module Verification Test

```kotlin
class KoinModuleTest : KoinTest {

    @Test
    fun `verify all modules`() {
        koinApplication {
            modules(appModule)
            checkModules {
                withInstance<ApplicationConfig>()
            }
        }
    }
}
```

---

## 5. Configuration

### HOCON application.conf

```hocon
ktor {
    deployment {
        port = 8080
        port = ${?PORT}
    }
    application {
        modules = [ com.example.ApplicationKt.module ]
    }
}

database {
    url = "jdbc:postgresql://localhost:5432/mydb"
    url = ${?DATABASE_URL}
    user = "postgres"
    user = ${?DATABASE_USER}
    password = "secret"
    password = ${?DATABASE_PASSWORD}
    pool_size = 10
    pool_size = ${?DATABASE_POOL_SIZE}
}

jwt {
    secret = "change-me-in-production"
    secret = ${?JWT_SECRET}
    issuer = "example.com"
    realm = "ktor-app"
    expiry_seconds = 86400
}
```

### Accessing Config Properties

```kotlin
fun Application.configureSecurity() {
    val jwtSecret = environment.config.property("jwt.secret").getString()
    val jwtIssuer = environment.config.property("jwt.issuer").getString()
    val jwtRealm = environment.config.property("jwt.realm").getString()
    val expirySeconds = environment.config.property("jwt.expiry_seconds").getString().toLong()

    install(Authentication) {
        jwt("auth-jwt") {
            realm = jwtRealm
            verifier(JWT.require(Algorithm.HMAC256(jwtSecret)).withIssuer(jwtIssuer).build())
            validate { credential ->
                JWTPrincipal(credential.payload)
            }
        }
    }
}
```

### Profile-Based Configuration

```hocon
# application-dev.conf
include "application.conf"

database {
    url = "jdbc:postgresql://localhost:5432/mydb_dev"
}

# application-prod.conf
include "application.conf"

ktor.deployment.port = 9090
database.pool_size = 25
```

### Selecting Profile at Runtime

```bash
# Via system property
java -jar app.jar -config=application-prod.conf

# Via environment variable
CONFIG_FILE=application-prod.conf java -jar app.jar
```

---

## 6. Testing

### testApplication Setup

```kotlin
class MerchantRoutesTest : KoinTest {

    private val mockMerchantService = mockk<MerchantService>()

    private val testModule = module {
        single<MerchantService> { mockMerchantService }
    }

    @Test
    fun `POST merchants should create and return 201`() = testApplication {
        application {
            install(Koin) {
                modules(testModule)
            }
            install(ContentNegotiation) { json() }
            install(StatusPages) { configureStatusPages() }
            configureRouting()
        }

        val request = CreateMerchantRequest(
            mid = "123456",
            name = "Test Shop",
            type = MerchantType.PHYSICAL
        )
        val expectedMerchant = Merchant(
            id = 1L,
            mid = "123456",
            name = "Test Shop",
            type = MerchantType.PHYSICAL,
            status = "active"
        )

        coEvery { mockMerchantService.create(any()) } returns expectedMerchant

        val response = client.post("/api/v1/merchants") {
            contentType(ContentType.Application.Json)
            setBody(Json.encodeToString(request))
        }

        assertEquals(HttpStatusCode.Created, response.status)
        val body = Json.decodeFromString<MerchantResponse>(response.bodyAsText())
        assertEquals("123456", body.mid)
        assertEquals("Test Shop", body.name)

        coVerify(exactly = 1) { mockMerchantService.create(any()) }
    }

    @Test
    fun `GET merchants by id should return 404 when not found`() = testApplication {
        application {
            install(Koin) { modules(testModule) }
            install(ContentNegotiation) { json() }
            install(StatusPages) { configureStatusPages() }
            configureRouting()
        }

        coEvery { mockMerchantService.findById(999L) } throws
            MerchantNotFoundException("Merchant 999 not found")

        val response = client.get("/api/v1/merchants/999")

        assertEquals(HttpStatusCode.NotFound, response.status)
        val problem = Json.decodeFromString<ProblemDetail>(response.bodyAsText())
        assertEquals("Merchant Not Found", problem.title)
    }

    @Test
    fun `GET merchants should return paginated list`() = testApplication {
        application {
            install(Koin) { modules(testModule) }
            install(ContentNegotiation) { json() }
            configureRouting()
        }

        val merchants = PaginatedResult(
            data = listOf(
                Merchant(1L, "111", "Shop A", MerchantType.PHYSICAL, "active"),
                Merchant(2L, "222", "Shop B", MerchantType.ONLINE, "active")
            ),
            total = 2,
            page = 0,
            limit = 20
        )

        coEvery { mockMerchantService.findAll(0, 20, null) } returns merchants

        val response = client.get("/api/v1/merchants?page=0&limit=20")

        assertEquals(HttpStatusCode.OK, response.status)
    }
}
```

### Integration Test with Test Database

```kotlin
class MerchantRepositoryIntegrationTest {

    companion object {
        private lateinit var database: Database

        @BeforeAll
        @JvmStatic
        fun setup() {
            database = Database.connect(
                url = "jdbc:h2:mem:test;DB_CLOSE_DELAY=-1",
                driver = "org.h2.Driver"
            )
            transaction(database) {
                SchemaUtils.create(Merchants)
            }
        }
    }

    private val repository = MerchantRepositoryImpl(database)

    @BeforeEach
    fun cleanup() {
        transaction(database) {
            Merchants.deleteAll()
        }
    }

    @Test
    fun `create and find merchant`() = runBlocking {
        val merchant = Merchant(mid = "12345", name = "Test", type = MerchantType.PHYSICAL)
        val created = repository.create(merchant)

        assertNotNull(created.id)

        val found = repository.findById(created.id)
        assertNotNull(found)
        assertEquals("12345", found!!.mid)
    }
}
```

---

## Anti-Patterns (Ktor-Specific)

- **Blocking calls in coroutines** — never use `runBlocking` inside route handlers; use `withContext(Dispatchers.IO)` or `newSuspendedTransaction` for blocking I/O
- **Missing StatusPages error handling** — unhandled exceptions produce empty 500 responses; always install `StatusPages` with handlers for expected exception types
- **N+1 queries without Exposed eager loading** — use `with(EntityClass)` for eager loading relationships, or write explicit join queries
- **Mutable state in routes** — route functions are shared across coroutines; never use `var` at the route scope for request-scoped data
- **Missing Content-Type negotiation** — forgetting to install `ContentNegotiation` causes `call.receive<T>()` and `call.respond()` to fail with serialization errors
- **Using `Thread.sleep()` in coroutines** — use `delay()` for coroutine-safe pausing
- **Not using `suspend` for repository functions** — repository methods called from coroutines should be suspending to avoid blocking the coroutine dispatcher
- **Hardcoded config values** — always use `application.conf` with environment variable fallbacks via `${?ENV_VAR}` syntax
