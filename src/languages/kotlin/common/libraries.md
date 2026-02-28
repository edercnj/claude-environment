# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Kotlin Libraries

## Mandatory

| Library                | Purpose        | Justification                                 |
| ---------------------- | -------------- | --------------------------------------------- |
| kotlinx-serialization  | Serialization  | Kotlin-native, compile-time safe, multiplatform|
| JUnit 5                | Testing        | Standard, mature, Kotlin-compatible            |
| kotest or assertk      | Assertions     | Kotlin-idiomatic assertion DSL                 |

### kotlinx-serialization

```kotlin
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class MerchantResponse(
    val id: Long,
    val mid: String,
    val name: String,
    val status: String,
)

val json = Json {
    ignoreUnknownKeys = true
    prettyPrint = false
    encodeDefaults = true
}

val encoded = json.encodeToString(MerchantResponse.serializer(), response)
val decoded = json.decodeFromString<MerchantResponse>(jsonString)
```

### Alternative: Jackson with Kotlin Module

```kotlin
import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper

val mapper = jacksonObjectMapper().apply {
    setSerializationInclusion(JsonInclude.Include.NON_NULL)
    configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)
}

val json = mapper.writeValueAsString(response)
val merchant = mapper.readValue<MerchantResponse>(json)
```

### Assertk

```kotlin
import assertk.assertThat
import assertk.assertions.*

assertThat(merchant.mid).isEqualTo("MID001")
assertThat(merchants).hasSize(5)
assertThat(result).isInstanceOf(TransactionResult.Approved::class)
assertThat { service.findByMid("X") }.isFailure()
```

## Recommended

| Library               | Purpose            | When to Use                             |
| --------------------- | ------------------ | --------------------------------------- |
| Koin                  | DI                 | Lightweight, Kotlin-native DI           |
| Hilt                  | DI                 | Android/Spring projects                 |
| Ktor                  | HTTP client/server | Kotlin-native, coroutine-based          |
| Arrow                 | Functional         | Either, Validated, optics               |
| MockK                 | Mocking            | Kotlin-native mocking (coroutines)      |
| Exposed               | ORM                | Kotlin-native SQL DSL                   |
| kotlinx-coroutines    | Async              | Structured concurrency                  |
| kotlinx-datetime      | Date/time          | Multiplatform date/time                 |

### Koin (DI)

```kotlin
val appModule = module {
    single { MerchantRepository(get()) }
    single { MerchantService(get()) }
    single { DatabaseConnection(getProperty("db.url")) }
}

class MerchantService(private val repository: MerchantRepository) {
    fun findByMid(mid: String): Merchant? = repository.findByMid(mid)
}
```

### Ktor (HTTP Client)

```kotlin
val client = HttpClient(CIO) {
    install(ContentNegotiation) {
        json(Json { ignoreUnknownKeys = true })
    }
    install(HttpTimeout) {
        requestTimeoutMillis = 10_000
    }
}

suspend fun fetchMerchant(mid: String): Merchant {
    return client.get("https://api.example.com/merchants/$mid").body()
}
```

### Arrow (Functional)

```kotlin
import arrow.core.Either
import arrow.core.raise.either

fun createMerchant(request: CreateMerchantRequest): Either<DomainError, Merchant> = either {
    val existing = repository.findByMid(request.mid)
    ensure(existing == null) { DomainError.AlreadyExists(request.mid) }
    val merchant = MerchantDtoMapper.toDomain(request)
    repository.save(merchant)
}
```

## Prohibited

| Library/Pattern         | Reason                                 | Alternative              |
| ----------------------- | -------------------------------------- | ------------------------ |
| Java-only assertion libs| Not Kotlin-idiomatic                   | assertk or kotest        |
| Mockito (without Kotlin)| Limited coroutine/null-safety support  | MockK                    |
| Gson                    | No Kotlin support, reflection-heavy    | kotlinx-serialization    |
| Java Date/Calendar      | Mutable, error-prone                   | kotlinx-datetime or java.time |

## Build Tool

- **Gradle** with Kotlin DSL (`build.gradle.kts`) mandatory
- Version catalog (`libs.versions.toml`) for dependency management
- `gradle.lockfile` committed for reproducible builds

## Security

- Run dependency vulnerability checks in CI
- Pin all plugin and dependency versions
- Use Gradle wrapper (`gradlew`) committed to repository
