# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# GDPR (General Data Protection Regulation) — Code & Architecture Requirements

> **Scope:** This document covers GDPR requirements that directly impact application code, API design, and data architecture. Organizational and governance requirements are out of scope unless they have code implications.

## Lawful Basis for Processing (Art. 6)

### Code Implications

Every data processing operation MUST have a documented lawful basis. The application must enforce this at the code level.

| Lawful Basis | Code Requirement |
|-------------|-----------------|
| Consent (Art. 6, 1a) | Granular consent service with per-purpose tracking, version management, withdrawal capability |
| Contract (Art. 6, 1b) | Processing limited to data strictly necessary for contract; reject scope creep |
| Legal Obligation (Art. 6, 1c) | Document the specific legal requirement; implement automated enforcement with expiry |
| Vital Interests (Art. 6, 1d) | Emergency processing logic; require manual authorization; audit all invocations |
| Public Task (Art. 6, 1e) | Official authority task; document legal mandate; restrict to mandated scope |
| Legitimate Interest (Art. 6, 1f) | Document LIA (Legitimate Interest Assessment); implement balancing controls; honor objections |

```
// Lawful basis enforcement pattern
function processPersonalData(data, purpose, basis):
    if basis == "CONSENT":
        consent = consentService.getConsent(data.subjectId, purpose)
        if consent == null OR consent.isWithdrawn() OR consent.isExpired():
            throw ProcessingDeniedException("No valid consent for " + purpose)
        if NOT consentVersionMatches(consent.version, currentConsentVersion):
            throw ProcessingDeniedException("Consent version outdated; re-consent required")

    if basis == "CONTRACT":
        contract = contractService.getContract(data.subjectId)
        if contract == null OR contract.isTerminated():
            throw ProcessingDeniedException("No active contract for processing")

    if basis == "LEGAL_OBLIGATION":
        legalBasis = legalRegistry.getLegalBasis(purpose)
        if legalBasis == null OR legalBasis.hasExpired():
            throw ProcessingDeniedException("No active legal basis for processing")

    if basis == "LEGITIMATE_INTEREST":
        lia = liaService.evaluateLIA(data.subjectId, purpose)
        if NOT lia.balancesFavor(dataSubject):
            throw ProcessingDeniedException("Legitimate interest assessment failed")
        if objectionRegistry.hasObjection(data.subjectId, purpose):
            throw ProcessingDeniedException("Data subject has objected to processing")

    processingLog.record({
        subjectId: data.subjectId,
        purpose: purpose,
        lawfulBasis: basis,
        liaId: basis == "LEGITIMATE_INTEREST" ? lia.id : null,
        timestamp: utcNow()
    })

    return executeProcessing(data, purpose)
```

## Data Subject Rights (Art. 15-22) — API Endpoint Patterns

### Required API Endpoints

The application MUST expose mechanisms (API endpoints or UI) for data subjects to exercise their rights within 30 days of request.

| Right | Article | API Endpoint Pattern | SLA |
|-------|---------|---------------------|-----|
| Access to data (DSAR) | Art. 15 | `GET /privacy/data-subject/{id}/data` | 30 days |
| Rectification (correction) | Art. 16 | `PATCH /privacy/data-subject/{id}/data` | 30 days |
| Erasure (right to be forgotten) | Art. 17 | `POST /privacy/data-subject/{id}/erase` | 30 days |
| Restriction of processing | Art. 18 | `POST /privacy/data-subject/{id}/restrict` | 30 days |
| Data portability | Art. 20 | `GET /privacy/data-subject/{id}/export` | 30 days |
| Right to object | Art. 21 | `POST /privacy/data-subject/{id}/object` | Immediate |
| Automated decisions | Art. 22 | `GET /privacy/data-subject/{id}/automated-decisions` | 30 days |

### Implementation Pattern

