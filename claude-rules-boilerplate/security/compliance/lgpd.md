# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# LGPD (Lei Geral de Proteção de Dados) — Code & Architecture Requirements

> **Scope:** This document covers LGPD requirements that directly impact application code, API design, and data architecture. Organizational and governance requirements are out of scope unless they have code implications.

## Lawful Basis for Processing (Art. 7)

### Code Implications

Every data processing operation MUST have a documented lawful basis. The application must enforce this at the code level.

| Lawful Basis | Code Requirement |
|-------------|-----------------|
| Consent (Art. 7, I) | Consent service with record of consent, version, timestamp, and withdrawal mechanism |
| Contract (Art. 7, V) | Processing limited to data necessary for contract fulfillment |
| Legal obligation (Art. 7, II) | Document the specific legal requirement; restrict processing scope |
| Legitimate interest (Art. 7, IX) | Document LIA (Legitimate Interest Assessment); implement proportionality controls |
| Credit protection (Art. 7, X) | Restrict to credit-related data; implement data minimization |

```
// Lawful basis enforcement pattern
function processPersonalData(data, purpose):
    lawfulBasis = consentService.getLawfulBasis(data.subjectId, purpose)

    if lawfulBasis == null:
        throw ProcessingDeniedException("No lawful basis for processing")

    if lawfulBasis.type == "CONSENT" AND lawfulBasis.isWithdrawn():
        throw ProcessingDeniedException("Consent has been withdrawn")

    if lawfulBasis.type == "CONSENT" AND lawfulBasis.isExpired():
        throw ProcessingDeniedException("Consent has expired")

    // Log the lawful basis used
    processingLog.record({
        subjectId: data.subjectId,
        purpose: purpose,
        lawfulBasis: lawfulBasis.type,
        timestamp: utcNow()
    })

    return executeProcessing(data, purpose)
```

## Data Subject Rights (Art. 17-22) — API Implications

### Required API Endpoints

The application MUST expose mechanisms (API endpoints or UI) for data subjects to exercise their rights.

| Right | Article | API Endpoint Pattern | SLA |
|-------|---------|---------------------|-----|
| Confirmation of processing | Art. 18, I | `GET /privacy/data-subject/{id}/processing` | 15 days |
| Access to data | Art. 18, II | `GET /privacy/data-subject/{id}/data` | 15 days |
| Correction | Art. 18, III | `PATCH /privacy/data-subject/{id}/data` | 15 days |
| Anonymization/blocking/deletion | Art. 18, IV | `POST /privacy/data-subject/{id}/anonymize` | 15 days |
| Data portability | Art. 18, V | `GET /privacy/data-subject/{id}/export` | 15 days |
| Consent revocation | Art. 18, IX | `DELETE /privacy/data-subject/{id}/consent/{purposeId}` | Immediate |
| Information about sharing | Art. 18, VII | `GET /privacy/data-subject/{id}/sharing` | 15 days |

### Implementation Pattern

```
// Data subject rights service
class DataSubjectRightsService:

    // Art. 18, II — Access to data
    function getSubjectData(subjectId, requesterId):
        verifyIdentity(requesterId, subjectId)
        data = collectAllPersonalData(subjectId)
        auditLog.log("DSAR_ACCESS", {subjectId, requesterId, timestamp: utcNow()})
        return formatForSubject(data)  // Human-readable format

    // Art. 18, IV — Anonymization
    function anonymizeSubjectData(subjectId, requesterId):
        verifyIdentity(requesterId, subjectId)
        // Check if data can be anonymized (no legal retention requirement)
        retentionCheck = retentionService.checkObligations(subjectId)
        if retentionCheck.hasActiveObligations:
            return {
                status: "PARTIAL",
                anonymized: retentionCheck.anonymizable,
                retained: retentionCheck.retained,
                retentionReason: retentionCheck.reason
            }
        anonymizationService.anonymize(subjectId)
        auditLog.log("DSAR_ANONYMIZE", {subjectId, requesterId, timestamp: utcNow()})
        return { status: "COMPLETED" }

    // Art. 18, V — Data portability
    function exportSubjectData(subjectId, requesterId, format):
        verifyIdentity(requesterId, subjectId)
        data = collectAllPersonalData(subjectId)
        exported = dataExporter.export(data, format)  // JSON, CSV, XML
        auditLog.log("DSAR_EXPORT", {subjectId, requesterId, format, timestamp: utcNow()})
        return exported
```

