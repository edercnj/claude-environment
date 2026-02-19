# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# HIPAA — Code & Architecture Requirements for Protected Health Information (PHI)

> **Scope:** This document covers HIPAA requirements that directly impact application code, API design, and data architecture for systems that process Protected Health Information (PHI). Organizational and administrative safeguards are out of scope unless they have code implications.

## PHI Definition — 18 Identifiers

Protected Health Information (PHI) is any individually identifiable health information. The following 18 identifiers, when associated with health data, constitute PHI:

| # | Identifier | Code Handling |
|---|-----------|---------------|
| 1 | Names | Encrypt at rest, mask in logs |
| 2 | Geographic data (smaller than state) | Encrypt at rest, generalize for analytics |
| 3 | Dates (except year) related to individual | Encrypt at rest, generalize to year for analytics |
| 4 | Phone numbers | Encrypt at rest, mask in logs |
| 5 | Fax numbers | Encrypt at rest, mask in logs |
| 6 | Email addresses | Encrypt at rest, mask in logs |
| 7 | Social Security Numbers | Encrypt at rest, never display full, mask in logs |
| 8 | Medical record numbers | Encrypt at rest, access-controlled |
| 9 | Health plan beneficiary numbers | Encrypt at rest, access-controlled |
| 10 | Account numbers | Encrypt at rest, mask in logs |
| 11 | Certificate/license numbers | Encrypt at rest, mask in logs |
| 12 | Vehicle identifiers and serial numbers | Encrypt at rest |
| 13 | Device identifiers and serial numbers | Encrypt at rest |
| 14 | Web URLs | Encrypt at rest, never log patient-specific URLs |
| 15 | IP addresses | Encrypt at rest, never log in PHI context |
| 16 | Biometric identifiers | Encrypt at rest, HSM-protected keys |
| 17 | Full-face photographs | Encrypt at rest, access-controlled |
| 18 | Any other unique identifying number | Encrypt at rest, evaluate per use case |

```
// PHI field annotations
@PHI(identifierType = "NAME")
class PatientRecord:

    @PHI(id = 1, type = "NAME")
    patientName: String

    @PHI(id = 3, type = "DATE")
    dateOfBirth: Date

    @PHI(id = 4, type = "PHONE")
    phoneNumber: String

    @PHI(id = 6, type = "EMAIL")
    email: String

    @PHI(id = 7, type = "SSN")
    socialSecurityNumber: String

    @PHI(id = 8, type = "MRN")
    medicalRecordNumber: String

    @HealthData  // Health data itself
    diagnosis: String
    medications: List<Medication>
    labResults: List<LabResult>
```

## Minimum Necessary Standard

### Principle

Access to PHI must be limited to the **minimum necessary** to accomplish the intended purpose. This applies to:
- Internal use and access
- Disclosures to other covered entities
- Requests for PHI from other entities

### Implementation

```
// Minimum necessary access based on role and purpose
class PhiAccessService:

    // Define minimum necessary fields per role/purpose
    accessProfiles = {
        "TREATING_PHYSICIAN": ["patientName", "dateOfBirth", "diagnosis", "medications", "labResults", "medicalRecordNumber"],
        "BILLING_STAFF": ["patientName", "accountNumber", "diagnosis.code", "procedureCodes"],
        "RECEPTIONIST": ["patientName", "phoneNumber", "appointmentDate"],
        "RESEARCHER": ["diagnosis", "medications", "labResults"],  // De-identified only
        "AUDITOR": ["accessLogs", "maskedPatientId"]
    }

    function getPatientData(patientId, requestingUser, purpose):
        // 1. Determine minimum necessary fields
        allowedFields = accessProfiles[requestingUser.role]
        if allowedFields == null:
            throw ForbiddenException("Role not authorized for PHI access")

        // 2. Retrieve only allowed fields
        data = repository.findById(patientId, fields = allowedFields)

        // 3. Apply additional restrictions based on purpose
        if purpose == "RESEARCH":
            data = deIdentificationService.deIdentify(data)

        // 4. Audit the access
        auditLog.log("PHI_ACCESS", {
            patientId: hash(patientId),
            requestingUser: requestingUser.id,
            role: requestingUser.role,
            purpose: purpose,
            fieldsAccessed: allowedFields,
            timestamp: utcNow()
        })

        return data
```

