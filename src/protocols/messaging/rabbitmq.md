# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# RabbitMQ — Message Broker Patterns

## Exchange Types and Use Cases

### Direct Exchange

**Behavior:** Routes messages to queues based on exact routing key match.

| Characteristic | Value |
|---|---|
| Binding key | Exact match required |
| Multiple subscribers | Multiple queues bind with same routing key |
| Message duplication | Yes (one copy per queue) |
| Latency | Very low |

**Use Cases:**
- Task distribution to workers
- RPC request-reply patterns
- Point-to-point messaging

**Example:**
```
Exchange: order-commands (direct)
Routing key: order.create
Queue 1 binds with order.create -> receives all order.create messages
Queue 2 binds with order.delete -> receives only order.delete messages
```

### Topic Exchange

**Behavior:** Routes messages based on wildcard pattern matching on routing keys.

| Characteristic | Value |
|---|---|
| Binding key | Supports wildcards: `*` (one word), `#` (zero or more words) |
| Multiple subscribers | Multiple queues bind with different patterns |
| Message duplication | Yes (one copy per queue) |
| Latency | Low |

**Use Cases:**
- Event broadcasting to multiple subscribers
- Sensor data distribution
- Publish-subscribe with filtering

**Pattern Rules:**
- `*` matches exactly one word between dots
- `#` matches zero or more words
- `orders.order.#` matches `orders.order.created`, `orders.order.cancelled`, `orders.order.status.changed`, etc.

**Example:**
```
Exchange: events (topic)
Message with routing key: orders.order.created
Queue 1 binds with orders.order.# -> receives message
Queue 2 binds with orders.* -> receives message
Queue 3 binds with #.created -> receives message
Queue 4 binds with payments.# -> does NOT receive message
```

### Fanout Exchange

**Behavior:** Routes all messages to ALL bound queues (ignores routing keys).

| Characteristic | Value |
|---|---|
| Binding key | Ignored |
| Multiple subscribers | All bound queues receive the message |
| Message duplication | Yes (one copy per queue) |
| Latency | Low |

**Use Cases:**
- Broadcasting to all subscribers
- System notifications
- Event log distribution

**Example:**
```
Exchange: notifications (fanout)
Message published (routing key ignored)
All queues bound to notifications receive the message
```

### Headers Exchange

**Behavior:** Routes messages based on header attributes, not routing keys.

| Characteristic | Value |
|---|---|
| Binding key | Ignored |
| Match criteria | Header key-value pairs with `x-match: all` or `x-match: any` |
| Multiple subscribers | Multiple queues with different header requirements |
| Latency | Medium |

**Use Cases:**
- Complex routing logic based on message attributes
- Multi-dimensional filtering

**Example:**
```
Exchange: priority-tasks (headers)
Message headers: { level: "high", type: "payment" }

Queue 1 binding: { x-match: all, level: "high", type: "payment" }
  -> Receives this message

Queue 2 binding: { x-match: any, level: "high", retry: true }
  -> Receives this message (matches level header)

Queue 3 binding: { x-match: all, level: "low" }
  -> Does NOT receive (level mismatch)
```

## Queue Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Service queue | `{service}.{purpose}` | `notification-service.email-sender` |
| Callback queue | `{service}.callback.{id}` | `order-service.callback.12345` |
| DLQ | `{queue-name}.dlt` | `notification-service.email-sender.dlt` |
| Temporary queue | `amq.gen-{UUID}` | RabbitMQ auto-generated |

**Rules:**
- Lowercase, hyphenated names
- Reflect the consumer service and purpose
- One queue per consumer service (logical consumer group)
- NEVER share queues across different services
- Document expected message types for each queue

## Routing Key Patterns

### Standard Format

```
{domain}.{entity}.{action}

Examples:
- orders.order.created
- payments.transaction.processed
- inventory.stock.reserved
```

### Wildcard Binding Patterns

| Pattern | Matches | Use Case |
|---|---|---|
| `orders.#` | All order-related events | Subscribe to all order events |
| `*.*.created` | All created events | Monitor all creation events |
| `orders.order.*` | All order actions | Subscribe to specific entity changes |
| `#` | All messages | Catch-all for logging/auditing |

**Rules:**
- Routing keys use dot notation (same as Kafka topic names)
- Bindings use wildcard patterns for filtering
- NEVER depend on routing key in topic exchange; it's just a string
- Document expected routing key patterns for each consumer

## Prefetch and QoS Settings

### Consumer Prefetch Configuration

| Parameter | Value | Purpose | Trade-off |
|---|---|---|---|
| `basic.qos(prefetch_count)` | 1 | One message at a time, max fairness | Lower throughput |
| `basic.qos(prefetch_count)` | 10 | Balance fairness and throughput | Recommended |
| `basic.qos(prefetch_count)` | 100+ | High throughput, less fair | Risk of uneven load |
| `basic.qos(global=true)` | true | QoS applies to entire channel | Fine-grained control |
| `basic.qos(global=false)` | false | QoS applies per consumer | Default, recommended |

