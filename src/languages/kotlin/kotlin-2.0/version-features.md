# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Kotlin 2.0 Version Features

## K2 Compiler

The K2 compiler replaces the legacy frontend, delivering significant performance improvements.

```kotlin
// build.gradle.kts
kotlin {
    compilerOptions {
        languageVersion.set(KotlinVersion.KOTLIN_2_0)
        apiVersion.set(KotlinVersion.KOTLIN_2_0)
    }
}
```

### Performance Improvements

| Metric                    | K1 (Legacy) | K2        |
| ------------------------- | ----------- | --------- |
| Full build time           | Baseline    | ~40% faster |
| Incremental compilation   | Baseline    | ~25% faster |
| Type inference accuracy   | Baseline    | Improved   |
| IDE responsiveness        | Baseline    | Improved   |

### Improved Type Inference

```kotlin
// K2 handles more complex inference scenarios
val items = buildList {
    add("hello")
    add("world")
    // K2 infers List<String> more reliably in complex builders
}

// Better smart cast propagation
fun process(value: Any) {
    if (value is String && value.length > 5) {
        // K2 smart casts more aggressively across conditions
        println(value.uppercase())
    }
}
```

## Context Receivers

Provide implicit context parameters to functions without polluting the parameter list.

```kotlin
// Define a context
class TransactionContext(
    val traceId: String,
    val merchantId: String,
)

class LoggingContext(
    val logger: Logger,
)

// Function requiring contexts
context(TransactionContext, LoggingContext)
fun processPayment(amount: BigDecimal): PaymentResult {
    logger.info("Processing payment", "traceId" to traceId, "merchant" to merchantId)
    // traceId and merchantId available implicitly
    return PaymentResult.approved(amount)
}

// Calling with context
with(TransactionContext(traceId = "abc", merchantId = "MID001")) {
    with(LoggingContext(logger = appLogger)) {
        val result = processPayment(BigDecimal("100.00"))
    }
}

// Practical: repository operations with context
context(DatabaseContext)
fun MerchantRepository.findActive(): List<Merchant> {
    return connection.query("SELECT * FROM merchants WHERE status = 'ACTIVE'")
}
```

## Value Classes (Inline Classes)

Zero-overhead type wrappers for domain primitives.

```kotlin
@JvmInline
value class MerchantId(val value: String) {
    init {
        require(value.isNotBlank()) { "MerchantId must not be blank" }
        require(value.length <= 15) { "MerchantId must not exceed 15 characters" }
    }
}

@JvmInline
value class TerminalId(val value: String) {
    init {
        require(value.length == 8) { "TerminalId must be exactly 8 characters" }
    }
}

@JvmInline
value class AmountCents(val value: Long) {
    init {
        require(value >= 0) { "Amount must be non-negative" }
    }

    fun toBigDecimal(): BigDecimal = BigDecimal(value).movePointLeft(2)
}

// Usage - compile-time type safety, zero runtime overhead
fun findMerchant(id: MerchantId): Merchant? = repository.findByMid(id.value)

// Cannot accidentally pass TerminalId where MerchantId is expected
val mid = MerchantId("MID000000000001")
val tid = TerminalId("TERM0001")
// findMerchant(tid) // Compilation error
```

## Data Objects

Combine `data` and `object` for singleton value types with proper `toString`.

```kotlin
// OLD - object without meaningful toString
object NoFilter : TransactionFilter {
    override fun apply(tx: Transaction): Boolean = true
    // toString() returns "NoFilter@1a2b3c4d"
}

// NEW (2.0) - data object with auto-generated toString
sealed interface TransactionFilter {
    fun apply(tx: Transaction): Boolean

    data object NoFilter : TransactionFilter {
        override fun apply(tx: Transaction): Boolean = true
        // toString() returns "NoFilter"
    }

    data class ByMerchant(val mid: String) : TransactionFilter {
        override fun apply(tx: Transaction): Boolean = tx.merchantId == mid
    }

    data class ByResponseCode(val code: String) : TransactionFilter {
        override fun apply(tx: Transaction): Boolean = tx.responseCode == code
    }
}

// Exhaustive when
fun describe(filter: TransactionFilter): String = when (filter) {
    is TransactionFilter.NoFilter -> "All transactions"
    is TransactionFilter.ByMerchant -> "Merchant: ${filter.mid}"
    is TransactionFilter.ByResponseCode -> "Response code: ${filter.code}"
}
```

## Improved Smart Casts

```kotlin
// K2 compiler handles more complex smart cast scenarios
sealed class Result<out T> {
    data class Success<T>(val value: T) : Result<T>()
    data class Failure(val error: Throwable) : Result<Nothing>()
}

fun <T> Result<T>.getOrThrow(): T = when (this) {
    is Result.Success -> value  // Smart cast works across sealed hierarchy
    is Result.Failure -> throw error
}

// Smart cast after contract-like checks
fun processInput(input: Any?) {
    requireNotNull(input)
    // input is now non-null smart cast

    if (input is String) {
        // input is String here
        println(input.uppercase())
    }
}

// Smart cast in combined conditions (improved in K2)
fun handle(value: Any) {
    if (value is List<*> && value.isNotEmpty()) {
        val first = value.first() // K2 preserves the smart cast
    }
}
```

## Guard Conditions in When

```kotlin
// Kotlin 2.1+ preview, available with language version 2.0+
sealed interface Response {
    data class Success(val data: String) : Response
    data class Error(val code: Int, val message: String) : Response
}

fun handleResponse(response: Response) = when (response) {
    is Response.Success -> "Data: ${response.data}"
    is Response.Error if response.code == 404 -> "Not found: ${response.message}"
    is Response.Error if response.code == 500 -> "Server error: ${response.message}"
    is Response.Error -> "Error ${response.code}: ${response.message}"
}
```
