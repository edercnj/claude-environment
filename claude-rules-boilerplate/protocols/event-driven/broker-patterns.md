# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Message Broker Conventions

## Topic Naming

### Format: `{domain}.{entity}.{event}`

| Segment | Convention | Example |
|---------|-----------|---------|
| Domain | Lowercase bounded context | `orders`, `payments`, `inventory` |
| Entity | Lowercase entity name | `order`, `payment`, `stock-item` |
| Event | Past tense, lowercase, kebab-case | `created`, `status-changed`, `cancelled` |
| Full topic | Dot-separated segments | `orders.order.created` |

### Additional Naming Patterns

| Pattern | Format | Use Case |
|---------|--------|----------|
| Internal events | `{domain}.{entity}.{event}` | Standard domain events |
| Integration events | `integration.{source}.{target}.{event}` | Cross-domain contracts |
| System events | `system.{component}.{event}` | Infrastructure events (deploy, health) |
| DLT topics | `{original-topic}.dlt` | Dead letter topics |
| Retry topics | `{original-topic}.retry.{attempt}` | Staged retry topics |
| Compacted topics | `{domain}.{entity}.snapshot` | State snapshot topics |

**Rules:**
- All lowercase; no uppercase characters
- Dot (`.`) as segment separator; hyphen (`-`) for multi-word within a segment
- Maximum topic name length: 249 characters (Kafka limit)
- Topic names MUST be descriptive; NEVER use abbreviations (`ord.ord.crt` is forbidden)
- Environment prefix is handled by cluster/namespace, NOT in the topic name
- NEVER include environment names in topic names (`prod.orders.order.created` is forbidden)

## Partition Strategy

### Choosing a Partition Key

| Strategy | Partition Key | Ordering Guarantee | Use Case |
|----------|---------------|-------------------|----------|
| By entity ID | `orderId`, `customerId` | Per-entity | Default; most common |
| By tenant ID | `tenantId` | Per-tenant | Multi-tenant SaaS |
| By region | `regionCode` | Per-region | Geographically distributed systems |
| By aggregate root | `aggregateId` | Per-aggregate | Event sourcing / DDD |
| Round-robin | None (null key) | None | Maximum throughput, no ordering needed |

**Rules:**
- ALWAYS set a partition key unless ordering is explicitly not needed
- Partition key MUST produce even distribution; avoid hot partitions
- Monitor partition skew; alert if any partition handles more than 3x the average load
- NEVER use high-cardinality keys that change over time (e.g., timestamp)
- NEVER use low-cardinality keys for high-throughput topics (e.g., boolean status)
- Document the partition key for every topic in the schema registry or topic catalog

### Partition Count Guidelines

| Topic Throughput | Recommended Partitions | Notes |
|-----------------|:----------------------:|-------|
| Low (< 1K msg/s) | 6 | Minimum for basic parallelism |
| Medium (1K-10K msg/s) | 12-24 | Scale with consumer count |
| High (10K-100K msg/s) | 24-64 | Match consumer instance count |
| Very high (> 100K msg/s) | 64-128 | Requires careful key distribution |

Partition count can be increased but NEVER decreased. Plan for growth with headroom.

## Consumer Lag Monitoring

### Metrics and Thresholds

| Metric | Warning Threshold | Critical Threshold | Action |
|--------|:-----------------:|:------------------:|--------|
| Consumer lag (messages) | > 10,000 | > 100,000 | Scale consumers or investigate bottleneck |
| Consumer lag (time) | > 5 minutes | > 30 minutes | Immediate investigation required |
| Lag growth rate | Increasing for > 10 min | Increasing for > 30 min | Consumer is falling behind; scale up |
| Rebalance frequency | > 2 per hour | > 5 per hour | Investigate consumer stability |
| Commit latency | > 1 second | > 5 seconds | Consumer processing too slow |

**Rules:**
- Consumer lag MUST be monitored for every consumer group
- Alerting MUST be configured at both warning and critical thresholds
- Lag dashboards MUST show: current lag, lag trend over time, processing rate, error rate
- Review lag thresholds quarterly; adjust based on SLA requirements
- Lag alert MUST include: consumer group, topic, partition, current lag, lag velocity

## Producer Acknowledgment Levels

| Level | Durability | Latency | When to Use |
|-------|:----------:|:-------:|-------------|
| `acks=0` (fire-and-forget) | None | Lowest | Metrics, telemetry, non-critical logs |
| `acks=1` (leader only) | Medium | Low | Default for most use cases |
| `acks=all` (all replicas) | Highest | Higher | Financial events, audit logs, critical state changes |

**Rules:**
- Default to `acks=1` for general-purpose topics
- Use `acks=all` for any event where data loss is unacceptable
- When using `acks=all`, set `min.insync.replicas=2` (or N/2+1 for larger replication factors)
- NEVER use `acks=0` for business-critical events
- Document the ack level for every producer in the service configuration
- Producer retries: enable with idempotent producer (`enable.idempotence=true`) when `acks=all`

### Producer Configuration Guidelines

