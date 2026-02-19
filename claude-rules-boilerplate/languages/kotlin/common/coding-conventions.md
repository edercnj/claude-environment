# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Kotlin Coding Conventions

## Style Enforcement

- **ktlint** or **detekt** mandatory
- Follow official Kotlin coding conventions
- Line length: **120 characters** maximum

## Naming Conventions

| Element         | Convention     | Example                    |
| --------------- | -------------- | -------------------------- |
| Class           | PascalCase     | `OrderProcessor`           |
| Interface       | PascalCase     | `MerchantRepository`       |
| Function        | camelCase      | `processOrder()`           |
| Property        | camelCase      | `merchantName`             |
| Constant        | UPPER_SNAKE    | `MAX_RETRY_COUNT`          |
| Enum Entry      | UPPER_SNAKE    | `PENDING`, `APPROVED`      |
| Package         | lowercase      | `com.example.merchant`     |
| File            | PascalCase     | `OrderProcessor.kt`        |
| Type Parameter  | Single letter  | `T`, `K`, `V`              |

## Data Classes for DTOs

```kotlin
// CORRECT - data class for immutable DTOs
data class MerchantResponse(
    val id: Long,
    val mid: String,
    val name: String,
    val documentMasked: String,
    val status: MerchantStatus,
    val createdAt: Instant,
)

data class CreateMerchantRequest(
    val mid: String,
    val name: String,
    val document: String,
    val mcc: String,
    val timeoutEnabled: Boolean = false,
)
```

## Sealed Classes

```kotlin
// CORRECT - sealed for exhaustive hierarchies
sealed class TransactionResult {
    data class Approved(val authCode: String, val stan: String) : TransactionResult()
    data class Denied(val responseCode: String, val reason: String) : TransactionResult()
    data class Error(val message: String, val cause: Throwable? = null) : TransactionResult()
}

// Exhaustive when expression
fun handleResult(result: TransactionResult): String = when (result) {
    is TransactionResult.Approved -> "Approved: ${result.authCode}"
    is TransactionResult.Denied -> "Denied: ${result.responseCode} - ${result.reason}"
    is TransactionResult.Error -> "Error: ${result.message}"
}
```

## Extension Functions

```kotlin
// CORRECT - utility operations as extensions
fun String.maskDocument(): String {
    if (length < 5) return "****"
    return "${substring(0, 3)}****${substring(length - 2)}"
}

fun BigDecimal.toCents(): Long = multiply(BigDecimal(100)).toLong()

fun <T> List<T>.toPaginatedResponse(page: Int, limit: Int, total: Long): PaginatedResponse<T> {
    val totalPages = ((total + limit - 1) / limit).toInt()
    return PaginatedResponse(this, PaginationInfo(page, limit, total, totalPages))
}
```

## Null Safety

```kotlin
// CORRECT - leverage Kotlin null safety
fun findMerchant(mid: String): Merchant? {
    return repository.findByMid(mid)
}

// Safe call + elvis operator
val city = merchant?.address?.city ?: "Unknown"

// FORBIDDEN - excessive use of !!
val name = merchant!!.name  // Avoid this

// CORRECT - require/check for preconditions
fun processOrder(order: Order) {
    require(order.amount > BigDecimal.ZERO) { "Amount must be positive" }
    check(order.status == OrderStatus.PENDING) { "Order must be in PENDING status" }
}
```

## Named Arguments

```kotlin
// CORRECT - named arguments for 3+ parameters
val merchant = createMerchant(
    mid = "MID000000000001",
    name = "Test Store",
    document = "12345678000190",
    mcc = "5411",
    timeoutEnabled = false,
)

// 1-2 parameters: named arguments optional
val result = findByMid("MID001")
```

## When Expressions

```kotlin
// CORRECT - exhaustive when for sealed types
fun mapResponseCode(code: String): String = when (code) {
    "00" -> "Approved"
    "05" -> "Generic Error"
    "14" -> "Invalid Card"
    "51" -> "Insufficient Funds"
    "96" -> "System Error"
    else -> "Unknown: $code"
}
```

## Coroutines

```kotlin
// CORRECT - suspend functions for async
suspend fun processTransaction(request: IsoMessage): TransactionResult {
    val merchant = merchantRepository.findByMid(request.merchantId)
        ?: return TransactionResult.Denied("14", "Merchant not found")

    val decision = withContext(Dispatchers.Default) {
        decisionEngine.decide(request.amount)
    }

    return TransactionResult.Approved(decision.authCode, request.stan)
}
```

## Object Declarations

```kotlin
// CORRECT - object for singletons
object MerchantDtoMapper {
    fun toResponse(merchant: Merchant): MerchantResponse = MerchantResponse(
        id = merchant.id,
        mid = merchant.mid,
        name = merchant.name,
        documentMasked = merchant.document.maskDocument(),
        status = merchant.status,
        createdAt = merchant.createdAt,
    )

    fun toDomain(request: CreateMerchantRequest): Merchant = Merchant(
        mid = request.mid,
        name = request.name,
        document = request.document,
        mcc = request.mcc,
    )
}

// CORRECT - companion object for factory methods
class Merchant private constructor(val mid: String, val name: String) {
    companion object {
        fun create(mid: String, name: String): Merchant {
            require(mid.isNotBlank()) { "MID must not be blank" }
            return Merchant(mid, name)
        }
    }
}
```

## Properties over Getters/Setters

```kotlin
// FORBIDDEN - Java-style getters/setters
class Merchant {
    private var name: String = ""
    fun getName(): String = name
    fun setName(value: String) { name = value }
}

// CORRECT - Kotlin properties
class Merchant(
    val mid: String,
    var name: String,
    val status: MerchantStatus = MerchantStatus.ACTIVE,
) {
    val isActive: Boolean get() = status == MerchantStatus.ACTIVE
}
```

## Size Limits

- Max **25 lines** per function
- Max **250 lines** per file
- Max **4 parameters** per function (use data class for more)

## Anti-Patterns (FORBIDDEN)

- Java-style getters/setters (use properties)
- `!!` operator without justification
- Platform types (`String!`) leaking into APIs
- Mutable collections in public APIs (use `List` not `MutableList`)
- `companion object` for utility functions (use top-level or extension functions)
- `var` when `val` is possible