### Recommended Defaults

```
// Per-consumer QoS (recommended)
channel.basicQos(prefetchCount=10, global=false)

// For long-running tasks (prefetch=1 for fair distribution)
channel.basicQos(prefetchCount=1, global=false)

// For high-throughput systems
channel.basicQos(prefetchCount=50, global=false)
```

**Rules:**
- Set prefetch BEFORE consuming to limit buffering
- Lower prefetch ensures fair distribution across consumer instances
- Higher prefetch maximizes throughput (risk of uneven load)
- Adjust based on message processing time: prefetch = throughput_goal * average_processing_time_seconds
- Monitor queue depth to detect prefetch issues

### Example: Dynamic Prefetch

```
function configureQos(processingTimeMs, targetThroughputMsgSec):
    // prefetch = how many messages should be buffered locally
    // If processing takes 100ms and we want 100 msg/sec throughput:
    // prefetch = 100 / 1000 * 100 = 10
    prefetch = max(1, ceil((processingTimeMs / 1000) * targetThroughputMsgSec))
    channel.basicQos(prefetch, global=false)
```

## Dead Letter Exchanges (DLX)

### DLX Configuration

```
// 1. Declare the main queue with DLX binding
queueArgs = {
    "x-dead-letter-exchange": "dlx-exchange",
    "x-dead-letter-routing-key": "dead-letter-key",
    "x-message-ttl": 60000,           // Message TTL: 60 seconds
    "x-max-length": 100000             // Max queue length
}
channel.queueDeclare(
    queue="notification-queue",
    durable=true,
    exclusive=false,
    autoDelete=false,
    arguments=queueArgs
)

// 2. Declare the DLX and DLQ
channel.exchangeDeclare("dlx-exchange", "direct", durable=true)
channel.queueDeclare(
    queue="notification-queue.dlt",
    durable=true,
    exclusive=false,
    autoDelete=false
)
channel.queueBind(
    queue="notification-queue.dlt",
    exchange="dlx-exchange",
    routingKey="dead-letter-key"
)
```

### Reasons Messages Go to DLX

| Reason | Detection | Action |
|---|---|---|
| Consumer NACK with requeue=false | Manual NACK | Message moves to DLX |
| Consumer rejection (basic.reject) | Code or framework | Message moves to DLX |
| Message TTL expires | x-message-ttl exceeded | Message moves to DLX |
| Queue length exceeds max | x-max-length reached | Oldest message dropped or moved to DLX |
| Consumer timeout | No ACK within timeout | Automatic requeue or DLX (framework-dependent) |

### DLQ Message Enrichment

```
deadLetterMessage = {
    originalQueue: "notification-service.email-sender",
    originalExchange: "events",
    originalRoutingKey: "orders.order.created",
    originalMessage: { /* payload */ },
    originalMessageId: "12345",
    errorInfo: {
        reason: "CONSUMER_REJECTION",
        description: "Invalid email address",
        rejectCode: 406,  // PRECONDITION_FAILED
        timestamp: "2026-02-19T14:30:00Z"
    },
    headers: {
        "x-death": [  // RabbitMQ auto-added
            {
                reason: "rejected",
                queue: "notification-service.email-sender",
                time: 1708354200,
                exchange: "events",
                "routing-keys": ["orders.order.created"],
                count: 1
            }
        ]
    }
}
```

## Message TTL and Expiration

### TTL Configuration

| Parameter | Where Set | Scope | Behavior |
|---|---|---|---|
| `x-message-ttl` | Queue declaration | All messages in queue | Expired messages move to DLX or are discarded |
| `expiration` | Message property | Individual message | Message expires; moves to DLX or discarded |
| `x-expires` | Queue declaration | Entire queue | Queue deleted if unused for this duration |

### TTL Pattern

```
// Queue-level TTL (60 seconds)
channel.queueDeclare(
    queue="fast-cache-queue",
    durable=false,
    arguments={"x-message-ttl": 60000}
)

// Message-level TTL (override per message)
properties = new AMQP.BasicProperties()
    .withExpiration("30000")  // 30 seconds
    .withDeliveryMode(2)       // Persistent

channel.basicPublish(
    exchange="cache-exchange",
    routingKey="cache.key",
    props=properties,
    body=message.getBytes()
)

// Queue auto-delete after inactivity
channel.queueDeclare(
    queue="temporary-queue",
    durable=false,
    arguments={"x-expires": 600000}  // Delete if unused for 10 minutes
)
```

**Rules:**
- Set TTL on queues that should naturally expire messages
- Use per-message TTL for different expiration policies
- DLX should receive expired messages (set x-dead-letter-exchange)
- Monitor TTL-expired messages: may indicate slow consumers

## Shovel and Federation for Multi-DC

### RabbitMQ Shovel (Point-to-Point)

**Use Case:** Move messages from one broker/cluster to another (one-way).