```
// Data subject rights service
class DataSubjectRightsService:

    // Art. 15 — Access to data
    function accessPersonalData(subjectId, requesterId):
        verifyIdentity(requesterId, subjectId)
        data = collectAllPersonalData(subjectId)
        response = formatForDataSubject(data)  // Human-readable, portable format
        auditLog.log("DSAR_ACCESS", {
            subjectId, requesterId, timestamp: utcNow(),
            dataCategories: data.getCategories()
        })
        recordComplianceDueDate(subjectId, "DSAR_ACCESS", utcNow() + 30.days)
        return response

    // Art. 16 — Rectification
    function rectifyPersonalData(subjectId, requesterId, corrections):
        verifyIdentity(requesterId, subjectId)
        validateCorrections(corrections)
        updated = applyCorrections(subjectId, corrections)
        auditLog.log("DSAR_RECTIFY", {
            subjectId, requesterId, timestamp: utcNow(),
            fieldsUpdated: corrections.getFields()
        })
        return updated

    // Art. 17 — Erasure (right to be forgotten)
    function erasePersonalData(subjectId, requesterId):
        verifyIdentity(requesterId, subjectId)
        // Check legal retention requirements
        retentionCheck = retentionService.checkLegalObligations(subjectId)
        if retentionCheck.hasObligations:
            return {
                status: "PARTIAL_ERASE",
                erased: retentionCheck.erasable,
                retained: retentionCheck.retained,
                reason: retentionCheck.reason
            }
        // Hard delete all personal data
        erasureService.hardDeleteAllData(subjectId)
        auditLog.log("DSAR_ERASE", {
            subjectId, requesterId, timestamp: utcNow()
        })
        return { status: "COMPLETE_ERASE" }

    // Art. 18 — Restriction of processing
    function restrictProcessing(subjectId, requesterId, reason):
        verifyIdentity(requesterId, subjectId)
        restriction = {
            subjectId: subjectId,
            reason: reason,
            createdAt: utcNow(),
            status: "ACTIVE"
        }
        restrictionRegistry.save(restriction)
        auditLog.log("DSAR_RESTRICT", {subjectId, requesterId, reason})
        return restriction

    // Art. 20 — Data portability
    function exportPersonalData(subjectId, requesterId, format):
        verifyIdentity(requesterId, subjectId)
        data = collectAllPersonalData(subjectId)
        exported = dataExporter.export(data, format)  // JSON, CSV, XML
        auditLog.log("DSAR_EXPORT", {
            subjectId, requesterId, format, timestamp: utcNow(),
            dataSize: exported.getSize()
        })
        return exported

    // Art. 21 — Right to object
    function objectToProcessing(subjectId, requesterId, purpose):
        verifyIdentity(requesterId, subjectId)
        objection = {
            subjectId: subjectId,
            purpose: purpose,
            createdAt: utcNow(),
            status: "ACTIVE"
        }
        objectionRegistry.save(objection)
        processingEngine.stopProcessing(subjectId, purpose)
        auditLog.log("DSAR_OBJECT", {subjectId, purpose})
        return objection

    // Art. 22 — Automated decision-making
    function getAutomatedDecisions(subjectId, requesterId):
        verifyIdentity(requesterId, subjectId)
        decisions = automatedDecisionRegistry.findBySubject(subjectId)
        response = decisions.map(d => {
            return {
                id: d.id,
                decision: d.decision,
                logic: d.getHumanReadableExplanation(),
                madeAt: d.createdAt,
                significantEffect: d.hasSignificantEffect
            }
        })
        auditLog.log("DSAR_AUTOMATED_DECISIONS", {subjectId, requesterId})
        return response
```

## Privacy by Design and Default (Art. 25)

### Principles

- Data minimization: collect and process ONLY data strictly necessary
- Privacy by default: maximum privacy controls enabled without user action
- Pseudonymization: replace identifiers where full identification unnecessary
- Encryption: all data encrypted at rest (AES-256-GCM) and in transit (TLS 1.3)
- Access control: role-based, field-level access per purpose

### Implementation

```
// Data minimization at API layer
function getCustomerForPurpose(customerId, purpose):
    customer = repository.find(customerId)
    if customer == null:
        throw NotFoundException()

    // Select only data required for this purpose
    if purpose == "BILLING":
        return {
            name: customer.name,
            address: customer.billingAddress,
            taxId: customer.taxId
        }
    if purpose == "MARKETING":
        if NOT hasConsent(customerId, "MARKETING"):
            throw ProcessingDeniedException("No consent for marketing")
        return {
            firstName: customer.firstName,
            email: customer.email
        }
    if purpose == "SUPPORT":
        return {
            name: customer.name,
            email: customer.email,
            phone: customer.phone
        }

// Pseudonymization for analytics
function pseudonymizeForAnalytics(data):
    return {
        pseudonymousId: hashWithSalt(data.customerId),
        category: data.category,
        amount: data.amount,
        timestamp: data.timestamp
        // Exclude: name, email, address, phone
    }
```

## Data Protection Impact Assessment (DPIA) (Art. 35)

### Automation and Risk Scoring

