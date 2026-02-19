# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# GDPR (General Data Protection Regulation) — Code & Architecture Requirements

> **Scope:** This document covers GDPR requirements that directly impact application code, API design, and data architecture. Organizational and governance requirements are out of scope unless they have code implications.

## Data Protection Officer (DPO)

### Code Implications

- Provide a dedicated communication channel for DPO inquiries (API or admin interface)
- DPO must have read-only access to all processing activity records
- Implement DPO dashboard with: processing activity overview, DSAR status, breach notification status, consent metrics

```
// DPO access role
enum GdprRole:
    DPO                 // Read-only access to all privacy data, processing records, DSARs
    PRIVACY_ENGINEER    // Can implement privacy controls, run anonymization
    DATA_STEWARD        // Can manage data classification and retention policies
    SUBJECT             // Data subject exercising their rights

function configureDpoAccess(userId):
    accessControl.grantRole(userId, GdprRole.DPO)
    // DPO gets read access to all processing records, DSARs, and consent data
    // DPO cannot modify or delete data
    accessControl.addPermission(userId, "processing-records", READ_ONLY)
    accessControl.addPermission(userId, "dsar-requests", READ_ONLY)
    accessControl.addPermission(userId, "consent-records", READ_ONLY)
    accessControl.addPermission(userId, "breach-notifications", READ_ONLY)
```

## Data Protection Impact Assessment (DPIA) — Triggers

### When DPIA is Required (Art. 35)

A DPIA must be conducted (and documented in code/architecture decisions) when:

| Trigger | Example | Code Implication |
|---------|---------|-----------------|
| Systematic and extensive profiling | Credit scoring, behavioral analytics | Document in architecture decision records |
| Large-scale processing of special categories | Health data, biometric data | Additional encryption and access controls |
| Systematic monitoring of public areas | Video surveillance, location tracking | Data minimization and retention controls |
| Automated decision-making with legal effects | Loan approval, insurance underwriting | Implement human review mechanism |
| Large-scale processing of children's data | Educational platforms, gaming | Age verification and parental consent |
| Innovative use of new technologies | AI/ML on personal data, facial recognition | Bias testing and explainability |

```
// DPIA-triggered controls for automated decision-making
function makeAutomatedDecision(subjectId, decisionType, inputData):
    // 1. Check if human review is required
    if requiresHumanReview(decisionType):
        decision = mlModel.predict(inputData)
        // Queue for human review instead of auto-applying
        return humanReviewQueue.submit({
            subjectId: subjectId,
            provisionalDecision: decision,
            explanation: mlModel.explain(inputData),
            reviewDeadline: utcNow() + 48.hours
        })

    // 2. Execute automated decision with explainability
    decision = mlModel.predict(inputData)
    auditLog.log("AUTOMATED_DECISION", {
        subjectId: subjectId,
        decisionType: decisionType,
        outcome: decision.result,
        explanation: decision.explanation,
        modelVersion: mlModel.version
    })
    return decision
```

## Lawful Basis for Processing (Art. 6)

| Lawful Basis | GDPR Article | Key Difference from LGPD |
|-------------|-------------|--------------------------|
| Consent | Art. 6(1)(a) | Must be freely given, specific, informed, unambiguous; as easy to withdraw as to give |
| Contract | Art. 6(1)(b) | Performance of a contract or pre-contractual steps |
| Legal obligation | Art. 6(1)(c) | EU/Member State law obligation |
| Vital interests | Art. 6(1)(d) | Life-threatening situations only |
| Public interest | Art. 6(1)(e) | Official authority or public interest task |
| Legitimate interest | Art. 6(1)(f) | Requires balancing test; does NOT apply to public authorities |

### Consent Requirements (Stricter than LGPD)

- Consent must be **granular** (separate consent for each purpose)
- Consent must be **freely given** (no bundling with service access)
- Withdrawal must be **as easy as** granting consent
- Pre-ticked boxes are NOT valid consent
- Consent for children under 16 requires parental authorization (Member States may lower to 13)

```
// GDPR-compliant consent implementation
function requestConsent(subjectId, purposes):
    // Each purpose requires separate, granular consent
    consents = []
    for purpose in purposes:
        consent = {
            id: generateUUID(),
            subjectId: subjectId,
            purpose: purpose.id,
            purposeDescription: purpose.description,
            legalText: purpose.consentText,
            legalTextVersion: purpose.version,
            grantedAt: utcNow(),
            method: "EXPLICIT_OPT_IN",        // Pre-ticked NOT allowed
            withdrawalMethod: "SAME_CHANNEL",  // As easy to withdraw as to give
            expiresAt: utcNow() + purpose.validityPeriod
        }
        consents.append(consent)
    consentRepository.saveAll(consents)
    return consents

// Withdrawal must be equally easy
function withdrawConsent(subjectId, purposeId):
    // Single action withdrawal (same effort as granting)
    consent = consentRepository.findActive(subjectId, purposeId)
    consent.status = "WITHDRAWN"
    consent.withdrawnAt = utcNow()
    consentRepository.save(consent)

    // Immediately cease processing
    processingEngine.stopProcessing(subjectId, purposeId)

    // Notify downstream processors
    dataProcessors.notifyConsentWithdrawal(subjectId, purposeId)

    auditLog.log("CONSENT_WITHDRAWN", {subjectId, purposeId})
```

