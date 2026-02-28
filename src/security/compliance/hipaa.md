# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# HIPAA (Health Insurance Portability and Accountability Act) — Code & Architecture Requirements

> **Scope:** This document covers HIPAA requirements that directly impact application code, API design, and data architecture for systems processing Protected Health Information (PHI). Administrative and organizational safeguards are out of scope unless they have code implications.

## Protected Health Information (PHI) — 18 Identifiers

Protected Health Information is any individually identifiable health information. The following 18 identifiers, when associated with health data, constitute PHI:

| # | Identifier | Code Handling |
|---|-----------|---------------|
| 1 | Names | Encrypt at rest; mask in logs and audit trails |
| 2 | Geographic locations (ZIP code ≤ 3 digits) | Encrypt at rest; generalize for analytics |
| 3 | Dates (except year) | Encrypt at rest; generalize to year ±1 range |
| 4 | Phone numbers | Encrypt at rest; mask in all logs |
| 5 | Fax numbers | Encrypt at rest; mask in all logs |
| 6 | Email addresses | Encrypt at rest; mask in logs |
| 7 | Social Security Numbers | Encrypt at rest; NEVER display full; mask in logs |
| 8 | Medical record numbers | Encrypt at rest; access-controlled; tokenize |
| 9 | Health plan beneficiary numbers | Encrypt at rest; access-controlled; tokenize |
| 10 | Account numbers | Encrypt at rest; mask in logs |
| 11 | Certificate/license numbers | Encrypt at rest; mask in logs |
| 12 | Vehicle identifiers and serial numbers | Encrypt at rest; access-controlled |
| 13 | Device identifiers and serial numbers | Encrypt at rest; track in audit log |
| 14 | Web URLs | Encrypt at rest; NEVER log patient-specific URLs |
| 15 | IP addresses (associated with PHI) | Encrypt at rest; do NOT link to patient IDs in logs |
| 16 | Biometric identifiers (fingerprints, retinal scans) | Encrypt at rest; HSM-protected keys |
| 17 | Full-face photographs and images | Encrypt at rest; access-controlled; no metadata |
| 18 | Any other unique identifying number | Encrypt at rest; evaluate case-by-case |

```
// PHI field annotations
@PHI(category = "MEDICAL_RECORD")
class PatientRecord:

    @PHI(identifier = 1, type = "NAME")
    patientName: String

    @PHI(identifier = 3, type = "DATE")
    dateOfBirth: Date

    @PHI(identifier = 4, type = "PHONE")
    phoneNumber: String

    @PHI(identifier = 7, type = "SSN")
    socialSecurityNumber: String

    @PHI(identifier = 8, type = "MEDICAL_RECORD_NUMBER")
    medicalRecordNumber: String

    @NotPHI
    encryptionKeyId: String
```

## Privacy Rule — Minimum Necessary Standard

### Code-Level Enforcement

Every PHI access MUST be evaluated against the minimum necessary standard: only access the minimum amount of PHI needed to accomplish the stated purpose.

| Purpose | Minimum Necessary | Code Enforcement |
|---------|------------------|------------------|
| Treatment | Only PHI required for patient care | Query by patient consent + purpose |
| Payment | Diagnosis, procedures, dates | Query: procedure codes + dates only |
| Healthcare operations | Necessary for management/evaluation | Role-based access control (RBAC) per purpose |
| Research | De-identified data unless IRB approved | Automatic de-identification pipeline |

```
// Minimum necessary enforcement
function getPatientDataForPurpose(patientId, purpose):
    patient = repository.find(patientId)

    if purpose == "TREATMENT":
        return {
            name: patient.name,
            dateOfBirth: patient.dateOfBirth,
            medicalHistory: patient.medicalHistory,
            currentMedications: patient.currentMedications,
            allergies: patient.allergies
        }

    if purpose == "BILLING":
        return {
            dateOfService: patient.dateOfService,
            procedureCodes: patient.procedureCodes,
            diagnosticCodes: patient.diagnosticCodes,
            billingAddress: patient.billingAddress
            // EXCLUDE: name, SSN, detailed medical history
        }

    if purpose == "RESEARCH":
        if NOT hasIRBApproval(patientId, purpose):
            throw ProcessingDeniedException("No IRB approval for research")
        return deidentifyForResearch(patient)

    throw ProcessingDeniedException("Unknown purpose")

// Purpose-based access control
class PHIAccessControl:
    function grantAccess(userId, purpose):
        allowed = allowedPurposesForRole(userId)
        if purpose NOT IN allowed:
            throw AuthorizationException("User not authorized for " + purpose)

        accessLog.record({
            userId: userId,
            purpose: purpose,
            grantedAt: utcNow(),
            expiresAt: utcNow() + 1.hour
        })
```

