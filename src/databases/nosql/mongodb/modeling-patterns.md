# MongoDB — Modeling Patterns

## Version Matrix

| Version | Key Features | EOL |
|---------|-------------|-----|
| **6.0** | Queryable Encryption, cluster-to-cluster sync, `$lookup` improvements | — |
| **7.0** | Compound wildcard indexes, `$percentile`, automatic merge for sharding | — |
| **8.0** | Queryable Encryption v2, improved bulk writes, OIDC auth, `$median` | Current |

## Embed vs Reference Decision

| Criterion | Embed (subdocument) | Reference (separate collection) |
|-----------|--------------------|---------------------------------|
| Relationship | 1:1 or 1:few | 1:many or many:many |
| Read pattern | Always read together | Read independently |
| Document growth | Bounded, predictable | Unbounded potential |
| Update frequency | Low on embedded data | High on referenced data |
| Document size | Total < 16MB | Would exceed 16MB |
| Atomicity needed | Yes (single doc = atomic) | No (multi-doc transaction OK) |
| Data duplication | Acceptable | Unacceptable |

**Decision shortcut:**
- Embed: address in user, line items in order (bounded)
- Reference: comments on post (unbounded), shared catalog items

## Modeling Patterns

| Pattern | Problem | Solution | Example |
|---------|---------|----------|---------|
| **Subset** | Document too large, most fields rarely read | Embed frequently-accessed subset, reference the rest | Product summary embedded, full specs in separate collection |
| **Computed** | Expensive aggregations on every read | Pre-compute and store result, update on write | `totalOrders` field on customer document |
| **Bucket** | Many small documents (time-series) | Group into buckets (e.g., 1 doc per hour) | IoT readings: 1 document = 60 measurements |
| **Outlier** | Few documents violate normal pattern | Flag outliers, store overflow in separate doc | Celebrity with 10M followers vs normal user with 200 |
| **Schema Versioning** | Schema evolves over time | `_schemaVersion` field, transform on read | Lazy migration of legacy documents |

## Schema Validation

```javascript
db.createCollection("merchants", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["mid", "name", "status", "createdAt"],
      properties: {
        mid: { bsonType: "string", maxLength: 15 },
        name: { bsonType: "string", maxLength: 100 },
        status: { enum: ["ACTIVE", "INACTIVE", "DELETED"] },
        createdAt: { bsonType: "date" }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
})
```

## Hard Limits

| Limit | Value | Consequence |
|-------|-------|-------------|
| Document size | **16 MB** | Split into multiple documents or use GridFS |
| Namespace length | 120 bytes | Keep database + collection names short |
| Nesting depth | 100 levels | Flatten deeply nested structures |
| Index key size | 1024 bytes | Use hashed indexes for large keys |
| Indexes per collection | 64 | Consolidate with compound indexes |

## Fatal Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| **Unbounded arrays** | Array grows indefinitely, hits 16MB | Bucket pattern or separate collection |
| **Massive documents** | Slow reads, wasted bandwidth | Subset pattern |
| **Relational modeling** | Excessive `$lookup` (JOIN equivalent) | Denormalize, embed |
| **No indexes** | Collection scans on every query | Create indexes for all query patterns |
| **Indexing everything** | Write amplification, wasted RAM | Index only queried fields |

## Framework Integration

| Framework | Extension/Dependency | Repository Pattern |
|-----------|---------------------|-------------------|
| **Quarkus** | `quarkus-mongodb-panache` | `PanacheMongoEntity` (Active Record) or `PanacheMongoRepository` |
| **Spring Boot** | `spring-boot-starter-data-mongodb` | `MongoRepository<T, ID>` interface |

### Quarkus Example

```java
@MongoEntity(collection = "merchants")
public class MerchantEntity extends PanacheMongoEntity {
    public String mid;
    public String name;
    public String status;
    public Instant createdAt;

    public static Optional<MerchantEntity> findByMid(String mid) {
        return find("mid", mid).firstResultOptional();
    }
}
```

### Spring Boot Example

```java
@Document(collection = "merchants")
public class MerchantDocument {
    @Id private String id;
    @Indexed(unique = true) private String mid;
    private String name;
    private String status;
    private Instant createdAt;
}

public interface MerchantRepository extends MongoRepository<MerchantDocument, String> {
    Optional<MerchantDocument> findByMid(String mid);
}
```
