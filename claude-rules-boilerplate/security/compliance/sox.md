# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# SOX (Sarbanes-Oxley) — Code & Architecture Requirements for Financial Systems

> **Scope:** This document covers SOX requirements that directly impact application code and architecture for systems involved in financial reporting. SOX compliance is primarily about internal controls over financial reporting (ICFR). Only code-relevant controls are covered here.

## Change Management Controls

### Section 404 — Internal Controls over Financial Reporting

All changes to systems that impact financial reporting must be:
- Authorized before implementation
- Tested before deployment
- Documented with full audit trail
- Reviewed by someone other than the author

### Code-Level Requirements

```
// Change management enforcement in CI/CD
pipeline:
    stage: code-review
        requirements:
            - Minimum 2 peer reviewers (one from different team)
            - No self-merge allowed
            - All comments resolved
            - Security review for financial logic changes
        gate: ALL requirements met

    stage: approval
        requirements:
            - Change request ticket linked to PR
            - Business owner approval for financial logic
            - Risk assessment completed
            - Rollback plan documented
        gate: ALL approvals obtained

    stage: testing
        requirements:
            - Unit tests pass (100% for financial calculations)
            - Integration tests pass
            - Financial reconciliation tests pass
            - Regression tests pass
        gate: ALL tests pass, zero financial calculation failures

    stage: deployment
        requirements:
            - Deployment approved by change management
            - Deployment window approved
            - Monitoring configured
            - Rollback procedure verified
        gate: Deployment authorization obtained
        audit:
            - Log: who deployed, when, what changed, approval reference
```

### Financial Calculation Integrity

```
// Financial calculations must be deterministic and auditable
class FinancialCalculationService:

    function calculateRevenue(transactions, period):
        // 1. Validate inputs
        validateTransactions(transactions)
        validatePeriod(period)

        // 2. Perform calculation with audit trail
        calculationId = generateUUID()
        auditLog.log("FINANCIAL_CALC_START", {
            calculationId: calculationId,
            type: "REVENUE",
            period: period,
            inputCount: length(transactions),
            inputHash: sha256(serialize(transactions))
        })

        // 3. Calculate using approved formula
        result = BigDecimal.ZERO
        for txn in transactions:
            result = result.add(txn.amount, RoundingMode.HALF_UP, scale = 2)

        // 4. Log result
        auditLog.log("FINANCIAL_CALC_COMPLETE", {
            calculationId: calculationId,
            result: result.toString(),
            resultHash: sha256(result.toString()),
            formula: "SUM(transaction.amount) with HALF_UP rounding, scale 2"
        })

        return result
```

## Segregation of Duties (SoD)

### Principle

No single individual should be able to:
- Authorize a transaction AND record it
- Develop code AND deploy it to production
- Create accounts AND approve payments
- Modify financial data AND approve the report

### Implementation

```
// Segregation of duties enforcement
enum SoxRole:
    DEVELOPER          // Can write code, cannot deploy to production
    RELEASE_MANAGER    // Can deploy code, cannot write financial logic
    FINANCIAL_ANALYST  // Can view financial data, cannot modify
    FINANCIAL_APPROVER // Can approve transactions, cannot initiate
    FINANCIAL_INITIATOR // Can create transactions, cannot approve
    AUDITOR            // Read-only access to all audit data
    SYSTEM_ADMIN       // Infrastructure access, no financial data access

// SoD conflict matrix
sodConflicts = {
    FINANCIAL_INITIATOR: [FINANCIAL_APPROVER],     // Cannot initiate AND approve
    DEVELOPER: [RELEASE_MANAGER],                   // Cannot develop AND deploy
    FINANCIAL_ANALYST: [SYSTEM_ADMIN],              // Cannot view financials AND modify system
}

function enforceSegregationOfDuties(userId, requestedRole):
    currentRoles = roleRepository.getRoles(userId)
    for currentRole in currentRoles:
        if requestedRole IN sodConflicts.get(currentRole, []):
            auditLog.warn("SOD_VIOLATION_PREVENTED", {
                userId: userId,
                currentRole: currentRole,
                requestedRole: requestedRole
            })
            throw ComplianceException(
                "Segregation of duties violation: cannot hold " +
                currentRole + " and " + requestedRole
            )
    roleRepository.grantRole(userId, requestedRole)
    auditLog.log("ROLE_GRANTED", {userId, role: requestedRole})
```

### Deployment SoD

