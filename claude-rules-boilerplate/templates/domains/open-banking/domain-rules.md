# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 51 — Open Banking / Open Finance Domain

> This rule describes the Open Banking / Open Finance domain, covering Brazilian Instant Payments (PIX),
> BACEN API standards, consent lifecycle management, payment initiation, and account aggregation.
> All implementations MUST comply with Open Finance Brasil specifications and BCB regulations.

## Domain Overview

Open Banking (Open Finance) enables secure sharing of financial data and payment initiation between
institutions through standardized APIs. In Brazil, the ecosystem is regulated by the Central Bank
(BACEN/BCB) and follows the Open Finance Brasil (OFB) specifications. The system mediates
consent-driven data sharing and payment flows between Account Servicing Payment Service Providers
(ASPSPs) and Third Party Providers (TPPs).

## System Role

- **Receives:** Consent requests, payment initiation requests, account data queries, webhook notifications
- **Processes:** OAuth 2.0 + FAPI authorization flows, consent validation, payment orchestration, data aggregation
- **Returns:** Standardized API responses per OFB specs, redirect URIs, payment status updates
- **Persists:** Consent records, payment transaction logs, refresh tokens, audit trails

## PIX — Brazilian Instant Payment System (MANDATORY)

### PIX Message Formats

| Message Type | Direction | Format | Description |
|-------------|-----------|--------|-------------|
| PACS.008 | Payer PSP -> SPI | ISO 20022 XML | Payment initiation |
| PACS.002 | SPI -> Payer PSP | ISO 20022 XML | Payment status report |
| PACS.004 | Payee PSP -> SPI | ISO 20022 XML | Payment return |
| CAMT.014 | PSP -> SPI | ISO 20022 XML | Return request |
| DICT API | PSP -> DICT | REST JSON | Key lookup/registration |

### Settlement Flow

```
Payer PSP -> SPI (PACS.008) -> Payee PSP
    |                              |
    v                              v
Debit payer account         Credit payee account
    |                              |
    v                              v
SPI settles via STR (Real-Time Gross Settlement)
```

- Settlement is REAL-TIME (< 10 seconds end-to-end)
- SPI operates 24/7/365 including holidays
- Maximum transaction amount: R$ 1,000,000.00 per transaction (configurable per PSP)
- Idempotency: EndToEndId (E2EId) is the unique identifier — MUST be exactly 32 characters

### QR Code Types

| Type | Use Case | Expiry | Amount | Reuse |
|------|----------|--------|--------|-------|
| Static | Fixed payment point (merchant) | Never expires | Optional (payer can edit) | Unlimited |
| Dynamic (Immediate) | Single transaction | Configurable (default: calendar.expiration) | Fixed (payer cannot edit) | Single use |
| Dynamic (Due Date) | Billing/invoicing | Due date + tolerance | Fixed with discount/penalty/interest | Single use |

### PIX Key Types (DICT)

| Key Type | Format | Validation |
|----------|--------|------------|
| CPF | 11 digits | Validate check digits (mod 11) |
| CNPJ | 14 digits | Validate check digits (mod 11) |
| Email | RFC 5322 | Max 77 characters |
| Phone | +5511999999999 | E.164 format, country code +55 |
| EVP | UUID v4 | Random key, no personal data |

## BACEN API Standards (MANDATORY)

### Authentication & Authorization

- **OAuth 2.0 + FAPI (Financial-grade API)**: All APIs MUST use FAPI 1.0 Advanced profile
- **MTLS (Mutual TLS)**: Client authentication via X.509 certificates issued by ICP-Brasil
- **Certificate Chain**: ICP-Brasil -> BACEN CA -> Institution Certificate
- **Token Endpoint**: MUST use `private_key_jwt` or `tls_client_auth` for client authentication
- **Access Tokens**: JWT format, signed with PS256, max lifetime 300 seconds (5 minutes)
- **ID Tokens**: MUST include `acr` claim with LoA (Level of Assurance)

### FAPI Compliance Requirements

```
Authorization Request:
- response_type: "code id_token" (hybrid flow) or "code" (PAR required)
- MUST use PAR (Pushed Authorization Requests) — RFC 9126
- MUST include request object (signed JWT) with nbf, exp, iss, aud, jti
- PKCE: REQUIRED with S256 method
- scope: openid + specific OFB scopes (consents, payments, accounts, etc.)

Token Request:
- MUST present client certificate (MTLS)
- grant_type: "authorization_code" or "client_credentials"
- DPoP: RECOMMENDED for sender-constrained tokens
```

### API Versioning

- Version in URL path: `/open-banking/v1/`, `/open-banking/v2/`
- Breaking changes increment major version
- Deprecation period: minimum 6 months with `Sunset` header

## Consent Lifecycle (MANDATORY)

### Consent States

```
AWAITING_AUTHORISATION -> AUTHORISED -> CONSUMED (for payments)
                       -> REJECTED
AUTHORISED -> REVOKED (by customer or TPP)
```

