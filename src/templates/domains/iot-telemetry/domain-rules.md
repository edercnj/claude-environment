# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 51 — IoT Telemetry Domain

> This rule describes the IoT (Internet of Things) Telemetry domain, covering device registry and
> provisioning, communication protocols, telemetry ingestion, command patterns, edge computing,
> data pipelines, and alert/rule engines.

## Domain Overview

The IoT Telemetry domain manages the full lifecycle of connected devices, from provisioning and
authentication through data ingestion, processing, storage, and analytics. It encompasses device
management (registry, twins/shadows), multi-protocol communication (MQTT, CoAP, AMQP, HTTP),
real-time telemetry processing, command and control patterns, edge computing, and alert/rule engines
for operational intelligence.

## System Role

- **Receives:** Device telemetry data, device registration requests, command acknowledgements, edge module reports
- **Processes:** Telemetry ingestion and validation, time-series aggregation, rule evaluation, anomaly detection, device state management
- **Returns:** Command messages, desired state updates, alert notifications, aggregated analytics, device provisioning credentials
- **Persists:** Time-series telemetry data, device registry, device twin/shadow state, alert history, command audit logs

## Device Registry (MANDATORY)

### Device Lifecycle

```
Device States:
REGISTERED -> PROVISIONED -> CONNECTED -> ACTIVE -> DISCONNECTED -> ACTIVE (reconnect)
                                                  -> DISABLED (admin action)
                                                  -> DECOMMISSIONED (end of life)
REGISTERED -> BLOCKED (security concern)
```

### Device Registration

| Attribute | Description | Required |
|-----------|-------------|----------|
| deviceId | Unique identifier (UUID or custom) | YES |
| deviceType | Classification (sensor, actuator, gateway, edge) | YES |
| model | Hardware model identifier | YES |
| firmwareVersion | Current firmware version | YES |
| capabilities | Supported protocols, telemetry types | YES |
| location | GPS coordinates or logical location | NO (recommended) |
| tags | Metadata key-value pairs for grouping | NO |
| parentDeviceId | Gateway or edge device (for child devices) | NO |

### Device Authentication

| Method | Use Case | Security Level | Rotation |
|--------|----------|---------------|----------|
| X.509 Certificate | Production devices, fleet enrollment | HIGH | Certificate renewal before expiry |
| SAS Token (Symmetric Key) | Development, constrained devices | MEDIUM | Rotate every 24-72 hours |
| TPM (Trusted Platform Module) | Hardware-secured devices | HIGHEST | Hardware-bound, no rotation |
| Token-based (JWT) | HTTP API access | MEDIUM | Short-lived (1 hour max) |

### Authentication Rules

- **AUTH-001**: X.509 certificates MUST be issued by a trusted CA (not self-signed in production)
- **AUTH-002**: SAS tokens MUST include expiry — never use non-expiring tokens
- **AUTH-003**: Per-device credentials — NEVER share credentials across devices
- **AUTH-004**: Certificate revocation list (CRL) or OCSP checked on every TLS handshake
- **AUTH-005**: Group enrollment via enrollment groups — devices auto-register with fleet certificate

### Device Twin / Shadow

The device twin (Azure) or device shadow (AWS) maintains a JSON document representing device state:

```json
{
  "deviceId": "sensor-001",
  "properties": {
    "desired": {
      "telemetryInterval": 30,
      "firmwareVersion": "2.1.0",
      "threshold": { "temperature": 85.0 }
    },
    "reported": {
      "telemetryInterval": 60,
      "firmwareVersion": "2.0.5",
      "battery": 78,
      "lastBootTime": "2024-01-15T08:00:00Z"
    }
  },
  "tags": {
    "location": "building-A/floor-3",
    "environment": "production"
  },
  "version": 42,
  "lastActivityTime": "2024-01-15T10:30:00Z"
}
```

- **TWIN-001**: `desired` properties are set by the backend — device reads and acts on them
- **TWIN-002**: `reported` properties are set by the device — backend reads for current state
- **TWIN-003**: Version field enables optimistic concurrency (If-Match header)
- **TWIN-004**: Twin updates MUST be partial (merge patch) — never send the full document
- **TWIN-005**: Maximum twin document size: 32 KB (Azure) / 8 KB per section (AWS)