| Parameter | Recommended Value | Purpose |
|-----------|-------------------|---------|
| `retries` | 3 (or `Integer.MAX_VALUE` with idempotent) | Automatic retry on transient failure |
| `retry.backoff.ms` | 100-1000 | Delay between retries |
| `max.in.flight.requests.per.connection` | 5 (with idempotent) or 1 (without) | Ordering guarantee |
| `linger.ms` | 5-20 | Batching window for throughput |
| `batch.size` | 16384-65536 | Batch size in bytes |
| `compression.type` | `lz4` or `zstd` | Compress for throughput; `zstd` for best ratio |

## Message Retention Policies

| Topic Type | Retention | Reasoning |
|------------|-----------|-----------|
| Standard event topics | 7 days | Default; covers most replay needs |
| Audit/compliance topics | 365 days or more | Regulatory requirements |
| High-volume telemetry | 24 hours | Cost management; data flows to analytics |
| Integration topics | 14 days | Buffer for downstream service outages |
| DLT topics | 30 days | Investigation and replay window |
| Compacted topics | Infinite (compaction) | State snapshots; only latest per key retained |

**Rules:**
- Retention MUST be configured per topic; NEVER rely on broker defaults
- Document retention policy for every topic in the topic catalog
- Retention changes MUST be reviewed; reducing retention can cause data loss for slow consumers
- Monitor disk usage; alert when broker storage exceeds 70% capacity
- Size-based retention (`retention.bytes`) can supplement time-based as a safety cap

## Compacted Topics for State Snapshots

Compacted topics retain only the latest value per key, functioning as a distributed key-value store.

| Use Case | Key | Value |
|----------|-----|-------|
| Current entity state | Entity ID | Latest state snapshot |
| Configuration | Config key | Current config value |
| User profiles | User ID | Current profile |
| Feature flags | Flag name | Current flag state |

**Rules:**
- Compacted topics MUST have `cleanup.policy=compact` (or `compact,delete` for combined)
- Keys MUST NOT be null on compacted topics (null key = tombstone logic breaks)
- To delete an entry, produce a message with the key and null value (tombstone)
- Tombstones are retained for `delete.retention.ms` (default 24h) before physical removal
- Compacted topics are NOT suitable for event streams; use them for state only
- Segment size and min compaction lag affect how quickly stale values are removed
- Monitor compaction lag; alert if compaction falls significantly behind

### Compaction Configuration

| Parameter | Recommended | Purpose |
|-----------|-------------|---------|
| `min.cleanable.dirty.ratio` | 0.5 | Trigger compaction when 50% of log is dirty |
| `min.compaction.lag.ms` | 0 (or up to 1 hour) | Minimum time before a message is eligible for compaction |
| `delete.retention.ms` | 86400000 (24h) | How long tombstones are retained |
| `segment.ms` | 604800000 (7 days) | Force segment roll for compaction eligibility |

## Schema Evolution Rules per Broker

### Compatibility Modes

| Mode | Allowed Changes | Use Case |
|------|----------------|----------|
| BACKWARD | New schema can read old data | Default; consumers update first |
| FORWARD | Old schema can read new data | Producers update first |
| FULL | Both backward and forward compatible | Safest; both directions |
| NONE | Any change allowed | Development only; NEVER in production |

### Evolution Rules by Format

| Change | Avro | Protobuf | JSON Schema |
|--------|:----:|:--------:|:-----------:|
| Add optional field | Safe | Safe | Safe |
| Add required field with default | Safe (BACKWARD) | N/A (proto3 all optional) | Unsafe |
| Remove optional field | Safe (FORWARD) | Safe (use reserved) | Safe |
| Remove required field | Unsafe | N/A | Unsafe |
| Rename field | Unsafe | Safe (number unchanged) | Unsafe |
| Change field type | Unsafe | Unsafe | Unsafe |

**Rules:**
- Production topics MUST use BACKWARD or FULL compatibility mode
- Schema registry MUST reject incompatible schema registrations
- Test schema compatibility in CI before deploying producer changes
- NEVER use NONE compatibility in production environments
- When a breaking change is unavoidable, create a new topic (e.g., `orders.order.created.v2`)

## Anti-Patterns (FORBIDDEN)

- Topic names with environment prefixes (`prod.orders.order.created`) -- use cluster separation
- Topics without documented partition keys -- every topic MUST have a documented partitioning strategy
- Consumer groups without lag monitoring -- lag MUST be monitored and alerted
- `acks=0` for business-critical events -- use `acks=1` minimum, `acks=all` for critical data
- Relying on broker default retention -- configure retention explicitly per topic
- Compacted topics used for event streams -- compaction is for state snapshots only
- NONE compatibility mode in production -- always enforce schema compatibility
- Reducing partition count on an existing topic -- partitions can only be added
- Producers without idempotence enabled when using `acks=all` -- enables safe retries
- Topics without schema registration -- all topics MUST have registered schemas
- Consumer groups shared across services -- each service owns its consumer group
- Hard-coded broker addresses in application code -- use configuration or service discovery
- Topics with unbounded message sizes -- enforce maximum message size (1 MB default)
- Ignoring consumer rebalance frequency -- frequent rebalances indicate instability
