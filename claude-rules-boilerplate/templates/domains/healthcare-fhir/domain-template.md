# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule — Healthcare FHIR Domain

<!-- TEMPLATE INSTRUCTIONS:
     Customize this file for your Healthcare FHIR implementation.
     Replace all {PLACEHOLDER} values and remove instruction comments.
     Reference: templates/domains/healthcare-fhir/domain-rules.md for comprehensive rules. -->

## Domain Overview

<!-- Describe your FHIR implementation context.
     Which FHIR version (R4, R5)? What role (EHR, PHR, HIE, FHIR facade)?
     What clinical domain (lab, pharmacy, radiology, general)? -->

{DOMAIN_OVERVIEW}

## System Role

- **Receives:** {e.g., FHIR resource requests, HL7v2 messages, CDA documents}
- **Processes:** {e.g., Resource validation, search resolution, terminology lookups}
- **Returns:** {e.g., FHIR JSON resources, OperationOutcome, Bundles}
- **Persists:** {e.g., FHIR resources with version history, AuditEvents}

## FHIR Version & Profile Configuration

```properties
fhir.version={R4|R5}
fhir.base-url={YOUR_FHIR_BASE_URL}
fhir.default-format={json|xml}
fhir.max-bundle-size={DEFAULT: 500}
```

### Supported Resources

<!-- List the FHIR resources your system supports. -->

| Resource | Read | Create | Update | Delete | Search | Notes |
|----------|------|--------|--------|--------|--------|-------|
| Patient | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {NOTES} |
| Observation | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {NOTES} |
| Condition | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {NOTES} |
| {RESOURCE} | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {Y/N} | {NOTES} |

### Implementation Guides / Profiles

<!-- List the FHIR IGs your system conforms to. -->

| IG / Profile | Version | Required | Notes |
|-------------|---------|----------|-------|
| US Core | {VERSION} | {YES/NO} | {NOTES} |
| {PROFILE_NAME} | {VERSION} | {YES/NO} | {NOTES} |

## Terminology Configuration

<!-- Configure which code systems your implementation uses. -->

| Code System | URI | Use Case | Required |
|------------|-----|----------|----------|
| SNOMED CT | http://snomed.info/sct | {USE_CASE} | {YES/NO} |
| LOINC | http://loinc.org | {USE_CASE} | {YES/NO} |
| ICD-10 | {URI} | {USE_CASE} | {YES/NO} |
| {CODE_SYSTEM} | {URI} | {USE_CASE} | {YES/NO} |

## SMART on FHIR Configuration

<!-- Configure your authorization setup. -->

```properties
smart.authorization-endpoint={AUTH_URL}
smart.token-endpoint={TOKEN_URL}
smart.supported-scopes={SCOPES}
smart.launch-modes={ehr|standalone|both}
```

### Role-Based Access

| Role | Scopes | Description |
|------|--------|-------------|
| Practitioner | {SCOPES} | {DESCRIPTION} |
| Patient | {SCOPES} | {DESCRIPTION} |
| System | {SCOPES} | {DESCRIPTION} |

## Data Interoperability

<!-- Configure if your system converts from legacy formats. -->

### Inbound Conversions

| Source Format | Enabled | Target Resources | Notes |
|--------------|---------|-----------------|-------|
| HL7v2 ADT | {YES/NO} | Patient, Encounter | {NOTES} |
| HL7v2 ORU | {YES/NO} | Observation, DiagnosticReport | {NOTES} |
| CDA | {YES/NO} | Bundle (document) | {NOTES} |

## Sensitive Data Handling

<!-- Define PHI handling rules specific to your implementation. -->

| Data | Classification | Logging | Storage | API Response |
|------|---------------|---------|---------|-------------|
| Patient Name | PHI | Audit only | Encrypted | Authorized |
| {DATA_FIELD} | {CLASS} | {LOG_RULE} | {STORE_RULE} | {API_RULE} |

## Compliance

<!-- Reference applicable compliance rules. -->

- HIPAA: {YES/NO} — Reference: `security/compliance/hipaa.md`
- 42 CFR Part 2: {YES/NO} — Substance abuse records
- State-specific: {STATE/REGULATION}

## Domain Anti-Patterns

<!-- List domain-specific mistakes to avoid in YOUR implementation. -->

{DOMAIN_ANTI_PATTERNS}

## Glossary

<!-- Add project-specific terms beyond standard FHIR terminology. -->

| Term | Definition |
|------|-----------|
| {TERM} | {DEFINITION} |