## Communication Protocols (MANDATORY)

### Protocol Comparison

| Protocol | Transport | QoS | Overhead | Best For |
|----------|-----------|-----|----------|----------|
| MQTT v5 | TCP/TLS | 0, 1, 2 | Very Low | Primary telemetry, commands |
| MQTT v3.1.1 | TCP/TLS | 0, 1, 2 | Very Low | Legacy device support |
| CoAP | UDP/DTLS | Confirmable, Non-confirmable | Minimal | Constrained devices, LPWANs |
| AMQP 1.0 | TCP/TLS | At-least-once, Exactly-once | Medium | High-throughput, reliable delivery |
| HTTP/HTTPS | TCP/TLS | N/A (request-response) | High | Fallback, batch uploads, webhooks |
| WebSocket | TCP/TLS | N/A | Medium | Browser-based dashboards, real-time |

### MQTT Configuration (Primary Protocol)

#### Topic Structure

```
Telemetry (device -> cloud):
  devices/{deviceId}/telemetry
  devices/{deviceId}/telemetry/{sensorType}

Commands (cloud -> device):
  devices/{deviceId}/commands/{commandName}
  devices/{deviceId}/commands/{commandName}/response

Twin/Shadow:
  $iothub/twin/PATCH/properties/desired    (cloud -> device)
  $iothub/twin/PATCH/properties/reported   (device -> cloud)
  $iothub/twin/GET                         (device requests full twin)

System:
  $iothub/twin/res/{status}/?$rid={requestId}   (twin response)
  devices/{deviceId}/messages/events             (D2C messages)
```

#### MQTT v5 Features (Preferred)

| Feature | Use Case | Configuration |
|---------|----------|---------------|
| Shared Subscriptions | Load-balance across consumers | `$share/{group}/topic` |
| Message Expiry | TTL for commands | `messageExpiryInterval: 3600` |
| Topic Alias | Reduce bandwidth for frequent topics | `topicAliasMaximum: 100` |
| User Properties | Custom metadata headers | Key-value pairs on message |
| Request/Response | Correlate command responses | `responseTopic` + `correlationData` |
| Flow Control | Back-pressure | `receiveMaximum: 50` |

#### QoS Levels

| QoS | Guarantee | Use Case | Overhead |
|-----|-----------|----------|----------|
| 0 | At-most-once (fire and forget) | Frequent telemetry (temp every 1s) | Lowest |
| 1 | At-least-once (ACK required) | Important telemetry, alerts | Medium |
| 2 | Exactly-once (4-step handshake) | Commands, configuration changes | Highest |

- **MQTT-001**: Use QoS 1 as default for telemetry — balance between reliability and overhead
- **MQTT-002**: Use QoS 2 for commands and configuration changes — exactly-once delivery
- **MQTT-003**: QoS 0 only for high-frequency, non-critical data (e.g., heartbeat every second)
- **MQTT-004**: Retained messages for latest device state — new subscribers get last value
- **MQTT-005**: Clean session = false for persistent subscriptions across reconnects
- **MQTT-006**: Last Will and Testament (LWT) for disconnect detection

### CoAP Configuration

```
CoAP Endpoints:
  GET  coap://server/devices/{deviceId}/twin          -- Read twin
  PUT  coap://server/devices/{deviceId}/telemetry     -- Send telemetry
  POST coap://server/devices/{deviceId}/commands       -- Execute command

Observe (subscription):
  GET coap://server/devices/{deviceId}/twin?observe=0  -- Subscribe to twin changes
```

- **COAP-001**: Use Confirmable (CON) messages for important data — Non-confirmable (NON) for frequent telemetry
- **COAP-002**: Block-wise transfer for payloads > 1024 bytes
- **COAP-003**: DTLS 1.2+ mandatory for production

## Telemetry Ingestion (MANDATORY)

### Time-Series Data Model

