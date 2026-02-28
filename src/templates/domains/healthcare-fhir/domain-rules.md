# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 51 — Healthcare FHIR Domain

> This rule describes the Healthcare FHIR (Fast Healthcare Interoperability Resources) domain,
> covering FHIR R4/R5 resource types, RESTful API patterns, terminology systems, SMART on FHIR
> authorization, data interoperability, and HIPAA compliance requirements.

## Domain Overview

FHIR (Fast Healthcare Interoperability Resources) is the HL7 standard for exchanging healthcare
information electronically. It defines a set of resources, RESTful APIs, and data formats for
representing clinical and administrative healthcare data. This domain covers building FHIR-compliant
systems that participate in the healthcare interoperability ecosystem, including EHR integration,
clinical data exchange, and patient-facing applications.

## System Role

- **Receives:** FHIR resource requests (CRUD), search queries, operation invocations, HL7v2/CDA messages for conversion
- **Processes:** Resource validation, search parameter resolution, terminology lookups, bundle transactions, authorization scopes
- **Returns:** FHIR-compliant JSON/XML resources, OperationOutcome for errors, Bundle for search results
- **Persists:** FHIR resources with full version history, audit events (AuditEvent resource), provenance records

## FHIR Resource Types (MANDATORY)

### Core Clinical Resources

| Resource | Description | Key Elements | Search Parameters |
|----------|-------------|--------------|-------------------|
| Patient | Demographics and administrative info | identifier, name, birthDate, gender, address | identifier, name, birthdate, gender, family |
| Observation | Measurements, lab results, vitals | code, value[x], status, effectiveDateTime, subject | code, date, patient, category, value-quantity |
| Condition | Diagnoses, problems, health concerns | code, clinicalStatus, verificationStatus, subject | code, clinical-status, patient, onset-date |
| MedicationRequest | Prescription/medication orders | medication[x], subject, dosageInstruction, status | patient, medication, status, authoredon |
| Encounter | Clinical visit or interaction | class, status, period, subject, participant | patient, date, class, status, type |
| Procedure | Clinical interventions performed | code, status, performedDateTime, subject | patient, date, code, status |
| AllergyIntolerance | Allergies and adverse reactions | code, clinicalStatus, patient, type, category | patient, clinical-status, type |
| DiagnosticReport | Lab reports, imaging studies | code, status, result, presentedForm, subject | patient, code, date, category |

### Administrative Resources

| Resource | Description | Key Elements |
|----------|-------------|--------------|
| Practitioner | Healthcare provider | identifier (NPI), name, qualification |
| Organization | Healthcare organization | identifier, name, type, address |
| Location | Physical place of care | name, type, address, position |
| Schedule | Availability slots | actor, planningHorizon, serviceType |
| Appointment | Scheduled encounter | status, participant, start, end |

### Infrastructure Resources

| Resource | Description | Purpose |
|----------|-------------|---------|
| Bundle | Collection of resources | Transaction, batch, search results, document |
| OperationOutcome | Error/warning details | Communicate processing issues |
| CapabilityStatement | Server capabilities | Describe supported resources, operations, search params |
| AuditEvent | Security audit log | Track access to PHI |
| Provenance | Resource origin tracking | Who created/modified what and when |

## RESTful FHIR API (MANDATORY)

### CRUD Operations

| Operation | HTTP Method | URL Pattern | Description |
|-----------|-------------|-------------|-------------|
| Read | GET | `[base]/[type]/[id]` | Read current version of resource |
| VRead | GET | `[base]/[type]/[id]/_history/[vid]` | Read specific version |
| Update | PUT | `[base]/[type]/[id]` | Update existing resource |
| Patch | PATCH | `[base]/[type]/[id]` | Partial update (JSON Patch or FHIR Patch) |
| Delete | DELETE | `[base]/[type]/[id]` | Delete resource |
| Create | POST | `[base]/[type]` | Create new resource |
| Search | GET/POST | `[base]/[type]?params` | Search resources |
| History | GET | `[base]/[type]/[id]/_history` | Version history |
| Capabilities | GET | `[base]/metadata` | Server capability statement |

### Conditional Operations

