# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Ktor — Exposed ORM Patterns
> Extends: `core/11-database-principles.md`

## Table Definition (DSL Style)

```kotlin
object MerchantsTable : LongIdTable("merchants") {
    val mid = varchar("mid", 15).uniqueIndex()
    val name = varchar("name", 100)
    val document = varchar("document", 14)
    val mcc = varchar("mcc", 4)
    val status = varchar("status", 20).default("ACTIVE")
    val createdAt = datetime("created_at").defaultExpression(CurrentDateTime)
    val updatedAt = datetime("updated_at").defaultExpression(CurrentDateTime)
}

object TerminalsTable : LongIdTable("terminals") {
    val tid = varchar("tid", 8).uniqueIndex()
    val merchantId = reference("merchant_id", MerchantsTable)
    val modelName = varchar("model_name", 50)
    val serialNumber = varchar("serial_number", 50)
    val status = varchar("status", 20).default("ACTIVE")
    val forceTimeout = bool("force_timeout").default(false)
    val createdAt = datetime("created_at").defaultExpression(CurrentDateTime)
}
```

## DAO Style

```kotlin
class MerchantEntity(id: EntityID<Long>) : LongEntity(id) {
    companion object : LongEntityClass<MerchantEntity>(MerchantsTable)

    var mid by MerchantsTable.mid
    var name by MerchantsTable.name
    var document by MerchantsTable.document
    var mcc by MerchantsTable.mcc
    var status by MerchantsTable.status
    var createdAt by MerchantsTable.createdAt
    var updatedAt by MerchantsTable.updatedAt

    val terminals by TerminalEntity referrersOn TerminalsTable.merchantId

    fun toDomain(): Merchant = Merchant(id.value, mid, name, document, mcc, status, createdAt, updatedAt)
}
```

## Repository with Transactions

```kotlin
class MerchantRepositoryImpl(private val db: Database) : MerchantRepository {

    override suspend fun findById(id: Long): Merchant? = dbQuery {
        MerchantEntity.findById(id)?.toDomain()
    }

    override suspend fun findByMid(mid: String): Merchant? = dbQuery {
        MerchantEntity.find { MerchantsTable.mid eq mid }.firstOrNull()?.toDomain()
    }

    override suspend fun create(merchant: Merchant): Merchant = dbQuery {
        MerchantEntity.new {
            mid = merchant.mid
            name = merchant.name
            document = merchant.document
            mcc = merchant.mcc
        }.toDomain()
    }

    override suspend fun paginate(offset: Int, limit: Int): Pair<List<Merchant>, Long> = dbQuery {
        val total = MerchantEntity.count()
        val items = MerchantEntity.all()
            .orderBy(MerchantsTable.createdAt to SortOrder.DESC)
            .limit(limit).offset(offset.toLong())
            .map { it.toDomain() }
        items to total
    }

    private suspend fun <T> dbQuery(block: () -> T): T =
        newSuspendedTransaction(Dispatchers.IO, db) { block() }
}
```

## Database Factory

```kotlin
object DatabaseFactory {
    fun create(config: DatabaseConfig): Database {
        return Database.connect(
            url = config.url,
            driver = config.driver,
            user = config.user,
            password = config.password,
        )
    }

    fun createTables() {
        transaction {
            SchemaUtils.create(MerchantsTable, TerminalsTable)
        }
    }
}
```

## DSL vs DAO

| Feature        | DSL                          | DAO                          |
| -------------- | ---------------------------- | ---------------------------- |
| Syntax         | SQL-like lambdas             | Entity objects               |
| Relationships  | Manual joins                 | Automatic via references     |
| Performance    | Slightly faster              | More convenient              |
| Use case       | Complex queries, aggregates  | CRUD operations              |

## Anti-Patterns

- Do NOT execute transactions on the main coroutine dispatcher -- use `Dispatchers.IO`
- Do NOT expose Exposed entities outside the repository -- map to domain models
- Do NOT forget `newSuspendedTransaction` for coroutine-safe DB access
- Do NOT mix DSL and DAO styles in the same repository without clear reason