```
// DPIA automation framework
class DPIAEngine:

    function evaluateProcessingActivity(activity):
        riskScore = 0

        // Risk factor scoring
        if activity.dataScale == "LARGE":
            riskScore += 3
        if activity.dataCategories.includes("SPECIAL_CATEGORIES"):
            riskScore += 3
        if activity.automatedDecisionMaking:
            riskScore += 3
        if activity.isInternationalTransfer:
            riskScore += 2
        if activity.involvesVulnerablePeople:
            riskScore += 2
        if activity.usesNewTechnology:
            riskScore += 2

        if riskScore >= 6:
            dpia = generateDPIA(activity)
            return {
                required: true,
                dpia: dpia,
                riskLevel: riskScore > 10 ? "HIGH" : "MEDIUM"
            }

        return { required: false, riskLevel: "LOW" }

    function generateDPIA(activity):
        return {
            id: generateUUID(),
            activityName: activity.name,
            description: activity.description,
            dataCategories: activity.dataCategories,
            purposes: activity.purposes,
            lawfulBasis: activity.lawfulBasis,
            risks: assessRisks(activity),
            mitigations: identifyMitigations(activity),
            residualRisk: reassessAfterMitigation(activity),
            supervisoryConsultationRequired: determineSupervisoryConsultation(activity),
            createdAt: utcNow(),
            expiryAt: utcNow() + 3.years
        }
```

## Data Protection Officer (Art. 37-39)

### DPO Notification Service

```
// DPO communication service
class DPONotificationService:

    function notifyDPO(notificationType, details):
        notification = {
            id: generateUUID(),
            type: notificationType,  // BREACH, DPIA, CONSENT_WITHDRAWAL, SAR
            details: details,
            createdAt: utcNow(),
            status: "SENT",
            dpoAcknowledgedAt: null
        }
        dpoNotificationRegistry.save(notification)

        // Send via secure channel
        secureEmailService.sendToDPO(
            subject: "[GDPR] " + notificationType,
            body: formatNotification(notification),
            attachments: details.getDocuments()
        )

        auditLog.log("DPO_NOTIFIED", {
            notificationType, timestamp: utcNow()
        })

        return notification

    // DPO contact configuration
    constant DPO_EMAIL = "dpo@example.com"
    constant DPO_SECURE_PORTAL = "https://dpo-portal.example.com"
```

## Cross-Border Transfers (Art. 44-49)

### Adequacy Decisions, SCCs, BCRs

```
// Transfer legality enforcement
function transferData(data, destinationCountry, destinationEntity):
    // 1. Evaluate transfer legality
    transferAssessment = transferPolicyService.assessTransfer(destinationCountry)

    if NOT transferAssessment.isLegal:
        throw TransferProhibitedException(
            "No legal mechanism for transfer to " + destinationCountry
        )

    // 2. Apply supplementary protections
    if transferAssessment.requiresEncryption:
        data = encryptData(data, transferAssessment.encryptionKeyId)

    if transferAssessment.requiresSCC:
        validateSCCInPlace(destinationEntity)

    // 3. Log transfer with full audit trail
    transferLog.record({
        subjectIds: data.getSubjectIds(),
        destinationCountry: destinationCountry,
        destinationEntity: destinationEntity,
        legalMechanism: transferAssessment.mechanism,
        dataCategories: data.getCategories(),
        timestamp: utcNow()
    })

    return transferService.send(data, destinationEntity)
```

## Breach Notification (Art. 33-34)

### 72-Hour Notification to Authority

```
// Breach detection and notification
class BreachNotificationService:

    function reportBreach(breachDetails):
        breach = {
            id: generateUUID(),
            detectedAt: utcNow(),
            affectedSubjects: breachDetails.getSubjectIds(),
            dataCategories: breachDetails.getCategories(),
            breachType: breachDetails.type,
            cause: breachDetails.cause,
            status: "REPORTED",
            notificationDeadline: utcNow() + 72.hours
        }
        breachRegistry.save(breach)

        // Notify DPO and supervisory authority
        dpoNotificationService.notifyDPO("BREACH", {
            breach: breach,
            technicalMeasures: breachDetails.getTechnicalMeasures(),
            likelyConsequences: assessRiskToDataSubjects(breach),
            mitigationActions: proposeMitigations(breach)
        })

        // If high risk, notify affected data subjects
        if assessRiskToDataSubjects(breach) == "HIGH":
            notifyDataSubjectsOfBreach(breach)

        auditLog.log("BREACH_REPORTED", {
            breachId: breach.id,
            affectedCount: breach.affectedSubjects.size()
        })

        return breach
```

## Data Processing Agreements (Art. 28)

### Processor Verification

```
// Processor verification and tracking
class ProcessorVerificationService:

    function registerProcessor(processorInfo):
        assessment = {
            id: generateUUID(),
            processorName: processorInfo.name,
            dpaInPlace: verifyDPAExists(processorInfo),
            securityMeasures: assessSecurityMeasures(processorInfo),
            certifications: gatherCertifications(processorInfo),
            approvedAt: utcNow(),
            status: "APPROVED"
        }
        processorRegistry.save(assessment)

        // Track sub-processors
        for subProcessor in processorInfo.subProcessors:
            registerSubProcessor(processorInfo.id, subProcessor)

        auditLog.log("PROCESSOR_REGISTERED", {
            processorId: assessment.id,
            processorName: processorInfo.name
        })

        return assessment
```