## Encryption Requirements

### Technical Safeguards (45 CFR 164.312)

| Requirement | Standard | Implementation |
|-------------|----------|----------------|
| Encryption at rest | AES-256 | All PHI fields encrypted at database level and/or application level |
| Encryption in transit | TLS 1.2+ (TLS 1.3 preferred) | All communications carrying PHI |
| Key management | NIST SP 800-57 | HSM or KMS for encryption keys |
| Integrity controls | SHA-256 HMAC | Verify PHI has not been altered |
| Emergency access | Break-glass procedure | Documented, audited, time-limited |

### Encryption Implementation

```
// PHI encryption at rest — field-level
class PhiEncryptionService:

    function encryptPhi(record):
        for field in record.getPhiFields():
            if field.value != null:
                encrypted = kms.encrypt(
                    plaintext = field.value,
                    keyId = "phi-encryption-key",
                    context = {
                        "patientId": record.patientId,
                        "fieldName": field.name,
                        "purpose": "phi-storage"
                    }
                )
                field.value = encrypted
        return record

    function decryptPhi(record, requestContext):
        // Verify access authorization before decryption
        if NOT isAuthorized(requestContext):
            throw ForbiddenException("Not authorized to decrypt PHI")

        for field in record.getPhiFields():
            if field.isEncrypted:
                decrypted = kms.decrypt(
                    ciphertext = field.value,
                    context = {
                        "patientId": record.patientId,
                        "fieldName": field.name,
                        "purpose": "phi-access"
                    }
                )
                field.value = decrypted

        auditLog.log("PHI_DECRYPTED", {
            recordId: record.id,
            requestContext: requestContext,
            fieldsDecrypted: record.getPhiFieldNames()
        })
        return record
```

## Access Controls

### Role-Based Access Control for PHI

```
// HIPAA access control model
enum HipaaRole:
    TREATING_PROVIDER    // Direct care, full clinical PHI access
    CONSULTING_PROVIDER  // Limited clinical PHI based on consultation scope
    NURSE               // Clinical PHI for assigned patients
    BILLING             // Limited to billing-relevant PHI
    ADMIN               // Administrative data only, no clinical PHI
    RESEARCHER          // De-identified data only
    AUDITOR             // Audit logs and compliance data
    EMERGENCY           // Break-glass access (time-limited, fully audited)
```

### Break-Glass Access

For emergency situations where normal access controls must be overridden:

```
// Break-glass emergency access procedure
function breakGlassAccess(userId, patientId, emergencyReason):
    // 1. Log the break-glass event with maximum detail
    auditLog.critical("BREAK_GLASS_ACCESS", {
        userId: userId,
        patientId: patientId,
        reason: emergencyReason,
        timestamp: utcNow(),
        expiresAt: utcNow() + 4.hours  // Time-limited access
    })

    // 2. Alert security and compliance team immediately
    alerting.sendCritical("BREAK_GLASS_ACTIVATED", {
        user: userId,
        patient: patientId,
        reason: emergencyReason
    })

    // 3. Grant temporary elevated access
    temporaryAccess = accessControl.grantTemporary(
        userId = userId,
        role = HipaaRole.EMERGENCY,
        scope = patientId,
        duration = 4.hours,
        requiresPostReview = true
    )

    // 4. Schedule mandatory post-access review
    complianceReview.schedule({
        type: "BREAK_GLASS_REVIEW",
        accessId: temporaryAccess.id,
        reviewDeadline: utcNow() + 24.hours,
        reviewers: ["privacy-officer", "department-head"]
    })

    return temporaryAccess
```

## Audit Trail — 6-Year Retention

### Requirements

- Retain all HIPAA-related audit records for a minimum of **6 years**
- Audit trail must be **tamper-proof** (append-only, integrity-verified)
- All PHI access, modification, and disclosure must be logged
- Audit logs must NOT contain PHI themselves (use hashed/masked references)

### Audit Events

| Event Category | Events to Log | Retention |
|---------------|---------------|-----------|
| PHI Access | View, download, print, export | 6 years |
| PHI Modification | Create, update, delete | 6 years |
| PHI Disclosure | Share, transmit, release | 6 years |
| Authentication | Login, logout, failed attempts | 6 years |
| Authorization | Access granted, denied, role changes | 6 years |
| System | Configuration changes, emergency access | 6 years |

