# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# WebSocket Protocol Conventions

## Connection Lifecycle

Every WebSocket connection follows a strict lifecycle with defined phases.

| Phase | Description | Timeout |
|-------|-------------|---------|
| 1. TCP + TLS Handshake | Standard HTTPS upgrade to WSS | 5 seconds |
| 2. WebSocket Upgrade | HTTP 101 Switching Protocols | Included in handshake |
| 3. Authentication | First message MUST be auth token | 10 seconds after connect |
| 4. Ready | Server sends acknowledgment; client can send/receive | N/A |
| 5. Active | Normal message exchange with heartbeats | Heartbeat interval |
| 6. Draining | Server stops accepting new messages; flushes pending | 30 seconds |
| 7. Close | Clean close frame exchange (1000 Normal Closure) | 5 seconds |

**Rules:**
- ALL connections MUST use WSS (TLS); plain WS is forbidden in all environments
- Server MUST close connections that do not authenticate within the auth timeout
- Server MUST send a connection acknowledgment message after successful authentication
- Connection acknowledgment MUST include: connection ID, server time, heartbeat interval, protocol version

## Message Framing

All messages MUST use a standard JSON envelope regardless of payload content.

### Message Envelope Structure

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `type` | string | Yes | Message category (see table below) |
| `payload` | object | Yes | Message-specific data |
| `correlationId` | string (UUID) | Yes | Links request to response; client-generated for requests, echoed in responses |
| `timestamp` | string (ISO 8601) | Yes | Message creation time in UTC |
| `version` | string | No | Protocol version (default: current) |

### Message Types

| Type | Direction | Purpose |
|------|-----------|---------|
| `auth` | Client -> Server | Authentication token submission |
| `auth_ack` | Server -> Client | Authentication accepted |
| `auth_error` | Server -> Client | Authentication rejected |
| `ping` | Either | Heartbeat request |
| `pong` | Either | Heartbeat response |
| `subscribe` | Client -> Server | Subscribe to a channel/topic |
| `unsubscribe` | Client -> Server | Unsubscribe from a channel/topic |
| `message` | Either | Application-level data |
| `error` | Server -> Client | Error notification |
| `close` | Either | Graceful connection shutdown |

## Heartbeat / Ping-Pong Configuration

| Parameter | Default | Range | Notes |
|-----------|---------|-------|-------|
| Heartbeat interval | 30 seconds | 15-60 seconds | Server sends ping; client responds with pong |
| Pong timeout | 10 seconds | 5-30 seconds | Maximum wait for pong after ping |
| Missed pongs before disconnect | 2 | 1-3 | Consecutive misses trigger server-side close |
| Client-initiated ping | Allowed | N/A | Server MUST respond with pong |

**Rules:**
- Server is the primary heartbeat initiator; client MAY also send pings
- Heartbeat interval is communicated in the `auth_ack` message
- Application messages reset the heartbeat timer (any traffic counts as alive)
- NEVER rely solely on TCP keep-alive; always use application-level heartbeats
- Log heartbeat failures with connection metadata for diagnostics

## Reconnection with Exponential Backoff

Clients MUST implement automatic reconnection with exponential backoff.

| Attempt | Delay | Notes |
|---------|-------|-------|
| 1 | 1 second | Immediate retry for transient failures |
| 2 | 2 seconds | |
| 3 | 4 seconds | |
| 4 | 8 seconds | |
| 5 | 16 seconds | |
| 6+ | 30 seconds (cap) | Maximum backoff; NEVER exceed this |

**Rules:**
- Add random jitter (0-1 second) to each delay to prevent thundering herd
- Reset backoff counter after a successful connection that stays alive for at least 60 seconds
- Maximum reconnection attempts: unlimited (with capped backoff)
- Client MUST resubscribe to all channels after reconnection
- Client MUST re-authenticate after reconnection (tokens may have expired)
- Distinguish between clean close (1000) and abnormal close; only reconnect on abnormal close
- Display connection status to user (if applicable) after 3 failed attempts

## Message Ordering Guarantees

| Guarantee | Scope | Notes |
|-----------|-------|-------|
| FIFO per connection | Single client | Messages arrive in the order sent within one connection |
| No ordering across connections | Multiple clients | Different clients may see events in different order |
| No ordering across channels | Single client | Messages from different channels may interleave |

**Rules:**
- If strict ordering is required across multiple channels, use a single channel with typed messages
- Include a monotonically increasing sequence number in messages when ordering must be validated
- Clients MUST handle out-of-order messages gracefully (idempotent processing)
- Servers MUST NOT reorder messages within a single connection

## Authentication

### Strategy 1: Token in First Message (Recommended)

