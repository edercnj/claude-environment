# Database & Cache Version Compatibility Matrix

## SQL Databases

| Feature | PG 14 | PG 15 | PG 16 | PG 17 | Oracle 19c | Oracle 21c | Oracle 23ai | MySQL 8.0 | MySQL 8.4 | MySQL 9.x |
|---|---|---|---|---|---|---|---|---|---|---|
| JSON support | jsonb | jsonb + JSON_TABLE (preview) | SQL/JSON standard | SQL/JSON full | JSON columns | Native JSON duality | JSON Relational Duality Views | JSON partial | JSON improved | JSON full |
| Generated columns | Stored only | Stored only | Stored only | Stored only | Virtual + Stored | Virtual + Stored | Virtual + Stored | Virtual + Stored | Virtual + Stored | Virtual + Stored |
| Logical replication | Tables only | Row filters, column lists | Parallel apply, standby | Failover slots, subscriber | GoldenGate | GoldenGate | Built-in Raft | binlog | binlog improved | Group Replication |
| Partitioning | Hash, Range, List | MERGE, SPLIT partition | SPLIT/MERGE concurrency | Identity on partitions | Interval, Hash, Range | Auto List | Auto partitioning | Range, Hash, List, Key | Improved pruning | Improved pruning |
| BOOLEAN native | Yes | Yes | Yes | Yes | NUMBER(1) | NUMBER(1) | BOOLEAN native | TINYINT(1) alias | TINYINT(1) alias | TINYINT(1) alias |
| Identity columns | GENERATED ALWAYS | GENERATED ALWAYS | GENERATED ALWAYS | GENERATED ALWAYS | GENERATED ALWAYS | GENERATED ALWAYS | GENERATED ALWAYS | AUTO_INCREMENT | AUTO_INCREMENT | AUTO_INCREMENT |
| DDL transactional | Yes | Yes | Yes | Yes | No (implicit commit) | No (implicit commit) | No (implicit commit) | No (implicit commit) | No (implicit commit) | No (implicit commit) |
| MERGE statement | No | MERGE added | MERGE | MERGE | Yes | Yes | Yes | No | No | No |
| pg_stat_io / IO stats | No | No | pg_stat_io | Enhanced | AWR/ASH | AWR/ASH | AWR/ASH | P_S | P_S | P_S |
| Vector search | pgvector ext | pgvector ext | pgvector ext | pgvector ext | No | No | AI Vector Search | No | No | HeatWave ML |

## NoSQL Databases

| Feature | MongoDB 6.0 | MongoDB 7.0 | MongoDB 8.0 | Cassandra 4.1 | Cassandra 5.0 | ScyllaDB 5.x |
|---|---|---|---|---|---|---|
| Queryable encryption | Preview | GA | Enhanced | N/A | N/A | N/A |
| Time series collections | Improved | Auto bucketing | Optimized | TTL per row | TTL per row | TTL per row |
| Change streams | Pre/post images | Split events | Optimized | CDC | Improved CDC | CDC |
| Aggregation | $densify, $fill | $percentile, $median | $rank window | UDA | UDA improved | UDA |
| Vector search | No | Atlas Vector Search | Native $vectorSearch | No | SAI with vectors | No |
| Sharding | Resharding online | Global indexes | Improved balancer | vnodes + tablets (beta) | Tablets GA | Tablets native |
| Transactions | Multi-doc | Multi-doc improved | Faster commits | Lightweight (CAS) | Accord protocol | Lightweight (CAS) |
| Compression | Snappy, Zstd | Snappy, Zstd | Zstd default | LZ4, Snappy, Zstd | LZ4, Snappy, Zstd | LZ4, Snappy, Zstd |

## Cache Systems

| Feature | Redis 7.0 | Redis 7.2 | Redis 7.4 | Dragonfly 1.x | Memcached 1.6 |
|---|---|---|---|---|---|
| Functions (Lua replacement) | Redis Functions GA | Triggers preview | Triggers improved | Lua compat | N/A |
| Client-side caching | Tracking mode | Tracking improved | Tracking + RESP3 | Not supported | N/A |
| ACL improvements | Selectors, Pub/Sub ACL | Command permissions | Key-pattern ACL | Basic ACL | SASL only |
| Multi-thread | I/O threads | I/O threads improved | I/O threads improved | Shared-nothing arch | Multi-thread native |
| Memory efficiency | listpack encoding | listpack improved | Optimized SDS | Dash data structure | Slab allocator |
| Streams | Full support | Consumer groups improved | Improved trimming | Partial compat | N/A |
| Cluster | Hash slots | Improved resharding | Slot migration improved | Single-node (multi-thread) | Consistent hashing |
| Pub/Sub | Sharded Pub/Sub | Sharded improved | Sharded improved | Full compat | N/A |
| Persistence | RDB + AOF | RDB + AOF improved | AOF improved | Snapshots | None (volatile) |

## Framework Integration

| Database | Quarkus Extension | Spring Boot Starter | Driver / Client |
|---|---|---|---|
| PostgreSQL | `quarkus-jdbc-postgresql`, `quarkus-reactive-pg-client` | `spring-boot-starter-data-jpa` + `postgresql` | `org.postgresql:postgresql` |
| Oracle | `quarkus-jdbc-oracle` | `spring-boot-starter-data-jpa` + `ojdbc11` | `com.oracle.database.jdbc:ojdbc11` |
| MySQL | `quarkus-jdbc-mysql` | `spring-boot-starter-data-jpa` + `mysql-connector-j` | `com.mysql:mysql-connector-j` |
| MongoDB | `quarkus-mongodb-panache` | `spring-boot-starter-data-mongodb` | `org.mongodb:mongodb-driver-sync` |
| Cassandra | `quarkus-cassandra-client` | `spring-boot-starter-data-cassandra` | `com.datastax.oss:java-driver-core` |
| ScyllaDB | `quarkus-cassandra-client` (compatible) | `spring-boot-starter-data-cassandra` (compatible) | `com.datastax.oss:java-driver-core` (shard-aware) |
| Redis | `quarkus-redis-client` | `spring-boot-starter-data-redis` | `io.lettuce:lettuce-core` / `redis.clients:jedis` |
| Dragonfly | `quarkus-redis-client` (compatible) | `spring-boot-starter-data-redis` (compatible) | `io.lettuce:lettuce-core` (RESP compat) |
| Memcached | Community / `spymemcached` | `spring-boot-starter-cache` + `xmemcached` | `net.spy:spymemcached` / `com.googlecode.xmemcached:xmemcached` |