```
// Enforce: developers cannot deploy their own code to production
function authorizeDeployment(deploymentRequest):
    codeAuthors = deploymentRequest.getCodeAuthors()
    deployer = deploymentRequest.deployedBy
    approver = deploymentRequest.approvedBy

    // Deployer must not be a code author
    if deployer IN codeAuthors:
        throw SodViolationException("Code author cannot deploy their own changes")

    // Approver must not be a code author or the deployer
    if approver IN codeAuthors OR approver == deployer:
        throw SodViolationException("Approver must be independent of author and deployer")

    auditLog.log("DEPLOYMENT_AUTHORIZED", {
        deployer: deployer,
        approver: approver,
        authors: codeAuthors,
        changeId: deploymentRequest.changeId
    })
```

## Audit Trail — Immutable Records

### Requirements

- **Immutability:** Financial records and audit logs must be tamper-proof
- **Completeness:** Every create, read, update, delete of financial data must be logged
- **Traceability:** Every change must be traceable to a specific individual
- **Retention:** Audit records retained for minimum 7 years
- **Integrity:** Cryptographic verification of audit log integrity

### Implementation

```
// Immutable audit trail for financial data
class SoxAuditService:

    function logFinancialEvent(event):
        auditRecord = {
            eventId: generateUUID(),
            timestamp: utcNow(),                  // NTP-synchronized
            sequenceNumber: nextSequenceNumber(),  // Monotonic, gap-free

            // Who
            userId: event.userId,
            userRole: event.userRole,
            ipAddress: event.ipAddress,

            // What
            action: event.action,                  // CREATE, UPDATE, DELETE, APPROVE
            entityType: event.entityType,          // "journal_entry", "invoice", "payment"
            entityId: event.entityId,
            previousValue: event.previousValue,    // For updates
            newValue: event.newValue,

            // Why
            changeReason: event.reason,
            changeTicket: event.ticketReference,
            authorization: event.approvalReference,

            // Integrity
            previousRecordHash: getLastRecordHash(),
            recordHash: null  // Calculated below
        }

        // Calculate chain hash for tamper detection
        auditRecord.recordHash = sha256(serialize(auditRecord))

        // Write to append-only storage (WORM)
        immutableStorage.append(auditRecord)

        return auditRecord

    // Verify audit trail integrity
    function verifyIntegrity(startDate, endDate):
        records = immutableStorage.getRange(startDate, endDate)
        previousHash = null
        for record in records:
            // Verify chain integrity
            if previousHash != null AND record.previousRecordHash != previousHash:
                return { valid: false, brokenAt: record.eventId, reason: "Chain broken" }
            // Verify self-integrity
            calculatedHash = sha256(serialize(recordWithoutHash(record)))
            if calculatedHash != record.recordHash:
                return { valid: false, brokenAt: record.eventId, reason: "Record tampered" }
            previousHash = record.recordHash
        return { valid: true, recordsVerified: length(records) }
```

## Data Integrity Validation

### Financial Data Validation Rules

```
// Financial data integrity checks
class FinancialIntegrityService:

    // Double-entry bookkeeping validation
    function validateJournalEntry(entry):
        totalDebits = sum(entry.lines.filter(l => l.type == DEBIT).map(l => l.amount))
        totalCredits = sum(entry.lines.filter(l => l.type == CREDIT).map(l => l.amount))

        if totalDebits != totalCredits:
            throw IntegrityException("Journal entry does not balance: " +
                "debits=" + totalDebits + " credits=" + totalCredits)

        if entry.lines.any(l => l.amount <= 0):
            throw IntegrityException("Line amounts must be positive")

        if entry.lines.any(l => l.amount.scale > 2):
            throw IntegrityException("Amounts must not exceed 2 decimal places")

    // Reconciliation check
    function reconcile(source, target, tolerance):
        sourceTotal = calculateTotal(source)
        targetTotal = calculateTotal(target)
        difference = abs(sourceTotal - targetTotal)

        reconciliationResult = {
            id: generateUUID(),
            timestamp: utcNow(),
            sourceTotal: sourceTotal,
            targetTotal: targetTotal,
            difference: difference,
            withinTolerance: difference <= tolerance,
            status: difference <= tolerance ? "MATCHED" : "EXCEPTION"
        }

        auditLog.log("RECONCILIATION", reconciliationResult)

        if NOT reconciliationResult.withinTolerance:
            alerting.send("RECONCILIATION_EXCEPTION", reconciliationResult)

        return reconciliationResult
```

### Period Close Controls

```
// Period close — prevent modifications to closed periods
function modifyFinancialRecord(record, period):
    periodStatus = periodService.getStatus(period)

    if periodStatus == "CLOSED":
        throw ComplianceException("Cannot modify records in closed period: " + period)

    if periodStatus == "CLOSING":
        // Require additional approval during closing period
        if NOT hasApproval(record.changeRequest, "PERIOD_CLOSE_APPROVER"):
            throw ComplianceException("Changes during closing period require additional approval")

    // Proceed with modification + audit
    auditLog.log("FINANCIAL_RECORD_MODIFIED", {
        recordId: record.id,
        period: period,
        periodStatus: periodStatus,
        modifier: currentUser.id,
        changeReason: record.changeReason
    })
```

