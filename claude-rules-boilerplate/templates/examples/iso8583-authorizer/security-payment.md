# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 21 — Payment Systems Security

> This rule covers security concerns SPECIFIC to payment card processing and ISO 8583.
> General application security (container hardening, credential management, infrastructure)
> is defined in the core security rule.

## Sensitive Data -- Classification

| Data | Classification | Can Log? | Can Persist? | Can Return in API? |
|------|---------------|----------|--------------|-------------------|
| PAN (DE-2) | **RESTRICTED** | Masked (6+4) | Masked (6+4) | Masked (6+4) |
| PIN Block (DE-52) | **PROHIBITED** | NEVER | NEVER | NEVER |
| CVV/CVC | **PROHIBITED** | NEVER | NEVER | NEVER |
| Track 1/2 (DE-35/36) | **PROHIBITED** | NEVER | NEVER | NEVER |
| Card Expiry (DE-14) | **RESTRICTED** | NEVER | Allowed | NEVER |
| STAN (DE-11) | Internal | Yes | Yes | Yes |
| Amount (DE-4) | Internal | Yes | Yes | Yes |
| MID (DE-42) | Internal | Yes | Yes | Yes |
| TID (DE-41) | Internal | Yes | Yes | Yes |

### Golden Rule

**If in doubt whether data is sensitive, treat it as PROHIBITED.**

## PAN Masking

Standard mask format: **first 6 digits + **** + last 4 digits**

```
Input:  "4111111111111111"
Output: "411111****1111"
```

Rules:
- If PAN is null or shorter than 13 characters, return `"****"`
- NEVER log the full PAN, even at DEBUG or TRACE level
- NEVER store the full PAN in the database -- always mask before persisting
- The masked PAN is safe for logging, persistence, and API responses

## PIN Block -- Absolute Prohibition

- NEVER log, not even at TRACE level
- NEVER persist in any form (database, file, cache)
- NEVER include in API responses
- NEVER include in observability data (spans, metrics, logs)
- Process in memory only, discard immediately after use

## CVV/CVC -- Absolute Prohibition

Same rules as PIN Block. NEVER log, persist, or return in any form.

## Track Data (DE-35, DE-36) -- Absolute Prohibition

Same rules as PIN Block. Track 1 and Track 2 data contain the full magnetic stripe information and MUST NEVER be stored or logged.

## Card Expiry (DE-14)

- NEVER log (even though it seems harmless, combined with PAN it enables fraud)
- Allowed to persist in database (needed for some business logic)
- NEVER return in API responses

## ISO 8583 Message Validation

All messages received via TCP MUST be validated BEFORE processing:

| Validation | Component | Action if Invalid |
|-----------|-----------|-----------------|
| Frame size (length header) | Frame Decoder | Reject, RC 96, keep connection |
| Recognized MTI | Message Router | Reject, RC 12, keep connection |
| Valid bitmap | ISO Parser | Reject, RC 96, keep connection |
| Required fields present | Transaction Handler | Reject, RC 30, keep connection |
| Type/size of each field | ISO Parser | Reject, RC 96, keep connection |
| Amount > 0 | Transaction Handler | Reject, RC 13, keep connection |

### Size Limits

| Element | Limit | Source |
|---------|-------|--------|
| ISO message body | 65535 bytes (2-byte header) | Wire protocol |
| PAN (DE-2) | 19 digits | ISO 8583 spec |
| STAN (DE-11) | 6 digits | ISO 8583 spec |
| MID (DE-42) | 15 characters | ISO 8583 spec |
| TID (DE-41) | 8 characters | ISO 8583 spec |

### Validation Principle

ALWAYS validate before processing. NEVER access a field assuming it exists or has the correct type. Null fields, missing fields, and malformed data are expected in adversarial environments.

## Fail Secure -- Transaction Authorization

The fail-secure principle is the most critical security rule for payment processing:

**When in doubt, DENY the transaction (RC 96).**

Scenarios where fail-secure applies:
- Decision engine throws an unexpected exception: **DENY (RC 96)**
- Database is unreachable (circuit breaker open): **DENY (RC 96)**
- Processing timeout: **DENY (RC 96)**
- Bulkhead capacity exceeded: **DENY (RC 96)**
- Any unhandled error in the processing chain: **DENY (RC 96)**

NEVER approve a transaction as a fallback. An approved transaction moves money; a denied transaction can be retried.

## Observability -- Sensitive Data in Spans and Metrics

Spans, metrics, and logs MUST NEVER contain:
- Full PAN
- PIN Block
- CVV/CVC
- Track Data
- Card Expiry
- Any authentication credentials

Safe attributes for spans and metrics:
- MTI, STAN, Response Code
- Merchant ID (MID), Terminal ID (TID)
- Transaction amount (in cents)
- Transaction type
- ISO version

## Security Anti-Patterns (PROHIBITED)

- Log full PAN, even at DEBUG/TRACE level
- Persist PIN Block or CVV in any form
- Approve transaction when the decision engine fails (fail-secure violation)
- Accept ISO messages without validating required fields
- Include sensitive card data in observability telemetry
- Store full PAN in the database (must be masked before persistence)
- Return card expiry date in REST API responses
