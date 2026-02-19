# Cassandra — Query Optimization

## Consistency Levels

| Level | Nodes Consulted | Latency | Use Case |
|-------|----------------|---------|----------|
| **ONE** | 1 replica | Lowest | Logging, analytics, non-critical reads |
| **TWO** | 2 replicas | Low | Improved confidence over ONE |
| **QUORUM** | ⌈(N+1)/2⌉ replicas | Medium | Default for most operations |
| **LOCAL_QUORUM** | Quorum in local DC | Medium | Multi-DC: strong local, eventual cross-DC |
| **EACH_QUORUM** | Quorum in each DC | Higher | Multi-DC: strong everywhere (writes only) |
| **ALL** | All replicas | Highest | Rare: maximum consistency, lowest availability |

### Strong Consistency Formula

```
R + W > N  →  Strong consistency guaranteed
```

| Configuration | R | W | N | Consistency | Availability |
|--------------|---|---|---|-------------|--------------|
| QUORUM read + QUORUM write | 2 | 2 | 3 | Strong | Tolerates 1 node down |
| ONE read + ALL write | 1 | 3 | 3 | Strong | Low write availability |
| ALL read + ONE write | 3 | 1 | 3 | Strong | Low read availability |
| ONE read + ONE write | 1 | 1 | 3 | Eventual | High availability |

**Recommendation:** `LOCAL_QUORUM` for both reads and writes in production.

## ALLOW FILTERING

**PROHIBITED in production.** Forces a full cluster scan.

| Query Type | Allowed | Reason |
|-----------|---------|--------|
| Partition key equality | Yes | Direct node lookup |
| Partition key + clustering key | Yes | Single partition range scan |
| Clustering key only | **NO** | Requires scanning all partitions |
| Non-key column | **NO** | Full cluster scan |
| With `ALLOW FILTERING` | **DEV ONLY** | Circumvents safety check |

```sql
-- ALLOWED: partition key specified
SELECT * FROM transactions_by_merchant WHERE merchant_id = '123' AND tx_date = '2026-02-18';

-- PROHIBITED: no partition key
SELECT * FROM transactions_by_merchant WHERE response_code = '00' ALLOW FILTERING;
-- Fix: create transactions_by_response_code table
```

## Storage Attached Indexes (SAI) — Cassandra 5.0+

SAI replaces legacy secondary indexes with better performance.

| Feature | Legacy 2i | SAI |
|---------|-----------|-----|
| Performance | Poor at scale | Good |
| Numeric range queries | No | Yes |
| Memory overhead | High | Low |
| Production-ready | No | Yes (5.0+) |

```sql
CREATE CUSTOM INDEX ON transactions_by_merchant (response_code)
USING 'StorageAttachedIndex';
```

**Rule:** SAI is acceptable for low-cardinality filtering within a partition. For high-volume queries, create a dedicated table.

## Tombstones and Compaction

### Tombstone Problem

Deletes in Cassandra create **tombstones** (markers) instead of removing data. Excessive tombstones degrade read performance.

| Situation | Impact | Mitigation |
|-----------|--------|------------|
| Frequent deletes | Read latency increases | Use TTL instead of DELETE |
| Wide partition deletes | GC pressure | Range delete + repair |
| gc_grace_seconds expired | Tombstones removed on compaction | Run repair within gc_grace window |

### Compaction Strategies

| Strategy | Best For | Characteristics |
|----------|----------|----------------|
| **SizeTieredCompactionStrategy** (STCS) | Write-heavy, general purpose | Default; high space amplification |
| **LeveledCompactionStrategy** (LCS) | Read-heavy, predictable latency | Low read amplification; higher write I/O |
| **TimeWindowCompactionStrategy** (TWCS) | Time-series, TTL data | Groups SSTables by time window; ideal with TTL |
| **UnifiedCompactionStrategy** (UCS) | Cassandra 5.0+ | Adaptive; replaces all strategies |

```sql
-- Time-series with daily windows and 90-day TTL
CREATE TABLE metrics_by_device (
    device_id TEXT,
    hour_bucket TIMESTAMP,
    recorded_at TIMESTAMP,
    value DOUBLE,
    PRIMARY KEY ((device_id, hour_bucket), recorded_at)
) WITH default_time_to_live = 7776000
  AND compaction = {
      'class': 'TimeWindowCompactionStrategy',
      'compaction_window_unit': 'DAYS',
      'compaction_window_size': 1
  };
```

## Connection Pool (DataStax Driver)

### Quarkus Configuration

```properties
quarkus.cassandra.contact-points=node1:9042,node2:9042,node3:9042
quarkus.cassandra.local-datacenter=datacenter1
quarkus.cassandra.keyspace=simulator
quarkus.cassandra.request.timeout=5s
quarkus.cassandra.request.consistency=LOCAL_QUORUM
quarkus.cassandra.request.page-size=5000
```

### Java Driver Configuration (`application.conf`)

```hocon
datastax-java-driver {
    basic {
        contact-points = ["node1:9042", "node2:9042"]
        session-keyspace = simulator
        load-balancing-policy.local-datacenter = datacenter1
        request {
            timeout = 5 seconds
            consistency = LOCAL_QUORUM
            page-size = 5000
        }
    }
    advanced {
        connection {
            max-requests-per-connection = 1024
            pool.local.size = 1
            pool.remote.size = 1
        }
        heartbeat.interval = 30 seconds
        reconnection-policy {
            class = ExponentialReconnectionPolicy
            base-delay = 1 second
            max-delay = 60 seconds
        }
    }
}
```

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| `ALLOW FILTERING` in prod | Full cluster scan | Create dedicated table |
| `SELECT *` large partitions | OOM, timeout | Use pagination (`page-size`) |
| `IN` on partition key with many values | Multi-node scatter | Parallelize individual queries |
| `DELETE` instead of TTL | Tombstone accumulation | Set `default_time_to_live` |
| Large batch statements | Coordinator overload | Use unlogged batches for same partition only |
| No `LOCAL_QUORUM` in multi-DC | Stale reads | Use `LOCAL_QUORUM` for consistency |
