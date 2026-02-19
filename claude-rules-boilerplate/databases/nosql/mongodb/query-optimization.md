# MongoDB — Query Optimization

## Index Types

| Type | Syntax | Use Case | Notes |
|------|--------|----------|-------|
| **Single field** | `{ field: 1 }` | Equality/range on one field | Most common |
| **Compound** | `{ a: 1, b: -1 }` | Multi-field queries, sorting | Field order matters (ESR) |
| **Multikey** | `{ arrayField: 1 }` | Queries on array elements | Auto-detected, one multikey per compound |
| **Text** | `{ field: "text" }` | Full-text search | One per collection, use Atlas Search for advanced |
| **TTL** | `{ createdAt: 1 }, expireAfterSeconds: 3600` | Auto-delete expired documents | Only on date fields, single field only |
| **Wildcard** | `{ "$**": 1 }` | Unknown/dynamic field names | 7.0+: compound wildcard supported |
| **Hashed** | `{ field: "hashed" }` | Shard key for even distribution | No range queries, equality only |
| **Geospatial** | `{ location: "2dsphere" }` | Location queries | GeoJSON format |

## ESR Rule (Index Field Ordering)

Order compound index fields as: **Equality -> Sort -> Range**

```javascript
// Query: find active merchants, sorted by name, created after date
db.merchants.find({ status: "ACTIVE", createdAt: { $gte: date } }).sort({ name: 1 })

// Optimal index (ESR):
//   E: status (equality)
//   S: name (sort)
//   R: createdAt (range)
db.merchants.createIndex({ status: 1, name: 1, createdAt: 1 })
```

| Position | Purpose | Reason |
|----------|---------|--------|
| **Equality** first | Narrows candidates immediately | Exact match = most selective |
| **Sort** second | Avoids in-memory sort | Index already ordered |
| **Range** last | Scans subset of remaining | Range after equality still efficient |

## Aggregation Pipeline

| Stage | Purpose | Performance Tip |
|-------|---------|----------------|
| `$match` | Filter documents | Place FIRST to use indexes |
| `$project` | Select/reshape fields | Reduce document size early |
| `$group` | Aggregate values | Use `$accumulator` for custom logic |
| `$lookup` | Left outer join | Add index on foreign field; avoid in hot paths |
| `$unwind` | Flatten arrays | Combine with `$match` to filter before unwind |
| `$sort` | Order results | After `$match`, before `$limit` |
| `$limit` / `$skip` | Pagination | Use range-based pagination for large datasets |

**Pipeline optimization rule:** `$match` and `$project` as early as possible to reduce documents flowing through the pipeline.

```javascript
// Template: efficient aggregation
db.transactions.aggregate([
    { $match: { merchantId: mid, createdAt: { $gte: from, $lte: to } } },
    { $project: { amount: 1, responseCode: 1, createdAt: 1 } },
    { $group: { _id: "$responseCode", total: { $sum: "$amount" }, count: { $sum: 1 } } },
    { $sort: { count: -1 } }
])
```

## Query Analysis with .explain()

```javascript
db.merchants.find({ status: "ACTIVE" }).explain("executionStats")
```

| Metric | Good | Bad |
|--------|------|-----|
| `totalKeysExamined` / `nReturned` | Ratio close to 1 | Ratio >> 1 (over-scanning) |
| `executionTimeMillis` | < 10ms for indexed queries | > 100ms |
| `stage` | `IXSCAN` | `COLLSCAN` (no index used) |
| `totalDocsExamined` | Close to `nReturned` | Much larger than `nReturned` |
| `hasSortStage` | `false` (index-sorted) | `true` (in-memory sort) |

**Rule:** Every query in production MUST show `IXSCAN` in explain output. `COLLSCAN` on collections > 1000 documents is PROHIBITED.

## Connection Pool Configuration

### Quarkus (`application.properties`)

```properties
quarkus.mongodb.connection-string=mongodb://host:27017/db
quarkus.mongodb.min-pool-size=5
quarkus.mongodb.max-pool-size=20
quarkus.mongodb.max-idle-time=5m
quarkus.mongodb.connect-timeout=5s
quarkus.mongodb.socket-timeout=10s
quarkus.mongodb.server-selection-timeout=10s
```

### Spring Boot (`application.yml`)

```yaml
spring:
  data:
    mongodb:
      uri: mongodb://host:27017/db
      auto-index-creation: false  # Create indexes via migrations
```

### MongoClient Direct (Java Driver)

```java
MongoClientSettings settings = MongoClientSettings.builder()
    .applyConnectionString(new ConnectionString(uri))
    .applyToConnectionPoolSettings(pool -> pool
        .minSize(5)
        .maxSize(20)
        .maxWaitTime(3, TimeUnit.SECONDS)
        .maxConnectionIdleTime(5, TimeUnit.MINUTES))
    .applyToSocketSettings(socket -> socket
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS))
    .build();
```

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| No indexes | Full collection scan | Create indexes for all query patterns |
| `$lookup` in hot path | Slow, defeats NoSQL purpose | Denormalize, embed |
| Skip-based pagination | O(n) for large offsets | Range-based: `{ _id: { $gt: lastId } }` |
| Regex without anchor | `{ name: /test/ }` = full scan | Use `{ name: /^test/ }` (prefix match uses index) |
| Returning all fields | Wastes bandwidth and memory | Use projection: `{ mid: 1, name: 1 }` |
| `auto-index-creation: true` | Uncontrolled index creation | Create indexes via migrations only |
