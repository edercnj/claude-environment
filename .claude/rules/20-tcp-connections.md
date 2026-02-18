# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 20 — Persistent TCP Connections

## Overview
The authorizer simulator maintains PERSISTENT TCP connections (long-lived) with acquirers and terminals. Multiple ISO 8583 messages arrive sequentially on the SAME connection, without disconnection between messages.

> **TCP Resilience:** Rate limiting per connection, backpressure and graceful degradation are defined in **Rule 24 — Application Resilience**. This rule (20) defines the TCP protocol and framing; Rule 24 defines protection patterns at the application level.

## TCP Connection Architecture

### Operating Model
```
Client connects → Validates identity → [Msg1 → Resp1] → [Msg2 → Resp2] → ... → [MsgN → RespN] → Disconnects
```

**Characteristics:**
- Connections: PERSISTENT (long-lived)
- Duration: hours or days
- Messages per connection: hundreds to thousands
- Disconnection: graceful (client closes) or timeout (idle)
- Each connection: completely independent

### Configuration
```properties
# application.properties
simulator.socket.port=8583
simulator.socket.host=0.0.0.0
simulator.socket.max-connections=100
simulator.socket.idle-timeout=300      # seconds
simulator.socket.read-timeout=30       # seconds
simulator.socket.length-header-bytes=2 # 2 or 4 bytes
simulator.socket.big-endian=true
```

## Message Framing Protocol

### Message Structure
```
[Length Header: 2 or 4 bytes] [ISO 8583 Message Body]
                               ↑
                               Size indicated by header
```

### Length Header Format
- **2-byte header (default):** unsigned short (0 - 65535 bytes)
- **4-byte header (optional):** unsigned int (0 - 4GB)
- **Byte Order:** big-endian (network byte order)
- **Scope:** size of ISO body (MTI + Bitmaps + Data Elements), DOES NOT include header

### Practical Example
```
Raw ISO message:             [0x31, 0x32, 0x30, 0x30, ...] (ISO request, 200 bytes)
With 2-byte framing (BE):    [0x00, 0xC8, 0x31, 0x32, 0x30, 0x30, ...]
                             └─────┬──────┘ └─────────┬──────────────┘
                                (200)      (ISO body)
```

### Vert.x RecordParser
```java
// ✅ STANDARD — 2-byte length framing
RecordParser parser = RecordParser.newFixed(2, socket);
parser.handler(lengthBuffer -> {
    int messageLength = lengthBuffer.getUnsignedShort(0);
    // Switch to fixed-size mode to read body
    parser.fixedSizeMode(messageLength);
    parser.handler(bodyBuffer -> {
        // Process ISO message
        processMessage(bodyBuffer);
        // Reset for next message (back to length reading)
        parser.fixedSizeMode(2);
    });
});
```

## Connection Lifecycle

### Phases
1. **Accept:** Client connects → server accepts socket
2. **Initialize:** Exchange greeting (optional), initial validation
3. **Message Loop:** Client sends messages, server responds (indefinite)
4. **Graceful Close:** Client closes socket
5. **Cleanup:** Server releases resources

