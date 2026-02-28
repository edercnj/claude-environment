# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# PCI Software Security Framework — Secure Software Lifecycle

> **Scope:** This document covers the PCI Software Security Framework Control Objectives that directly impact code, architecture, and development lifecycle decisions. Organizational governance is out of scope.

## Control Objective 1: Software Security Governance and Secure SDLC Integration

### Secure Development Requirements

| Requirement | Implementation | Verification |
|-------------|----------------|--------------|
| Security policy document | Documented policy covering SDLC security practices | Accessible to all developers; reviewed annually |
| Developer training | Annual secure coding training for all developers | Completion tracked; refresher on incidents |
| Vulnerability management process | Defined process for identifying, assigning risk, and remediating vulnerabilities | SLA per severity level (critical: 30 days) |
| Component inventory | Maintain list of all software components and third-party dependencies | Automated scanning; tracked in dependency manifest |
| Risk assessment | Risk-rank new vulnerabilities; evaluate applicability per product | Scoring methodology documented (CVSS 3.1) |

```
// Secure SDLC workflow
sdlcWorkflow:
    phase: requirements
        - Threat modeling session with security team
        - Establish security requirements and acceptance criteria
        - Document risk assumptions and constraints

    phase: design
        - Architecture review for security implications
        - Identify data flows and trust boundaries
        - Design authentication and authorization mechanisms

    phase: development
        - Code review with security checklist
        - Developers follow secure coding guidelines
        - No hardcoded credentials or secrets

    phase: testing
        - SAST scan on all code (zero critical/high findings)
        - SCA scan for dependency vulnerabilities
        - Security testing per OWASP Top 10

    phase: deployment
        - Security sign-off required before production
        - Immutable release artifacts
        - Audit trail of deployment

    phase: monitoring
        - Continuous vulnerability scanning
        - Runtime security monitoring
        - Incident response procedures

// Developer secure coding training checklist
secureCodingTraining:
    ✓ Input validation and data sanitization
    ✓ Authentication and authorization patterns
    ✓ Cryptography (encryption, hashing, key management)
    ✓ Secure error handling
    ✓ Logging without sensitive data
    ✓ OWASP Top 10 vulnerabilities
    ✓ Secure dependency management
    ✓ Code review practices and tooling
```

## Control Objective 2: Software Design with Attack Surface Minimization

### Defense-in-Depth Architecture

| Layer | Control | Implementation |
|-------|---------|----------------|
| Network | Segmentation, firewalls, WAF | Non-CDE services isolated from payment processing |
| Application | Input validation, authentication, authorization | Whitelist-based validation; RBAC at every decision point |
| Data | Encryption, masking, tokenization | Sensitive data encrypted at rest and in transit |
| Audit | Logging, monitoring, alerting | Immutable audit trails; SIEM integration |

```
// Threat modeling (STRIDE methodology)
@ThreatModel
class PaymentProcessingThreatModel:

    function identifyThreats():
        threats = [
            // Spoofing
            Threat.SPOOFING_IDENTITY: "Attacker impersonates legitimate user",
            Threat.SPOOFING_AUTH: "Attacker forges authentication token",

            // Tampering
            Threat.TAMPERING_PAN: "Attacker modifies PAN in transit or at rest",
            Threat.TAMPERING_AMOUNT: "Attacker modifies transaction amount",

            // Repudiation
            Threat.REPUDIATION_DENIAL: "User denies performing transaction",

            // Information Disclosure
            Threat.INFO_DISCLOSURE_PAN: "PAN leaked through logs or error messages",
            Threat.INFO_DISCLOSURE_KEY: "Encryption key exposed",

            // Denial of Service
            Threat.DOS_RATE_LIMIT: "Attacker floods with requests",
            Threat.DOS_RESOURCE: "Attacker exhausts processing capacity",

            // Elevation of Privilege
            Threat.ELEVATION_PRIVILEGE: "Attacker gains admin or payment processor role"
        ]

        mitigations = [
            Threat.SPOOFING_IDENTITY: ["MFA required", "Session timeout 15 minutes"],
            Threat.SPOOFING_AUTH: ["JWT signed with strong key", "Token validation on every request"],
            Threat.TAMPERING_PAN: ["AES-256-GCM encryption", "Tokenization preferred"],
            Threat.TAMPERING_AMOUNT: ["Server-side amount calculation", "Immutable audit log"],
            Threat.REPUDIATION_DENIAL: ["Immutable audit log with timestamps", "Non-repudiation via digital signature"],
            Threat.INFO_DISCLOSURE_PAN: ["Mask in logs and UI", "No PAN in error messages"],
            Threat.INFO_DISCLOSURE_KEY: ["HSM or vault storage", "Separate from encrypted data"],
            Threat.DOS_RATE_LIMIT: ["Rate limiting per IP/user", "Bulkhead isolation"],
            Threat.DOS_RESOURCE: ["Resource quotas", "Graceful degradation"],
            Threat.ELEVATION_PRIVILEGE: ["RBAC enforcement", "Audit every role change"]
        ]

        return threats.map { (threat, mitigation) ->
            documentThreatMitigation(threat, mitigation)
        }
```