```json
{
  "deviceId": "sensor-001",
  "timestamp": "2024-01-15T10:30:00.123Z",
  "metrics": {
    "temperature": { "value": 23.5, "unit": "celsius" },
    "humidity": { "value": 65.2, "unit": "percent" },
    "pressure": { "value": 1013.25, "unit": "hPa" }
  },
  "metadata": {
    "firmwareVersion": "2.0.5",
    "signalStrength": -72,
    "batteryLevel": 78
  }
}
```

### Ingestion Rules

- **INGEST-001**: Timestamp MUST be ISO 8601 UTC — reject messages without valid timestamp
- **INGEST-002**: Late arrival tolerance: configurable window (default: 1 hour) — older messages go to late-arrival queue
- **INGEST-003**: Duplicate detection: `deviceId` + `timestamp` + `metricName` composite key
- **INGEST-004**: Schema validation per device type — reject non-conforming payloads with error
- **INGEST-005**: Out-of-range detection: reject values outside physical bounds (e.g., temperature < -273.15C)

### Batching

```json
{
  "deviceId": "sensor-001",
  "batch": [
    { "timestamp": "2024-01-15T10:30:00Z", "metrics": { "temperature": { "value": 23.5 } } },
    { "timestamp": "2024-01-15T10:30:10Z", "metrics": { "temperature": { "value": 23.6 } } },
    { "timestamp": "2024-01-15T10:30:20Z", "metrics": { "temperature": { "value": 23.7 } } }
  ]
}
```

- **BATCH-001**: Maximum batch size: 500 messages or 256 KB (whichever is smaller)
- **BATCH-002**: Batch messages MUST be ordered by timestamp (ascending)
- **BATCH-003**: Each message in a batch is validated independently — partial acceptance allowed
- **BATCH-004**: Compression: gzip or Snappy for batch payloads > 1 KB

### Compression

| Algorithm | Ratio | CPU Cost | Use Case |
|-----------|-------|----------|----------|
| gzip | High (70-90%) | Medium | Batch uploads, HTTP |
| Snappy | Medium (50-70%) | Low | Real-time streams |
| LZ4 | Medium (50-70%) | Very Low | Low-latency streams |
| None | - | None | Small payloads < 128 bytes |

## Command Patterns (MANDATORY)

### Direct Method (Synchronous)

```
Cloud -> Device: invoke method "reboot" with payload {"delay": 10}
Device -> Cloud: respond with status 200, payload {"message": "rebooting in 10s"}
Timeout: configurable (default: 30 seconds)
```

- **CMD-001**: Direct methods require device to be CONNECTED — fail fast if offline
- **CMD-002**: Method timeout: 5-300 seconds (configurable per method)
- **CMD-003**: Response payload: max 128 KB
- **CMD-004**: Method names: alphanumeric + underscore, max 128 characters

### Desired State (Twin Update — Asynchronous)

```
Cloud: set desired.firmwareVersion = "2.1.0"
Device: receives delta notification
Device: downloads firmware, applies update
Device: set reported.firmwareVersion = "2.1.0"
Cloud: detects desired == reported -> update complete
```

- **STATE-001**: Desired state updates work even when device is offline — applied on reconnect
- **STATE-002**: Version conflict resolution: last-writer-wins with optimistic concurrency
- **STATE-003**: Monitor desired vs. reported delta for stuck updates (timeout: configurable)

### Cloud-to-Device Messages (Asynchronous Queue)

```
Cloud: enqueue message for device
Device: receives message when connected (FIFO queue)
Device: completes/abandons/rejects message
```

- **C2D-001**: Message queue depth: maximum 50 messages per device
- **C2D-002**: Message TTL: configurable (default: 1 hour, max: 48 hours)
- **C2D-003**: Delivery guarantee: at-least-once (device must ACK)
- **C2D-004**: Message feedback: complete (processed), abandon (re-queue), reject (dead-letter)

## Edge Computing (MANDATORY)

### Edge Architecture

