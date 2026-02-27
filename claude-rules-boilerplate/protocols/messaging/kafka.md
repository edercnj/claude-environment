# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Apache Kafka — Message Broker Patterns

## Topic Naming Conventions

### Format: `{domain}.{entity}.{action}`

| Segment | Convention | Example |
|---------|-----------|---------|
| Domain | Lowercase bounded context | `orders`, `payments`, `inventory` |
| Entity | Lowercase entity name | `order`, `payment`, `transaction` |
| Action | Past tense, lowercase, kebab-case | `created`, `status-changed`, `cancelled` |
| Full topic | Dot-separated segments | `orders.order.created` |

### Additional Patterns

| Pattern | Format | Use Case |
|---------|--------|----------|
| Internal events | `{domain}.{entity}.{action}` | Standard domain events |
| Integration events | `integration.{source}.{target}.{action}` | Cross-domain contracts |
| System events | `system.{component}.{action}` | Infrastructure events |
| DLT topics | `{original-topic}.dlt` | Dead letter topics |
| Retry topics | `{original-topic}.retry.{attempt}` | Staged retry topics |

**Rules:**
- All lowercase; no uppercase characters
- Dot (`.`) as separator; hyphen (`-`) for multi-word within segment
- Maximum length: 249 characters
- NEVER use abbreviations: `ord.ord.crt` is forbidden
- NEVER include environment names: `prod.orders.order.created` is forbidden
- Document the topic purpose and schema in a topic catalog

## Consumer Group Patterns

| Pattern | Format | Responsibility | Example |
|---------|--------|----------------|---------|
| Service consumer group | `{service-name}-{purpose}` | Single service, specific purpose | `notification-service-email-sender` |
| Role consumer group | `{service}-{role}` | Multiple readers of same events | `analytics-service-aggregator` |
| Dedicated DLQ group | `{original-group}.dlt` | Consume from DLT for failed events | `order-service-processor.dlt` |

**Rules:**
- One consumer group per service per topic (no sharing across services)
- Consumer group name MUST reflect the purpose and service
- Rebalancing strategy: Cooperative (preferred) to minimize stop-the-world pauses
- Session timeout: 30 seconds (detect unresponsive consumers)
- Heartbeat interval: 10 seconds (ensure liveness)

## Exactly-Once Semantics (EOS)

### Producer Configuration for Idempotence

| Configuration | Value | Purpose |
|---------------|-------|---------|
| `enable.idempotence` | `true` | Enable idempotent producer |
| `acks` | `all` | Wait for all in-sync replicas |
| `retries` | `2147483647` | (Integer.MAX_VALUE) Unlimited retries |
| `max.in.flight.requests.per.connection` | `5` | Preserve ordering with idempotence |
| `min.insync.replicas` | `2` | (broker config) Minimum replicas that acknowledge |

### Consumer Configuration for Idempotence

| Configuration | Value | Purpose |
|---------------|-------|---------|
| `isolation.level` | `read_committed` | Only consume committed messages |
| `enable.auto.commit` | `false` | Manual commit after processing |
| `auto.offset.reset` | `earliest` | Start from beginning on rebalance |
| `group.instance.id` | `{unique-id}` | (optional) Static membership, faster rebalance |

### Idempotent Processing Pattern

```
function processMessage(message):
    // 1. Read from database: has this event ID been processed?
    if processedEvents.contains(message.eventId):
        log.info("Idempotent duplicate, skipping", eventId: message.eventId)
        commitOffset(message.offset)
        return

    // 2. Process the message (business logic)
    result = businessLogic.process(message.payload)

    // 3. Persist the result + record that this event ID was processed
    // CRITICAL: Use a single transaction to ensure atomicity
    transaction {
        repository.save(result)
        processedEvents.record(message.eventId, timestamp: utcNow())
    }

    // 4. Commit the offset (idempotent)
    consumer.commitSync(message.offset)

// Processed events storage
processedEvents = {
    table: "kafka_processed_events",
    schema: {
        event_id: UUID PRIMARY KEY,
        processed_at: TIMESTAMP,
        consumer_group: STRING,
        partition: INT,
        offset: BIGINT
    }
}
```

### Exactly-Once with Transactional Writes

When using Kafka transactions for exactly-once:

```
function processMessageTransactional(message):
    // 1. Begin Kafka transaction
    producer.beginTransaction()

    try:
        // 2. Process and produce results
        result = businessLogic.process(message.payload)
        producer.send(outputTopic, result)

        // 3. Commit offset within the transaction
        consumer.sendOffsetsToTransaction({
            offsetsToCommit: message.offset,
            consumerGroupId: consumerGroup
        })

        // 4. Commit the transaction atomically
        producer.commitTransaction()

    catch Exception as e:
        log.error("Processing failed, rolling back", exception: e)
        producer.abortTransaction()
        throw e  // Will be retried by consumer framework
```

## Schema Registry Integration