### Minimization of Attack Surface

| Principle | Implementation |
|-----------|----------------|
| Least functionality | Enable only required features; disable debug mode by default |
| Minimize dependencies | Reduce third-party dependencies; regularly audit for necessity |
| Principle of least privilege | Services run with minimum required permissions |
| Separate concerns | Payment processing isolated from other business logic |
| Immutable artifacts | Container images signed; code commits verified |

## Control Objective 3: Secure Software Development

### Code Review and Security Validation

| Phase | Requirement | Implementation |
|-------|-------------|----------------|
| Before commit | Pre-commit hooks: secret detection, linting | Reject commits with hardcoded secrets |
| During code review | Peer review with security checklist | Two-person rule for payment service code |
| Before merge | SAST scan; zero critical/high findings | Automated gate in CI/CD |
| Before release | Security team sign-off; vulnerability disclosure | PCI compliance validation |

```
// Code review security checklist
codeReviewChecklist:
    Authentication & Authorization:
        ✓ All endpoints require authentication (unless public)
        ✓ Authorization checks on every protected resource
        ✓ No hardcoded role checks; use centralized RBAC
        ✓ Session tokens validated on every request

    Input Validation:
        ✓ All external input validated at boundary
        ✓ Allowlist-based validation (not denylist)
        ✓ Type, range, and format validation enforced
        ✓ File uploads validated by content (magic bytes)

    Output Encoding:
        ✓ HTML context: entities encoded (&lt;, &gt;, &quot;)
        ✓ JavaScript context: Unicode escaped
        ✓ URL context: percent encoded
        ✓ CSV context: quoted and escaped

    Cryptography:
        ✓ Encryption uses AES-256-GCM (no ECB)
        ✓ Hashing uses argon2id or bcrypt (cost >= 12)
        ✓ Signatures use RSA 4096 or ECDSA P-256
        ✓ Keys stored in HSM or vault (never in code)

    Error Handling:
        ✓ No stack traces in production responses
        ✓ Errors logged server-side with full details
        ✓ Clients receive generic error messages
        ✓ Sensitive data not included in error context

    Logging & Monitoring:
        ✓ No passwords, tokens, or full PAN logged
        ✓ Security events logged (auth, authorization, data access)
        ✓ Logs sent to SIEM for monitoring
        ✓ Audit trail immutable and time-synchronized

    Dependencies:
        ✓ All dependencies explicitly declared
        ✓ Versions pinned (no floating ranges)
        ✓ No deprecated or vulnerable dependencies
        ✓ License compliance verified

    Configuration:
        ✓ No secrets in code or configuration files
        ✓ Credentials sourced from vault/secrets manager
        ✓ Different configuration per environment
        ✓ Debug mode disabled in non-development

// Static Application Security Testing (SAST) in CI/CD
sast:
    tools: [SonarQube, Semgrep, CodeQL, Snyk Code]
    trigger: every pull request
    gate:
        critical: zero (block merge)
        high: zero (block merge)
        medium: review (recommend fix)
        low: inform (track for next sprint)
    coverage:
        - Injection flaws (SQL, command, LDAP, XPath)
        - XSS (stored, reflected, DOM-based)
        - CSRF and broken authentication
        - Sensitive data exposure
        - Using known vulnerable components
        - Broken access control
        - Security misconfiguration
```

### Secure Dependency Management

| Requirement | Implementation |
|-------------|----------------|
| Inventory | Maintain list of all direct and transitive dependencies |
| Scanning | Automated scanning for known vulnerabilities (SCA) |
| Remediation | Patch critical within 30 days; high within 60 days |
| License compliance | Verify all dependencies have acceptable licenses |
| Private registry | Use private package repository (Nexus, Artifactory) to prevent supply-chain attacks |

