# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# SOX (Sarbanes-Oxley Act) — Code & Architecture Requirements

> **Scope:** This document covers SOX requirements that directly impact application code, API design, and financial data architecture. Organizational and governance requirements are out of scope unless they have code implications.

## Section 302: Corporate Responsibility for Financial Reports

### Code Implications

Financial data must be protected by validation controls, approval workflows, and reconciliation mechanisms at the code level.

| SOX Section 302 Requirement | Code Requirement |
|----------------------------|-----------------|
| Data integrity controls | Validation pipelines with checksum verification on all financial records |
| Approval workflows | Multi-step approval logic before financial data is committed |
| Change authorization | Audit trail capturing who approved each financial transaction |
| Error detection | Real-time validation of monetary amounts, dates, and calculations |
| Reconciliation automation | Scheduled batch reconciliation with documented discrepancy handling |

```
// Financial data integrity control pattern
function processFinancialRecord(record, approver):
    // 1. Validate data integrity
    validationResult = validateFinancialRecord(record)
    if NOT validationResult.isValid:
        auditLog.record({
            event: "VALIDATION_FAILED",
            recordId: record.id,
            errors: validationResult.errors,
            timestamp: utcNow()
        })
        throw FinancialValidationException(validationResult.errors)

    // 2. Capture checksum for audit trail
    checksum = computeChecksum(record)

    // 3. Submit for approval (Section 302 requirement)
    approvalRequest = createApprovalRequest(record, approver, checksum)
    approvalService.submitForApproval(approvalRequest)

    // 4. Persist with approval context
    persistedRecord = repository.save({
        ...record,
        status: "PENDING_APPROVAL",
        checksum: checksum,
        approvalRequestId: approvalRequest.id,
        submittedAt: utcNow(),
        submittedBy: getCurrentUser()
    })

    auditLog.record({
        event: "FINANCIAL_RECORD_SUBMITTED",
        recordId: persistedRecord.id,
        amount: persistedRecord.amount,
        approver: approver,
        checksum: checksum,
        timestamp: utcNow()
    })

    return persistedRecord
```

## Section 404: Internal Controls over Financial Reporting

### Code Implications

Automated control testing and evidence collection must be embedded in the application architecture.

| SOX Section 404 Requirement | Code Requirement |
|---------------------------|-----------------|
| Control testing automation | Scheduled control verification tests running against financial data |
| Evidence collection | Systematic capture of control execution results with timestamps |
| Segregation of duties enforcement | Role-based access preventing conflicting operations by same user |
| Control effectiveness monitoring | Real-time dashboards showing control pass/fail status |
| Control remediation tracking | Automated workflow for addressing failed controls |

```
// Automated control testing pattern
interface FinancialControl:
    controlId: String
    controlName: String

    function verify(): ControlTestResult

class AmountValidationControl implements FinancialControl:
    controlId: "CTRL-001"
    controlName: "Financial Amount Validation"

    function verify(): ControlTestResult
        records = repository.findAllFinancialRecords()
        failedRecords = []

        for record in records:
            if NOT isValidAmount(record.amount):
                failedRecords.append({
                    recordId: record.id,
                    reason: "Invalid amount: " + record.amount
                })

        result = {
            controlId: controlId,
            controlName: controlName,
            testedAt: utcNow(),
            testCount: length(records),
            failureCount: length(failedRecords),
            status: failedRecords.isEmpty() ? "PASSED" : "FAILED",
            failures: failedRecords
        }

        evidenceCollector.recordControlTest(result)
        return result

// Segregation of duties enforcement
class SoDAuditService:
    function enforceSegregationOfDuties(user, operation):
        userRoles = roleService.getUserRoles(user.id)
        conflictingRoles = getSoDMatrix().getConflictingRoles(operation)

        for role in userRoles:
            if role IN conflictingRoles:
                auditLog.critical("SOD_VIOLATION_ATTEMPTED", {
                    userId: user.id,
                    userRoles: userRoles,
                    attemptedOperation: operation,
                    conflictingRole: role,
                    timestamp: utcNow()
                })
                throw SoDAuditException("User has conflicting roles for this operation")

        return true

// Control effectiveness dashboard
class ControlStatusDashboard:
    function getControlStatus(): ControlStatusSummary
        allControls = controlRegistry.getAllControls()
        statusSummary = {
            totalControls: length(allControls),
            passedControls: 0,
            failedControls: 0,
            lastTestedAt: null,
            controlsByStatus: {},
            failingControls: []
        }

        for control in allControls:
            result = control.verify()

            if result.status == "PASSED":
                statusSummary.passedControls++
            else:
                statusSummary.failedControls++
                statusSummary.failingControls.append({
                    controlId: result.controlId,
                    controlName: result.controlName,
                    failureCount: result.failureCount,
                    testedAt: result.testedAt
                })

            statusSummary.lastTestedAt = result.testedAt

        return statusSummary
```