## Security Rule — Administrative, Physical, Technical Safeguards

### Administrative Safeguards

| Safeguard | Code Requirement |
|-----------|-----------------|
| Workforce authorization | Role-based access control (RBAC) with purpose tracking |
| Workforce security | Automatic logoff after inactivity (15 min); session timeout enforcement |
| Workforce training tracking | Log all access events; quarterly audit of logs |
| Security management process | Centralized logging and monitoring of PHI access |
| Access management | User provisioning/deprovisioning automation; approval workflows |

```
// Workforce access control
class WorkforceAccessControl:

    function grantAccess(userId, role, purpose, duration):
        authorization = {
            userId: userId,
            role: role,
            purpose: purpose,
            grantedAt: utcNow(),
            expiresAt: utcNow() + duration,
            approvedBy: requireApproval(userId, role, purpose),
            status: "ACTIVE"
        }
        authorizationRegistry.save(authorization)
        auditLog.log("ACCESS_GRANTED", authorization)

    function enforceSessionTimeout(userId, lastActivity):
        inactivityDuration = utcNow() - lastActivity
        if inactivityDuration > 15.minutes:
            sessionService.logout(userId)
            auditLog.log("SESSION_TIMEOUT", {userId, inactivityDuration})
            throw SessionExpiredException("Session expired due to inactivity")
```

### Physical Safeguards

| Safeguard | Code Requirement |
|-----------|-----------------|
| Facility access controls | Log all physical access to servers storing PHI |
| Workstation security | Require TLS for all PHI transmission; disable clipboard sharing |
| Workstation use policy | Log and audit workstation access per purpose |
| Device management | Inventory and track all devices accessing PHI; enforce encryption |

### Technical Safeguards

| Safeguard | Implementation | Enforcement |
|-----------|-----------------|------------|
| Access control | RBAC + purpose verification | Every PHI access requires user + purpose authorization |
| Audit controls | Immutable access logs (6 years minimum) | Every PHI read/write logged with user, timestamp, purpose |
| Integrity controls | Hash-based integrity verification | Detect unauthorized PHI modifications |
| Transmission security | TLS 1.3 for all PHI in transit | Reject non-TLS connections |
| Encryption at rest | AES-256-GCM for all PHI | Automatic encryption on write; decryption only on read with authorization |

```
// Audit logging with 6-year retention
class AuditLogService:

    function logPHIAccess(userId, patientId, purpose, action):
        auditEntry = {
            id: generateUUID(),
            userId: userId,
            patientId: patientId,
            purpose: purpose,
            action: action,  // READ, WRITE, DELETE, EXPORT
            timestamp: utcNow(),
            ipAddress: getCurrentIpAddress(),
            sessionId: getCurrentSessionId(),
            status: "SUCCESS"
        }
        auditRepository.save(auditEntry)

        // Immutable audit log (cannot be deleted or modified)
        immutableLog.append(auditEntry)

    function enforceRetention():
        // Audit logs retained for 6 years minimum
        expirationDate = utcNow() - 6.years
        deletedCount = auditRepository.deleteOlderThan(expirationDate)
        auditLog.log("AUDIT_LOG_PURGE", {
            deletedCount: deletedCount,
            purgeDate: utcNow()
        })

// Transmission security
class TransmissionSecurityControl:
    function validatePHITransmission(connection):
        if NOT connection.isTLS13():
            throw TransmissionSecurityException("Only TLS 1.3 allowed for PHI")

        if connection.cipherSuite NOT IN APPROVED_SUITES:
            throw TransmissionSecurityException("Cipher suite not approved")

        connection.enableForwardSecrecy()
```

## Breach Notification Rule

### Breach Detection and Risk Assessment (4-Factor Test)

```
// Breach assessment framework
class BreachAssessmentService:

    function assessBreach(securityEvent):
        // 4-Factor breach test
        factors = {
            accessType: assessAccessType(securityEvent),       // Factor 1: type/amount of PHI
            unauthorized: assessUnauthorizedAccess(securityEvent),  // Factor 2: nature of access
            actualAcquisition: assessActualAcquisition(securityEvent), // Factor 3: evidence of acquisition
            mitigationMeasures: assessMitigationMeasures(securityEvent) // Factor 4: remediation taken
        }

        riskAssessment = {
            lowRisk: factors.accessType.isMinimal AND
                     factors.unauthorized.isLimited AND
                     NOT factors.actualAcquisition.confirmed AND
                     factors.mitigationMeasures.effective,
            mediumRisk: factors.accessType.isModerate OR
                        factors.actualAcquisition.likely,
            highRisk: factors.accessType.isExtensive AND
                      factors.actualAcquisition.confirmed AND
                      factors.mitigationMeasures.ineffective
        }

        return riskAssessment

    function determineNotificationRequired(riskAssessment):
        // Only HIGH or MEDIUM risk requires notification
        return riskAssessment.highRisk OR riskAssessment.mediumRisk
```