```
// Dependency vulnerability scanning
@Component
class DependencySecurityManager:

    @Scheduled(cron = "0 0 * * *")  // Daily
    function scanDependencies():
        // 1. Get current dependency list
        dependencies = dependencyAnalyzer.analyze()

        // 2. Check for known vulnerabilities
        vulnerabilities = nvdClient.checkVulnerabilities(dependencies)

        // 3. Evaluate severity and SLA
        for vulnerability in vulnerabilities:
            sla = calculateSLA(vulnerability.severity)
            patchDeadline = vulnerability.discoveredAt + sla

            if now() > patchDeadline:
                alerting.critical("VULNERABILITY_SLA_EXCEEDED", {
                    dependency: vulnerability.componentName,
                    cve: vulnerability.cve,
                    deadline: patchDeadline
                })

            // 4. Log for tracking
            auditLog.log("VULNERABILITY_FOUND", {
                dependency: vulnerability.componentName,
                cve: vulnerability.cve,
                severity: vulnerability.severity,
                discoveredAt: vulnerability.discoveredAt
            })
```

## Control Objective 4: Vulnerability Management

### Discovery and Remediation

| Activity | Frequency | Responsibility | SLA |
|----------|-----------|-----------------|-----|
| Dependency scanning | Continuous (CI/CD) | Build pipeline | N/A (blocks merge) |
| SAST scanning | Every commit | Developer + SAST tool | Critical: block merge |
| DAST scanning | Before release | QA + security team | High: before release |
| Penetration testing | Annual + after major changes | Authorized pentesters | Within 90 days of report |
| Vulnerability assessment | Quarterly | Security team | Findings tracked to resolution |

```
// Vulnerability tracking and remediation workflow
@Component
class VulnerabilityManagementService:

    class Vulnerability:
        id: UUID
        source: String              // SAST, DAST, pentest, CVE
        severity: Severity          // CRITICAL, HIGH, MEDIUM, LOW
        discoveredAt: Instant
        affectedComponent: String
        description: String
        remediationSteps: String
        deadline: Instant           // Based on severity SLA
        status: Status              // OPEN, IN_PROGRESS, RESOLVED, ACCEPTED
        owner: String               // Developer responsible for fix

    function trackVulnerability(vulnerability: Vulnerability):
        // Calculate deadline based on severity
        sla = switch (vulnerability.severity):
            CRITICAL: 30.days
            HIGH: 60.days
            MEDIUM: 90.days
            LOW: 180.days

        vulnerability.deadline = vulnerability.discoveredAt + sla

        // Store for tracking
        repository.save(vulnerability)

        // Alert responsible party
        notificationService.notify(vulnerability.owner, {
            message: "Vulnerability assigned",
            vulnerability: vulnerability,
            deadline: vulnerability.deadline
        })

        // Log the discovery
        auditLog.log("VULNERABILITY_TRACKED", {
            vulnerabilityId: vulnerability.id,
            severity: vulnerability.severity,
            deadline: vulnerability.deadline
        })

    function enforceDeadlines():
        // Check for exceeded deadlines
        overdue = repository.findOverdueVulnerabilities()
        for vulnerability in overdue:
            if vulnerability.status != RESOLVED:
                alerting.critical("VULNERABILITY_DEADLINE_EXCEEDED", {
                    vulnerabilityId: vulnerability.id,
                    deadline: vulnerability.deadline,
                    daysOverdue: daysBetween(vulnerability.deadline, now())
                })
```

## Control Objective 5: Secure Authentication and Session Management

### Authentication Requirements

| Requirement | Implementation | Code Pattern |
|-------------|----------------|-------------|
| MFA mandatory | TOTP, SMS, hardware keys (TOTP preferred) | Required for CDE and payment processing |
| Passwords | 12+ chars, mixed case, numbers, symbols, 90-day rotation | Enforced at authentication service |
| Account lockout | Lock after 6 failed attempts; 30-minute minimum lockout | Rate limiter with exponential backoff |
| Session timeout | 15 minutes inactivity for payment applications | Server-side session invalidation |
| Secure cookies | HttpOnly, Secure, SameSite=Strict | Set by framework; verified in security tests |