## Section 409: Real-Time Disclosure

### Code Implications

Material events must trigger automated detection and filing workflows.

| SOX Section 409 Requirement | Code Requirement |
|---------------------------|-----------------|
| Material event detection | Real-time monitoring for events meeting materiality thresholds |
| Automated filing triggers | Workflows that generate disclosure documents when threshold exceeded |
| Timestamp verification | Precise capture of event occurrence time and detection time |
| Evidence preservation | Complete record of detection logic and materiality calculations |

```
// Material event detection pattern
class MaterialEventDetector:
    function detectMaterialEvent(event):
        // 1. Evaluate against materiality thresholds
        isMaterial = evaluateMateriality(event)

        if NOT isMaterial:
            return { detected: false, reason: "Below materiality threshold" }

        // 2. Log material event with full context
        detectionRecord = {
            eventId: generateUUID(),
            eventType: event.type,
            occurrenceTime: event.timestamp,
            detectionTime: utcNow(),
            materialityThreshold: getMaterialityThreshold(event.type),
            eventValue: event.value,
            impactArea: event.impactArea,
            description: event.description
        }

        auditLog.critical("MATERIAL_EVENT_DETECTED", detectionRecord)

        // 3. Trigger automated filing workflow
        filingWorkflow = createFilingWorkflow(detectionRecord)
        filingService.initiateDisclosureFiling(filingWorkflow)

        // 4. Notify senior management
        escalationService.notifyAuditCommittee(detectionRecord)

        return {
            detected: true,
            eventId: detectionRecord.eventId,
            filingInitiated: true,
            filingId: filingWorkflow.id
        }

function evaluateMateriality(event):
    thresholds = {
        "REVENUE_ADJUSTMENT": 1000000,      // $1M threshold
        "LOSS_REVERSAL": 500000,            // $500K threshold
        "ASSET_IMPAIRMENT": 2000000,        // $2M threshold
        "RESTATEMENT": 100000,              // $100K threshold
        "INTERNAL_CONTROL_FAILURE": 250000  // $250K threshold
    }

    threshold = thresholds.get(event.type, 0)
    return event.value >= threshold
```

## Change Management Controls

### Code Implications

Code change audit trails, approval gates, and rollback mechanisms must be enforced at every stage.

| Change Management Requirement | Code Requirement |
|------------------------------|-----------------|
| Code change audit trail | Git commits with approver identity and authorization |
| Approval gates | Automated workflow requiring sign-off before deployment |
| Segregation of duties in deployment | No single person can approve and deploy financial system changes |
| Rollback mechanisms | Automated ability to revert financial system changes with audit trail |
| Change documentation | Linked tracking connecting commits to JIRA/change tickets |

