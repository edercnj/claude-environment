# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# AWS SQS — Message Broker Patterns

## FIFO vs Standard Queues

### Standard Queues (Default)

| Characteristic | Value |
|---|---|
| Ordering | Best-effort (messages may be out of order) |
| Exactly-once delivery | Not guaranteed (may receive duplicates) |
| Throughput | Unlimited |
| Latency | Very low (immediate availability) |
| Message retention | 1-1440 minutes (configurable) |
| Deduplication | None |
| Use case | High-throughput, order-independent processing |

**When to Use Standard Queues:**
- Event streaming (order doesn't matter)
- Task distribution to workers (each task independent)
- Non-critical notifications
- Metrics and telemetry aggregation
- Systems where duplicates can be handled downstream

### FIFO Queues (Ordered)

| Characteristic | Value |
|---|---|
| Ordering | Strict order per MessageGroupId |
| Exactly-once delivery | Exactly once (within deduplication window) |
| Throughput | 3,000 messages/sec (up to 30,000 with batching) |
| Latency | Higher than Standard (ordered processing) |
| Message retention | 1-1440 minutes (configurable) |
| Deduplication | Optional (content hash or explicit ID) |
| Use case | Ordered events, financial transactions, critical workflows |

**When to Use FIFO Queues:**
- Order matters (event sequence)
- Exactly-once processing required
- Financial transactions (credits, debits)
- Workflow state machines
- Message ordering per entity (e.g., per-user sequence)

### Selection Decision Tree

```
Question 1: Must messages be processed in order?
  NO  -> Use Standard Queue
  YES -> Continue

Question 2: Is exactly-once delivery mandatory?
  NO  -> Use Standard Queue (order achieved via MessageGroupId)
  YES -> Use FIFO Queue

Question 3: Can throughput be < 3,000 msg/sec per queue?
  YES -> Use FIFO Queue
  NO  -> Consider multiple FIFO queues with different MessageGroupIds
         OR use Standard Queue with order-handling in consumer
```

## Visibility Timeout Patterns

### Understanding Visibility Timeout

| Phase | Duration | What Happens |
|---|---|---|
| 1. Message received by consumer | 0ms | Message becomes invisible to other consumers |
| 2. Consumer processes message | Variable | Message hidden from queue (visibility timeout) |
| 3. Consumer deletes message | N/A | Message removed from queue permanently |
| 4. (if no delete) Visibility timeout expires | 30-900 seconds | Message reappears in queue, available again |

### Visibility Timeout Configuration

| Timeout | Use Case | Risk |
|---|---|---|
| 30 seconds (default) | Fast processing (< 20s) | Reprocessing if consumer slow |
| 60 seconds | Medium processing (20-50s) | Balanced |
| 300+ seconds | Long processing (> 5 minutes) | Long wait if consumer fails |
| 900 seconds (max) | Very long operations (batch jobs) | Very high reprocessing cost |

**Rules:**
- Visibility timeout > expected processing time + buffer
- Set to 1.5-2x the expected processing time (safety margin)
- For FIFO: shorter timeout minimizes failure window
- For Standard: longer timeout acceptable (duplicates handled downstream)
- Dynamically extend timeout (ChangeMessageVisibility) for long operations

### Visibility Timeout Pattern

```
function processMessage(message):
    // 1. Receive message (automatically hidden for 30 seconds)
    messages = sqs.receiveMessage(
        QueueUrl=queueUrl,
        MaxNumberOfMessages=1,
        VisibilityTimeout=30,
        WaitTimeSeconds=20
    )

    if messages.empty:
        return

    message = messages[0]

    try:
        // 2. Process the message
        result = businessLogic.process(message.Body)

        // 3. If processing takes longer than expected, extend visibility
        if processingTime > 20s:
            sqs.changeMessageVisibility(
                QueueUrl=queueUrl,
                ReceiptHandle=message.ReceiptHandle,
                VisibilityTimeout=60  // Extend by 30 more seconds
            )

        // 4. Upon success, delete the message
        sqs.deleteMessage(
            QueueUrl=queueUrl,
            ReceiptHandle=message.ReceiptHandle
        )

    catch ProcessingException as e:
        // 5. On error: let visibility timeout expire (auto-requeue)
        // OR explicitly move to DLQ
        log.error("Processing failed, message will be requeued", error=e)
        // No delete = message returns to queue after timeout
```

## Dead Letter Queues (DLQ)

### DLQ Configuration

```
// 1. Create main queue
mainQueue = sqs.createQueue(
    QueueName="notification-service-queue",
    Attributes={
        "VisibilityTimeout": "60",
        "MessageRetentionPeriod": "86400",  // 1 day
        "RedrivePolicy": "{...}"  // See below
    }
)

// 2. Create DLQ with longer retention
dlq = sqs.createQueue(
    QueueName="notification-service-queue.fifo.dlt",
    Attributes={
        "VisibilityTimeout": "300",           // Longer for investigation
        "MessageRetentionPeriod": "1209600"   // 14 days (longer than main)
    }
)

// 3. Configure redrive policy (send to DLQ after maxReceiveCount failures)
redrivePolicy = {
    "deadLetterTargetArn": dlq.queueArn,
    "maxReceiveCount": "3"  // Move to DLQ after 3 failures
}

mainQueue.setAttributes({
    "RedrivePolicy": json.stringify(redrivePolicy)
})
```

### Redrive Policy Configuration

| Parameter | Recommended | Purpose |
|---|---|---|
| `deadLetterTargetArn` | ARN of DLQ | Target queue for failed messages |
| `maxReceiveCount` | 3 | Move to DLQ after this many receives without delete |

**Rules:**
- `maxReceiveCount` = number of retries; set to 3-5 for transient errors
- DLQ retention > main queue retention (time for investigation)
- DLQ alerting: alert immediately on any message arrival
- Monitor DLQ backlog: investigate and fix root cause
- Implement manual replay tool to send DLQ messages back to main queue

### DLQ Message Enrichment

```
dlqMessage = {
    originalQueueUrl: "https://sqs.us-east-1.amazonaws.com/123456789/notification-queue",
    originalMessageId: "12345",
    originalReceiptHandle: "abc123...",
    originalBody: { /* payload */ },
    failureInfo: {
        receiveCount: 3,          // Delivered 3 times, failed all
        firstReceived: "2026-02-19T14:20:00Z",
        lastFailure: "2026-02-19T14:30:00Z",
        lastError: "InvalidEmail: email@invalid",
        processingDuration: "45 seconds"
    },
    metadata: {
        approximateAgeSeconds: 600,
        approximateReceiveCount: 3,
        sentTimestamp: "2026-02-19T14:15:00Z"
    }
}
```

## Long Polling vs Short Polling

### Long Polling (Recommended)

```
// Long polling: wait up to 20 seconds for messages
response = sqs.receiveMessage(
    QueueUrl=queueUrl,
    MaxNumberOfMessages=10,
    WaitTimeSeconds=20,  // Long poll
    VisibilityTimeout=30
)

// Characteristics:
// - CPU efficient (minimal polling)
// - Lower latency (messages delivered as soon as available)
// - Lower SQS API calls (fewer ReceiveMessage invocations)
// - Cost: ~30-50% lower than short polling
```

### Short Polling (Legacy)

```
// Short polling: return immediately with or without messages
response = sqs.receiveMessage(
    QueueUrl=queueUrl,
    MaxNumberOfMessages=10,
    WaitTimeSeconds=0,  // Short poll (return immediately)
    VisibilityTimeout=30
)

// Characteristics:
// - Always returns immediately (high CPU usage)
// - Higher latency if queue is empty (must poll again)
// - High SQS API call volume
// - Cost: ~3-5x higher than long polling
// - Only use for extremely latency-sensitive operations
```

### Configuration Guidelines

| Scenario | WaitTimeSeconds |
|---|---|
| Default (background processing) | 20 |
| Time-sensitive operations | 10 |
| High-frequency polling | 5 |
| Real-time systems | 1 |
| Legacy short polling | 0 (AVOID) |

**Rules:**
- Always use long polling (WaitTimeSeconds > 0)
- Set to 20 seconds (maximum) for most use cases
- Reduce to 10 seconds only if latency is critical
- Short polling (0 seconds) FORBIDDEN except for specific use cases

## Message Deduplication

### Content-Based Deduplication (FIFO only)

```
// For FIFO queues with ContentBasedDeduplication
// SQS automatically deduplicates identical messages within 5-minute window

sqs.sendMessage(
    QueueUrl=fifoQueueUrl,
    MessageBody=json.stringify({ orderId: "12345", total: 5000 }),
    MessageGroupId="customer-123",
    // No MessageDeduplicationId needed - SQS uses content hash
)

// SQS deduplication window: 5 minutes
// If same message sent twice within 5 minutes -> second copy discarded
// If sent after 5 minutes -> second copy accepted (new deduplication window)
```

### Explicit MessageDeduplicationId (FIFO only)

```
// For explicit deduplication with application-controlled ID
// Useful when message content may change (e.g., timestamp added)

sqs.sendMessage(
    QueueUrl=fifoQueueUrl,
    MessageBody=json.stringify({
        orderId: "12345",
        total: 5000,
        createdAt: "2026-02-19T14:30:00Z"  // Will change on retry
    }),
    MessageGroupId="customer-123",
    MessageDeduplicationId="order-12345",  // Business logic ID
    // Same order ID won't be duplicated even if created_at changes
)
```

### Standard Queue Idempotency (Manual)

```
// Standard queues MUST implement deduplication downstream
// Use unique business key for idempotency

function processMessage(message):
    // 1. Extract unique business identifier
    messageId = message.messageAttributes.get("idempotencyKey")

    // 2. Check if already processed
    if processedMessages.contains(messageId):
        log.info("Already processed, skipping", messageId: messageId)
        return

    // 3. Process the message
    result = businessLogic.process(message.body)

    // 4. Record successful processing
    processedMessages.record(messageId, timestamp: utcNow())

    // 5. Delete from queue only after success
    sqs.deleteMessage(
        QueueUrl=queueUrl,
        ReceiptHandle=message.receiptHandle
    )

// Processed messages storage (database table)
processedMessagesTable = {
    schema: {
        message_id: UUID PRIMARY KEY,
        processed_at: TIMESTAMP,
        result_status: STRING
    }
}
```

## Message Grouping (MessageGroupId)

### FIFO Message Grouping

| Aspect | Configuration | Behavior |
|---|---|---|
| MessageGroupId | Required for FIFO | All messages in same group processed sequentially |
| Ordering guarantee | Per-group | Messages in Group A and B can be out of order relative to each other |
| Parallelism | Depends on group count | N groups = up to N concurrent consumers |
| Use case | Entity ordering | Events for same order, same customer, same aggregate |

### Grouping Strategies

| Strategy | MessageGroupId | Ordering Scope | Parallelism |
|---|---|---|---|
| Per-entity | `orderId` | Single order | One order at a time |
| Per-tenant | `tenantId` | All orders in tenant | Multiple orders per tenant in parallel |
| Per-aggregate root | `aggregateId` | Single aggregate | One aggregate instance at a time |
| Fixed groups | `group-1`, `group-2`, ... | All messages in group | Limited parallelism |

### Example: Per-Entity Grouping

```
// Order processing with per-order group ID
function publishOrderEvent(event):
    sqs.sendMessage(
        QueueUrl=fifoQueueUrl,
        MessageBody=json.stringify(event),
        MessageGroupId=event.orderId,  // All events for same order in same group
        MessageDeduplicationId=event.eventId
    )

// Result:
// - Order 12345: processed sequentially, guaranteed order
// - Order 12346: processed sequentially, guaranteed order
// - Both orders processed in parallel (different groups)
```

## Batch Operations

### SendMessageBatch (Bulk Publishing)

```
function publishEventsInBatch(events):
    // 1. Build batch request (max 10 messages per batch)
    entries = events.stream()
        .limit(10)
        .mapToIndex((event, index) -> {
            return {
                Id: String(index),
                MessageBody: json.stringify(event),
                MessageGroupId: event.orderId,  // FIFO only
                MessageDeduplicationId: event.eventId,  // FIFO only
                MessageAttributes: {
                    "eventType": { DataType: "String", StringValue: event.type }
                }
            }
        })
        .collect(toList())

    // 2. Send batch
    response = sqs.sendMessageBatch(
        QueueUrl=queueUrl,
        Entries=entries
    )

    // 3. Handle partial failures
    if response.failed.isNotEmpty():
        log.error("Batch send partial failure",
            successful: response.successful.size(),
            failed: response.failed.size()
        )
        // Retry failed entries individually
        response.failed.forEach(failedEntry ->
            retryQueue.add(events.get(failedEntry.id))
        )

// Performance:
// - Single message: 1 API call per message
// - Batch of 10: 1 API call for all
// - Cost reduction: ~90% for large batches
```

### ReceiveMessageBatch (Bulk Consumption)

```
function consumeMessagesBatch():
    // 1. Receive up to 10 messages
    response = sqs.receiveMessage(
        QueueUrl=queueUrl,
        MaxNumberOfMessages=10,  // Max 10 per receive
        WaitTimeSeconds=20,
        VisibilityTimeout=60
    )

    messages = response.messages

    // 2. Process all messages
    results = messages.parallelStream()
        .map(message -> processMessage(message))
        .collect(toList())

    // 3. Delete successfully processed messages in batch
    successfulEntries = results.stream()
        .filter(r -> r.success)
        .mapToIndex((result, index) -> {
            return {
                Id: String(index),
                ReceiptHandle: result.message.receiptHandle
            }
        })
        .collect(toList())

    sqs.deleteMessageBatch(
        QueueUrl=queueUrl,
        Entries=successfulEntries
    )

    // 4. Handle failed messages
    failedResults = results.stream()
        .filter(r -> !r.success)
        .collect(toList())

    // Failed messages are automatically requeued after visibility timeout
```

### DeleteMessageBatch

```
function deleteSuccessfulMessages(receiptHandles):
    entries = receiptHandles.stream()
        .mapToIndex((handle, index) -> {
            return {
                Id: String(index),
                ReceiptHandle: handle
            }
        })
        .limit(10)
        .collect(toList())

    response = sqs.deleteMessageBatch(
        QueueUrl=queueUrl,
        Entries=entries
    )

    // Handle partial failures (some deletes may fail)
    if response.failed.isNotEmpty():
        log.warn("Batch delete partial failure",
            failed: response.failed.size()
        )
        // Failed deletes: messages remain in queue, will be redelivered
```

### Batch Operation Rules

| Constraint | Value | Notes |
|---|---|---|
| Max messages per batch | 10 | ReceiveMessage, DeleteMessage, SendMessage |
| Max payload per message | 256 KB | Combined message + attributes |
| Retry strategy | Exponential backoff | For failed entries in batch |
| Partial failures | Expected | Some messages may fail; retry individually |

## CloudWatch Metrics and Alarms

### Recommended Metrics

```
// Queue depth (backlog)
CloudWatch Metric: ApproximateNumberOfMessagesVisible
Alarm: WARN if > 1000, CRITICAL if > 10000

// Processing lag
Metric: ApproximateAgeOfOldestMessage
Alarm: WARN if > 5 minutes, CRITICAL if > 30 minutes

// Message volume
Metric: NumberOfMessagesSent
Alarm: WARN if drops > 50% compared to baseline

// DLQ messages
Metric: ApproximateNumberOfMessagesVisible (on DLQ)
Alarm: CRITICAL if > 0 (any DLQ message is an error)

// Number of messages deleted
Metric: NumberOfMessagesDeleted
Alarm: WARN if drops significantly (fewer messages processed)
```

### Alarm Configuration Examples

```
// Alert on queue backlog
alarm = cloudwatch.putMetricAlarm(
    AlarmName="SQS-Queue-Backlog-High",
    MetricName="ApproximateNumberOfMessagesVisible",
    Namespace="AWS/SQS",
    Statistic="Average",
    Period=300,              // 5 minutes
    EvaluationPeriods=2,     // Trigger after 10 minutes of high backlog
    Threshold=5000,
    ComparisonOperator="GreaterThanThreshold",
    AlarmActions=["arn:aws:sns:..."]  // SNS topic for notifications
)

// Alert on DLQ messages
dlqAlarm = cloudwatch.putMetricAlarm(
    AlarmName="SQS-DLQ-Messages-Present",
    MetricName="ApproximateNumberOfMessagesVisible",
    Dimensions=[
        { Name: "QueueName", Value: "notification-queue.dlt" }
    ],
    Threshold=0,
    ComparisonOperator="GreaterThanOrEqualToThreshold",
    TreatMissingData="notBreaching"
)
```

## Anti-Patterns (FORBIDDEN)

### Queue Configuration
- Choosing Standard over FIFO when ordering is needed
- Setting very long VisibilityTimeout (> 300 seconds) without dynamic extension
- Not configuring DLQ on critical queues
- MessageRetentionPeriod too short (< 1 day) for error investigation
- No maxReceiveCount configured on DLQ redrive policy

### Message Processing
- Not handling FIFO deduplication window (5 minutes only)
- Standard queue without application-level idempotency
- Deleting message before confirming processing success
- No retry mechanism for transient failures
- Processing messages sequentially when parallelism possible

### Scalability and Performance
- Using short polling (WaitTimeSeconds=0) instead of long polling
- Sending single messages instead of batching (batch=10 is default)
- Consuming one message at a time instead of MaxNumberOfMessages=10
- Not monitoring queue depth and processing lag
- Insufficient visibility timeout for message processing duration

### Resilience and Monitoring
- No alerting on DLQ message arrival
- DLQ without longer retention than main queue
- Batch operations without handling partial failures
- Consuming without monitoring ApproximateAgeOfOldestMessage
- No metrics dashboard for queue health

### Security and Operations
- Message payloads containing sensitive data unencrypted
- Hard-coded queue URLs in application code (use configuration)
- No encryption at rest or in transit
- IAM permissions too broad (allow all actions)
- Lack of message attribute documentation