```
// Comprehensive authentication with hardened security
@Service
class AuthenticationService:

    function authenticate(credentials: AuthRequest):
        try:
            // 1. Rate limit check (brute force protection)
            if rateLimiter.isLocked(credentials.username):
                auditLog.warn("AUTH_ATTEMPT_LOCKED_ACCOUNT", {
                    username: credentials.username,
                    sourceIp: request.remoteIp,
                    timestamp: utcNow()
                })
                throw AccountLockedException("Account locked for 30 minutes")

            // 2. Find user
            user = userRepository.findByUsername(credentials.username)
            if user == null:
                rateLimiter.recordFailure(credentials.username)
                auditLog.warn("AUTH_FAILED_USER_NOT_FOUND", {
                    username: credentials.username,
                    sourceIp: request.remoteIp
                })
                throw AuthenticationException("Invalid credentials")

            // 3. Verify password with strong hashing
            if NOT passwordEncoder.matches(credentials.password, user.passwordHash):
                rateLimiter.recordFailure(credentials.username)
                auditLog.warn("AUTH_FAILED_INVALID_PASSWORD", {
                    userId: user.id,
                    sourceIp: request.remoteIp,
                    attemptCount: rateLimiter.getFailureCount(credentials.username)
                })
                throw AuthenticationException("Invalid credentials")

            // 4. Verify MFA (mandatory for CDE access)
            if user.hasRole("PAYMENT_PROCESSOR") OR user.hasRole("CDE_ADMIN"):
                if NOT mfaService.verify(user, credentials.mfaCode, credentials.mfaMethod):
                    auditLog.warn("AUTH_FAILED_MFA", {
                        userId: user.id,
                        sourceIp: request.remoteIp
                    })
                    throw AuthenticationException("MFA verification failed")

            // 5. Create secure session
            rateLimiter.reset(credentials.username)
            session = sessionManager.createSecureSession(user, {
                maxAge: 15.minutes,
                secure: true,           // HTTPS only
                httpOnly: true,         // No JavaScript access
                sameSite: "Strict"      // No CSRF
            })

            // 6. Audit successful authentication
            auditLog.log("AUTH_SUCCESS", {
                userId: user.id,
                sessionId: session.id,
                sourceIp: request.remoteIp,
                mfaMethod: credentials.mfaMethod,
                timestamp: utcNow()
            })

            return { sessionId: session.id, user: userToResponse(user) }

        catch (exception: Exception):
            auditLog.error("AUTH_EXCEPTION", {
                username: credentials.username,
                exception: exception.message,
                sourceIp: request.remoteIp
            })
            throw
```

### Session Management and Timeouts

```
// Secure session management with inactivity timeout
@Component
class SessionManagementService:

    @Scheduled(fixedRate = 60000)  // Check every 60 seconds
    function enforceSessionTimeouts():
        sessions = sessionRepository.findAllActive()
        for session in sessions:
            if isInactive(session, 15.minutes):
                invalidateSession(session)
                auditLog.log("SESSION_TIMEOUT", {
                    sessionId: session.id,
                    userId: session.userId,
                    inactiveDuration: calculateInactiveDuration(session)
                })

    function isInactive(session, timeout):
        lastActivity = session.lastActivityTime
        return (now() - lastActivity) > timeout

    function invalidateSession(session):
        session.status = INVALIDATED
        session.invalidatedAt = utcNow()
        sessionRepository.save(session)

        // Remove from cache
        sessionCache.evict(session.id)
```

## Control Objective 6: Protecting Sensitive Data

### Data Classification and Protection

| Classification | At Rest | In Transit | Logging | Display |
|----------------|---------|-----------|---------|---------|
| PROHIBITED | Never | Never | Never | Never |
| RESTRICTED | AES-256-GCM | TLS 1.3 | Masked only | Masked only |
| INTERNAL | Encrypted (TDE) | TLS 1.2+ | Allowed | Allowed |
| PUBLIC | Optional | TLS 1.2+ | Allowed | Allowed |

```
// Field-level encryption for RESTRICTED data
@Entity
class Customer:
    id: Long
    name: String                       // INTERNAL

    @Encrypted(algorithm = "AES-256-GCM")
    email: String                      // RESTRICTED

    @Encrypted(algorithm = "AES-256-GCM")
    phone: String                      // RESTRICTED

    @Encrypted(algorithm = "AES-256-GCM")
    @Tokenize
    pan: String                        // RESTRICTED (also tokenized)

// Field-level masking for display and logging
function maskEmail(email):
    if email == null OR email.length() < 5:
        return "***"
    parts = email.split("@")
    localPart = parts[0]
    domain = parts[1]
    // Show only first char + domain
    return localPart.substring(0, 1) + "***@" + domain

function maskPhone(phone):
    if phone == null OR phone.length() < 4:
        return "****"
    // Show only last 4 digits
    return "****" + phone.substring(phone.length() - 4)

function maskPan(pan):
    if pan == null OR pan.length() < 13:
        return "****"
    // Show first 6 and last 4
    return pan.substring(0, 6) + "****" + pan.substring(pan.length() - 4)

// Audit logging with masking
auditLog.info("CUSTOMER_CREATED", {
    customerId: customer.id,
    email: maskEmail(customer.email),      // Masked in logs
    phone: maskPhone(customer.phone),      // Masked in logs
    timestamp: utcNow()
})
```