```
// Change management control pattern
class ChangeManagementService:
    function submitChangeForApproval(changeRequest):
        // 1. Validate change doesn't touch restricted areas without dual approval
        riskLevel = assessChangeRisk(changeRequest)

        if riskLevel == "HIGH":
            // Financial system changes require dual approval
            changeRequest.approversRequired = 2
            changeRequest.approvalGates = ["TECHNICAL_REVIEW", "AUDIT_REVIEW", "DEPLOYMENT"]
        else:
            changeRequest.approversRequired = 1
            changeRequest.approvalGates = ["TECHNICAL_REVIEW"]

        // 2. Create audit record
        auditLog.record({
            event: "CHANGE_REQUEST_SUBMITTED",
            changeId: changeRequest.id,
            summary: changeRequest.summary,
            riskLevel: riskLevel,
            affectedSystems: changeRequest.affectedSystems,
            commits: changeRequest.gitCommits,
            submittedBy: getCurrentUser(),
            submittedAt: utcNow()
        })

        // 3. Route through approval workflow
        approvalWorkflow = workflowService.createApprovalWorkflow(changeRequest)
        return approvalWorkflow

    function approveChange(changeId, approver, approverRole):
        changeRequest = repository.findChangeById(changeId)

        // Segregation of duties check
        if approverRole == "DEPLOYER" AND changeRequest.submittedBy == approver:
            throw SoDAuditException("Approver cannot be the change submitter")

        currentApprovals = changeRequest.getApprovals()
        requiredApprovals = changeRequest.approversRequired

        approval = {
            changeId: changeId,
            approvedBy: approver,
            approverRole: approverRole,
            approvedAt: utcNow(),
            approvalComments: approvalComments
        }

        changeRequest.addApproval(approval)

        auditLog.record({
            event: "CHANGE_APPROVED",
            changeId: changeId,
            approver: approver,
            approverRole: approverRole,
            approvalCount: length(currentApprovals) + 1,
            requiredCount: requiredApprovals,
            timestamp: utcNow()
        })

        // If all approvals obtained, trigger deployment
        if length(changeRequest.getApprovals()) >= requiredApprovals:
            deploymentService.scheduleDeployment(changeRequest)

    function rollbackChange(changeId, reason):
        changeRequest = repository.findChangeById(changeId)

        rollback = {
            changeId: changeId,
            rollbackInitiatedBy: getCurrentUser(),
            rollbackReason: reason,
            rollbackTime: utcNow(),
            previousVersion: changeRequest.previousVersion
        }

        // Revert to previous version
        deploymentService.deployVersion(rollback.previousVersion)

        auditLog.critical("CHANGE_ROLLED_BACK", rollback)

        // Notify audit committee
        escalationService.notifyAuditCommittee(rollback)
```

## Segregation of Duties (SoD)

### Code Implications

Conflicting roles must be detected and prevented at runtime.

| SoD Requirement | Code Requirement |
|----------------|-----------------|
| Role-based enforcement | User roles checked against SoD matrix before operation |
| Conflicting role detection | Real-time validation that user lacks conflicting role combinations |
| Approval chain separation | Different people approve and execute financial transactions |
| Access review automation | Periodic automated reports of role assignments vs. SoD policy |

```
// Segregation of duties matrix
class SoDMatrix:
    sodRules = {
        "APPROVE_PAYMENT": {
            conflicts: ["PROCESS_PAYMENT", "RECONCILE_ACCOUNTS"],
            description: "Payment approval and processing must be separate"
        },
        "PROCESS_PAYMENT": {
            conflicts: ["APPROVE_PAYMENT", "AUDIT_PAYMENT"],
            description: "Payment processing and auditing must be separate"
        },
        "RECORD_JOURNAL_ENTRY": {
            conflicts: ["APPROVE_JOURNAL_ENTRY", "RECONCILE_ACCOUNTS"],
            description: "Journal entry recording and approval must be separate"
        },
        "APPROVE_JOURNAL_ENTRY": {
            conflicts: ["RECORD_JOURNAL_ENTRY"],
            description: "Journal entry approval requires different person than recorder"
        },
        "GRANT_FINANCIAL_ACCESS": {
            conflicts: ["PROCESS_FINANCIAL_TRANSACTION"],
            description: "Access control administrator cannot process financial transactions"
        }
    }

    function validateSoD(user, requestedRole):
        currentRoles = roleService.getUserRoles(user.id)
        conflictingRoles = sodRules.get(requestedRole).conflicts

        for role in currentRoles:
            if role IN conflictingRoles:
                return {
                    valid: false,
                    reason: "Role conflict detected",
                    conflictingRoles: [role]
                }

        return { valid: true }

    function accessReviewReport():
        allUsers = userService.getAllUsers()
        violations = []

        for user in allUsers:
            roles = roleService.getUserRoles(user.id)

            for role in roles:
                conflictingRoles = sodRules.get(role).conflicts
                for conflictRole in conflictingRoles:
                    if conflictRole IN roles:
                        violations.append({
                            userId: user.id,
                            userName: user.name,
                            role1: role,
                            role2: conflictRole,
                            detectionTime: utcNow(),
                            riskDescription: sodRules.get(role).description
                        })

        if length(violations) > 0:
            auditLog.critical("SOD_VIOLATIONS_DETECTED", {
                violationCount: length(violations),
                violations: violations,
                reportGeneratedAt: utcNow()
            })

        return violations
```