## Data Subject Rights (Art. 12-22)

### Right to Erasure / Right to Be Forgotten (Art. 17) — Stricter than LGPD

GDPR's right to erasure is more expansive than LGPD's anonymization right:

- Must erase ALL personal data, not just anonymize
- Must notify ALL recipients of the data about the erasure request
- Must make reasonable efforts to inform third parties who processed the data
- Must erase data from backups within a reasonable timeframe

```
// Right to Be Forgotten implementation (Art. 17)
function eraseSubjectData(subjectId, requesterId):
    verifyIdentity(requesterId, subjectId)

    // 1. Check for exceptions (Art. 17(3))
    exceptions = checkErasureExceptions(subjectId)
    if exceptions.hasBlockingExceptions:
        return {
            status: "PARTIALLY_COMPLETED",
            erasedCategories: exceptions.erasableCategories,
            retainedCategories: exceptions.retainedCategories,
            retentionReason: exceptions.reasons  // Legal obligation, public interest, etc.
        }

    // 2. Erase from primary storage
    primaryData = repository.findAllBySubject(subjectId)
    for record in primaryData:
        repository.hardDelete(record)  // Hard delete, not soft delete

    // 3. Erase from search indexes
    searchIndex.removeSubject(subjectId)

    // 4. Erase from caches
    cacheService.evictSubject(subjectId)

    // 5. Notify all data recipients (Art. 17(2))
    recipients = sharingRegistry.getRecipients(subjectId)
    for recipient in recipients:
        recipient.notifyErasure(subjectId)
        auditLog.log("ERASURE_NOTIFICATION_SENT", {subjectId, recipient: recipient.id})

    // 6. Schedule backup erasure
    backupErasureService.schedule(subjectId, {
        deadline: utcNow() + 30.days,  // Reasonable timeframe for backup cleanup
        method: "CRYPTOGRAPHIC_ERASURE"
    })

    // 7. Audit trail (retained for compliance, without PII)
    auditLog.log("DSAR_ERASURE_COMPLETED", {
        subjectId: hash(subjectId),  // Hashed in audit log
        requesterId: requesterId,
        timestamp: utcNow(),
        recipientsNotified: length(recipients)
    })

    return { status: "COMPLETED" }
```

### Right to Data Portability (Art. 20)

- Provide data in structured, commonly used, machine-readable format (JSON, CSV, XML)
- Support direct transfer to another controller where technically feasible

### Right to Object to Profiling (Art. 21-22)

- Implement opt-out from automated profiling
- Provide human review mechanism for automated decisions with legal effects
- Right to explanation of automated decision logic

## Privacy by Design and by Default (Art. 25)

### Privacy by Design Principles

| Principle | Implementation |
|-----------|---------------|
| Proactive not reactive | Security controls built in from design phase |
| Privacy as default | Maximum privacy settings by default |
| Privacy embedded in design | Data protection integrated into architecture |
| Full functionality | Privacy without sacrificing functionality |
| End-to-end security | Data protected throughout its lifecycle |
| Visibility and transparency | Processing activities visible and verifiable |
| Respect for user privacy | User-centric design for privacy controls |

### Code Implementation

```
// Privacy by Default — minimum data exposure
class UserProfileResponse:
    // Only expose what is necessary for the specific context
    @JsonView(Views.Public)
    displayName: String

    @JsonView(Views.Self)           // Only visible to the user themselves
    email: String

    @JsonView(Views.Self)
    phone: String

    @JsonView(Views.Admin)          // Only visible to admins with justification
    registrationIp: String

    // NEVER exposed via API
    @JsonIgnore
    passwordHash: String

    @JsonIgnore
    internalFlags: Map

// Default view is most restrictive
function getProfile(requestedUserId, requestingUser):
    profile = userRepository.find(requestedUserId)
    if requestingUser.id == requestedUserId:
        return serialize(profile, Views.Self)
    if requestingUser.hasRole("ADMIN"):
        auditLog.log("ADMIN_PROFILE_ACCESS", {target: requestedUserId, admin: requestingUser.id})
        return serialize(profile, Views.Admin)
    return serialize(profile, Views.Public)  // Default: most restrictive
```

## 72-Hour Breach Notification (Art. 33-34)

### Requirements

