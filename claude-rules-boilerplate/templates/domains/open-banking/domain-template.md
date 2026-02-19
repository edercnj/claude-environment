# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule — Open Banking / Open Finance Domain

<!-- TEMPLATE INSTRUCTIONS:
     Customize this file for your Open Banking / Open Finance implementation.
     Replace all {PLACEHOLDER} values and remove instruction comments.
     Reference: templates/domains/open-banking/domain-rules.md for comprehensive rules. -->

## Domain Overview

<!-- Describe your Open Banking implementation context.
     Which country/regulation? Which participant role (ASPSP, TPP, both)?
     Which Open Finance phases are you implementing? -->

{DOMAIN_OVERVIEW}

## System Role

- **Receives:** {e.g., Consent requests, payment initiation requests, data queries}
- **Processes:** {e.g., OAuth 2.0 + FAPI flows, consent validation, PIX orchestration}
- **Returns:** {e.g., Standardized OFB API responses, payment status updates}
- **Persists:** {e.g., Consent records, payment logs, audit trails}

## Instant Payment Configuration

<!-- Configure your PIX / instant payment implementation. -->

### Supported Payment Types

| Type | Enabled | Notes |
|------|---------|-------|
| PIX via Key | {YES/NO} | {DICT lookup required} |
| PIX via Account | {YES/NO} | {Manual entry} |
| PIX QR Static | {YES/NO} | {Merchant use case} |
| PIX QR Dynamic | {YES/NO} | {Single-use, fixed amount} |

### Institution Configuration

```properties
institution.ispb={YOUR_8_DIGIT_ISPB}
institution.name={YOUR_INSTITUTION_NAME}
institution.participant-type={ASPSP|TPP|BOTH}
pix.e2eid.prefix=E{ISPB}
pix.transaction.max-amount={MAX_AMOUNT_IN_CENTS}
pix.settlement.timeout-seconds=10
```

## Authentication & Authorization

<!-- Configure your FAPI / OAuth 2.0 setup. -->

### Certificate Configuration

```properties
mtls.keystore.path={PATH_TO_KEYSTORE}
mtls.keystore.type={PKCS12|JKS}
mtls.truststore.path={PATH_TO_BACEN_TRUSTSTORE}
oauth.client-auth-method={private_key_jwt|tls_client_auth}
oauth.token.signing-algorithm=PS256
oauth.token.max-lifetime-seconds=300
```

### Supported Scopes

<!-- List the OFB scopes your implementation supports. -->

| Scope | Enabled | Phase |
|-------|---------|-------|
| openid | YES | - |
| consents | {YES/NO} | 2 |
| accounts | {YES/NO} | 2 |
| credit-cards-accounts | {YES/NO} | 2 |
| payments | {YES/NO} | 3 |

## Consent Configuration

### Consent Rules

- Maximum consent duration: {DURATION, e.g., 12 months}
- Re-authentication interval: {INTERVAL, e.g., 180 days}
- Data deletion deadline after revocation: {HOURS, e.g., 24 hours}

### Permission Groups

<!-- Enable/disable permission groups for your implementation. -->

{PERMISSION_GROUPS_TABLE}

## Error Code Mapping

<!-- Map your internal error codes to BACEN standard codes. -->

| Internal Code | BACEN Code | HTTP Status | Description |
|--------------|------------|-------------|-------------|
| {INTERNAL_CODE} | {BACEN_CODE} | {STATUS} | {DESCRIPTION} |

## Sensitive Data Handling

<!-- Define masking rules specific to your implementation. -->

| Data | Masking Rule | Storage | Logging |
|------|-------------|---------|---------|
| CPF | `***.***.XXX-XX` | AES-256 encrypted | Masked only |
| Account Number | `****1234` | AES-256 encrypted | Masked only |
| {ADDITIONAL_DATA} | {MASK_RULE} | {STORAGE_RULE} | {LOG_RULE} |

## Rate Limiting

```properties
rate-limit.global.requests-per-second={DEFAULT: 300}
rate-limit.per-endpoint.accounts={LIMIT}
rate-limit.per-endpoint.payments={LIMIT}
rate-limit.per-endpoint.consents={LIMIT}
```

## Domain Anti-Patterns

<!-- List domain-specific mistakes to avoid in YOUR implementation. -->

{DOMAIN_ANTI_PATTERNS}

## Glossary

<!-- Add project-specific terms beyond standard Open Banking terminology. -->

| Term | Definition |
|------|-----------|
| {TERM} | {DEFINITION} |
