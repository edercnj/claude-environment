# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 07 — Security Principles

## Principles
- **Defense in Depth:** multiple layers of protection
- **Least Privilege:** minimum necessary access
- **Fail Secure:** errors must result in denial, not approval
- **Zero Trust on Data:** all input is hostile until validated

## Sensitive Data — Classification

Define your data classification per your domain. Universal categories:

| Classification | Examples | Can Log? | Can Persist? | Can Return in API? |
|---------------|---------|----------|-------------|-------------------|
| **PROHIBITED** | Passwords, tokens, secrets, encryption keys | NEVER | NEVER | NEVER |
| **RESTRICTED** | PII (email, phone, SSN), financial identifiers | Masked only | Masked or encrypted | Masked only |
| **INTERNAL** | Internal IDs, amounts, timestamps | Yes | Yes | Yes |
| **PUBLIC** | Product names, status codes | Yes | Yes | Yes |

### Masking Rules

For RESTRICTED data, define masking functions per data type:

```
// Example: mask email
"user@example.com" → "u***@example.com"

// Example: mask identifier (first 3 + last 2 visible)
"123456789012345" → "123****45"

// Example: mask phone
"+1234567890" → "+1****7890"
```

### Golden Rule

**If in doubt whether data is sensitive, treat it as PROHIBITED.**

## Input Validation

### All External Input MUST Be Validated Before Processing

| Validation | Where | Action if Invalid |
|-----------|-------|------------------|
| Message size | Transport layer (decoder) | Reject, return error |
| Message format | Parser | Reject, return error |
| Required fields present | Handler | Reject, return error |
| Field types and ranges | Handler | Reject, return error |
| Business constraints | Domain | Reject, return error |

### Size Limits

Define maximum sizes for all inputs:

| Element | Limit | Configurable? |
|---------|-------|:-------------:|
| Request body (HTTP) | 1 MB | Yes |
| Message body (protocol) | 64 KB | Yes |
| String fields | Per specification | Fixed |
| File uploads | Per requirement | Yes |

### API Validation

Use framework-provided validation (Bean Validation, Pydantic, Zod, etc.):

```
CreateRequest:
    name: required, max 100 chars
    email: required, valid email format
    identifier: required, pattern-matched
```

## Secure Error Handling

### Error Responses

```
// GOOD — Generic error for client, details in log
Response: { "type": "/errors/processing-error", "status": 500, "detail": "Internal processing error" }
Log: "Processing failed: id=123, error=NullPointerException at Handler:42"

// BAD — Stack trace exposed to client
Response: { "error": "NullPointerException at Handler.java:42", "trace": "..." }
```

### Fail Secure

```
// GOOD — When in doubt, deny
function decide(input):
    try:
        return decisionEngine.decide(input)
    catch Exception:
        log.error("Decision engine failed, denying")
        return DENIED  // Safe default

// BAD — Error results in approval
function decide(input):
    try:
        return decisionEngine.decide(input)
    catch Exception:
        return APPROVED  // DANGER: error = approval
```

**Rule:** Every fallback, catch block, and error handler MUST default to the SAFE state (deny, reject, block).

## Credentials and Secrets

### Storage

| Type | Location | Format |
|------|----------|--------|
| Database passwords | Secret manager / K8s Secret | Environment variable |
| API keys | Secret manager / K8s Secret | Environment variable |
| TLS certificates | Secret manager / K8s Secret | Mounted volume |

### Prohibitions

- Credentials hardcoded in source code
- Credentials in configuration files (except defaults for local dev)
- Credentials in ConfigMaps (use Secrets)
- Credentials in logs, traces, metrics, or error messages
- Credentials in container image layers
- Credentials committed to version control

## Infrastructure Security

### Container Security

- **Non-root user:** run as unprivileged user (UID >= 1000)
- **Read-only filesystem:** when possible
- **No privilege escalation:** `allowPrivilegeEscalation: false`
- **Minimal image:** use distroless or slim base images
- **Drop all capabilities:** `capabilities.drop: ["ALL"]`

### Kubernetes Security Context

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

## Connection Security

| Control | Purpose |
|---------|---------|
| Max concurrent connections | Prevent resource exhaustion |
| Idle timeout | Free zombie connections |
| Read timeout | Prevent slowloris attacks |
| Max message/request size | Prevent buffer overflow |
| Rate limiting | Prevent DoS (see Resilience rule) |

## Observability Security

Spans, metrics, and logs MUST NEVER contain:
- Passwords, tokens, secrets
- Full PII (use masked versions)
- Encryption keys
- Session tokens
- Request/response bodies with sensitive data

## Anti-Patterns (FORBIDDEN)

- Log sensitive data, even at DEBUG/TRACE level
- Persist secrets in any unencrypted form
- Return stack traces in production API responses
- Approve/allow on error (fail-open)
- Accept input without validating required fields
- Hardcode credentials in any repository file
- Run containers as root
- Disable input validation "to simplify"
- Trust internal network traffic implicitly (zero trust)
- Store secrets in environment variables without a secrets manager in production