## Audit Trail Requirements

### Code Implications

All financial data changes must produce immutable, tamper-evident audit logs.

| Audit Trail Requirement | Code Requirement |
|------------------------|-----------------|
| Immutable audit logs | Append-only logging; no updates or deletions |
| 7-year retention | All audit records retained per regulatory requirement |
| Tamper detection | Cryptographic chaining and checksums to detect unauthorized changes |
| Chain of custody | Complete record of who accessed/modified each record |
| Timestamp precision | UTC timestamps with nanosecond precision for ordering |

```
// Immutable audit trail pattern
class AuditTrailService:
    function logFinancialEvent(event):
        // 1. Create audit record with full context
        auditRecord = {
            id: generateUUID(),
            eventType: event.type,
            eventData: event.data,
            timestamp: utcNow(),
            userId: getCurrentUser().id,
            userRole: getCurrentUser().role,
            ipAddress: getCurrentRequest().ipAddress,
            sessionId: getCurrentSession().id,

            // Previous record hash (chain of custody)
            previousRecordHash: getLastAuditRecordHash(),

            // Checksum of this record
            recordHash: null  // Computed below
        }

        // 2. Compute hash chain
        auditRecord.recordHash = computeSha256Hash(auditRecord)

        // 3. Persist to immutable store (append-only database)
        repository.appendAuditRecord(auditRecord)

        // 4. Replicate to external audit store (e.g., AWS S3, Azure Blob)
        externalAuditStore.append(auditRecord)

        return auditRecord

    function verifyAuditTrailIntegrity():
        records = repository.getAllAuditRecords()

        previousHash = null
        integrityViolations = []

        for record in records:
            // 1. Verify record hasn't been modified
            computedHash = computeSha256Hash(record)
            if computedHash != record.recordHash:
                integrityViolations.append({
                    recordId: record.id,
                    violation: "RECORD_HASH_MISMATCH",
                    expectedHash: computedHash,
                    storedHash: record.recordHash,
                    detectionTime: utcNow()
                })

            // 2. Verify chain continuity
            if previousHash != null AND previousHash != record.previousRecordHash:
                integrityViolations.append({
                    recordId: record.id,
                    violation: "CHAIN_BROKEN",
                    expectedPreviousHash: previousHash,
                    storedPreviousHash: record.previousRecordHash,
                    detectionTime: utcNow()
                })

            previousHash = record.recordHash

        if length(integrityViolations) > 0:
            alerting.sendCritical("AUDIT_TRAIL_INTEGRITY_VIOLATION", integrityViolations)

        return {
            recordsVerified: length(records),
            violations: integrityViolations,
            integralityStatus: integrityViolations.isEmpty() ? "VALID" : "COMPROMISED"
        }

    function retentionEnforcement():
        // 7-year retention requirement (2555 days)
        retentionBoundary = utcNow() - duration("2555 days")

        // NEVER delete audit records; archive to cold storage
        archivedCount = repository.archiveRecordsBefore(retentionBoundary, archiveDestination)

        auditLog.record({
            event: "AUDIT_RECORDS_ARCHIVED",
            archivedCount: archivedCount,
            archiveDestination: archiveDestination,
            retentionBoundary: retentionBoundary,
            timestamp: utcNow()
        })
```

## Data Integrity Controls

### Code Implications

Financial data validation pipelines and reconciliation automation must be embedded in application logic.