```
Cloud Platform
    |
    | (intermittent connectivity)
    |
Edge Device / Gateway
    |-- Edge Runtime (container orchestrator)
    |     |-- Module A: Protocol translation (Modbus -> MQTT)
    |     |-- Module B: Local analytics (anomaly detection)
    |     |-- Module C: Local storage (SQLite/InfluxDB)
    |     |-- Edge Hub: Local message broker
    |
    |-- Child Devices (sensors, actuators)
         |-- via Modbus, BLE, Zigbee, Z-Wave, etc.
```

### Edge Module Rules

- **EDGE-001**: Edge modules MUST function during cloud disconnection (offline-first design)
- **EDGE-002**: Store-and-forward: buffer telemetry locally during disconnection, sync on reconnect
- **EDGE-003**: Local processing: filter, aggregate, or transform data before cloud upload
- **EDGE-004**: Edge module updates: deployed as container images, pulled from cloud registry
- **EDGE-005**: Local storage capacity: configurable retention policy (time-based or size-based)
- **EDGE-006**: Priority queue: critical alerts sent first when connectivity resumes

### Store-and-Forward Configuration

```properties
edge.store-forward.enabled=true
edge.store-forward.max-size-mb=1024
edge.store-forward.retention-hours=72
edge.store-forward.priority.critical=1
edge.store-forward.priority.telemetry=5
edge.store-forward.priority.diagnostic=10
edge.store-forward.sync-batch-size=100
```

## Data Pipeline (MANDATORY)

### Pipeline Stages

```
Ingestion -> Processing -> Storage -> Analytics

Ingestion:
  MQTT Broker / API Gateway -> Message Queue (Kafka/EventHubs)

Processing:
  Stream Processor (Flink/Spark Streaming/ASA)
    -> Validate schema
    -> Enrich (join with device registry)
    -> Aggregate (time windows: tumbling, sliding, session)
    -> Detect anomalies

Storage:
  Hot Path: Time-series DB (InfluxDB, TimescaleDB, ADX) — recent data, fast queries
  Warm Path: Columnar store (Parquet/Delta Lake) — weeks/months, analytical queries
  Cold Path: Object storage (S3/Blob) — archive, compliance, raw data

Analytics:
  Real-time dashboards -> Hot path
  Historical reports -> Warm path
  ML model training -> Cold path
```

### Time-Series Storage Rules

- **TS-001**: Partition by device and time (e.g., daily partitions)
- **TS-002**: Retention policies: hot (7 days), warm (90 days), cold (1+ years) — configurable
- **TS-003**: Downsampling: aggregate older data (e.g., 1-minute averages for data older than 7 days)
- **TS-004**: Compression: time-series specific (delta-of-delta, gorilla encoding)
- **TS-005**: Query optimization: pre-computed rollups for common aggregation periods (1min, 5min, 1hr, 1day)

### Stream Processing Windows

| Window Type | Description | Use Case |
|-------------|-------------|----------|
| Tumbling | Fixed, non-overlapping | Average temperature every 5 minutes |
| Sliding | Fixed, overlapping | Moving average over 10 minutes, evaluated every 1 minute |
| Session | Gap-based, variable | Group events with < 30 seconds gap |
| Snapshot | Point-in-time | Current state of all devices |

## Alert / Rule Engine (MANDATORY)

### Alert Types

| Type | Detection Method | Latency | Use Case |
|------|-----------------|---------|----------|
| Threshold | Simple comparison | < 1 second | Temperature > 85C |
| Rate of Change | Delta over time window | < 5 seconds | Temperature rising > 5C/minute |
| Anomaly Detection | Statistical / ML model | < 30 seconds | Unusual vibration pattern |
| Geofencing | GPS coordinate boundary | < 5 seconds | Device left designated area |
| Absence | No data within expected interval | Configurable | No heartbeat for 5 minutes |
| Composite | Multiple conditions (AND/OR) | < 5 seconds | High temp AND low pressure |

### Rule Definition