### Consent Request

```json
{
  "data": {
    "permissions": ["ACCOUNTS_READ", "ACCOUNTS_BALANCES_READ", "TRANSACTIONS_READ"],
    "expirationDateTime": "2025-12-31T23:59:59Z",
    "transactionFromDateTime": "2024-01-01T00:00:00Z",
    "transactionToDateTime": "2025-12-31T23:59:59Z"
  }
}
```

### Consent Rules

- **CONSENT-001**: Consent MUST expire — maximum 12 months for data sharing
- **CONSENT-002**: Customer MUST explicitly authorize each permission group
- **CONSENT-003**: Revocation is immediate and irrevocable — all cached data MUST be purged
- **CONSENT-004**: Re-authentication required if consent is older than 180 days (configurable)
- **CONSENT-005**: Consent for payments is single-use — status moves to CONSUMED after execution
- **CONSENT-006**: Granular permissions — customer can authorize accounts individually

### Permission Groups

| Group | Permissions | Description |
|-------|------------|-------------|
| Registration Data | CUSTOMERS_PERSONAL_IDENTIFICATIONS_READ | CPF, name, address |
| Accounts | ACCOUNTS_READ, ACCOUNTS_BALANCES_READ | Account list and balances |
| Transactions | ACCOUNTS_TRANSACTIONS_READ | Transaction history |
| Credit Cards | CREDIT_CARDS_ACCOUNTS_READ, CREDIT_CARDS_ACCOUNTS_BILLS_READ | Card data |
| Payments | PAYMENTS_INITIATE | Payment initiation (single-use consent) |

## Payment Initiation (MANDATORY)

### SPI Integration

- All PIX payments MUST be routed through the SPI (Sistema de Pagamentos Instantaneos)
- The EndToEndId (E2EId) format: `E{ISPB_8}{YYYYMMDDHHMMSS}{SEQ_11}`
- ISPB: 8-digit institution identifier assigned by BACEN
- Timestamp: UTC, format YYYYMMDDHHMMss
- Sequence: 11-character unique sequence (alphanumeric)

### Idempotency Requirements

- **IDEM-001**: All POST endpoints MUST support `x-idempotency-key` header
- **IDEM-002**: Idempotency key format: UUID v4
- **IDEM-003**: Key validity: 24 hours from first use
- **IDEM-004**: Repeated requests with same key MUST return original response (same status code and body)
- **IDEM-005**: Different payload with same key MUST return 422 Unprocessable Entity

### Payment States

```
RCVD (Received) -> PATC (Partially Accepted Technical) -> ACSP (Accepted Settlement in Process)
                -> RJCT (Rejected)
ACSP -> ACSC (Accepted Settlement Completed)
     -> ACCC (Accepted Credit Settlement Completed)
     -> RJCT (Rejected)
```

### Payment Rejection Reasons

| Code | Description | Action |
|------|-------------|--------|
| AGNT | Agent error (PSP) | Retry with corrected data |
| CURR | Currency mismatch | Must be BRL |
| CUST | Customer request | No retry |
| DNOR | Debtor not found | Verify account |
| DS04 | Order cancelled | No retry |
| FOCR | Fraud/compliance | Block and investigate |
| RC09 | Invalid purpose | Verify payment type |
| RC10 | Transaction not allowed | Check limits |
| RUTA | Return not accepted | Verify return window |

## Account Aggregation

### Data Sharing Agreements

- Data is shared ONLY within the scope of an active consent
- TPP MUST refresh data at intervals defined by BACEN (minimum 4x/day for balances)
- Data retention: TPP MUST delete all shared data within 24 hours of consent revocation
- Data MUST be stored encrypted at rest (AES-256) and in transit (TLS 1.2+)

### Refresh Token Management

- **REFRESH-001**: Refresh tokens MUST be rotated on each use (single-use)
- **REFRESH-002**: Maximum refresh token lifetime: 90 days
- **REFRESH-003**: Refresh token MUST be bound to the client certificate (MTLS)
- **REFRESH-004**: On rotation failure, invalidate the entire token chain
- **REFRESH-005**: Store refresh tokens encrypted, NEVER in plaintext

## Regulatory Compliance

### BCB Resolution No. 1 (Open Finance Brasil)

- All participating institutions MUST implement mandatory APIs by phase deadlines
- Phase 1: Institution data (public, no auth)
- Phase 2: Customer data sharing (consent required)
- Phase 3: Payment initiation (PIX)
- Phase 4: Advanced services (insurance, investments, forex)

### Mandatory Headers

| Header | Value | Required |
|--------|-------|----------|
| `x-fapi-interaction-id` | UUID v4 | All requests/responses |
| `x-fapi-auth-date` | RFC 7231 date | Customer-present requests |
| `x-fapi-customer-ip-address` | IPv4/IPv6 | Customer-present requests |
| `x-idempotency-key` | UUID v4 | All POST requests |
| `Content-Type` | application/json; charset=utf-8 | All requests with body |

