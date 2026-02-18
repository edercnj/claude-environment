# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 21 — Application Security (Payment Systems)

## Principles
- **Defense in Depth:** multiple layers of protection
- **Least Privilege:** minimum necessary access
- **Fail Secure:** errors must result in denial, not approval
- **Zero Trust on Data:** all input is hostile until validated

## Sensitive Data — Classification

| Data | Classification | Can log? | Can persist? | Can return in API? |
|------|--------------|-------------|-----------------|----------------------|
| PAN (DE-2) | **RESTRICTED** | Masked (6+4) | Masked (6+4) | Masked (6+4) |
| PIN Block (DE-52) | **PROHIBITED** | ❌ NEVER | ❌ NEVER | ❌ NEVER |
| CVV/CVC | **PROHIBITED** | ❌ NEVER | ❌ NEVER | ❌ NEVER |
| Track 1/2 (DE-35/36) | **PROHIBITED** | ❌ NEVER | ❌ NEVER | ❌ NEVER |
| Card Expiry (DE-14) | **RESTRICTED** | ❌ NEVER | Allowed | ❌ NEVER |
| STAN (DE-11) | Internal | ✅ Yes | ✅ Yes | ✅ Yes |
| Amount (DE-4) | Internal | ✅ Yes | ✅ Yes | ✅ Yes |
| MID (DE-42) | Internal | ✅ Yes | ✅ Yes | ✅ Yes |
| TID (DE-41) | Internal | ✅ Yes | ✅ Yes | ✅ Yes |

### PAN Masking
```java
// ✅ CORRECT — Standard mask: first 6 + last 4
public static String maskPan(String pan) {
    if (pan == null || pan.length() < 13) return "****";
    return pan.substring(0, 6) + "****" + pan.substring(pan.length() - 4);
}
// "4111111111111111" → "411111****1111"

// ❌ WRONG — Full PAN
LOG.info("Processing card {}", pan);
```

### Golden Rule
**If in doubt whether data is sensitive, treat it as PROHIBITED.**

## Input Validation

### ISO 8583 Messages
All messages received via TCP MUST be validated BEFORE processing:

| Validation | Where | Action if invalid |
|-----------|------|-----------------|
| Frame size (length header) | MessageFrameDecoder | Reject, RC 96, keep connection |
| Recognized MTI | MessageRouter | Reject, RC 12, keep connection |
| Valid bitmap | Parser (b8583) | Reject, RC 96, keep connection |
| Required fields present | Handler | Reject, RC 30, keep connection |
| Type/size of each field | Parser (b8583) | Reject, RC 96, keep connection |
| Amount > 0 | Handler | Reject, RC 13, keep connection |

```java
// ✅ CORRECT — Validate before processing
public TransactionResult process(IsoMessage request) {
    validateRequiredFields(request);  // Throws exception if invalid
    var amount = extractAndValidateAmount(request);
    // ...
}

// ❌ WRONG — Process without validation
public TransactionResult process(IsoMessage request) {
    var amount = new BigDecimal(request.getField(4));  // What if field 4 is null? Or not numeric?
}
```

### Size Limits
| Element | Limit | Configurable |
|----------|--------|-------------|
| ISO message body | 65535 bytes (2-byte header) | Via length header config |
| REST request body | 1 MB | `quarkus.http.limits.max-body-size` |
| PAN (DE-2) | 19 digits | Fixed (ISO spec) |
| STAN (DE-11) | 6 digits | Fixed (ISO spec) |
| MID (DE-42) | 15 characters | Fixed (ISO spec) |
| TID (DE-41) | 8 characters | Fixed (ISO spec) |

### REST API Validation
```java
// ✅ CORRECT — Bean Validation in Records
public record CreateMerchantRequest(
    @NotBlank @Size(max = 15) String mid,
    @NotBlank @Size(max = 100) String name,
    @NotBlank @Pattern(regexp = "\\d{11,14}") String document,
    @NotBlank @Size(min = 4, max = 4) @Pattern(regexp = "\\d{4}") String mcc
) {}
```