- Notify supervisory authority within **72 hours** of becoming aware of a breach
- Notify affected data subjects "without undue delay" if high risk to rights/freedoms
- Document ALL breaches, even those not requiring notification

### Automated Breach Detection and Notification

```
// Breach detection and notification pipeline
class BreachNotificationService:

    function detectAndReport(securityEvent):
        // 1. Assess if event constitutes a breach
        assessment = breachAssessor.evaluate(securityEvent)
        if NOT assessment.isPersonalDataBreach:
            return  // Not a personal data breach

        // 2. Create breach record (document ALL breaches)
        breach = {
            id: generateUUID(),
            detectedAt: utcNow(),
            notificationDeadline: utcNow() + 72.hours,  // Art. 33 deadline
            nature: assessment.nature,
            categoriesAffected: assessment.dataCategories,
            approximateSubjects: assessment.subjectCount,
            consequences: assessment.likelyConsequences,
            measuresTaken: assessment.mitigationActions,
            status: "DETECTED"
        }
        breachRepository.save(breach)

        // 3. Alert DPO and security team immediately
        alerting.sendCritical("PERSONAL_DATA_BREACH", breach)

        // 4. If high risk, prepare subject notification
        if assessment.riskLevel == "HIGH":
            breach.requiresSubjectNotification = true
            prepareSubjectNotification(breach)

        // 5. Start 72-hour clock
        scheduler.schedule(breach.notificationDeadline, () => {
            if breach.status != "AUTHORITY_NOTIFIED":
                alerting.sendCritical("BREACH_NOTIFICATION_OVERDUE", breach)
            }
        })

    function notifyAuthority(breachId, dpoApproval):
        breach = breachRepository.find(breachId)
        notification = {
            natureOfBreach: breach.nature,
            categoriesAndApproximateNumber: breach.categoriesAffected,
            dpoContact: dpoService.getContact(),
            likelyConsequences: breach.consequences,
            measuresTaken: breach.measuresTaken
        }
        // Submit to supervisory authority
        authorityApi.submit(notification)
        breach.status = "AUTHORITY_NOTIFIED"
        breach.notifiedAt = utcNow()
        breachRepository.save(breach)
```

## International Data Transfers (Art. 44-49)

### Transfer Mechanisms

| Mechanism | Article | Use When |
|-----------|---------|----------|
| Adequacy decision | Art. 45 | Transferring to country with EU adequacy decision |
| Standard Contractual Clauses (SCCs) | Art. 46(2)(c) | Most common mechanism for third-country transfers |
| Binding Corporate Rules (BCRs) | Art. 47 | Intra-group transfers |
| Explicit consent | Art. 49(1)(a) | Occasional transfers with informed consent |
| Contractual necessity | Art. 49(1)(b) | Transfer necessary for contract performance |

### Code Implementation

```
// Transfer impact assessment at code level
function transferData(data, destination):
    assessment = transferImpactService.evaluate(destination.country)

    if NOT assessment.hasAdequateProtection:
        // Apply supplementary measures
        data = applySupplementaryMeasures(data, assessment.requiredMeasures)

    // Log transfer with legal basis
    transferLog.record({
        dataCategories: data.getCategories(),
        destinationCountry: destination.country,
        transferMechanism: assessment.legalBasis,
        supplementaryMeasures: assessment.requiredMeasures,
        timestamp: utcNow()
    })

    return executeTransfer(data, destination)
```

## Comparison with LGPD — Key Differences

| Aspect | GDPR | LGPD |
|--------|------|------|
| Breach notification | 72 hours to authority | "Reasonable time" to ANPD |
| DPO requirement | Mandatory for certain controllers | Mandatory for all controllers |
| Right to erasure | Hard delete + notify recipients | Anonymization acceptable |
| Children's consent age | 16 (Member States may lower to 13) | Not explicitly defined |
| Fines | Up to 4% global annual turnover or 20M EUR | Up to 2% revenue in Brazil, max 50M BRL per violation |
| Privacy by Design | Explicit legal requirement (Art. 25) | Implicit in security measures (Art. 46) |
| DPIA | Mandatory for high-risk processing | Not explicitly required (good practice) |
| Transfer mechanisms | SCCs, BCRs, adequacy decisions | Similar but ANPD-specific |

## Anti-Patterns (FORBIDDEN)

- Process personal data without documented lawful basis
- Use pre-ticked consent boxes or bundled consent
- Make consent withdrawal harder than consent granting
- Implement soft-delete instead of hard-delete for erasure requests
- Fail to notify data recipients of erasure requests
- Skip DPIA for high-risk processing activities
- Deploy automated decision-making without human review mechanism
- Transfer data to third countries without adequate safeguards
- Fail to detect and report breaches within 72 hours
- Expose more personal data than necessary by default (violates Privacy by Design)
- Retain personal data beyond the defined purpose and retention period
- Process children's data without age verification and parental consent mechanisms