### Secure Data Disposal

| Method | When to Use | Implementation |
|--------|-----------|----------------|
| Cryptographic erasure | RESTRICTED/PROHIBITED data | Delete encryption key; data becomes unrecoverable |
| Overwrite in memory | Passwords, keys in memory | Zero-fill byte arrays in finally block |
| Scheduled purge | Data beyond retention period | Automated job; immutable audit log of disposal |

```
// Secure data disposal patterns
@Component
class DataDisposalService:

    // 1. Cryptographic erasure (delete key, render data unrecoverable)
    function disposeByKeyDeletion(dataId):
        dataRecord = repository.find(dataId)
        keyId = dataRecord.encryptionKeyId

        // Delete encryption key
        keyStore.deleteKey(keyId)

        // Data is now unrecoverable (cryptographic erasure)
        auditLog.log("DATA_DISPOSED_CRYPTO_ERASURE", {
            dataId: dataId,
            keyId: keyId,
            timestamp: utcNow()
        })

    // 2. Memory disposal (zero-fill sensitive arrays)
    function processSensitiveData(sensitiveBytes: byte[]):
        try:
            result = processBytes(sensitiveBytes)
            return result
        finally:
            // Zero-fill the array
            for i in 0..<sensitiveBytes.length:
                sensitiveBytes[i] = 0

    // 3. Automated retention enforcement
    @Scheduled(cron = "0 2 * * *")  // Daily at 2 AM
    function enforceDataRetention():
        policy = retentionPolicyService.getPolicy()
        expiredRecords = repository.findByExpirationBefore(now())

        for record in expiredRecords:
            if NOT hasActiveRetentionObligation(record):
                disposeByKeyDeletion(record.id)
                auditLog.log("RETENTION_PURGE", {
                    recordId: record.id,
                    reason: "retention_period_expired",
                    timestamp: utcNow()
                })
```

## Control Objective 7: Threat Detection and Runtime Monitoring

### Real-Time Security Monitoring

| Event Type | Monitoring | Alert Threshold | Response |
|-----------|-----------|----------------|----------|
| Brute force attempts | Failed logins | 5 failures in 5 minutes | Lock account; alert security |
| Bulk data access | Record count per request | > 100 records in single request | Flag for review; audit log |
| Privilege escalation | Role changes | Any unauthorized change | Immediate investigation |
| Configuration change | Setting modifications | Any security setting change | Review within 1 hour |
| Encryption key access | Key usage | Any detokenization event | Audit log; monitor patterns |

```
// Security event monitoring with SIEM integration
@Component
class SecurityMonitoringService:

    @Component
    SecurityEventListener:

        @EventListener
        function onFailedLogin(event: FailedLoginEvent):
            // 1. Check rate limiter
            failureCount = rateLimiter.incrementFailure(event.username)
            if failureCount >= 5:
                rateLimiter.lockAccount(event.username, 30.minutes)
                alerting.high("ACCOUNT_LOCKED_BRUTE_FORCE", {
                    username: event.username,
                    sourceIp: event.sourceIp,
                    failureCount: failureCount
                })

            // 2. Log the event
            auditLog.warn("AUTH_FAILED", event)

            // 3. Publish to SIEM
            siemConnector.publish(event)

        @EventListener
        function onBulkDataAccess(event: BulkAccessEvent):
            if event.recordCount > 100:
                alerting.high("BULK_DATA_ACCESS", {
                    userId: event.userId,
                    recordCount: event.recordCount,
                    sourceIp: event.sourceIp
                })
                auditLog.warn("BULK_ACCESS_DETECTED", event)

        @EventListener
        function onPrivilegeEscalation(event: RoleChangeEvent):
            if NOT isAuthorizedChange(event.userId, event.newRole):
                alerting.critical("PRIVILEGE_ESCALATION", {
                    userId: event.userId,
                    previousRole: event.previousRole,
                    newRole: event.newRole,
                    grantedBy: event.grantedBy
                })
                auditLog.error("UNAUTHORIZED_PRIVILEGE_CHANGE", event)

    function isAuthorizedChange(userId, newRole):
        return accessControl.isAllowed(currentUser, "GRANT_ROLE", newRole)
```