## Implementation Patterns

### Granular, Versioned Consent Management

```
// Consent service with granular purposes
class ConsentManagementService:

    function recordConsent(subjectId, purposes, consentVersion, channel):
        consentRecord = {
            id: generateUUID(),
            subjectId: subjectId,
            consentVersion: consentVersion,
            grantedAt: utcNow(),
            channel: channel,
            purposes: purposes,  // Granular per purpose
            status: "ACTIVE",
            expiresAt: calculateExpiry(consentVersion)
        }
        consentRepository.save(consentRecord)

        for purpose in purposes:
            consentEventLog.log({
                subjectId: subjectId,
                purpose: purpose,
                action: "CONSENT_GRANTED",
                timestamp: utcNow()
            })

        return consentRecord

    function withdrawConsent(subjectId, purpose):
        consents = consentRepository.findActive(subjectId, purpose)
        for consent in consents:
            consent.purposes.removeIf(p => p.purpose == purpose)
            if consent.purposes.isEmpty():
                consent.status = "WITHDRAWN"
                consent.withdrawnAt = utcNow()
            consentRepository.save(consent)

        processingEngine.stopProcessing(subjectId, purpose)
        consentEventLog.log({
            subjectId: subjectId,
            purpose: purpose,
            action: "CONSENT_WITHDRAWN",
            timestamp: utcNow()
        })
```

### Right-to-Erasure Cascade

```
// Hard-delete erasure with recipient notification
class ErasureService:

    function eraseDataSubject(subjectId):
        // Check legal retention obligations
        retentionCheck = checkRetentionObligations(subjectId)
        if retentionCheck.hasObligations:
            return {
                status: "PARTIAL",
                erased: retentionCheck.erasable,
                retained: retentionCheck.retained,
                reason: retentionCheck.reason
            }

        // Hard delete from all systems
        for system in getAllSystemsWithData(subjectId):
            eraseFromSystem(system, subjectId)

        // Remove from indexes and caches
        searchIndexService.removeSubject(subjectId)
        cacheService.evictAllForSubject(subjectId)

        // Notify all recipients
        recipients = sharingRegistry.getRecipients(subjectId)
        for recipient in recipients:
            recipient.requestDataDeletion(subjectId)

        // Pseudonymize logs
        logPseudonymizer.pseudonymizeLogs(subjectId)

        auditLog.log("ERASURE_COMPLETED", {
            subjectId: hashForAudit(subjectId),
            timestamp: utcNow()
        })

        return { status: "COMPLETE" }
```

### DPIA Template and Automation

```
// Standard DPIA template
template DPIATemplate:
    property activityName: String
    property dataCategories: Set<DataCategory>
    property purposes: Set<Purpose>
    property lawfulBasis: LawfulBasis

    method generateDPIA():
        return {
            description: generateDescription(),
            necessity: assessNecessity(),
            proportionality: assessProportionality(),
            risks: identifyRisks(),
            mitigations: proposeMitigations(),
            residualRisks: reassessAfterMitigations()
        }
```

### Data Inventory Service (Record of Processing Activities)

```
// Art. 30: Record of Processing Activities
class DataInventoryService:

    function maintainROPA():
        return {
            processingActivities: scanForActivities(),
            dataFlows: mapDataFlows(),
            systemsOfRecord: identifySystemsOfRecord(),
            processors: listProcessors(),
            internationalTransfers: listTransfers(),
            retentionPolicies: mapRetentionPolicies()
        }

    function scanForActivities():
        activities = []
        for annotation in findAnnotations(PersonalDataAnnotation.class):
            activity = {
                name: annotation.getActivityName(),
                dataCategories: annotation.getDataCategories(),
                purposes: annotation.getPurposes(),
                lawfulBasis: annotation.getLawfulBasis(),
                recipients: annotation.getRecipients(),
                retention: annotation.getRetention()
            }
            activities.add(activity)
        return activities
```

## Anti-Patterns (FORBIDDEN)

- Process personal data without documented lawful basis — basis enforcement mandatory
- Use pre-ticked consent boxes or bundled consent — granular opt-in required
- Make consent withdrawal harder than consent granting — symmetric effort required
- Implement soft-delete instead of hard-delete for erasure — hard delete mandatory
- Fail to notify recipients of erasure requests — notification to recipients required
- Skip DPIA for high-risk processing — DPIA automation mandatory
- Deploy automated decision-making without human review — human review required for significant decisions
- Transfer data to third countries without adequate safeguards — SCCs or adequacy required
- Exceed 72-hour breach notification deadline — automated notification tracking mandatory
- Process children's data without age verification — verification and parental consent required
- Ignore right-to-object requests; continue processing — objection registry mandatory
- Retain personal data indefinitely — TTL and retention review mandatory
- Log full personal data including in production — masking in logs mandatory