```json
{
  "ruleId": "rule-001",
  "name": "High Temperature Alert",
  "description": "Alert when temperature exceeds threshold",
  "enabled": true,
  "condition": {
    "type": "threshold",
    "metric": "temperature",
    "operator": "gt",
    "value": 85.0,
    "duration": "PT5M",
    "aggregation": "avg"
  },
  "severity": "critical",
  "actions": [
    { "type": "notification", "channel": "email", "recipients": ["ops@example.com"] },
    { "type": "command", "method": "shutdown", "payload": { "reason": "overtemperature" } },
    { "type": "webhook", "url": "https://incident.example.com/api/alert" }
  ],
  "cooldown": "PT15M",
  "scope": {
    "deviceType": "temperature-sensor",
    "tags": { "environment": "production" }
  }
}
```

### Alert Rules

- **ALERT-001**: Cooldown period prevents alert storms — minimum configurable interval between alerts
- **ALERT-002**: Severity levels: critical, warning, info — each with different notification channels
- **ALERT-003**: Alert acknowledgement: manual or auto-resolve when condition clears
- **ALERT-004**: Escalation: unacknowledged critical alerts escalate after configurable timeout
- **ALERT-005**: Suppression windows: maintenance mode disables non-critical alerts for a time range
- **ALERT-006**: Composite rules evaluate atomically — all conditions must be met simultaneously

## Sensitive Data — NEVER Log in Plaintext

| Data | Classification | Can Log? | Can Persist? | Can Return in API? |
|------|---------------|----------|--------------|-------------------|
| Device Credentials (cert/key) | CREDENTIAL | NEVER | Secure vault only | NEVER |
| SAS Token | CREDENTIAL | NEVER | Hashed only | NEVER |
| GPS Location | PII (if linked to person) | Coordinates masked | Encrypted | With authorization |
| Device Owner Info | PII | Masked | Encrypted | With authorization |
| Telemetry Data | OPERATIONAL | Yes (aggregated) | Yes | Yes (authorized) |
| Firmware Binary | IP / PROPRIETARY | Hash only | Encrypted storage | Authenticated download |
| Command Payloads | OPERATIONAL | Summary only | Yes (audit trail) | Yes (authorized) |
| Edge Local Storage | MIXED | NEVER (stays on edge) | Encrypted at rest | Via edge API only |

## Domain Anti-Patterns

- Using non-expiring credentials or shared secrets across device fleets
- Sending full telemetry to the cloud without edge filtering or aggregation
- Implementing fire-and-forget commands without acknowledgement tracking
- Storing time-series data in a relational database without partitioning strategy
- Using polling instead of MQTT subscriptions for real-time device state
- Processing all telemetry through a single pipeline without priority queuing
- Hardcoding device firmware URLs instead of using twin/shadow desired state
- Ignoring message ordering and idempotency in telemetry consumers
- Running anomaly detection on raw data instead of aggregated windows
- Designing edge modules that require constant cloud connectivity
- Using QoS 2 for all MQTT messages regardless of data criticality (over-engineering)
- Storing device twin/shadow history without retention policies (unbounded growth)

## Glossary

| Term | Definition |
|------|-----------|
| MQTT | Message Queuing Telemetry Transport — lightweight pub/sub messaging protocol |
| CoAP | Constrained Application Protocol — UDP-based protocol for constrained devices |
| AMQP | Advanced Message Queuing Protocol — enterprise messaging protocol |
| DTLS | Datagram Transport Layer Security — TLS equivalent for UDP |
| QoS | Quality of Service — message delivery guarantee level |
| LWT | Last Will and Testament — MQTT message sent when device disconnects unexpectedly |
| Twin | Device Twin (Azure) — cloud-side JSON document representing device state |
| Shadow | Device Shadow (AWS) — equivalent to Device Twin |
| D2C | Device-to-Cloud — telemetry direction |
| C2D | Cloud-to-Device — command direction |
| SAS | Shared Access Signature — token-based authentication |
| TPM | Trusted Platform Module — hardware security module |
| OTA | Over-The-Air — firmware update mechanism |
| LPWAN | Low-Power Wide-Area Network — LoRa, NB-IoT, Sigfox |
| Edge | Computing node between devices and cloud, providing local processing |
| Downsampling | Reducing data resolution by aggregating over time windows |
| Retention Policy | Rules for how long data is stored at each storage tier |
| Geofencing | Virtual geographic boundary triggering alerts on entry/exit |