## Access Control Reviews

### Periodic Access Reviews

```
// Automated access review process
class AccessReviewService:

    // Quarterly access review (SOX requirement)
    @Scheduled(cron = "0 0 1 1,4,7,10 *")  // First day of each quarter
    function initiateQuarterlyReview():
        financialSystemUsers = userRepository.findBySystemCategory("FINANCIAL")

        for user in financialSystemUsers:
            review = {
                id: generateUUID(),
                userId: user.id,
                currentRoles: user.roles,
                currentPermissions: user.permissions,
                lastActivity: activityLog.getLastActivity(user.id),
                reviewPeriod: currentQuarter(),
                status: "PENDING_REVIEW",
                assignedReviewer: user.manager,
                deadline: utcNow() + 30.days
            }
            reviewRepository.save(review)
            notificationService.notify(user.manager, "ACCESS_REVIEW_REQUIRED", review)

        auditLog.log("ACCESS_REVIEW_INITIATED", {
            quarter: currentQuarter(),
            usersToReview: length(financialSystemUsers)
        })

    // Process review decision
    function completeReview(reviewId, decision, reviewer):
        review = reviewRepository.find(reviewId)

        if reviewer != review.assignedReviewer:
            throw ForbiddenException("Only assigned reviewer can complete this review")

        review.decision = decision  // MAINTAIN, MODIFY, REVOKE
        review.reviewedBy = reviewer
        review.reviewedAt = utcNow()
        review.status = "COMPLETED"

        if decision == "REVOKE":
            accessControl.revokeAll(review.userId)
            auditLog.log("ACCESS_REVOKED", {userId: review.userId, reason: "Quarterly review"})

        if decision == "MODIFY":
            // Apply modified permissions
            accessControl.updatePermissions(review.userId, review.newPermissions)
            auditLog.log("ACCESS_MODIFIED", {userId: review.userId, changes: review.changes})

        reviewRepository.save(review)
```

## Evidence Collection Automation

### Automated SOX Evidence Collection

```
// Automated evidence collection for SOX audit
class SoxEvidenceCollector:

    function collectEvidence(auditPeriod):
        evidence = {
            period: auditPeriod,
            collectedAt: utcNow(),
            collectedBy: "automated-sox-collector",
            artifacts: []
        }

        // 1. Change management evidence
        evidence.artifacts.append({
            control: "CHANGE_MANAGEMENT",
            data: collectChangeManagementEvidence(auditPeriod),
            // All PRs, approvals, deployments with audit trails
        })

        // 2. Access control evidence
        evidence.artifacts.append({
            control: "ACCESS_CONTROL",
            data: collectAccessControlEvidence(auditPeriod),
            // Access reviews, role assignments, SoD compliance
        })

        // 3. Segregation of duties evidence
        evidence.artifacts.append({
            control: "SEGREGATION_OF_DUTIES",
            data: collectSodEvidence(auditPeriod),
            // SoD matrix, violation attempts, exceptions
        })

        // 4. Financial processing integrity
        evidence.artifacts.append({
            control: "PROCESSING_INTEGRITY",
            data: collectIntegrityEvidence(auditPeriod),
            // Reconciliations, validation results, exception handling
        })

        // 5. Audit trail integrity
        evidence.artifacts.append({
            control: "AUDIT_TRAIL",
            data: collectAuditTrailEvidence(auditPeriod),
            // Chain verification, completeness check, retention compliance
        })

        // Store evidence package
        evidenceHash = sha256(serialize(evidence))
        evidence.integrityHash = evidenceHash
        evidenceStorage.store(evidence)

        auditLog.log("SOX_EVIDENCE_COLLECTED", {
            period: auditPeriod,
            artifactCount: length(evidence.artifacts),
            integrityHash: evidenceHash
        })

        return evidence

    function collectChangeManagementEvidence(period):
        return {
            totalChanges: changeLog.countByPeriod(period),
            authorizedChanges: changeLog.countAuthorized(period),
            unauthorizedAttempts: changeLog.countUnauthorized(period),
            deployments: deploymentLog.getByPeriod(period),
            rollbacks: deploymentLog.getRollbacks(period),
            emergencyChanges: changeLog.getEmergencyChanges(period),
            samplePRs: changeLog.getSampleWithApprovals(period, sampleSize = 25)
        }
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
