# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# PCI Software Security Framework — Secure Software Lifecycle

> **Scope:** This document covers the PCI Software Security Framework (SSF) Control Objectives (CO) that directly impact code, architecture, and development lifecycle decisions.

## Secure Software Lifecycle (CO 1-4)

### CO 1 — Security Governance

- Define and maintain a software security policy document
- Assign security roles and responsibilities within the development team
- Conduct security training for all developers at least annually
- Maintain an inventory of all software components and third-party dependencies

### CO 2 — Secure Defaults

- All software MUST ship with secure default configurations
- Features that weaken security must be opt-in, never opt-out
- Default credentials must never exist in production builds
- Debug/diagnostic modes must be disabled by default

```
// GOOD — Secure defaults, insecure features require explicit opt-in
configuration:
    tls:
        minVersion: "1.3"           // Secure default
        enabled: true               // Secure by default
    authentication:
        mfa: true                   // Enabled by default
        sessionTimeout: 15m         // Short default
        maxFailedAttempts: 5        // Lockout enabled by default
    logging:
        debug: false                // Disabled by default
        sensitiveDataMasking: true  // Enabled by default

// BAD — Insecure defaults requiring opt-in security
configuration:
    tls:
        enabled: false              // VIOLATION: security disabled by default
    authentication:
        mfa: false                  // VIOLATION: security feature off by default
```

### CO 3 — Threat Identification

- Perform threat modeling for all new features and significant changes
- Use STRIDE or equivalent methodology to identify threats
- Document threat model results and mitigation strategies
- Review threat models when architecture changes

### CO 4 — Vulnerability Detection and Remediation

- Integrate automated security testing into CI/CD pipeline
- Perform static analysis (SAST) on every code change
- Perform dynamic analysis (DAST) before each release
- Conduct penetration testing at least annually
- Track all vulnerabilities to closure with defined SLAs

```
// CI/CD security gates aligned with CO 4
pipeline:
    stage: static-analysis
        tools: [SAST, secret-detection, dependency-scan]
        gate: zero critical/high findings

    stage: dynamic-analysis
        tools: [DAST, API-security-scan]
        gate: zero critical findings, high findings triaged

    stage: release-readiness
        checklist:
            - All SAST/DAST findings resolved or accepted with justification
            - Dependency vulnerabilities within SLA
            - Penetration test current (within 12 months)
            - Security review completed for new features
```

## Authentication & Access (CO 5-6)

### CO 5 — Authentication

- Support multi-factor authentication for all user-facing applications
- Implement secure credential storage (argon2id/bcrypt, see Cryptography rules)
- Enforce password complexity: minimum 12 characters, mix of character types
- Implement account lockout after configurable number of failed attempts (default: 5)
- Session management: server-side sessions, secure cookies, proper invalidation

```
// Authentication aligned with CO 5
function authenticate(credentials):
    // 1. Rate limit check
    if rateLimiter.isLocked(credentials.username):
        auditLog.log("AUTH_LOCKED", {username: credentials.username})
        throw AccountLockedException("Account temporarily locked")

    // 2. Credential verification
    user = userRepository.findByUsername(credentials.username)
    if NOT passwordEncoder.verify(credentials.password, user.passwordHash):
        rateLimiter.recordFailure(credentials.username)
        auditLog.log("AUTH_FAILED", {username: credentials.username})
        throw AuthenticationException("Invalid credentials")

    // 3. MFA verification (mandatory)
    if NOT mfaService.verify(user, credentials.mfaToken):
        auditLog.log("MFA_FAILED", {userId: user.id})
        throw AuthenticationException("MFA verification failed")

    // 4. Create secure session
    rateLimiter.reset(credentials.username)
    session = sessionManager.create(user, {
        maxAge: 15.minutes,
        secure: true,
        httpOnly: true,
        sameSite: "Strict"
    })
    auditLog.log("AUTH_SUCCESS", {userId: user.id})
    return session
```

### CO 6 — Access Control

- Implement least-privilege access control for all application functions
- Enforce authorization checks on every request (server-side)
- Support role-based (RBAC) or attribute-based (ABAC) access control
- Log all access control decisions (grant and deny)
- Provide mechanisms for access review and revocation

```
// Access control aligned with CO 6
@PreAuthorize
function accessResource(user, resource, action):
    // 1. Check authorization
    decision = accessControl.evaluate(user, resource, action)

    // 2. Log the decision
    auditLog.log("ACCESS_DECISION", {
        userId: user.id,
        resource: resource.id,
        action: action,
        decision: decision.result,
        reason: decision.reason
    })

    // 3. Enforce the decision
    if decision.result == DENY:
        throw ForbiddenException("Access denied: " + decision.reason)

    return resource.execute(action)
```

## Sensitive Data Protection (CO 7-8)

### CO 7 — Protection of Sensitive Data

