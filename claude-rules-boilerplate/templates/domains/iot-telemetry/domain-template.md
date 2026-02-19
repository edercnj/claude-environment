# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule — IoT Telemetry Domain

<!-- TEMPLATE INSTRUCTIONS:
     Customize this file for your IoT Telemetry implementation.
     Replace all {PLACEHOLDER} values and remove instruction comments.
     Reference: templates/domains/iot-telemetry/domain-rules.md for comprehensive rules. -->

## Domain Overview

<!-- Describe your IoT implementation context.
     What type of devices? What industry (manufacturing, agriculture, smart building, fleet)?
     What scale (number of devices, messages per second)? -->

{DOMAIN_OVERVIEW}

## System Role

- **Receives:** {e.g., Device telemetry, registration requests, command acknowledgements}
- **Processes:** {e.g., Telemetry validation, time-series aggregation, rule evaluation}
- **Returns:** {e.g., Commands, desired state updates, alert notifications}
- **Persists:** {e.g., Time-series data, device registry, twin state, alert history}

## Device Configuration

### Device Types

| Device Type | Protocol | Auth Method | Telemetry Interval | Notes |
|------------|----------|-------------|-------------------|-------|
| {TYPE_NAME} | {MQTT/CoAP/HTTP} | {X.509/SAS/JWT} | {INTERVAL} | {NOTES} |

### Device Registry

```properties
device.registry.id-format={UUID|CUSTOM_FORMAT}
device.auth.default-method={X509|SAS|JWT}
device.auth.sas-token-ttl-hours={DEFAULT: 24}
device.auth.certificate-ca={CA_PATH}
device.twin.max-size-kb={DEFAULT: 32}
```

## Protocol Configuration

### Primary Protocol

```properties
mqtt.broker.url={BROKER_URL}
mqtt.version={5|3.1.1}
mqtt.default-qos={0|1|2}
mqtt.keepalive-seconds={DEFAULT: 60}
mqtt.clean-session={true|false}
mqtt.tls.enabled=true
mqtt.tls.min-version=1.2
```

### Topic Structure

<!-- Define your MQTT topic hierarchy. -->

```
Telemetry: {TOPIC_PATTERN}
Commands:  {TOPIC_PATTERN}
Twin:      {TOPIC_PATTERN}
Alerts:    {TOPIC_PATTERN}
```

### Fallback Protocols

| Protocol | Enabled | Use Case | Notes |
|----------|---------|----------|-------|
| CoAP | {YES/NO} | {USE_CASE} | {NOTES} |
| AMQP | {YES/NO} | {USE_CASE} | {NOTES} |
| HTTP | {YES/NO} | {USE_CASE} | {NOTES} |

## Telemetry Configuration

### Ingestion Rules

```properties
telemetry.late-arrival.tolerance-minutes={DEFAULT: 60}
telemetry.batch.max-messages={DEFAULT: 500}
telemetry.batch.max-size-kb={DEFAULT: 256}
telemetry.compression={gzip|snappy|lz4|none}
telemetry.duplicate-detection.enabled=true
```

### Metrics

<!-- Define the telemetry metrics your devices send. -->

| Metric | Unit | Data Type | Valid Range | Alert Threshold |
|--------|------|-----------|-------------|-----------------|
| {METRIC_NAME} | {UNIT} | {float/int/bool/string} | {MIN - MAX} | {THRESHOLD} |

## Data Pipeline Configuration

### Storage Tiers

| Tier | Engine | Retention | Granularity | Use Case |
|------|--------|-----------|-------------|----------|
| Hot | {ENGINE} | {DAYS} | {RAW/1min/5min} | {USE_CASE} |
| Warm | {ENGINE} | {DAYS} | {1hr/1day} | {USE_CASE} |
| Cold | {ENGINE} | {MONTHS/YEARS} | {1day/raw archive} | {USE_CASE} |

### Downsampling Rules

```properties
downsampling.hot-to-warm.interval={DEFAULT: 7d}
downsampling.hot-to-warm.aggregation={avg|min|max|count}
downsampling.warm-to-cold.interval={DEFAULT: 90d}
```

## Edge Computing

<!-- Configure if your deployment includes edge devices. -->

### Edge Configuration

```properties
edge.enabled={true|false}
edge.store-forward.enabled={true|false}
edge.store-forward.max-size-mb={DEFAULT: 1024}
edge.store-forward.retention-hours={DEFAULT: 72}
edge.local-processing.enabled={true|false}
```

### Edge Modules

| Module | Purpose | Enabled | Notes |
|--------|---------|---------|-------|
| {MODULE_NAME} | {PURPOSE} | {YES/NO} | {NOTES} |

## Alert / Rule Engine

### Alert Rules

<!-- Define your alert rules. -->

| Rule ID | Name | Type | Condition | Severity | Actions |
|---------|------|------|-----------|----------|---------|
| {RULE_ID} | {NAME} | {threshold/anomaly/geofence/absence} | {CONDITION} | {critical/warning/info} | {ACTIONS} |

### Alert Configuration

```properties
alert.cooldown.default-minutes={DEFAULT: 15}
alert.escalation.timeout-minutes={DEFAULT: 30}
alert.notification.channels={email,sms,webhook,pagerduty}
alert.maintenance-mode.enabled=false
```

## Command Configuration

### Supported Commands

| Command | Method | Timeout (s) | QoS | Description |
|---------|--------|------------|-----|-------------|
| {COMMAND_NAME} | {direct/twin/c2d} | {TIMEOUT} | {QoS} | {DESCRIPTION} |

## Sensitive Data Handling

| Data | Classification | Logging | Storage | API Response |
|------|---------------|---------|---------|-------------|
| Device Credentials | CREDENTIAL | NEVER | Vault only | NEVER |
| GPS Location | PII | Masked | Encrypted | Authorized |
| {DATA_FIELD} | {CLASS} | {LOG_RULE} | {STORE_RULE} | {API_RULE} |

## Domain Anti-Patterns

<!-- List domain-specific mistakes to avoid in YOUR implementation. -->

{DOMAIN_ANTI_PATTERNS}

## Glossary

<!-- Add project-specific terms beyond standard IoT terminology. -->

| Term | Definition |
|------|-----------|
| {TERM} | {DEFINITION} |