### Rate Limiting

- Global: 300 requests/second per institution
- Per-endpoint: varies (see OFB spec per API)
- Response headers: `X-Rate-Limit-Limit`, `X-Rate-Limit-Remaining`, `X-Rate-Limit-Reset`
- Exceeded: HTTP 429 with `Retry-After` header

## Error Handling — BACEN Standard Error Codes

### Error Response Format

```json
{
  "errors": [
    {
      "code": "DETALHE_PAGAMENTO_INVALIDO",
      "title": "Detalhe do pagamento invalido",
      "detail": "O campo pixKey nao e valido para o tipo de chave informado"
    }
  ],
  "meta": {
    "totalRecords": 1,
    "totalPages": 1,
    "requestDateTime": "2024-01-15T10:30:00Z"
  }
}
```

### Standard Error Codes

| HTTP Status | Code | Description |
|-------------|------|-------------|
| 400 | NAO_INFORMADO | Required field not provided |
| 400 | DETALHE_PAGAMENTO_INVALIDO | Invalid payment detail |
| 401 | UNAUTHORIZED | Invalid or expired token |
| 403 | PERMISSAO_NEGADA | Insufficient consent permissions |
| 403 | CONSENTIMENTO_INVALIDO | Consent expired or revoked |
| 404 | RECURSO_NAO_ENCONTRADO | Resource not found |
| 422 | DETALHE_PAGAMENTO_INVALIDO | Business rule violation |
| 422 | PAGAMENTO_DIVERGENTE_CONSENTIMENTO | Payment does not match consent |
| 429 | LIMITE_EXCEDIDO | Rate limit exceeded |
| 500 | ERRO_INTERNO | Internal server error |

## Sensitive Data — NEVER Log in Plaintext

| Data | Classification | Can Log? | Can Persist? | Can Return in API? |
|------|---------------|----------|--------------|-------------------|
| CPF (Tax ID) | PII / RESTRICTED | Masked (***.***.XXX-XX) | Encrypted | Only to data owner via consent |
| CNPJ | PII | Masked (**.XXX.XXX/XXXX-**) | Encrypted | Only to data owner via consent |
| Account Number | FINANCIAL | Masked (****1234) | Encrypted | Via consent only |
| Account Balance | FINANCIAL | NEVER | Encrypted | Via consent only |
| PIX Key (CPF/Phone) | PII | Masked | Encrypted | Masked in responses |
| Refresh Token | CREDENTIAL | NEVER | Encrypted (AES-256) | NEVER |
| Client Certificate | CREDENTIAL | Thumbprint only | Secure keystore | NEVER |
| Transaction History | FINANCIAL / PII | Summary only | Encrypted | Via consent only |

### Masking Rules

- CPF: Show only last 3 digits before check digits: `***.***. 123-XX`
- CNPJ: Show only middle section: `**.123.456/0001-**`
- Account: Show only last 4 digits: `****1234`
- Phone: Show only last 4 digits: `+55**\*****9999`
- Email: Show first char + domain: `e***@domain.com`

## Domain Anti-Patterns

- Storing consent permissions as a single comma-separated string instead of normalized table
- Caching account data beyond the consent validity period
- Using symmetric keys for JWT signing (MUST use asymmetric — PS256)
- Implementing PIX without idempotency on payment endpoints
- Logging full CPF or account numbers in application logs
- Hardcoding ISPB or institution identifiers
- Skipping MTLS validation in staging/test environments
- Processing payment initiation without validating consent status first
- Using refresh tokens without rotation (replay attack vector)
- Treating consent expiration as a soft limit (it is HARD — reject after expiry)

## Glossary

| Term | Definition |
|------|-----------|
| ASPSP | Account Servicing Payment Service Provider — the bank holding the account |
| TPP | Third Party Provider — authorized institution accessing data or initiating payments |
| SPI | Sistema de Pagamentos Instantaneos — BACEN's instant payment infrastructure |
| DICT | Diretorio de Identificadores de Contas Transacionais — PIX key directory |
| E2EId | End-to-End Identification — unique 32-character PIX transaction identifier |
| ISPB | Identificador do Sistema de Pagamentos Brasileiro — 8-digit institution code |
| FAPI | Financial-grade API — OAuth 2.0 security profile for financial services |
| MTLS | Mutual TLS — both client and server present certificates |
| PAR | Pushed Authorization Request — RFC 9126, server-side authz request storage |
| ICP-Brasil | Brazilian Public Key Infrastructure — certificate authority chain |
| OFB | Open Finance Brasil — the Brazilian Open Finance specification body |
| BCB | Banco Central do Brasil — Brazilian Central Bank (regulator) |
| STR | Sistema de Transferencia de Reservas — Real-Time Gross Settlement system |
| DPoP | Demonstrating Proof of Possession — sender-constrained access tokens |