| Step | Action |
|------|--------|
| 1 | Client connects to WSS endpoint |
| 2 | Client sends `auth` message with bearer token |
| 3 | Server validates token |
| 4 | Server sends `auth_ack` or `auth_error` |
| 5 | Server drops connection if no auth within timeout |

### Strategy 2: Token in Query Parameter (Fallback Only)

| Step | Action |
|------|--------|
| 1 | Client connects to `wss://host/ws?token=xxx` |
| 2 | Server validates token during upgrade handshake |
| 3 | Connection is established already authenticated |

**Use query parameter ONLY** when the client library does not support custom headers or initial messages (e.g., browser-native WebSocket API without subprotocol negotiation).

**Token in query parameter risks:** tokens appear in server access logs, proxy logs, and browser history. Mitigate with short-lived tokens (max 60 seconds TTL).

### Token Refresh

- Server MUST send an `error` message with a `TOKEN_EXPIRING` type 60 seconds before token expiry
- Client refreshes the token via HTTP and sends a new `auth` message on the existing connection
- If the client does not refresh in time, server closes with code 4001 (Authentication Expired)

## Room / Channel Patterns

| Concept | Description | Naming Convention |
|---------|-------------|-------------------|
| Channel | Logical grouping of related messages | `domain:entity:qualifier` (e.g., `orders:12345:updates`) |
| Room | Shared channel for multiple participants | `room:identifier` (e.g., `room:support-chat-789`) |
| Broadcast | Server-to-all-connected-clients | `system:broadcast` |
| Private | Server-to-single-client | Implicit (any message on the connection) |

**Rules:**
- Channel names use colon-separated segments, lowercase, no spaces
- Maximum channel name length: 256 characters
- Maximum channels per connection: 50 (configurable)
- Server MUST validate channel access permissions on subscribe
- Unsubscribe MUST be acknowledged by the server

## Binary vs Text Frames

| Frame Type | When to Use | Content |
|------------|-------------|---------|
| Text (opcode 0x1) | Default for all application messages | JSON envelope |
| Binary (opcode 0x2) | File transfers, media streams, compressed payloads | Raw bytes with header prefix |

**Rules:**
- Default to text frames with JSON for all control and application messages
- Use binary frames ONLY for bulk data transfer (files, images, audio)
- Binary frames MUST include a 4-byte header: 2 bytes message type + 2 bytes payload length
- NEVER mix JSON and binary in the same frame
- Document the binary protocol separately if used

## Message Size Limits

| Limit | Default | Configurable Range |
|-------|---------|-------------------|
| Maximum text frame size | 64 KB | 16 KB - 1 MB |
| Maximum binary frame size | 1 MB | 64 KB - 16 MB |
| Maximum message size (after reassembly) | 1 MB | 64 KB - 16 MB |

**Rules:**
- Server MUST close connections that send oversized messages (close code 1009: Message Too Big)
- Communicate maximum message size in the `auth_ack` message
- For payloads exceeding the limit, use chunked transfer with application-level reassembly
- Log oversized message attempts with client identity for abuse detection

## Connection Draining on Deploy (Graceful Shutdown)

| Step | Timeout | Action |
|------|---------|--------|
| 1 | Immediate | Stop accepting new connections; remove from load balancer |
| 2 | Immediate | Send `close` message to all connected clients with reason `SERVER_SHUTTING_DOWN` |
| 3 | 30 seconds | Wait for in-flight messages to complete |
| 4 | 30 seconds | Send WebSocket close frame (1001: Going Away) to remaining connections |
| 5 | 5 seconds | Force-terminate any connections that did not close cleanly |

**Rules:**
- Total drain timeout: 65 seconds maximum (align with Kubernetes `terminationGracePeriodSeconds`)
- Clients receiving a drain signal MUST reconnect to a different server instance
- Load balancer health check MUST fail immediately on shutdown signal to prevent new connections
- During draining, server MUST still process pong responses (do not break heartbeat)
- Log drain statistics: connections drained, connections force-terminated, in-flight messages lost

## Anti-Patterns (FORBIDDEN)

- Plain WS (unencrypted) connections in any environment -- always use WSS
- Connections without authentication timeout -- unauthenticated connections MUST be closed
- Missing heartbeat mechanism -- all connections MUST have ping/pong
- Reconnection without exponential backoff -- prevents thundering herd
- Reconnection without jitter -- causes synchronized retry storms
- Sending messages before authentication is complete
- Relying on TCP keep-alive as the sole liveness check
- Unbounded message sizes without server-enforced limits
- Long-lived tokens in query parameters -- use short-lived tokens or first-message auth
- Channels without access control validation on subscribe
- Hard-killing connections on deploy without drain period
- Custom binary protocols without documentation
- Messages without correlation IDs -- impossible to trace request/response pairs
- Stateful servers that cannot handle reconnection to a different instance