## Data Minimization (Art. 6)

### Principles

- Collect ONLY data that is strictly necessary for the stated purpose
- Limit data access to personnel/services that need it for their function
- Implement field-level access control for PII
- Delete data when the processing purpose is fulfilled

### Implementation

```
// Data minimization at the API level
// GOOD — Only requested fields returned, based on purpose
function getCustomer(customerId, purpose):
    customer = repository.find(customerId)
    if purpose == "BILLING":
        return { name: customer.name, taxId: customer.taxId, address: customer.billingAddress }
    if purpose == "MARKETING":
        if NOT hasConsent(customerId, "MARKETING"):
            throw ProcessingDeniedException("No consent for marketing")
        return { name: customer.firstName, email: customer.email }
    if purpose == "SUPPORT":
        return { name: customer.name, email: customer.email, phone: customer.phone }

// BAD — Returns all data regardless of purpose
function getCustomer(customerId):
    return repository.find(customerId)  // VIOLATION: no minimization
```

## Processing Records (Art. 37)

### Record of Processing Activities (ROPA)

The application MUST maintain a machine-readable record of all processing activities.

```
// Processing record structure (Art. 37)
processingRecord = {
    activityId: "ACT-001",
    activityName: "Customer Registration",
    controller: "Company Name LTDA",
    operator: "Payment Service",
    purpose: "Contract fulfillment",
    lawfulBasis: "CONTRACT",
    dataCategories: ["name", "email", "taxId", "address"],
    dataSubjectCategories: ["customers"],
    recipients: ["billing-service", "email-service"],
    internationalTransfers: [],
    retentionPeriod: "5 years after contract termination",
    securityMeasures: ["encryption-at-rest", "encryption-in-transit", "access-control"],
    lastUpdated: "2024-01-15T00:00:00Z"
}

// Automated ROPA generation
function generateROPA():
    activities = processingActivityRegistry.getAll()
    return activities.map(activity => {
        return {
            ...activity,
            dataFlows: dataFlowMapper.getFlows(activity.activityId),
            thirdParties: sharingRegistry.getRecipients(activity.activityId)
        }
    })
```

## International Transfer (Art. 33-36)

### Requirements

- International data transfers require adequate protection
- Acceptable mechanisms: adequacy decision (ANPD), standard contractual clauses, binding corporate rules, specific consent
- Log all international transfers with destination country and legal basis

### Code Implementation

```
// International transfer control
function transferData(data, destinationCountry, destinationEntity):
    // 1. Check if transfer is allowed
    transferBasis = transferPolicyService.evaluate(destinationCountry, destinationEntity)
    if NOT transferBasis.isAllowed:
        throw TransferDeniedException("No legal basis for transfer to " + destinationCountry)

    // 2. Apply additional protections if required
    if transferBasis.requiresEncryption:
        data = encryptionService.encrypt(data, transferBasis.encryptionKeyId)

    // 3. Log the transfer
    transferLog.record({
        subjectIds: data.getSubjectIds(),
        destinationCountry: destinationCountry,
        destinationEntity: destinationEntity,
        legalBasis: transferBasis.type,
        dataCategories: data.getCategories(),
        timestamp: utcNow()
    })

    // 4. Execute transfer
    return transferService.send(data, destinationEntity)
```

## Security Measures (Art. 46)

### Technical Measures Required

| Measure | Implementation |
|---------|---------------|
| Encryption at rest | AES-256-GCM for all PII fields |
| Encryption in transit | TLS 1.3 for all communications |
| Access control | RBAC with PII-specific roles |
| Audit logging | All PII access logged with purpose |
| Pseudonymization | Replace identifiers where full PII not needed |
| Anonymization | Irreversible removal of identifying attributes |
| Backup encryption | All backups encrypted with separate keys |
| Incident detection | Real-time monitoring for data breaches |

### Security Incident Response (Art. 48)

- Notify ANPD (Autoridade Nacional de Protecao de Dados) within reasonable time
- Notification must include: nature of data, affected subjects, technical measures, risks, mitigation actions
- Implement automated breach detection and notification workflows

## Implementation Patterns

### PII Annotations

```
// Annotate PII fields for automated discovery and control
@PersonalData(category = "IDENTIFYING", retention = "5_YEARS")
class Customer:

    @PII(type = "NAME")
    name: String

    @PII(type = "EMAIL")
    @SensitiveData
    email: String

    @PII(type = "TAX_ID")
    @SensitiveData
    taxId: String

    @PII(type = "PHONE")
    @SensitiveData
    phone: String

    @NotPersonalData
    accountType: String

    @PII(type = "ADDRESS")
    address: Address
```

