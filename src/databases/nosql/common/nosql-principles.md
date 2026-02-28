# NoSQL Principles

## CAP Theorem — Practical Tradeoffs

Every distributed system must choose two of three guarantees during a network partition.

| Guarantee | Description | Sacrifice |
|-----------|-------------|-----------|
| **CP** (Consistency + Partition Tolerance) | All nodes see the same data; rejects writes during partition | Availability |
| **AP** (Availability + Partition Tolerance) | All nodes accept reads/writes; data may diverge temporarily | Consistency |
| **CA** (Consistency + Availability) | Only possible without partitions (single-node) | Partition Tolerance |

| System | CAP Choice | Example Use Case |
|--------|-----------|------------------|
| MongoDB (default) | CP | Financial ledgers, inventory counts |
| Cassandra | AP | IoT telemetry, activity feeds |
| DynamoDB | AP (tunable) | Shopping carts, session stores |
| Redis Cluster | AP | Caching, rate limiting |
| CockroachDB | CP | Distributed SQL, banking |

## Query-Driven Modeling

NoSQL data modeling starts from **access patterns**, not entity relationships.

1. List every query the application executes
2. Design tables/collections/documents to serve each query directly
3. Duplicate data across structures if needed — reads are optimized, writes pay the cost

**Relational:** normalize first, query with JOINs.
**NoSQL:** denormalize first, query without JOINs.

## Denormalization as Pattern

| Aspect | Relational | NoSQL |
|--------|-----------|-------|
| Duplication | Anti-pattern | Expected pattern |
| JOINs | Cheap (DB engine) | Expensive or impossible |
| Write cost | Low (single update) | Higher (update N copies) |
| Read cost | Higher (multiple tables) | Low (single read) |
| Consistency | Guaranteed by FK | Application responsibility |

**Rule:** Denormalize when read frequency >> write frequency for the same data.

## Consistency Models

| Model | Guarantee | Latency | Use Case |
|-------|-----------|---------|----------|
| **Strong** | Read returns latest write | Higher | Financial transactions, inventory |
| **Eventual** | Read may return stale data (converges) | Lower | Social feeds, analytics, caches |
| **Causal** | Respects cause-effect ordering | Medium | Chat messages, comment threads |
| **Read-your-writes** | Writer sees own updates immediately | Medium | User profile edits |

**Decision rule:** Use strong consistency when incorrect data causes money loss or safety risk. Use eventual everywhere else.

## Schema Evolution Strategies

| Strategy | Description | Best For |
|----------|-------------|----------|
| **Schema versioning** | `_schemaVersion` field per document | MongoDB, document DBs |
| **Lazy migration** | Transform on read, write back new format | High-volume collections |
| **Eager migration** | Batch job transforms all documents | Small collections, downtime OK |
| **Expand-contract** | Add new field -> migrate -> remove old field | Zero-downtime deployments |
| **Default values** | Application fills missing fields on read | Additive changes only |

## SQL vs NoSQL Decision Matrix

| Criterion | Choose SQL | Choose NoSQL |
|-----------|-----------|-------------|
| Data relationships | Complex, many-to-many | Simple, hierarchical |
| Schema | Stable, well-defined | Evolving, flexible |
| Transactions | Multi-table ACID required | Single-document sufficient |
| Query patterns | Ad-hoc, complex reporting | Known, optimized paths |
| Scale model | Vertical (scale-up) sufficient | Horizontal (scale-out) required |
| Consistency | Strong consistency mandatory | Eventual consistency acceptable |
| Data volume | < 10TB, moderate throughput | > 10TB or high throughput |
| Team expertise | SQL proficiency | NoSQL proficiency |
| Joins | Frequent cross-entity queries | Rare or none |
| Compliance | ACID audit trails required | Flexibility over guarantees |

**Anti-pattern:** Using NoSQL because it is "modern." If your data is relational and fits in a single node, PostgreSQL is almost always the better choice.