| Data Integrity Requirement | Code Requirement |
|---------------------------|-----------------|
| Financial data validation | Multi-layer validation (format, range, business rules) |
| Reconciliation automation | Scheduled batch reconciliation comparing source and GL |
| Checksum verification | Hash-based integrity checks on financial records |
| Exception handling | Documented procedure for discrepancies above threshold |

```
// Financial data validation pipeline
class FinancialDataValidator:
    function validateFinancialRecord(record):
        errors = []

        // 1. Format validation
        if NOT isValidMonetaryAmount(record.amount):
            errors.append({ field: "amount", error: "Invalid monetary format" })

        if NOT isValidDate(record.transactionDate):
            errors.append({ field: "transactionDate", error: "Invalid date format" })

        // 2. Range validation
        if record.amount < 0:
            errors.append({ field: "amount", error: "Amount cannot be negative" })

        if record.amount > getMaxTransactionAmount():
            errors.append({ field: "amount", error: "Amount exceeds limit" })

        // 3. Business rule validation
        if record.accountCode NOT IN getValidAccountCodes():
            errors.append({ field: "accountCode", error: "Invalid GL account" })

        if record.costCenter NOT IN getValidCostCenters():
            errors.append({ field: "costCenter", error: "Invalid cost center" })

        // 4. Cross-field validation
        if record.transactionType == "REVERSAL" AND record.originalTransactionId == null:
            errors.append({ error: "Reversal must reference original transaction" })

        return {
            valid: errors.isEmpty(),
            errors: errors,
            validatedAt: utcNow()
        }

// Automated reconciliation pattern
class ReconciliationEngine:
    @Scheduled(cron = "0 1 * * *")  // Daily at 1 AM
    function performDailyReconciliation():
        reconciliationRun = {
            runId: generateUUID(),
            startedAt: utcNow(),
            sourceRecords: 0,
            glRecords: 0,
            matchedRecords: 0,
            discrepancies: []
        }

        // 1. Extract from source system
        sourceData = sourceSystemExtractor.getTransactions(previousRunTimestamp)
        reconciliationRun.sourceRecords = length(sourceData)

        // 2. Extract from General Ledger
        glData = glRepository.getTransactions(previousRunTimestamp)
        reconciliationRun.glRecords = length(glData)

        // 3. Match and reconcile
        for sourceRecord in sourceData:
            glRecord = findMatchingGLRecord(sourceRecord, glData)

            if glRecord == null:
                reconciliationRun.discrepancies.append({
                    type: "MISSING_IN_GL",
                    sourceRecord: sourceRecord,
                    detectedAt: utcNow()
                })
            else if sourceRecord.amount != glRecord.amount:
                reconciliationRun.discrepancies.append({
                    type: "AMOUNT_MISMATCH",
                    sourceRecord: sourceRecord,
                    glRecord: glRecord,
                    detectedAt: utcNow()
                })
            else:
                reconciliationRun.matchedRecords++

        // 4. Check for GL records without source (orphans)
        for glRecord in glData:
            if NOT findMatchingSourceRecord(glRecord, sourceData):
                reconciliationRun.discrepancies.append({
                    type: "ORPHAN_GL_RECORD",
                    glRecord: glRecord,
                    detectedAt: utcNow()
                })

        // 5. Evaluate discrepancy threshold
        totalDiscrepancy = sum(d.sourceRecord.amount for d in reconciliationRun.discrepancies)

        if totalDiscrepancy > getReconciliationThreshold():
            reconciliationRun.status = "FAILED_THRESHOLD_EXCEEDED"
            escalationService.notifyAuditCommittee(reconciliationRun)
        else:
            reconciliationRun.status = "COMPLETED"

        // 6. Log reconciliation run
        auditLog.record({
            event: "DAILY_RECONCILIATION_COMPLETED",
            reconciliationRun: reconciliationRun,
            timestamp: utcNow()
        })

        return reconciliationRun
```

## Access Controls

### Code Implications

Privileged access management, access review automation, and session recording for financial systems.

| Access Control Requirement | Code Requirement |
|--------------------------|-----------------|
| Privileged access management | System accounts and database access restricted and monitored |
| Access review automation | Periodic automated reports of financial system access |
| Session recording | All financial system transactions logged with user identity |
| MFA enforcement | Multi-factor authentication required for financial system access |