- **Conditional Create**: `POST [base]/[type]` with `If-None-Exist` header
- **Conditional Update**: `PUT [base]/[type]?[search params]`
- **Conditional Delete**: `DELETE [base]/[type]?[search params]`
- Conditional operations use search parameters to identify the target resource
- If multiple matches: return 412 Precondition Failed

### FHIR Operations (Custom)

| Operation | Scope | Description |
|-----------|-------|-------------|
| `$everything` | Patient, Encounter | Returns all data related to a patient or encounter |
| `$validate` | Resource | Validate a resource against profiles |
| `$expand` | ValueSet | Expand a value set |
| `$lookup` | CodeSystem | Look up a code in a code system |
| `$translate` | ConceptMap | Translate between code systems |
| `$match` | Patient | Probabilistic patient matching |
| `$summary` | Resource | Return summary view of resource |

## Bundle Types (MANDATORY)

| Type | Processing | Atomicity | Use Case |
|------|-----------|-----------|----------|
| transaction | All-or-nothing | Full ACID | Create related resources together |
| batch | Independent entries | None (each entry independent) | Bulk operations |
| searchset | Read-only result | N/A | Search response |
| document | Immutable bundle | N/A | Clinical document (e.g., discharge summary) |
| collection | Grouped resources | N/A | Arbitrary grouping |
| history | Version list | N/A | Resource history response |

### Transaction Bundle Rules

- **BUNDLE-001**: All entries MUST succeed or all MUST rollback (ACID)
- **BUNDLE-002**: Entries are processed in order — references between entries use `fullUrl`
- **BUNDLE-003**: Conditional references resolved before execution
- **BUNDLE-004**: Response bundle contains one entry per request entry with status codes
- **BUNDLE-005**: Maximum bundle size: server-defined (recommend 500 entries max)

## Search Parameters (MANDATORY)

### Search Parameter Types

| Type | Example | Syntax |
|------|---------|--------|
| string | `name=John` | Case-insensitive, starts-with by default |
| token | `code=http://loinc.org\|12345-6` | system\|code |
| date | `birthdate=ge2000-01-01` | Prefixes: eq, ne, gt, lt, ge, le, sa, eb |
| reference | `patient=Patient/123` | Resource reference |
| quantity | `value-quantity=gt5.4\|http://unitsofmeasure.org\|mg` | comparator\|value\|system\|code |
| uri | `url=http://example.com/fhir/ValueSet/123` | Exact match |
| composite | `code-value-quantity=http://loinc.org\|12345$gt5.4` | Combined parameters |

### Chained Searches

```
# Find observations for patients named "Smith"
GET [base]/Observation?patient.name=Smith

# Find observations for patients at a specific organization
GET [base]/Observation?patient.organization.name=General%20Hospital
```

### Include / RevInclude

```
# Include the referenced Patient with each Observation
GET [base]/Observation?_include=Observation:patient

# Include MedicationRequests that reference the Patient
GET [base]/Patient?_revinclude=MedicationRequest:patient

# Iterate includes (recursive)
GET [base]/MedicationRequest?_include:iterate=MedicationRequest:medication
```

### Search Result Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `_count` | Page size | `_count=20` |
| `_offset` | Starting index | `_offset=40` |
| `_sort` | Sort order | `_sort=-date,name` |
| `_total` | Include total count | `_total=accurate` |
| `_summary` | Summary mode | `_summary=true` |
| `_elements` | Include specific elements | `_elements=identifier,name` |

## Terminology Systems (MANDATORY)

### Code Systems

| System | URI | Use Case |
|--------|-----|----------|
| SNOMED CT | `http://snomed.info/sct` | Clinical findings, procedures, body structures |
| LOINC | `http://loinc.org` | Laboratory observations, vital signs, documents |
| ICD-10-CM | `http://hl7.org/fhir/sid/icd-10-cm` | Diagnosis coding (US) |
| ICD-10 | `http://hl7.org/fhir/sid/icd-10` | Diagnosis coding (International) |
| CPT | `http://www.ama-assn.org/go/cpt` | Procedure coding (US) |
| RxNorm | `http://www.nlm.nih.gov/research/umls/rxnorm` | Medication coding (US) |
| NDC | `http://hl7.org/fhir/sid/ndc` | Drug identification (US) |
| UCUM | `http://unitsofmeasure.org` | Units of measure |
| CVX | `http://hl7.org/fhir/sid/cvx` | Vaccine codes |