### Supported Formats

| Format | Compatibility | Performance | When to Use |
|--------|:-------------:|:-----------:|-------------|
| Avro | Best | Binary optimized | Default for Kafka |
| Protobuf | Excellent | Binary, compact | When gRPC also used |
| JSON Schema | Good | Text, verbose | Less strict, flexible |

### Compatibility Modes

| Mode | Allowed Changes | Consumer | Producer | Use Case |
|------|----------------|----------|----------|----------|
| BACKWARD | New schema reads old data | Can update first | Backward | Default |
| FORWARD | Old schema reads new data | Can continue | Update first | Gradual producer rollout |
| FULL | Both directions | Any | Any | Safest, most flexible |
| NONE | Any change | DANGER | DANGER | Dev only |

**Rules:**
- Production MUST use BACKWARD or FULL mode
- Schema version increments on breaking change
- Breaking changes require new topic (e.g., `orders.order.created.v2`)
- Schema evolution MUST be tested in CI before deployment

### Schema Registration Pattern

```
// Register schema with Kafka Schema Registry (REST API)
POST /subjects/{topic}-value/versions
{
    "schema": {
        "type": "record",
        "name": "OrderCreated",
        "namespace": "com.company.orders",
        "fields": [
            { "name": "orderId", "type": "string" },
            { "name": "customerId", "type": "string" },
            { "name": "totalAmount", "type": "long" },
            { "name": "currency", "type": "string", "default": "USD" },
            { "name": "createdAt", "type": "string" }
        ]
    },
    "schemaType": "AVRO",
    "references": []
}

// Producer embeds schema ID in message
record = {
    schemaId: 101,  // Retrieved from schema registry
    payload: {
        orderId: "12345",
        customerId: "CUST-001",
        totalAmount: 5000,
        currency: "BRL",
        createdAt: "2026-02-19T14:30:00Z"
    }
}

// Consumer validates against schema
message = deserialize(record.payload, schemaRegistry.getSchema(record.schemaId))
```

## Dead Letter Topics (DLT)

### Naming Convention

| Pattern | Format | Retention | Alerting |
|---------|--------|-----------|----------|
| Main topic | `orders.order.created` | 7 days | Standard |
| DLT topic | `orders.order.created.dlt` | 30 days | Immediate on any message |
| Retry topic | `orders.order.created.retry.1` | 7 days | Monitor for backlog |

### DLT Message Enrichment

```
deadLetterRecord = {
    originalTopic: "orders.order.created",
    originalPartition: 3,
    originalOffset: 123456789,
    originalMessage: { /* original payload */ },
    error: {
        errorType: "DESERIALIZATION_ERROR",
        errorMessage: "Invalid Avro format",
        stackTrace: "...",
        timestamp: "2026-02-19T14:30:00Z"
    },
    failureMetadata: {
        attemptCount: 3,
        firstAttemptTime: "2026-02-19T14:25:00Z",
        lastAttemptTime: "2026-02-19T14:30:00Z",
        consumerGroup: "notification-service-mailer",
        consumerId: "notification-service-1"
    },
    correlationId: "550e8400-e29b-41d4-a716-446655440000"
}
```

### Retry Policy

| Attempt | Delay | Total Elapsed | Action if Fails |
|---------|-------|---------------|-----------------|
| 1 | Immediate | 0s | Retry |
| 2 | 1 second | 1s | Retry |
| 3 | 5 seconds | 6s | Retry |
| 4 | 30 seconds | 36s | DLT |

**Implementation:**
- Use separate retry topics per attempt level
- If a message fails in `{topic}.retry.1`, it goes to `{topic}.retry.2`
- After final retry failure, move to `{topic}.dlt`
- DLT monitor alerts operations team immediately
- Replay process: inspect error, fix underlying issue, move messages back to main topic

## ACLs and Security

### Authentication (SASL/SSL)

| Mechanism | Client Auth | Server Auth | When to Use |
|-----------|:----------:|:----------:|-------------|
| SASL/PLAINTEXT | Username/password | No | Development, internal networks |
| SASL/SSL | Username/password | TLS certificate | Production, encryption needed |
| SASL/SCRAM | Credentials database | TLS certificate | Production with credential rotation |
| OAuth 2.0 | Bearer token | TLS certificate | Enterprise SSO integration |

### Authorization (ACL Rules)

```
// ACL: Allow service 'order-service' to produce to topics matching 'orders.*'
{
    principal: "User:order-service",
    resourceType: "TOPIC",
    resourceName: "orders.*",
    operation: "WRITE",
    effect: "ALLOW"
}

// ACL: Allow service 'notification-service' to consume from 'orders.order.created'
{
    principal: "User:notification-service",
    resourceType: "TOPIC",
    resourceName: "orders.order.created",
    operation: "READ",
    effect: "ALLOW"
}

// ACL: Allow group to commit offsets
{
    principal: "User:notification-service",
    resourceType: "GROUP",
    resourceName: "notification-service-mailer",
    operation: "READ",
    effect: "ALLOW"
}
```

