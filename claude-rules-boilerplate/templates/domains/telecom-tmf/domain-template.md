# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule — Telecom TM Forum Domain

<!-- TEMPLATE INSTRUCTIONS:
     Customize this file for your Telecom TM Forum implementation.
     Replace all {PLACEHOLDER} values and remove instruction comments.
     Reference: templates/domains/telecom-tmf/domain-rules.md for comprehensive rules. -->

## Domain Overview

<!-- Describe your telecom implementation context.
     Which TMF APIs are you implementing? BSS, OSS, or both?
     What type of operator (MNO, MVNO, ISP, converged)? -->

{DOMAIN_OVERVIEW}

## System Role

- **Receives:** {e.g., Order requests, catalog queries, billing inquiries, event notifications}
- **Processes:** {e.g., Order orchestration, inventory allocation, rating/billing}
- **Returns:** {e.g., TMF-compliant API responses, event notifications}
- **Persists:** {e.g., Orders, inventory, billing records, customer data}

## TMF API Configuration

### Implemented APIs

| TMF API | TMF ID | Version | Role (Provider/Consumer) | Notes |
|---------|--------|---------|-------------------------|-------|
| Product Catalog | TMF620 | {v4} | {Provider/Consumer} | {NOTES} |
| Product Ordering | TMF622 | {v4} | {Provider/Consumer} | {NOTES} |
| Product Inventory | TMF637 | {v4} | {Provider/Consumer} | {NOTES} |
| Customer Bill | TMF678 | {v4} | {Provider/Consumer} | {NOTES} |
| Party Management | TMF632 | {v4} | {Provider/Consumer} | {NOTES} |
| {API_NAME} | {TMF_ID} | {VERSION} | {ROLE} | {NOTES} |

### API Base Configuration

```properties
tmf.api.base-url={YOUR_API_BASE_URL}/tmf-api
tmf.api.version=v4
tmf.api.pagination.default-limit={DEFAULT: 20}
tmf.api.pagination.max-limit={DEFAULT: 100}
```

## Product/Service/Resource Model

<!-- Define your specific layered model. -->

### Product Types

| Product | Services | Resources | Notes |
|---------|----------|-----------|-------|
| {PRODUCT_NAME} | {SERVICE_LIST} | {RESOURCE_LIST} | {NOTES} |

### Catalog Configuration

```properties
catalog.product-lifecycle.default-state=IN_STUDY
catalog.offering.require-approval={true|false}
catalog.specification.versioning={SEMANTIC|INCREMENTAL}
```

## Order Orchestration

<!-- Define your order processing rules. -->

### Order Item Processing

| Action | Validation Rules | Orchestration Steps | Notes |
|--------|-----------------|---------------------|-------|
| add | {RULES} | {STEPS} | {NOTES} |
| modify | {RULES} | {STEPS} | {NOTES} |
| delete | {RULES} | {STEPS} | {NOTES} |

## Event Configuration

### Hub/Listener Setup

```properties
event.hub.base-url={HUB_URL}
event.retry.max-attempts={DEFAULT: 3}
event.retry.backoff=1s,5s,30s
event.dead-letter.enabled={true|false}
```

### Subscribed Events

| Event Type | Source API | Callback URL | Filter |
|-----------|-----------|-------------|--------|
| {EVENT_TYPE} | {TMF_ID} | {CALLBACK} | {FILTER} |

## Billing Configuration

```properties
billing.currency={CURRENCY_CODE}
billing.minor-units={DEFAULT: 2}
billing.cycle.frequency={MONTHLY|WEEKLY}
billing.proration.enabled={true|false}
billing.tax.calculation-mode={INCLUSIVE|EXCLUSIVE}
```

## Sensitive Data Handling

| Data | Classification | Logging | Storage | API Response |
|------|---------------|---------|---------|-------------|
| Customer Name | PII | Audit only | Encrypted | Authorized |
| National ID | RESTRICTED | NEVER | Encrypted | Masked |
| {DATA_FIELD} | {CLASS} | {LOG_RULE} | {STORE_RULE} | {API_RULE} |

## Domain Anti-Patterns

<!-- List domain-specific mistakes to avoid in YOUR implementation. -->

{DOMAIN_ANTI_PATTERNS}

## Glossary

<!-- Add project-specific terms beyond standard TMF terminology. -->

| Term | Definition |
|------|-----------|
| {TERM} | {DEFINITION} |