### Coding Rules

- **TERM-001**: Every coded element MUST include `system` and `code` at minimum
- **TERM-002**: `display` is RECOMMENDED for human readability but MUST NOT be used for logic
- **TERM-003**: Use the most specific code available (prefer leaf codes over parent codes)
- **TERM-004**: Multiple codings allowed — use `coding[]` array for translations across systems
- **TERM-005**: `text` element provides human-readable fallback when no code matches

### Coding Example

```json
{
  "code": {
    "coding": [
      {
        "system": "http://loinc.org",
        "code": "85354-9",
        "display": "Blood pressure panel"
      },
      {
        "system": "http://snomed.info/sct",
        "code": "75367002",
        "display": "Blood pressure"
      }
    ],
    "text": "Blood pressure"
  }
}
```

## SMART on FHIR (MANDATORY)

### OAuth 2.0 Scopes

| Scope Pattern | Description | Example |
|---------------|-------------|---------|
| `patient/[Resource].read` | Read access to patient-specific data | `patient/Observation.read` |
| `patient/[Resource].write` | Write access to patient-specific data | `patient/MedicationRequest.write` |
| `user/[Resource].read` | Read access in user context | `user/Patient.read` |
| `user/[Resource].write` | Write access in user context | `user/Encounter.write` |
| `system/[Resource].read` | Backend service read access | `system/Patient.read` |
| `launch` | EHR launch context | Request launch context |
| `launch/patient` | Standalone patient selection | Patient picker at launch |
| `openid fhirUser` | Identity token with FHIR user | User identity |

### Launch Context

```
EHR Launch Flow:
1. EHR provides launch parameter in authorization URL
2. App exchanges launch code for context (patient ID, encounter ID, etc.)
3. App receives access token scoped to the launch context

Standalone Launch Flow:
1. App requests launch/patient scope
2. Authorization server presents patient picker
3. App receives patient context in token response
```

### Token Response (SMART)

```json
{
  "access_token": "eyJ...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "patient/Observation.read patient/Patient.read launch/patient",
  "patient": "Patient/123",
  "encounter": "Encounter/456",
  "id_token": "eyJ...",
  "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4="
}
```

### SMART Configuration

- Well-known endpoint: `[base]/.well-known/smart-configuration`
- MUST advertise: authorization_endpoint, token_endpoint, capabilities
- Capabilities: `launch-ehr`, `launch-standalone`, `client-public`, `client-confidential-symmetric`, `sso-openid-connect`

## Data Interoperability (MANDATORY)

### HL7v2 to FHIR Conversion

| HL7v2 Segment | FHIR Resource | Key Mappings |
|---------------|---------------|--------------|
| PID | Patient | PID-3 -> identifier, PID-5 -> name, PID-7 -> birthDate |
| OBX | Observation | OBX-3 -> code, OBX-5 -> value[x], OBX-14 -> effectiveDateTime |
| DG1 | Condition | DG1-3 -> code, DG1-5 -> onsetDateTime |
| RXA | Immunization | RXA-5 -> vaccineCode, RXA-3 -> occurrenceDateTime |
| ORC/RXE | MedicationRequest | RXE-2 -> medication, ORC-1 -> intent |
| PV1 | Encounter | PV1-2 -> class, PV1-44 -> period |
| AL1 | AllergyIntolerance | AL1-3 -> code, AL1-2 -> type |

### CDA to FHIR Conversion

- ClinicalDocument -> Bundle (type: document) + Composition resource
- CDA sections -> FHIR Composition.section with embedded resource references
- CDA entries -> Individual FHIR resources referenced from sections
- Use ConceptMap for CDA template OID -> FHIR profile mapping

### Conversion Rules

- **CONV-001**: Always generate a Provenance resource linking to the source HL7v2/CDA message
- **CONV-002**: Preserve original identifiers in `identifier` element with source system
- **CONV-003**: Map terminology codes to preferred FHIR code systems using ConceptMap
- **CONV-004**: Unknown/unmappable elements -> store in `extension` with source system URI
- **CONV-005**: Validate converted resources against target FHIR profiles before persisting

## HIPAA Compliance Integration

> For comprehensive HIPAA rules, reference: `security/compliance/hipaa.md`