**Rules:**
- Default: DENY ALL (whitelist only what's needed)
- Separate credentials per service (no shared credentials)
- Rotate credentials every 90 days
- Monitor ACL violations in audit logs
- Use DNS-based service names (not IPs) for identification

## Partitioning Strategies

### Partition Key Selection

| Strategy | Key | Ordering | Throughput | Use Case |
|----------|-----|----------|-----------|----------|
| Entity ID | `orderId` | Per-entity | High | Default, most common |
| Tenant ID | `tenantId` | Per-tenant | High | Multi-tenant systems |
| Aggregate root | `aggregateId` | Per-aggregate | High | Event sourcing |
| Round-robin | `null` | None | Maximum | No ordering needed |
| Composite | `tenantId + orderId` | Per-tenant-entity | High | Large tenants need sharding |

### Partition Count Guidelines

| Throughput | Partitions | Consumers | Headroom |
|-----------|-----------|-----------|----------|
| < 1 KB/s | 6 | 6 | 2x |
| 1-10 KB/s | 12-24 | 12-24 | 2x |
| 10-100 KB/s | 24-64 | 24-64 | 1.5x |
| > 100 KB/s | 64-128+ | 64-128+ | Varies |

**Rules:**
- Partition count can increase, NEVER decrease
- Number of partitions >= number of consumer instances for parallelism
- Monitor partition skew: no partition should handle > 3x the average
- Avoid hot partitions: ensure partition keys distribute evenly
- Document partition key for every topic

### Hot Partition Prevention

```
// PROBLEM: All events for same customer routed to same partition
partition = hash(customerId) % numPartitions

// SOLUTION 1: Add prefix with random suffix
partition = hash(customerId + "-" + randomSuffix) % numPartitions

// SOLUTION 2: Aggregate then disaggregate
// - Produce to multiple partitions during spike
// - Deduplicate/aggregate downstream

// SOLUTION 3: Use composite key with salt
partition = hash(tenantId + "|" + (recordCount % 10)) % numPartitions
```

## Consumer Lag Monitoring

### Metrics Dashboard

| Metric | Query | Warning | Critical | Action |
|--------|-------|---------|----------|--------|
| Current lag (messages) | `max_lag - current_offset` | > 10K | > 100K | Scale consumers |
| Current lag (time) | `(current_timestamp - last_message_time)` | > 5 min | > 30 min | Investigate |
| Lag velocity | `lag_growth_rate` (messages/sec) | > 100/sec | > 500/sec | Check consumer health |
| Rebalance frequency | Count per hour | > 2 | > 5 | Investigate instability |
| Processing rate | `messages_processed / time` | Drops > 50% | Drops > 80% | Consumer bottleneck |

**Rules:**
- Lag monitoring MANDATORY for all consumer groups
- Alert on both lag VALUE and lag TREND (velocity)
- Dashboard shows: lag, trend, processing rate, error rate per consumer
- Review thresholds quarterly based on SLA
- Include consumer group ID, topic, partition in alert

### Monitoring Implementation

```
// Prometheus metrics for consumer lag
kafka_consumer_lag_sum{
    group="notification-service-mailer",
    topic="orders.order.created",
    partition="3"
} 12500

// Alert rule
alert: ConsumerLagCritical
  expr: kafka_consumer_lag_sum > 100000
  for: 5m
  annotations:
    summary: "High consumer lag for {{ $labels.group }}"
    description: "Lag is {{ $value }} messages"

// Dashboard queries
- Current lag over time
- Lag by partition and consumer group
- Processing rate (messages/sec)
- Rebalance events per group
```

## Anti-Patterns (FORBIDDEN)

### Naming & Configuration
- Topic names with environment prefixes (`prod.orders.order.created`)
- Topics without documented partition keys
- Unbounded topic retention (set explicit policies)
- Using NONE compatibility mode in production
- Abbreviations in topic names (`ord.ord.crt`)

### Producer & Consumer
- `enable.idempotence=false` for at-least-once topics
- Producer without retries on transient failures
- Consumer groups shared across multiple services
- Consuming without explicit offset management
- Processing without idempotency checks

### Resilience & Monitoring
- No dead letter topic configuration
- Consumer groups without lag monitoring or alerting
- No retry mechanism for failed messages
- Unlimited retries without exponential backoff
- Ignoring partition skew and hot partition problems

### Security & Compliance
- Credentials hardcoded in producer/consumer configuration
- PLAINTEXT authentication in production
- Schemas without compatibility enforcement
- No audit logging for ACL changes
- Sensitive data in message payloads without encryption

### Data Quality
- Messages larger than 1 MB (default limit)
- Null partition keys on ordered topics
- Schema evolution without testing in CI
- Consumer lag growing without investigation
- Duplicate processing without deduplication table