```
// Shovel configuration (RabbitMQ admin)
{
    sources: [
        {
            brokers: ["rabbitmq-dc1.example.com"],
            queue: "notification-service.email-sender",
            ackMode: "on-confirm"  // Only remove from source after destination confirms
        }
    ],
    destinations: [
        {
            brokers: ["rabbitmq-dc2.example.com"],
            exchange: "events",
            routingKey: "orders.order.created"  // Can modify routing key
        }
    ],
    prefetchCount: 10,
    reconnectDelay: 5  // Seconds between retry on failure
}
```

**Characteristics:**
- One-way message flow (source to destination)
- Can transform routing keys during transfer
- Ack mode: `on-confirm` ensures no message loss
- Use case: Backup site, read replicas, geographically distributed consumers

### RabbitMQ Federation (Loosely Coupled)

**Use Case:** Replicate exchanges/queues across multiple brokers (collaborative).

```
// Federation link configuration
{
    upstream: "dc1-upstream",
    brokers: ["rabbitmq-dc1.example.com"],
    exchanges: [
        {
            name: "events",
            type: "topic"
        }
    ],
    queues: [
        {
            name: "notification-service.email-sender"
        }
    ],
    expires: 3600000,  // Federated resource lifetime
    messageTTL: 60000
}
```

**Characteristics:**
- Bidirectional replication of exchanges and queues
- Loosely coupled: each site operates independently
- Circular routing prevention: automatic de-duplication
- Use case: Active-active disaster recovery, multi-site deployment

### Decision: Shovel vs Federation

| Factor | Shovel | Federation |
|---|:---:|:---:|
| Message loss risk | Low (with on-confirm) | Very low (replicated) |
| Complexity | Simple, point-to-point | Complex, mesh topology |
| Failure handling | Automatic reconnect | Automatic topology detection |
| Use case | Backup, archive | Active-active DR |
| Latency | One-way, potentially higher | Bidirectional replication |

## Connection Pooling and Channel Management

### Connection Pool Configuration

```
// Connection factory with pooling
factory = new ConnectionFactory()
factory.setHost("rabbitmq.example.com")
factory.setPort(5672)
factory.setUsername("service-user")
factory.setPassword("secret")
factory.setVirtualHost("/")
factory.setConnectionTimeout(10000)     // 10 seconds
factory.setRequestedHeartbeat(60)       // Heartbeat every 60 seconds
factory.setNetworkRecoveryInterval(5000) // Reconnect every 5 seconds

// Use connection pool (Spring or manual)
CachingConnectionFactory pool = new CachingConnectionFactory(factory)
pool.setChannelCacheSize(25)            // Max channels per connection
pool.setConnectionCacheSize(10)         // Max connections in pool

channel = pool.createConnection().createChannel()
```

### Channel Management Rules

| Guideline | Rationale |
|---|---|
| One channel per consumer thread | Channels are NOT thread-safe |
| Reuse channels across multiple queues | Channels are lightweight, but TCP connections are expensive |
| Declare queues/exchanges once at startup | Idempotent; prevent errors if already declared |
| Use channel.close() or try-with-resources | Proper cleanup prevents connection leaks |
| Monitor channel count: alert if > 100 per connection | High channel count may indicate resource leak |

### Thread-Safe Channel Usage

```
// CORRECT: One channel per consumer thread
class EmailConsumer extends Thread:
    function run():
        channel = connection.createChannel()
        try:
            channel.basicQos(10)
            channel.basicConsume("notification-service.email-sender", autoAck=false, consumer)
        finally:
            channel.close()

// WRONG: Sharing channel across threads (NOT thread-safe)
sharedChannel = connection.createChannel()
executor.submit(() -> sharedChannel.basicConsume(...))  // Race condition!
executor.submit(() -> sharedChannel.basicConsume(...))  // Race condition!
```

## Anti-Patterns (FORBIDDEN)

### Exchange and Queue Design
- Creating exchanges/queues per message (performance killer)
- Using fanout exchange for selective delivery (use topic instead)
- Topic exchange with single word routing keys (prevents wildcards)
- Binding multiple queues without understanding duplication
- Queue names that don't reflect consumer service

### Consumer Configuration
- Not setting basic.qos (leads to uneven load distribution)
- Prefetch count too high (> 1000) on slow consumers
- Auto-ack enabled on unreliable consumers (message loss)
- No DLX configured on critical queues
- Consumer timeout with no retry mechanism

### Resilience and Monitoring
- No dead letter exchange configured
- TTL not set on temporary queues (unbounded growth)
- Message TTL without corresponding DLX
- Shovel/Federation without heartbeat monitoring
- No alerting on DLX message arrival

### Security and Operations
- Sharing credentials across multiple services
- No SSL/TLS encryption for inter-broker communication
- Vhost access not restricted by role
- Message payloads containing sensitive data unencrypted
- Manual queue declaration in production (use IaC)

### Performance and Reliability
- Connection pooling disabled (TCP overhead)
- Channel count per connection not monitored
- Message size > 128 MB (default limit)
- Network recovery interval too long (> 60s)
- Queue without durable flag (messages lost on restart)