### 60-Day Notification Timeline

```
// Breach notification automation
class BreachNotificationService:

    function reportBreach(breachDetails):
        breach = {
            id: generateUUID(),
            detectedAt: utcNow(),
            affectedPatients: breachDetails.getPatientIds(),
            phiCategories: breachDetails.getPHICategories(),
            recordCount: breachDetails.getRecordCount(),
            cause: breachDetails.cause,
            status: "REPORTED",
            notificationDeadline: utcNow() + 60.days
        }
        breachRegistry.save(breach)

        // Risk assessment
        riskAssessment = assessBreach(breachDetails)

        // If high/medium risk, initiate notification
        if riskAssessment.highRisk OR riskAssessment.mediumRisk:
            initiateNotifications(breach, riskAssessment)

        // Notify HHS within 60 days
        recordBreachDueDate(breach.id, utcNow() + 60.days)

        auditLog.log("BREACH_REPORTED", {
            breachId: breach.id,
            affectedCount: breach.affectedPatients.size()
        })

    function initiateNotifications(breach, riskAssessment):
        // Notify affected individuals
        for patientId in breach.affectedPatients:
            notifyPatient(patientId, breach, riskAssessment)

        // Notify media (if 500+ individuals)
        if breach.affectedPatients.size() >= 500:
            notifyMedia(breach, riskAssessment)

        // Notify HHS
        notifyHHS(breach, riskAssessment)

    function recordNotificationSLA():
        // Patients: without unreasonable delay, no later than 60 days
        // Media: no later than 60 days
        // HHS: no later than 60 days
        constant NOTIFICATION_SLA = 60.days
```

## Business Associate Agreements (BAA)

### BAA Verification Service

```
// Business Associate verification
class BAAVerificationService:

    function registerSubcontractor(subcontractorInfo):
        // Verify BAA is in place
        baa = baaRepository.findBySubcontractor(subcontractorInfo.id)
        if baa == null OR NOT baa.isSigned OR baa.isExpired():
            throw BAAMissingException(
                "BAA required for subcontractor: " + subcontractorInfo.name
            )

        subcontractorRecord = {
            id: generateUUID(),
            name: subcontractorInfo.name,
            purpose: subcontractorInfo.purpose,
            phiCategories: subcontractorInfo.phiCategories,
            baaId: baa.id,
            baaSignedAt: baa.signedAt,
            baaExpiresAt: baa.expiresAt,
            approvedAt: utcNow(),
            status: "APPROVED"
        }
        subcontractorRegistry.save(subcontractorRecord)

        auditLog.log("SUBCONTRACTOR_REGISTERED", {
            subcontractor: subcontractorInfo.name,
            baaId: baa.id
        })

    function trackSubcontractorAccess(subcontractorId, phiAccess):
        access = {
            subcontractorId: subcontractorId,
            phiCategories: phiAccess.categories,
            accessedAt: utcNow(),
            purpose: phiAccess.purpose
        }
        accessLog.record(access)

        // Verify subcontractor only accesses authorized PHI
        subcontractor = subcontractorRegistry.find(subcontractorId)
        for phiCategory in phiAccess.categories:
            if phiCategory NOT IN subcontractor.phiCategories:
                auditLog.warn("UNAUTHORIZED_SUBCONTRACTOR_ACCESS", {
                    subcontractor: subcontractor.name,
                    phiCategory: phiCategory
                })
```

## De-Identification Methods

### Safe Harbor Method (Remove 18 Identifiers)

```
// Safe Harbor de-identification
class SafeHarborDeidentifier:

    function deidentify(patientData):
        deidentified = {
            // REMOVED: all 18 identifiers
            // ALLOWED: age (years), dates (year only), geographic areas (state-level)
            ageYears: patientData.ageInYears,
            serviceYear: patientData.serviceDate.getYear(),
            state: patientData.address.getState(),
            // Clinical data (no identifiers)
            diagnosis: patientData.diagnosis,
            procedures: patientData.procedures,
            labResults: patientData.labResults
        }
        return deidentified

// Expert Determination de-identification
class ExpertDeterminationDeidentifier:

    function deidentifyWithExpertReview(patientData, expertReview):
        // Expert determines very small risk of re-identification
        if NOT expertReview.approvesAsDeidentified():
            throw DeidentificationException("Expert determination failed")

        return {
            // Expert-approved de-identification
            // May allow more detail than Safe Harbor, if expert determines low risk
            ageRange: patientData.ageRange,  // e.g., "40-50"
            serviceMonth: patientData.serviceDate.getYear() + "-" + patientData.serviceDate.getMonth(),
            generalLocation: patientData.address.getCity(),
            diagnosis: patientData.diagnosis,
            procedures: patientData.procedures,
            labResults: patientData.labResults
        }
```