```
// Privileged access management pattern
class PrivilegedAccessService:
    function grantFinancialSystemAccess(user, role, approver, durationDays):
        // 1. Verify approver authorization
        if NOT isApprovalAuthorized(approver, role):
            throw AccessDeniedException("Approver not authorized to grant this role")

        // 2. Verify MFA is enabled
        if NOT isMFAEnabled(user):
            throw AccessDeniedException("MFA must be enabled for financial system access")

        // 3. Record access grant
        accessGrant = {
            userId: user.id,
            userName: user.name,
            role: role,
            approvedBy: approver,
            grantedAt: utcNow(),
            expiresAt: utcNow() + duration(durationDays + " days"),
            durationDays: durationDays,
            justification: justification
        }

        repository.persist(accessGrant)

        auditLog.record({
            event: "PRIVILEGED_ACCESS_GRANTED",
            userId: user.id,
            role: role,
            approvedBy: approver,
            durationDays: durationDays,
            grantedAt: utcNow()
        })

        return accessGrant

    @Scheduled(cron = "0 2 * * *")  // Daily at 2 AM
    function performAccessReview():
        activeAccounts = repository.getAllActiveFinancialSystemAccounts()

        accessReview = {
            reviewDate: utcNow(),
            totalAccounts: length(activeAccounts),
            expiredAccess: [],
            unusedAccess: [],
            anomalousAccess: []
        }

        for account in activeAccounts:
            // 1. Check for expired access
            if account.expiresAt < utcNow():
                accessReview.expiredAccess.append(account)
                revokeAccess(account)

            // 2. Check for unused access
            lastUsed = getLastAccessTimestamp(account)
            if utcNow() - lastUsed > duration("90 days"):
                accessReview.unusedAccess.append({
                    account: account,
                    daysSinceLastUse: (utcNow() - lastUsed).toDays()
                })

            // 3. Check for anomalous usage
            sessionCount = getSessionCountInLastDay(account)
            avgSessionCount = getAverageSessionCountForAccount(account, "30 days")

            if sessionCount > avgSessionCount * 3:
                accessReview.anomalousAccess.append({
                    account: account,
                    sessionCount: sessionCount,
                    averageSessionCount: avgSessionCount
                })

        auditLog.record({
            event: "ACCESS_REVIEW_COMPLETED",
            reviewDate: utcNow(),
            totalAccounts: accessReview.totalAccounts,
            expiredAccessCount: length(accessReview.expiredAccess),
            unusedAccessCount: length(accessReview.unusedAccess),
            anomalousAccessCount: length(accessReview.anomalousAccess)
        })

        return accessReview

    function recordFinancialSystemSession(user, session):
        sessionRecord = {
            sessionId: session.id,
            userId: user.id,
            userName: user.name,
            userRole: user.role,
            loginTime: session.loginTime,
            logoutTime: null,
            ipAddress: session.ipAddress,
            transactions: []  // Track all transactions in this session
        }

        repository.persistSessionRecord(sessionRecord)

        return sessionRecord

    function recordTransactionInSession(sessionId, transaction):
        transactionRecord = {
            transactionId: generateUUID(),
            sessionId: sessionId,
            transactionType: transaction.type,
            amount: transaction.amount,
            accountCode: transaction.accountCode,
            timestamp: utcNow(),
            result: transaction.result
        }

        repository.appendTransactionToSession(sessionId, transactionRecord)

        auditLog.record({
            event: "FINANCIAL_TRANSACTION_EXECUTED",
            sessionId: sessionId,
            transactionId: transactionRecord.id,
            transactionType: transaction.type,
            amount: transaction.amount,
            timestamp: utcNow()
        })
```

## Implementation Patterns

### Immutable Audit Log Service