```
// HIPAA audit log structure
hipaaAuditEvent = {
    eventId: generateUUID(),
    timestamp: utcNow(),                         // NTP-synchronized
    eventType: "PHI_ACCESS",
    classification: "SECURITY",

    // Who
    actor: {
        userId: "provider-123",
        role: "TREATING_PROVIDER",
        department: "cardiology",
        ipAddress: "10.0.1.42",
        workstation: "WS-CARDIO-07"
    },

    // What
    action: "VIEW",
    resource: {
        type: "patient-record",
        id: hash("patient-456"),                 // Hashed, not raw PHI
        fieldsAccessed: ["diagnosis", "medications", "labResults"]
    },

    // Why
    purpose: "treatment",
    orderReference: "ORD-789",                   // If applicable

    // Outcome
    outcome: "SUCCESS",

    // Integrity
    previousEventHash: "sha256:abc123...",       // Chain integrity
    eventHash: "sha256:def456..."                // Self-hash
}
```

## Business Associate Agreement (BAA) Awareness

### Code Implications

- Application must track which third-party services process PHI
- Verify BAA status before transmitting PHI to any third party
- Implement controls to prevent PHI transmission to non-BAA entities

```
// BAA enforcement at integration level
class BaaEnforcementService:

    function sendToThirdParty(data, recipient):
        // 1. Check if data contains PHI
        if NOT containsPhi(data):
            return transmit(data, recipient)

        // 2. Verify BAA status
        baaStatus = baaRegistry.getStatus(recipient)
        if baaStatus != "ACTIVE":
            auditLog.warn("BAA_VIOLATION_PREVENTED", {
                recipient: recipient.id,
                baaStatus: baaStatus,
                dataContainsPhi: true
            })
            throw ComplianceException("Cannot send PHI to entity without active BAA")

        // 3. Transmit with audit
        auditLog.log("PHI_DISCLOSURE", {
            recipient: recipient.id,
            baaId: baaStatus.agreementId,
            dataCategories: data.getPhiCategories(),
            timestamp: utcNow()
        })
        return transmit(data, recipient)
```

## De-Identification Standards

### Safe Harbor Method (45 CFR 164.514(b))

Remove ALL 18 identifiers plus any information that could identify the individual:

```
// Safe Harbor de-identification
function deIdentifySafeHarbor(record):
    deIdentified = {
        // Remove all 18 identifiers
        // Keep only clinical/analytical data
        diagnosis: record.diagnosis,
        medications: record.medications.map(med => {
            return { name: med.name, dosage: med.dosage, duration: med.duration }
        }),
        labResults: record.labResults.map(lab => {
            return { testName: lab.name, value: lab.value, unit: lab.unit, normalRange: lab.normalRange }
        }),

        // Generalize geographic data to state level
        state: record.address.state,

        // Generalize dates to year only
        encounterYear: record.encounterDate.year,

        // Generalize age (cap at 89)
        ageGroup: min(record.age, 89),

        // Generate random study ID
        studyId: generateUUID()
    }

    // Verify no residual identifiers
    if piiScanner.detect(deIdentified).hasFindings:
        throw DeIdentificationException("Residual identifiers detected")

    auditLog.log("DE_IDENTIFICATION", {
        method: "SAFE_HARBOR",
        originalRecordId: hash(record.id),
        studyId: deIdentified.studyId
    })

    return deIdentified
```

### Expert Determination Method (45 CFR 164.514(a))

- Requires a qualified statistical/scientific expert
- Expert determines that risk of identification is "very small"
- Document the expert's methods and results
- Re-evaluate when data is combined with other datasets

## Anti-Patterns (FORBIDDEN)

- Store PHI without encryption at rest
- Transmit PHI without TLS encryption
- Access more PHI than the minimum necessary for the purpose
- Allow PHI access without proper authentication and authorization
- Log PHI in application logs (use hashed/masked references)
- Send PHI to third parties without verified BAA
- Retain audit logs for less than 6 years
- Implement break-glass access without full audit trail and post-review
- Use de-identified data without proper Safe Harbor or Expert Determination validation
- Share PHI via email without encryption
- Store PHI on personal devices or unsecured storage
- Skip audit logging for any PHI access or disclosure event
- Allow generic/shared accounts to access PHI systems
