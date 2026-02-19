# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule — Insurance ACORD Domain

<!-- TEMPLATE INSTRUCTIONS:
     Customize this file for your Insurance implementation.
     Replace all {PLACEHOLDER} values and remove instruction comments.
     Reference: templates/domains/insurance-acord/domain-rules.md for comprehensive rules. -->

## Domain Overview

<!-- Describe your insurance implementation context.
     Which lines of business? Which market (US, Brazil, both)?
     What role (carrier, MGA, TPA, broker platform)? -->

{DOMAIN_OVERVIEW}

## System Role

- **Receives:** {e.g., Quote requests, policy change requests, FNOL, underwriting submissions}
- **Processes:** {e.g., Rating, underwriting, claims adjudication, reserve management}
- **Returns:** {e.g., Quotes, policy documents, claims status, ACORD messages}
- **Persists:** {e.g., Policies, claims, underwriting data, financial transactions}

## Lines of Business

<!-- List the LOBs your system supports. -->

| LOB | Code | Enabled | Notes |
|-----|------|---------|-------|
| Personal Auto | {CODE} | {YES/NO} | {NOTES} |
| Homeowners | {CODE} | {YES/NO} | {NOTES} |
| Commercial Property | {CODE} | {YES/NO} | {NOTES} |
| General Liability | {CODE} | {YES/NO} | {NOTES} |
| {LOB_NAME} | {CODE} | {YES/NO} | {NOTES} |

## Policy Configuration

### Policy Number Format

```properties
policy.number.format={LOB}-{YEAR}-{SEQUENCE}
policy.endorsement.versioning={SEQUENTIAL|TIMESTAMP}
policy.renewal.advance-days={DEFAULT: 60}
policy.free-look.days={DEFAULT: 10}
```

### Policy Lifecycle

<!-- Customize which lifecycle phases your system implements. -->

| Phase | Implemented | Automation Level | Notes |
|-------|-----------|-----------------|-------|
| Quote | {YES/NO} | {AUTO/MANUAL/HYBRID} | {NOTES} |
| Bind | {YES/NO} | {AUTO/MANUAL/HYBRID} | {NOTES} |
| Issue | {YES/NO} | {AUTO/MANUAL/HYBRID} | {NOTES} |
| Endorse | {YES/NO} | {AUTO/MANUAL/HYBRID} | {NOTES} |
| Renew | {YES/NO} | {AUTO/MANUAL/HYBRID} | {NOTES} |
| Cancel | {YES/NO} | {AUTO/MANUAL/HYBRID} | {NOTES} |

## Rating Configuration

```properties
rating.rounding.premium=NEAREST_CENT
rating.rounding.factors=4_DECIMAL_PLACES
rating.minimum-premium={AMOUNT_IN_CENTS}
rating.currency={ISO_4217_CODE}
rating.tables.versioning={DATE_EFFECTIVE|SEQUENTIAL}
```

### Rating Factors

<!-- Define the rating factors for your products. -->

| Factor | Source | Weight | Applicable LOBs |
|--------|--------|--------|-----------------|
| {FACTOR_NAME} | {DATA_SOURCE} | {HIGH/MEDIUM/LOW} | {LOBs} |

## Claims Configuration

```properties
claims.number.format=CLM-{YEAR}-{SEQUENCE}
claims.fnol.auto-acknowledge={true|false}
claims.reserve.review-interval-days={DEFAULT: 30}
claims.settlement.max-auto-approve={AMOUNT_IN_CENTS}
claims.siu.referral-threshold={AMOUNT_IN_CENTS}
```

### Claims Workflow

<!-- Define adjuster routing and authorization levels. -->

| Claim Type | Auto-Route To | Auth Level 1 | Auth Level 2 | Notes |
|-----------|--------------|-------------|-------------|-------|
| {CLAIM_TYPE} | {ADJUSTER_TEAM} | {AMOUNT} | {AMOUNT} | {NOTES} |

## Underwriting Rules

<!-- Define your straight-through processing and referral criteria. -->

### Auto-Accept Criteria

| Criterion | Threshold | LOB |
|-----------|-----------|-----|
| {CRITERION} | {THRESHOLD} | {LOB} |

### Referral Criteria

| Criterion | Threshold | Refer To |
|-----------|-----------|----------|
| {CRITERION} | {THRESHOLD} | {ROLE} |

## Regulatory Configuration

<!-- Configure jurisdiction-specific rules. -->

| Jurisdiction | Regulator | Rate Filing | Cancellation Notice | Free Look |
|-------------|-----------|------------|--------------------|-----------|
| {STATE/COUNTRY} | {REGULATOR} | {TYPE} | {DAYS} | {DAYS} |

## ACORD Integration

### Message Formats

| Format | Enabled | Version | Use Case |
|--------|---------|---------|----------|
| ACORD XML | {YES/NO} | {VERSION} | {USE_CASE} |
| ACORD JSON | {YES/NO} | {VERSION} | {USE_CASE} |
| ACORD Forms | {YES/NO} | {VERSION} | {USE_CASE} |

## Sensitive Data Handling

| Data | Classification | Logging | Storage | API Response |
|------|---------------|---------|---------|-------------|
| SSN / CPF | RESTRICTED | NEVER | Encrypted | Masked (last 4) |
| Medical Records | PHI | NEVER | Encrypted | Authorized only |
| {DATA_FIELD} | {CLASS} | {LOG_RULE} | {STORE_RULE} | {API_RULE} |

## Domain Anti-Patterns

<!-- List domain-specific mistakes to avoid in YOUR implementation. -->

{DOMAIN_ANTI_PATTERNS}

## Glossary

<!-- Add project-specific terms beyond standard insurance terminology. -->

| Term | Definition |
|------|-----------|
| {TERM} | {DEFINITION} |
