# Cassandra — Modeling Patterns

## Version Matrix

| Distribution | Version | Key Features |
|-------------|---------|-------------|
| **Apache Cassandra** | 4.1 | Virtual tables, audit logging, Java 11+ |
| **Apache Cassandra** | 5.0 | Trie-based indexes (SAI), JDK 17, vector search, unified compaction |
| **DataStax Enterprise** | 6.8+ | DSE Search (Solr), DSE Graph, advanced security |
| **ScyllaDB** | 5.x / 6.x | C++ rewrite, shard-per-core, compatible CQL, 10x throughput |

## Core Principle: Query-First Design

In Cassandra, you design **one table per query pattern**. There are no JOINs, no secondary indexes for production (use SAI or materialized views sparingly).

| Step | Action |
|------|--------|
| 1 | List all queries the application needs |
| 2 | Design one table per query |
| 3 | Duplicate data across tables as needed |
| 4 | Validate partition sizes (< 100MB) |

## Partition Key Design

| Concern | Rule |
|---------|------|
| Max partition size | **100 MB** (soft limit, degrades above) |
| Hot partitions | Distribute writes evenly across partitions |
| Partition key selection | High cardinality field(s) |
| Compound partition key | `((tenant_id, bucket), event_time)` to spread load |
| Single partition reads | FAST (single node) |
| Cross-partition reads | SLOW (coordinator fans out) — avoid |

### Partition Key vs Clustering Key

| Component | Purpose | Determines | Example |
|-----------|---------|-----------|---------|
| **Partition key** | Which node stores the data | Data distribution | `merchant_id` |
| **Clustering key** | Order within partition | Sort order on disk | `created_at DESC` |

```sql
CREATE TABLE transactions_by_merchant (
    merchant_id TEXT,
    created_at  TIMESTAMP,
    stan        TEXT,
    amount      BIGINT,
    response_code TEXT,
    PRIMARY KEY ((merchant_id), created_at)
) WITH CLUSTERING ORDER BY (created_at DESC);
```

## Bucketing Patterns

Prevent unbounded partition growth by adding a time bucket to the partition key.

| Strategy | Partition Key | Use Case |
|----------|--------------|----------|
| **Daily bucket** | `((merchant_id, date), created_at)` | Medium volume (< 10K rows/day) |
| **Hourly bucket** | `((sensor_id, hour), timestamp)` | High volume IoT |
| **Monthly bucket** | `((user_id, month), event_time)` | Low volume per user |
| **Modulo bucket** | `((entity_id, id % N), ...)` | Even spread, no time affinity |

```sql
CREATE TABLE transactions_by_merchant_daily (
    merchant_id TEXT,
    tx_date     DATE,        -- bucket
    created_at  TIMESTAMP,
    stan        TEXT,
    amount      BIGINT,
    response_code TEXT,
    PRIMARY KEY ((merchant_id, tx_date), created_at)
) WITH CLUSTERING ORDER BY (created_at DESC);
```

## Table Naming Convention

Suffix tables with the query pattern they serve:

| Table Name | Query It Serves |
|-----------|----------------|
| `transactions_by_merchant` | Get transactions for a merchant |
| `transactions_by_stan_and_date` | Lookup transaction by STAN + date |
| `merchants_by_status` | List merchants filtered by status |
| `terminals_by_merchant` | Get terminals for a merchant |
| `events_by_user_daily` | Get user events bucketed by day |

## Framework Integration

| Framework | Extension/Dependency | Mapper |
|-----------|---------------------|--------|
| **Quarkus** | `quarkus-cassandra` | DataStax Java Driver Mapper (`@Entity`, `@Dao`) |
| **Spring Boot** | `spring-boot-starter-data-cassandra` | `CassandraRepository<T, ID>` |

### Quarkus (DataStax Mapper)

```java
@Entity
@CqlName("transactions_by_merchant")
public class TransactionEntity {
    @PartitionKey
    private String merchantId;
    @ClusteringColumn
    private Instant createdAt;
    private String stan;
    private long amount;
    private String responseCode;
}

@Dao
public interface TransactionDao {
    @Select
    PagingIterable<TransactionEntity> findByMerchant(String merchantId);

    @Insert
    void save(TransactionEntity entity);
}
```

### Spring Boot

```java
@Table("transactions_by_merchant")
public class TransactionEntity {
    @PrimaryKeyColumn(type = PrimaryKeyType.PARTITIONED)
    private String merchantId;
    @PrimaryKeyColumn(type = PrimaryKeyType.CLUSTERED, ordering = Ordering.DESCENDING)
    private Instant createdAt;
    private String stan;
    private long amount;
    private String responseCode;
}
```

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Relational modeling | No JOINs, slow multi-partition reads | One table per query |
| Unbounded partitions | Partition > 100MB degrades performance | Bucketing |
| Secondary indexes in prod | Full cluster scan | SAI (5.0+) or dedicated table |
| `SELECT *` without partition key | Full table scan | Always include partition key in WHERE |
| Wide rows without TTL | Partitions grow forever | Set TTL on time-series data |
| Counter tables for analytics | Counter limitations (no read-before-write) | Pre-aggregation tables |