### Implementation
```java
@ApplicationScoped
public class TcpServerBootstrap {
    @Inject Vertx vertx;
    @Inject IsoMessageHandler handler;
    @Inject ConnectionManager connectionManager;
    @Inject ConnectionMetrics metrics;

    void onStart(@Observes StartupEvent ev) {
        NetServer server = vertx.createNetServer()
            .connectHandler(this::handleConnection)
            .listen(port, host, result -> {
                if (result.succeeded()) {
                    LOGGER.info("TCP Server listening on {}:{}", host, port);
                } else {
                    LOGGER.error("Failed to start TCP Server", result.cause());
                }
            });
    }

    void handleConnection(NetSocket socket) {
        String connectionId = UUID.randomUUID().toString();
        String remoteAddress = socket.remoteAddress().toString();

        ConnectionContext context = new ConnectionContext(
            connectionId,
            remoteAddress,
            OffsetDateTime.now()
        );
        connectionManager.register(context);
        metrics.recordConnectionOpened(connectionId);

        // Configure message framing
        RecordParser parser = RecordParser.newFixed(2, socket);
        parser.handler(lengthBuffer -> {
            handleLengthFrame(lengthBuffer, parser, socket, context);
        });

        // Setup handlers
        socket.closeHandler(v -> {
            connectionManager.unregister(connectionId);
            metrics.recordConnectionClosed(connectionId, context);
            LOGGER.info("Connection closed: {}", connectionId);
        });

        socket.exceptionHandler(error -> {
            handleConnectionError(socket, context, error);
        });

        LOGGER.info("Connection established: {} from {}", connectionId, remoteAddress);
    }

    private void handleLengthFrame(Buffer lengthBuffer, RecordParser parser,
                                    NetSocket socket, ConnectionContext context) {
        int messageLength = lengthBuffer.getUnsignedShort(0);

        // Validate length
        if (messageLength <= 0 || messageLength > 65535) {
            LOGGER.error("Invalid message length: {}", messageLength);
            socket.write(encodeErrorResponse("Invalid length prefix"));
            return;
        }

        // Switch to body reading mode
        parser.fixedSizeMode(messageLength);
        parser.handler(bodyBuffer -> {
            handleMessageBody(bodyBuffer, parser, socket, context);
        });
    }

    private void handleMessageBody(Buffer bodyBuffer, RecordParser parser,
                                    NetSocket socket, ConnectionContext context) {
        try {
            // Process ISO message asynchronously
            handler.process(bodyBuffer)
                .subscribe().with(
                    response -> {
                        // Send response with framing
                        byte[] framed = frameMessage(response);
                        socket.write(Buffer.buffer(framed));
                        context.recordMessageProcessed();
                        metrics.recordMessageProcessed(context);
                    },
                    error -> {
                        LOGGER.error("Error processing message", error);
                        handleProcessingError(socket, context, error);
                    }
                );

            // Reset parser for next message
            parser.fixedSizeMode(2);
            parser.handler(lengthBuffer ->
                handleLengthFrame(lengthBuffer, parser, socket, context)
            );

        } catch (Exception e) {
            LOGGER.error("Unexpected error in message handler", e);
            handleProcessingError(socket, context, e);
        }
    }

    private void handleConnectionError(NetSocket socket, ConnectionContext context, Throwable error) {
        String errorType = error.getClass().getSimpleName();
        LOGGER.error("Connection error ({}): {}", context.connectionId(), error.getMessage());

        if (error instanceof IOException || error.getCause() instanceof IOException) {
            // Connection reset, closed, etc
            connectionManager.unregister(context.connectionId());
            metrics.recordConnectionError(context, errorType);
        } else {
            // Other errors - try to keep connection alive
            LOGGER.warn("Non-fatal connection error, keeping connection alive", error);
        }
    }

    private void handleProcessingError(NetSocket socket, ConnectionContext context, Throwable error) {
        try {
            // Send error response code 96 (System error)
            byte[] errorResponse = encodeErrorResponse("96");
            socket.write(Buffer.buffer(errorResponse));
        } catch (Exception e) {
            LOGGER.error("Failed to send error response", e);
        }
        // Keep connection open
    }

    private byte[] frameMessage(byte[] isoMessage) {
        ByteBuffer buffer = ByteBuffer.allocate(2 + isoMessage.length);
        buffer.putShort((short) isoMessage.length);
        buffer.put(isoMessage);
        return buffer.array();
    }
}
```

## Thread Safety

### Mandatory Rules

1. **NEVER share mutable state across connections**
   ```java
   // ❌ WRONG — shared state
   @ApplicationScoped
   public class SocketHandler {
       private List<IsoMessage> messageBuffer = new ArrayList<>(); // Danger!
   }

   // ✅ CORRECT — state per connection
   @ApplicationScoped
   public class SocketHandler {
       private Map<String, ConnectionState> connectionStates = new ConcurrentHashMap<>();
   }
   ```

2. **Each connection has its own RecordParser**
   ```java
   // RecordParser is not thread-safe, but each connection has one
   void handleConnection(NetSocket socket) {
       RecordParser parser = RecordParser.newFixed(2, socket); // New for each connection
       // ...
   }
   ```

3. **Transaction Context is per-message, not per-connection**
   ```java
   // ✅ CORRECT — new context for each message
   void handleMessageBody(Buffer bodyBuffer, ...) {
       TransactionContext txContext = new TransactionContext(/* ... */);
       handler.process(txContext, bodyBuffer);
   }
   ```

4. **Connection Metadata is read-only after init**
   ```java
   public record ConnectionContext(
       String connectionId,
       String remoteAddress,
       OffsetDateTime connectedAt,
       // ... read-only fields
   ) {
       public synchronized void recordMessageProcessed() {
           // ... increment counters
       }
   }
   ```