```
class ImmutableAuditLog:
    function append(auditEvent):
        // Append-only: no updates allowed
        record = {
            id: generateUUID(),
            eventType: auditEvent.type,
            eventData: auditEvent.data,
            timestamp: utcNow(),
            sequenceNumber: getNextSequenceNumber(),
            previousHash: getLastRecordHash(),
            recordHash: null
        }

        record.recordHash = computeSha256(record)

        database.appendOnly(record)
        externalStore.append(record)

        return record

    function verifyIntegrity():
        records = database.getAllRecords()

        for i in 0..length(records)-1:
            record = records[i]

            // Verify hash
            if computeSha256(record) != record.recordHash:
                return { valid: false, error: "Record hash mismatch at record " + i }

            // Verify chain
            if i > 0:
                previousRecord = records[i-1]
                if previousRecord.recordHash != record.previousHash:
                    return { valid: false, error: "Chain broken between record " + (i-1) + " and " + i }

        return { valid: true }
```

### Segregation of Duties Matrix Enforcement

```
class SoDMatrixEngine:
    sodMatrix = {
        "APPROVE": ["EXECUTE"],
        "EXECUTE": ["APPROVE"],
        "RECORD": ["APPROVE", "AUDIT"],
        "APPROVE": ["RECORD"],
        "AUDIT": ["EXECUTE", "RECORD"]
    }

    function validateUserOperationAllowed(userId, operation):
        userRoles = roleService.getRoles(userId)
        conflictingRoles = sodMatrix.get(operation, [])

        for role in userRoles:
            if role IN conflictingRoles:
                auditLog.warn("SOD_VIOLATION_BLOCKED", {
                    userId: userId,
                    userRoles: userRoles,
                    attemptedOperation: operation,
                    conflictingRole: role,
                    timestamp: utcNow()
                })
                return false

        return true
```

### Financial Data Validation Pipeline

```
class FinancialValidationPipeline:
    function validate(record):
        validations = [
            FormatValidation,
            RangeValidation,
            BusinessRuleValidation,
            GLAccountValidation,
            CrossFieldValidation,
            DuplicateDetectionValidation
        ]

        errors = []

        for validator in validations:
            result = validator.validate(record)
            if NOT result.valid:
                errors.addAll(result.errors)

        return {
            valid: errors.isEmpty(),
            errors: errors,
            validatedAt: utcNow(),
            checksum: computeRecordChecksum(record)
        }
```

### Change Approval Workflow

```
class ChangeApprovalWorkflow:
    function createApprovalRequest(change, submitter):
        approvalRequest = {
            id: generateUUID(),
            changeId: change.id,
            submittedBy: submitter,
            submittedAt: utcNow(),
            status: "PENDING",
            approvals: [],
            requiredApprovals: determineApprovalCount(change),
            stages: ["TECHNICAL_REVIEW", "AUDIT_REVIEW"]
        }

        return approvalRequest

    function recordApproval(requestId, approver, approverRole):
        request = repository.find(requestId)

        approval = {
            approver: approver,
            approverRole: approverRole,
            approvedAt: utcNow(),
            comments: comments
        }

        request.approvals.append(approval)

        if length(request.approvals) >= request.requiredApprovals:
            request.status = "APPROVED"
```

### Control Evidence Collector

```
class ControlEvidenceCollector:
    function recordControlTest(control, result):
        evidence = {
            controlId: control.id,
            testDate: utcNow(),
            testResult: result.status,
            recordsTestedCount: result.testCount,
            recordsFailedCount: result.failureCount,
            evidenceLocation: storeEvidenceArtifact(result),
            verifiedBy: getCurrentUser()
        }

        repository.persist(evidence)

        auditLog.record({
            event: "CONTROL_EVIDENCE_RECORDED",
            controlId: control.id,
            result: result.status,
            timestamp: utcNow()
        })
```

## Anti-Patterns (FORBIDDEN)

- Allow self-deployment of code to production (SoD violation)
- Allow the same person to initiate and approve financial transactions
- Store financial audit logs in mutable storage
- Skip change management for "urgent" fixes without documented exception process
- Retain audit records for less than 7 years
- Allow modifications to records in closed financial periods
- Use floating-point arithmetic for financial calculations (use BigDecimal/Decimal)
- Deploy financial system changes without peer review and approval
- Skip quarterly access reviews for financial system users
- Allow generic/shared accounts on financial systems
- Modify audit trail records after creation
- Skip reconciliation between financial subsystems
