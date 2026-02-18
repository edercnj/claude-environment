# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 20 — Persistent TCP Connections

## Overview

The authorizer simulator maintains PERSISTENT TCP connections (long-lived) with acquirers and terminals. Multiple ISO 8583 messages arrive sequentially on the SAME connection, without disconnection between messages.

## Connection Model

### Operating Model
```
Client connects -> Validates identity -> [Msg1 -> Resp1] -> [Msg2 -> Resp2] -> ... -> [MsgN -> RespN] -> Disconnects
```

**Characteristics:**
- Connections: PERSISTENT (long-lived)
- Duration: hours or days
- Messages per connection: hundreds to thousands
- Disconnection: graceful (client closes) or timeout (idle)
- Each connection: completely independent

### Connection Limits

| Limit | Default | Configurable |
|-------|---------|-------------|
| Max concurrent connections | 100 | Yes |
| Idle timeout | 300s | Yes |
| Read timeout | 30s | Yes |
| Max message size | 65535 bytes | Via length header (2 or 4 bytes) |

## Message Framing Protocol

### Wire Format
```
[Length Header: 2 or 4 bytes] [ISO 8583 Message Body]
                               ^
                               Size indicated by header
```

### Length Header Format
- **2-byte header (default):** unsigned short (0 - 65535 bytes)
- **4-byte header (optional):** unsigned int (0 - 4GB)
- **Byte Order:** big-endian (network byte order)
- **Scope:** size of ISO body (MTI + Bitmaps + Data Elements), DOES NOT include header itself

### Practical Example
```
Raw ISO message:             [0x31, 0x32, 0x30, 0x30, ...] (ISO request, 200 bytes)
With 2-byte framing (BE):   [0x00, 0xC8, 0x31, 0x32, 0x30, 0x30, ...]
                             |--- header --| |------ ISO body ------|
                                 (200)
```

### Framing Algorithm (Read)
1. Read exactly 2 bytes (or 4 bytes) from socket
2. Interpret as unsigned integer (big-endian) = message length N
3. Validate: 0 < N <= max message size (65535 for 2-byte header)
4. Read exactly N bytes from socket = ISO 8583 message body
5. Process message body
6. Go to step 1 (next message on same connection)

### Framing Algorithm (Write)
1. Pack ISO 8583 response into byte array = response body
2. Calculate length = response body size
3. Write 2 bytes (or 4 bytes) big-endian length header
4. Write response body
5. Flush

## Connection Lifecycle

### Phases
1. **Accept:** Client connects, server accepts socket
2. **Initialize:** Exchange greeting (optional), initial validation
3. **Message Loop:** Client sends messages, server responds (indefinite loop)
4. **Graceful Close:** Client closes socket
5. **Cleanup:** Server releases resources (connection tracking, metrics)

### Connection Registration
- Each connection gets a unique identifier (UUID)
- Connection metadata is captured at accept time: remote address, timestamp
- Connection is registered in a connection manager for tracking
- On close: unregister from manager, emit metrics

## Error Handling per Connection

### Strategy Table

| Error | Action | Connection State | Log Level |
|-------|--------|-----------------|-----------|
| Parse error (invalid ISO) | Send error response (RC 96) | **OPEN** | ERROR |
| Processing error | Send error response (RC 96) | **OPEN** | ERROR |
| Timeout simulation (RULE-002) | Delay response intentionally | **OPEN** | INFO |
| Connection reset by client | Close + cleanup | **CLOSED** | WARN |
| Buffer overflow (message too large) | Reject message + log | **OPEN** | ERROR |
| Unknown MTI | Send error response (RC 12) | **OPEN** | WARN |
| Unknown/fatal error | Close connection | **CLOSED** | ERROR |

### Key Principle: Keep Connection Alive

On recoverable errors (parse, processing, unknown MTI), the connection MUST remain open. Only close on:
- Client-initiated close
- Idle timeout
- Unrecoverable errors (connection reset, fatal I/O)

### Error Response Pattern
When an error occurs during message processing:
1. Build an ISO 8583 error response with appropriate Response Code (RC 96 for system error, RC 12 for invalid transaction)
2. Frame the response with the length header
3. Send to client
4. Reset the framing parser to read the next length header
5. Connection remains open for next message

## Thread Safety Rules

1. **NEVER share mutable state across connections** -- each connection has its own parser and context
2. **Each connection has its own framing parser** -- the parser is not thread-safe, one instance per connection
3. **Transaction context is per-message, not per-connection** -- create a new processing context for each message within a connection
4. **Connection metadata is read-only after initialization** -- once the connection is established, its identity data (ID, remote address, connected-at) is immutable
5. **Message handlers are stateless singletons** -- shared across all connections, no mutable instance state

## Backpressure (Flow Control)

When the server cannot process messages as fast as the client sends them:

| Mechanism | Threshold | Action |
|-----------|-----------|--------|
| Pending messages per connection | > 10 | Pause reading from this socket |
| Resume threshold | <= 5 | Resume reading from this socket |
| Pending messages global | > 1000 | Reject new connections |

### Rules
- Backpressure is per-connection: pausing one connection does NOT affect others
- Use socket-level read pause/resume (TCP flow control)
- NEVER use thread sleep to simulate backpressure -- it blocks the event loop
- NEVER forget to resume -- paused connections must resume when load decreases
- Track pending message count per connection and globally

## Metrics per Connection

The following data should be tracked for each connection:

| Metric | Type | Description |
|--------|------|-------------|
| Connection ID | String | Unique identifier |
| Remote Address | String | Client IP:port |
| Connected At | Timestamp | Connection establishment time |
| Last Activity At | Timestamp | Last message sent or received |
| Message Count | Counter | Total messages processed |
| Bytes Received | Counter | Total bytes received |
| Bytes Sent | Counter | Total bytes sent |
| Average Response Time | Gauge | Average processing time in ms |
| Error Count | Counter | Total errors on this connection |
| Timeout Simulation Count | Counter | Number of RULE-002 timeout simulations |

## Anti-Patterns (PROHIBITED)

- Closing connection on recoverable errors (parse errors, unknown MTI)
- Sharing a single framing parser across multiple connections
- Storing mutable per-connection state in a singleton bean without proper isolation
- Using blocking I/O on the event loop thread
- Forgetting to clean up connection resources on close
- Not tracking connection metrics (makes debugging production issues impossible)
- Processing timeout simulations (RULE-002) on the main processing thread pool (blocks other messages)