5. **CDI Beans are @ApplicationScoped (singletons)**
   ```java
   // ✅ CORRECT — stateless service
   @ApplicationScoped
   public class IsoMessageHandler {
       @Inject TransactionService transactionService;

       public Uni<byte[]> process(Buffer messageBody) {
           // No mutable state, stateless
       }
   }
   ```

## Connection Management

### Limits
| Limit | Default | Configurable |
|-------|---------|-------------|
| Max concurrent connections | 100 | Yes (`simulator.socket.max-connections`) |
| Idle timeout | 300s | Yes (`simulator.socket.idle-timeout`) |
| Read timeout | 30s | Yes (`simulator.socket.read-timeout`) |
| Max message size | 65535 bytes | Via header (2 or 4 bytes) |

### Connection Pool
```java
@ApplicationScoped
public class ConnectionManager {
    private final ConcurrentHashMap<String, ConnectionContext> connections = new ConcurrentHashMap<>();
    private final int maxConnections;

    public synchronized void register(ConnectionContext context) {
        if (connections.size() >= maxConnections) {
            throw new TooManyConnectionsException("Max connections exceeded");
        }
        connections.put(context.connectionId(), context);
    }

    public synchronized void unregister(String connectionId) {
        connections.remove(connectionId);
    }

    public Collection<ConnectionContext> getActiveConnections() {
        return Collections.unmodifiableCollection(connections.values());
    }
}
```

### Idle Timeout
```java
// Setup in handleConnection
socket.setIdleTimeout(idleTimeoutSeconds);

socket.exceptionHandler(error -> {
    if (error.getClass().getSimpleName().contains("Idle")) {
        LOGGER.info("Connection idle timeout: {}", context.connectionId());
        socket.close();
    } else {
        handleConnectionError(socket, context, error);
    }
});
```

### Keep-Alive
```java
// Vert.x NetSocket enables TCP keep-alive automatically
// Additional configuration via system properties (if needed)
System.setProperty("java.net.preferIPv4Stack", "true");
```

### Backpressure (Flow Control)
```java
// If the handler is slower than the client sending
// Use socket.pause() / socket.resume()

private AtomicInteger pendingMessages = new AtomicInteger(0);

private void handleMessageBody(...) {
    pendingMessages.incrementAndGet();

    if (pendingMessages.get() > 10) {
        socket.pause(); // Pause reading
    }

    handler.process(bodyBuffer)
        .subscribe().with(
            response -> {
                socket.write(Buffer.buffer(framed));

                if (pendingMessages.decrementAndGet() <= 5) {
                    socket.resume(); // Resume reading
                }
            },
            // ...
        );
}
```

## Error Handling per Connection

### Strategy
| Error | Action | Connection | Log |
|-------|--------|-----------|-----|
| Parse error | Send error response (RC 96) | **OPEN** | ERROR |
| Processing error | Send error response (RC 96) | **OPEN** | ERROR |
| Timeout (RULE-002) | Delay response | **OPEN** | INFO |
| Connection reset | Close + cleanup | **CLOSED** | WARN |
| Buffer overflow | Reject message + log | **OPEN** | ERROR |
| Unknown MTI | Send error response (RC 12) | **OPEN** | WARN |

### Implementation
```java
private void handleProcessingError(NetSocket socket, ConnectionContext context, Throwable error) {
    if (error instanceof TimeoutSimulationException) {
        // RULE-002: don't close, just delay response
        LOGGER.info("Timeout simulation: {}", context.connectionId());
        // Response will be delayed in the application
        return;
    }

    if (error instanceof MessageParsingException) {
        LOGGER.error("Parse error: {}", error.getMessage());
        try {
            socket.write(Buffer.buffer(encodeErrorResponse("96")));
        } catch (Exception e) {
            LOGGER.error("Failed to send error response", e);
        }
        return;
    }

    if (error instanceof TransactionProcessingException) {
        LOGGER.error("Transaction processing error", error);
        try {
            socket.write(Buffer.buffer(encodeErrorResponse("96")));
        } catch (Exception e) {
            LOGGER.error("Failed to send error response", e);
        }
        return;
    }

    // Unknown error - close connection
    LOGGER.error("Unknown error, closing connection", error);
    socket.close();
}
```

## Metrics per Connection