## Control Objective 8: Secure Software Updates and Releases

### Secure Release Process

| Phase | Control | Implementation |
|-------|---------|----------------|
| Artifact signing | Sign all release artifacts | GPG/RSA signature on binaries, container images |
| Integrity verification | Verify signature before deployment | Automated check in deployment pipeline |
| Release notes | Document all changes and security fixes | Publish with every release |
| Rollback capability | Maintain previous versions for rollback | Keep 3 prior versions available |
| Deployment audit | Track all deployments with who/when/what | Immutable deployment log |

```
// Secure software release and signing
@Component
class SecureReleaseService:

    function createAndSignRelease(version):
        // 1. Build the application
        buildArtifact = buildApplication(version)

        // 2. Generate cryptographic signature
        signature = signArtifact(buildArtifact, signingKey)

        // 3. Create signed container image
        image = buildContainerImage(buildArtifact, version)
        signImage(image, signingKey)

        // 4. Create release manifest
        releaseManifest = {
            version: version,
            releaseDate: utcNow(),
            artifacts: {
                binary: buildArtifact,
                signature: signature,
                containerImage: image,
                checksum: sha256(buildArtifact)
            },
            releaseNotes: getReleaseNotes(version),
            securityFixes: getSecurityFixes(version),
            releasedBy: currentUser.id
        }

        // 5. Store in secure repository
        artifactRepository.store(releaseManifest)

        // 6. Audit the release
        auditLog.log("RELEASE_CREATED", {
            version: version,
            releasedBy: currentUser.id,
            timestamp: utcNow()
        })

        return releaseManifest

    function deployRelease(version):
        // 1. Verify signature
        releaseManifest = artifactRepository.get(version)
        if NOT verifySignature(releaseManifest.artifacts.signature):
            throw SecurityException("Signature verification failed")

        // 2. Verify image integrity
        if NOT verifyImageSignature(releaseManifest.artifacts.containerImage):
            throw SecurityException("Container image signature verification failed")

        // 3. Deploy
        deploymentService.deploy(releaseManifest)

        // 4. Audit deployment
        auditLog.log("RELEASE_DEPLOYED", {
            version: version,
            deployedBy: currentUser.id,
            timestamp: utcNow()
        })
```

## Implementation Patterns

### Threat Model Template

```
// Threat model for critical features
@ThreatModel
class FeatureThreatModel:
    - Feature name
    - Data flows (inputs, processing, outputs)
    - Trust boundaries
    - Assets at risk
    - Identified threats (per STRIDE)
    - Risk rating per threat (probability * impact)
    - Mitigation strategies
    - Residual risk assessment
    - Sign-off by security team
```

### SAST Integration Pattern

```
// Static analysis in CI/CD pipeline
sast:
    tools: [SonarQube, Semgrep, CodeQL]
    trigger: every pull request
    gate:
        critical: block merge (zero tolerance)
        high: block merge (zero tolerance)
        medium: notify (do not block)
        low: track (no action required)
    excluded: test code, generated code, vendor code
```

### Audit Log Service Pattern

```
// Immutable audit logging for compliance
auditLog:
    storage: append-only (WORM or blockchain-backed)
    events:
        - Authentication (success/failure)
        - Authorization (grant/deny)
        - Data access (read/write/delete)
        - Configuration changes
        - Security settings modifications
    retention: 1 year (3 months online, rest archived)
    tampering_detection: hash chain verification
    integration: SIEM (real-time forwarding)
```

## Anti-Patterns (FORBIDDEN)

- Release software with debug features enabled by default
- Implement authentication without MFA capability
- Skip security testing gates in CI/CD pipeline
- Store sensitive data without encryption or tokenization
- Log sensitive data (passwords, keys, PAN, SAD) in any log level
- Deploy without immutable audit logging of all security events
- Allow data to persist beyond defined retention periods
- Implement authorization checks only on client-side
- Omit comprehensive threat modeling for new features
- Use weak hashing algorithms (MD5, SHA-1) for passwords
- Hardcode default credentials in any environment beyond local development
- Ship production releases without signature verification
- Deploy without real-time security event monitoring and alerting
- Ignore vulnerability scanning results or extend deadlines repeatedly
- Deploy CDE-handling code without explicit security team approval