## Implementation Patterns

### PHI Annotation System

```
// PHI field detection and management
@PHI(category = "MEDICAL_RECORD")
class PatientRecord:

    @PHI(identifier = 1, type = "NAME", encryption = "REQUIRED")
    patientName: String

    @PHI(identifier = 3, type = "DATE", encryption = "REQUIRED", generalizeForAnalytics = "YEAR")
    dateOfBirth: Date

    @PHI(identifier = 7, type = "SSN", encryption = "REQUIRED", maskInLogs = "FULL")
    socialSecurityNumber: String

    @NotPHI
    encryptionKeyId: String
```

### Access Audit Service

```
// Comprehensive audit service
class PHIAccessAuditService:

    function auditAllAccess(userId, action, phiRecords, purpose):
        for record in phiRecords:
            auditEntry = {
                userId: userId,
                action: action,  // READ, WRITE, DELETE
                recordType: record.type,
                purpose: purpose,
                timestamp: utcNow(),
                phiCategories: getPhiCategories(record),
                sessionId: getSessionId(),
                ipAddress: getIpAddress()
            }
            immutableAuditLog.append(auditEntry)

        // 6-year retention
        auditRepository.enforceRetention(6.years)
```

### Minimum Necessary Enforcement

```
// Field-level minimum necessary control
class MinimumNecessaryEnforcer:

    function enforceForPurpose(purpose):
        allowedFields = minimumNecessaryPolicy.getAllowedFields(purpose)
        return (data) -> {
            filtered = {}
            for field in allowedFields:
                filtered[field] = data[field]
            return filtered
        }
```

### "Break the Glass" Emergency Access

```
// Emergency override mechanism
class EmergencyAccessService:

    function grantEmergencyAccess(userId, patientId, reason):
        if NOT isEmergencySituation(reason):
            throw InvalidEmergencyException("Not a valid emergency")

        emergencyAccess = {
            userId: userId,
            patientId: patientId,
            reason: reason,
            grantedAt: utcNow(),
            expiresAt: utcNow() + 1.hour,  // Temporary access
            requiresJustification: true
        }
        emergencyAccessRegistry.save(emergencyAccess)

        // Immediately audit emergency access
        auditLog.log("EMERGENCY_ACCESS_GRANTED", {
            userId: userId,
            patientId: patientId,
            reason: reason,
            timestamp: utcNow()
        })

        // Require retrospective justification within 24 hours
        scheduler.schedule(utcNow() + 24.hours, () => {
            if NOT emergencyAccess.isJustified():
                auditLog.warn("UNJUSTIFIED_EMERGENCY_ACCESS", {
                    userId: userId,
                    patientId: patientId
                })
        })
```

## Encryption Requirements

### At Rest (AES-256-GCM)

```
// Encryption at rest for PHI
function encryptPHI(data, encryptionKeyId):
    key = keyManagementService.getKey(encryptionKeyId)
    ciphertext = aes256gcm.encrypt(data, key)
    return {
        ciphertext: ciphertext,
        keyId: encryptionKeyId,
        algorithm: "AES-256-GCM"
    }

function decryptPHI(encrypted):
    key = keyManagementService.getKey(encrypted.keyId)
    plaintext = aes256gcm.decrypt(encrypted.ciphertext, key)
    return plaintext
```

### In Transit (TLS 1.3)

```
// Transport security for PHI
function validateTransportSecurity():
    tlsVersion = getConnection().getVersion()
    if tlsVersion < "1.3":
        throw TransportSecurityException("TLS 1.3 required")

    cipherSuite = getConnection().getCipherSuite()
    if cipherSuite NOT IN HIPAA_APPROVED_SUITES:
        throw TransportSecurityException("Cipher not approved")
```

## Anti-Patterns (FORBIDDEN)

- Access PHI without documenting purpose — purpose tracking mandatory
- Store PHI beyond retention period — automatic deletion required
- Access PHI without audit logging — immutable 6-year audit trail mandatory
- Use weak encryption (< AES-256) — AES-256-GCM minimum
- Deploy without Business Associate Agreements — BAA verification required
- Return more PHI than minimum necessary — field-level access control mandatory
- Skip breach risk assessment — 4-factor test for all incidents
- Exceed 60-day breach notification deadline — automated tracking required
- Allow unencrypted PHI transmission — TLS 1.3 only
- Log full PHI including sensitive identifiers — masking in all logs mandatory
- Fail to de-identify research data — Safe Harbor or Expert Determination required
- Transmit PHI to unauthorized subcontractors — BAA verification mandatory
- Bypass emergency access logging — "break the glass" audit required
- Retain access logs less than 6 years — 6-year immutable retention mandatory