### PII Detection

```
// Automated PII detection in unstructured data
function scanForPII(text):
    patterns = {
        "CPF": regex("\\d{3}\\.\\d{3}\\.\\d{3}-\\d{2}"),
        "CNPJ": regex("\\d{2}\\.\\d{3}\\.\\d{3}/\\d{4}-\\d{2}"),
        "EMAIL": regex("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"),
        "PHONE_BR": regex("\\+?55\\s?\\(?\\d{2}\\)?\\s?\\d{4,5}-?\\d{4}"),
        "CEP": regex("\\d{5}-\\d{3}")
    }
    findings = []
    for name, pattern in patterns:
        matches = pattern.findAll(text)
        if matches:
            findings.append({type: name, count: length(matches)})
    return findings
```

### Retention Engine

```
// Automated data retention enforcement
class RetentionEngine:

    function evaluateRetention(record):
        policy = retentionPolicyService.getPolicy(record.dataCategory)
        expirationDate = record.createdAt + policy.retentionPeriod

        if utcNow() > expirationDate:
            if NOT hasActiveRetentionObligation(record):
                return RetentionDecision.DELETE
            return RetentionDecision.RETAIN  // Legal obligation overrides

        return RetentionDecision.RETAIN

    @Scheduled(cron = "0 3 * * *")  // Daily at 3 AM
    function enforceRetention():
        expiredRecords = repository.findByRetentionExpired(utcNow())
        for record in expiredRecords:
            decision = evaluateRetention(record)
            if decision == RetentionDecision.DELETE:
                anonymizationService.anonymize(record)
                auditLog.log("RETENTION_PURGE", {
                    recordId: record.id,
                    dataCategory: record.dataCategory,
                    reason: "retention_period_expired"
                })
```

### Anonymization

```
// Anonymization techniques
class AnonymizationService:

    function anonymize(subjectId):
        records = repository.findAllBySubject(subjectId)
        for record in records:
            // Replace identifying fields with anonymized values
            record.name = "ANONYMIZED"
            record.email = generateHash(record.email)  // One-way hash
            record.phone = null
            record.taxId = null
            record.address = null
            // Preserve non-identifying data for analytics
            record.accountType = record.accountType      // Kept
            record.createdYear = record.createdAt.year    // Generalized
            record.isAnonymized = true
            repository.save(record)

        // Remove from search indexes
        searchIndex.removeSubject(subjectId)

        // Remove from caches
        cacheService.evictSubject(subjectId)
```

### Consent Service

```
// Consent management service
class ConsentService:

    function recordConsent(subjectId, purpose, version, channel):
        consent = {
            id: generateUUID(),
            subjectId: subjectId,
            purpose: purpose,
            version: version,                    // Consent text version
            grantedAt: utcNow(),
            channel: channel,                    // "web", "app", "api"
            status: "ACTIVE",
            expiresAt: utcNow() + consentTTL(purpose)
        }
        consentRepository.save(consent)
        auditLog.log("CONSENT_GRANTED", {subjectId, purpose, version})
        return consent

    function withdrawConsent(subjectId, purpose):
        consent = consentRepository.findActive(subjectId, purpose)
        if consent == null:
            throw NotFoundException("No active consent found")
        consent.status = "WITHDRAWN"
        consent.withdrawnAt = utcNow()
        consentRepository.save(consent)
        auditLog.log("CONSENT_WITHDRAWN", {subjectId, purpose})

        // Trigger data processing cessation
        processingEngine.stopProcessing(subjectId, purpose)
        return consent

    function hasValidConsent(subjectId, purpose):
        consent = consentRepository.findActive(subjectId, purpose)
        return consent != null AND consent.status == "ACTIVE" AND NOT consent.isExpired()
```

## Anti-Patterns (FORBIDDEN)

- Process personal data without verifiable lawful basis
- Collect more data than necessary for the stated purpose
- Return all PII fields regardless of the requesting purpose
- Store personal data beyond the defined retention period without legal justification
- Transfer data internationally without documented legal basis
- Fail to provide mechanisms for data subject rights exercise
- Log full PII in application logs
- Use personal data for purposes other than those consented to
- Implement consent as a non-revocable, one-time action
- Skip audit logging for PII access and processing operations