### What to Measure
```java
public record ConnectionMetrics(
    String connectionId,
    String remoteAddress,
    OffsetDateTime connectedAt,
    OffsetDateTime lastActivityAt,

    long messageCount,
    long bytesReceived,
    long bytesSent,

    double averageResponseTimeMs,
    long maxResponseTimeMs,
    long minResponseTimeMs,

    long errorCount,
    long timeoutSimulationCount
) {}
```

### Implementation
```java
@ApplicationScoped
public class ConnectionMetrics {
    @Inject Meter meter;

    private final ConcurrentHashMap<String, ConnectionContext> metrics = new ConcurrentHashMap<>();

    public void recordConnectionOpened(String connectionId) {
        meter.upDownCounterBuilder("simulator.connections.active")
            .build()
            .add(1, Attributes.builder().put("protocol", "tcp").build());
    }

    public void recordConnectionClosed(String connectionId, ConnectionContext context) {
        long durationSeconds = Duration.between(context.connectedAt(), OffsetDateTime.now()).getSeconds();

        meter.histogramBuilder("simulator.connection.duration")
            .setUnit("s")
            .build()
            .record(durationSeconds);

        meter.counterBuilder("simulator.connections.total_messages")
            .build()
            .add(context.messageCount());

        meter.upDownCounterBuilder("simulator.connections.active")
            .build()
            .add(-1, Attributes.builder().put("protocol", "tcp").build());
    }

    public void recordMessageProcessed(ConnectionContext context) {
        context.recordMessageProcessed();
    }
}
```

## Complete Example: Echo Test Handler

```java
@ApplicationScoped
public class EchoTestHandler {
    @Inject Tracer tracer;
    @Inject ConnectionMetrics metrics;

    public Uni<byte[]> handle(Buffer requestBuffer, ConnectionContext context) {
        Span span = tracer.spanBuilder("echo.test")
            .setAttribute("connection.id", context.connectionId())
            .startSpan();

        try (Scope scope = span.makeCurrent()) {
            // Parse MTI 1804
            IsoMessage request = parseMessage(requestBuffer);

            // Change MTI to 1814 (echo response)
            IsoMessage response = request.toBuilder()
                .withMti("1814")
                .withResponseCode("00")
                .build();

            // Pack and frame
            byte[] packedMessage = response.pack();
            byte[] framedMessage = frameMessage(packedMessage);

            span.setStatus(StatusCode.OK);
            return Uni.createFrom().item(framedMessage);

        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            return Uni.createFrom().failure(e);
        } finally {
            span.end();
        }
    }

    private byte[] frameMessage(byte[] isoMessage) {
        ByteBuffer buffer = ByteBuffer.allocate(2 + isoMessage.length);
        buffer.putShort((short) isoMessage.length);
        buffer.put(isoMessage);
        return buffer.array();
    }
}
```

## TCP Socket Tests

### Basic Test
```java
@QuarkusTest
class TcpConnectionTest {
    @ConfigProperty(name = "simulator.socket.port")
    int port;

    @Test
    void multipleMessages_sameConnection_allProcessed() throws IOException {
        try (var client = new TcpTestClient("localhost", port)) {
            // Message 1
            byte[] req1 = buildEchoRequest("1804");
            byte[] res1 = client.sendAndReceive(req1);
            assertThat(extractMti(res1)).isEqualTo("1814");

            // Message 2 — same socket
            byte[] req2 = buildEchoRequest("1804");
            byte[] res2 = client.sendAndReceive(req2);
            assertThat(extractMti(res2)).isEqualTo("1814");

            // Connection remains open
            assertThat(client.isConnected()).isTrue();
        }
    }

    @Test
    void idleTimeout_noActivity_connectionClosed() throws IOException {
        try (var client = new TcpTestClient("localhost", port)) {
            Thread.sleep(35000); // Greater than timeout

            // Next attempt should fail
            assertThatThrownBy(() -> client.sendAndReceive(buildEchoRequest("1804")))
                .isInstanceOf(IOException.class);
        }
    }

    @Test
    void backpressure_fastSend_bufferHandled() throws IOException {
        try (var client = new TcpTestClient("localhost", port)) {
            // Send multiple messages rapidly
            for (int i = 0; i < 100; i++) {
                byte[] req = buildEchoRequest("1804");
                client.send(req);
            }

            // All responses should be received
            for (int i = 0; i < 100; i++) {
                byte[] res = client.receive();
                assertThat(extractMti(res)).isEqualTo("1814");
            }
        }
    }
}
```