- Classify all data handled by the application (see Rule 07 — Security Principles)
- Encrypt sensitive data at rest and in transit (see Cryptography rules)
- Implement data masking for display and logging contexts
- Minimize data collection: only collect what is necessary for business function
- Implement data retention policies: delete data when no longer needed

| Data Classification | At Rest | In Transit | Logging | Display |
|---------------------|---------|------------|---------|---------|
| PROHIBITED | Never stored | N/A | Never | Never |
| RESTRICTED | AES-256-GCM encrypted | TLS 1.3 | Masked only | Masked only |
| INTERNAL | Encrypted (TDE minimum) | TLS 1.2+ | Allowed | Allowed |
| PUBLIC | No encryption required | TLS 1.2+ | Allowed | Allowed |

### CO 8 — Secure Data Disposal

- Implement cryptographic erasure: delete encryption keys to render data unrecoverable
- Overwrite sensitive data in memory after use (zero-fill byte arrays)
- Implement automated data retention enforcement (scheduled purge jobs)
- Log all data disposal events for audit purposes

```
// Secure data disposal patterns

// 1. Memory disposal
function processSecureData(sensitiveBytes):
    try:
        result = processingEngine.process(sensitiveBytes)
        return result
    finally:
        Arrays.fill(sensitiveBytes, 0)  // Zero-fill after use

// 2. Cryptographic erasure
function disposeCustomerData(customerId):
    // Delete the encryption key, rendering all encrypted data unrecoverable
    keyId = keyMapping.getKeyForCustomer(customerId)
    keyStore.destroyKey(keyId)
    auditLog.log("DATA_DISPOSED", {customerId, method: "cryptographic-erasure"})

// 3. Automated retention enforcement
@Scheduled(cron = "0 2 * * *")  // Daily at 2 AM
function enforceRetentionPolicy():
    expiredRecords = repository.findExpired(retentionPolicy)
    for record in expiredRecords:
        disposeRecord(record)
        auditLog.log("RETENTION_PURGE", {recordId: record.id, policy: retentionPolicy.name})
```

## Logging & Monitoring (CO 9-10)

### CO 9 — Activity Logging

- Log all security-relevant events with sufficient detail for forensic analysis
- Include: who, what, when, where, outcome (success/failure)
- Protect logs from tampering (append-only storage, separate access controls)
- Retain logs per regulatory requirements (minimum 1 year)
- Never log sensitive data (passwords, keys, full PAN, SAD)

### Mandatory Log Events

| Event Category | Events |
|---------------|--------|
| Authentication | Login success/failure, logout, MFA events, password changes |
| Authorization | Access granted/denied, privilege escalation, role changes |
| Data Access | Read/write of sensitive data, bulk data operations, exports |
| Configuration | Security setting changes, feature toggles, key rotation |
| System | Application start/stop, error conditions, resource exhaustion |

```
// Structured security log entry aligned with CO 9
securityLog = {
    timestamp: utcNow(),              // ISO-8601, NTP-synchronized
    eventId: generateUUID(),          // Unique event identifier
    level: "INFO",
    category: "AUTHENTICATION",
    action: "LOGIN",
    outcome: "SUCCESS",
    actor: {
        userId: "user-123",
        sessionId: "sess-abc",
        sourceIp: "203.0.113.42",
        userAgent: "Mozilla/5.0..."
    },
    target: {
        type: "user-session",
        id: "sess-abc"
    },
    context: {
        applicationName: "payment-service",
        applicationVersion: "2.4.1",
        environment: "production"
    }
}
```

### CO 10 — Security Monitoring

- Implement real-time monitoring for security events
- Define alerting thresholds for anomalous activity patterns
- Monitor for: brute force attempts, unusual data access patterns, privilege escalation, configuration changes
- Integrate with SIEM (Security Information and Event Management) system
- Respond to security alerts within defined SLAs

### Alerting Thresholds

| Alert | Threshold | Response SLA |
|-------|-----------|-------------|
| Multiple authentication failures | 5 failures in 5 minutes per account | Automated lockout + alert |
| Bulk data access | > 100 records in single request | Immediate review |
| Privilege escalation attempt | Any unauthorized role change | Immediate investigation |
| Configuration change in production | Any security setting change | Review within 1 hour |
| New admin account created | Any new privileged account | Review within 4 hours |

## Anti-Patterns (FORBIDDEN)

- Ship software with debug mode enabled by default
- Implement authentication without MFA support
- Skip security testing gates in CI/CD pipeline
- Store sensitive data without classification-appropriate controls
- Log sensitive data (passwords, keys, PAN, SAD) in any log level
- Allow data to persist beyond defined retention periods
- Implement access control checks only on the client side
- Deploy without security monitoring and alerting configured
- Use default credentials in any non-local-development environment
- Skip threat modeling for new features or architecture changes