### PHI (Protected Health Information) Handling

- **PHI-001**: All PHI access MUST be logged via AuditEvent resource
- **PHI-002**: Minimum necessary standard — only return data required for the stated purpose
- **PHI-003**: Patient consent (FHIR Consent resource) MUST be checked before sharing data
- **PHI-004**: De-identification: remove 18 HIPAA identifiers or apply expert determination method
- **PHI-005**: Breach notification: detect and report unauthorized PHI access within 60 days
- **PHI-006**: Right of access: patients can request all their PHI via `$everything` operation

### Access Control

- Role-based access: Practitioner, Nurse, Admin, Patient, System
- Attribute-based rules: treating relationship, consent status, data sensitivity
- Break-the-glass: emergency override with mandatory justification and audit

## Sensitive Data — PHI Handling

| Data | Classification | Can Log? | Can Persist? | Can Return in API? |
|------|---------------|----------|--------------|-------------------|
| Patient Name | PHI | Audit log only | Yes (encrypted at rest) | Yes (with authorization) |
| Date of Birth | PHI | Audit log only | Yes (encrypted at rest) | Yes (with authorization) |
| SSN | PHI / RESTRICTED | NEVER | Encrypted, separate store | NEVER in FHIR responses |
| Medical Record Number | PHI | Masked (last 4) | Yes | Yes (with authorization) |
| Diagnosis Codes | PHI | Code only (no display) | Yes | Yes (with authorization) |
| Lab Results | PHI | NEVER in detail | Yes (encrypted at rest) | Yes (with authorization) |
| Genetic Data | PHI / SENSITIVE | NEVER | Encrypted, access-controlled | Requires specific consent |
| Mental Health Records | PHI / SENSITIVE | NEVER | Encrypted, access-controlled | Requires specific consent (42 CFR Part 2) |
| Substance Abuse Records | PHI / RESTRICTED | NEVER | Encrypted, access-controlled | Requires specific consent (42 CFR Part 2) |
| Insurance Information | PHI | Masked | Yes | Yes (with authorization) |

## Domain Anti-Patterns

- Storing FHIR resources as opaque JSON blobs without indexing search parameters
- Implementing search without supporting chained parameters and includes
- Using non-standard code systems when SNOMED CT, LOINC, or ICD-10 codes exist
- Returning full resource graphs when `_summary` or `_elements` are requested
- Ignoring `If-Match` headers for concurrent update detection (use `meta.versionId`)
- Implementing `$everything` without pagination (can return millions of records)
- Mixing FHIR R4 and R5 resources in the same bundle without versioning
- Hardcoding terminology codes instead of using ValueSet/CodeSystem resources
- Skipping OperationOutcome in error responses (FHIR servers MUST return it)
- Processing transaction bundles without ACID guarantees
- Returning PHI without checking SMART on FHIR scopes and consent status
- Using sequential numeric IDs instead of UUIDs for resource identifiers

## Glossary

| Term | Definition |
|------|-----------|
| FHIR | Fast Healthcare Interoperability Resources — HL7 standard for health data exchange |
| PHI | Protected Health Information — individually identifiable health data under HIPAA |
| EHR | Electronic Health Record — digital version of a patient's medical chart |
| SMART | Substitutable Medical Applications, Reusable Technologies — OAuth-based launch framework |
| HL7v2 | Health Level Seven Version 2 — legacy pipe-delimited messaging standard |
| CDA | Clinical Document Architecture — XML-based clinical document standard |
| SNOMED CT | Systematized Nomenclature of Medicine Clinical Terms — clinical terminology |
| LOINC | Logical Observation Identifiers Names and Codes — lab and clinical observation codes |
| ICD-10 | International Classification of Diseases, 10th Revision — diagnosis codes |
| UCUM | Unified Code for Units of Measure — standard unit codes |
| NPI | National Provider Identifier — unique 10-digit provider ID (US) |
| CapabilityStatement | FHIR resource describing server's supported functionality |
| OperationOutcome | FHIR resource for communicating errors, warnings, and information |
| Bundle | FHIR container for a collection of resources |
| ValueSet | FHIR resource defining a set of codes from one or more code systems |
| ConceptMap | FHIR resource defining mappings between code systems |