## Secure Error Handling

### Error Responses
```java
// ✅ CORRECT — Generic error for client, details in log
// Response to client:
{ "type": "/errors/processing-error", "status": 500, "detail": "Internal processing error" }
// Internal log:
LOG.error("Transaction processing failed: mti={}, stan={}, error={}", mti, stan, e.getMessage());

// ❌ WRONG — Stack trace exposed to client
{ "error": "NullPointerException at TransactionHandler.java:42", "trace": "..." }
```

### Fail Secure

> The fail-secure principle is reinforced in all resilience patterns (circuit breaker fallback, timeout fallback, bulkhead rejection). See **Rule 24 — Application Resilience** for complete implementation.

```java
// ✅ CORRECT — When in doubt, deny
public String decide(BigDecimal amount) {
    try {
        return centsDecisionEngine.decide(amount);
    } catch (Exception e) {
        LOG.error("Decision engine failed, denying transaction", e);
        return RESPONSE_CODE_SYSTEM_ERROR;  // RC 96 — denies the transaction
    }
}

// ❌ WRONG — Error results in approval
public String decide(BigDecimal amount) {
    try {
        return centsDecisionEngine.decide(amount);
    } catch (Exception e) {
        return RESPONSE_CODE_APPROVED;  // DANGER: error = approval
    }
}
```

## TCP Connections — Security

| Control | Configuration | Reason |
|----------|-------------|--------|
| Max connections | `simulator.socket.max-connections=100` | Prevent resource exhaustion |
| Idle timeout | `simulator.socket.idle-timeout=300` | Free zombie connections |
| Read timeout | `simulator.socket.read-timeout=30` | Prevent slowloris |
| Max message size | Limited by length header (2 bytes = 65535) | Prevent buffer overflow |
| Rate limiting (TCP) | `simulator.resilience.rate-limit.tcp-per-connection` | Prevent DoS (Rule 24) |
| Rate limiting (REST) | `simulator.resilience.rate-limit.rest-per-ip` | Prevent DoS (Rule 24) |

## Credentials and Secrets

### Where to store
| Type | Location | Format |
|------|-------|---------|
| DB password | Kubernetes Secret | `${DB_PASSWORD}` via env var |
| API keys | Kubernetes Secret | `${API_KEY}` via env var |
| TLS certificates | Kubernetes Secret (type: tls) | Mounted as volume |

### Prohibitions
- ❌ Credentials hardcoded in Java code
- ❌ Credentials in `application.properties` (except defaults for local dev)
- ❌ Credentials in ConfigMap (use Secret)
- ❌ Credentials in logs, traces, metrics
- ❌ Credentials in Docker image layers

## Infrastructure

### Container Security
- **Non-root:** `USER 1001` in all Dockerfiles
- **Read-only filesystem:** when possible
- **No new privileges:** `securityContext.allowPrivilegeEscalation: false`
- **Minimal image:** `quarkus-micro-image` (native) or `eclipse-temurin:21-jre-alpine` (JVM)

### Kubernetes Security
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

## OpenTelemetry — Sensitive Data

Spans, metrics, and logs MUST NEVER contain:
- Full PAN
- PIN Block
- CVV/CVC
- Track Data
- Card Expiry
- Credentials

```java
// ✅ CORRECT — Span with safe data
span.setAttribute("iso.mti", "1200");
span.setAttribute("iso.stan", "123456");
span.setAttribute("merchant.id", "123456789012345");

// ❌ WRONG — Span with sensitive data
span.setAttribute("card.pan", "4111111111111111");
span.setAttribute("card.pin_block", pinBlock);
```

## Security Anti-Patterns (PROHIBITED)
- ❌ Log full PAN, even at DEBUG/TRACE level
- ❌ Persist PIN Block or CVV in any form
- ❌ Return stack traces in production REST responses
- ❌ Approve transaction if decision engine errors
- ❌ Accept ISO messages without validating required fields
- ❌ Hardcoded credentials in any repository file
- ❌ Container running as root
- ❌ Disable input validation "to simplify"
