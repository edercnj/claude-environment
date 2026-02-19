# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# PCI-DSS — Code & Architecture Requirements

> **Scope:** This document covers PCI-DSS requirements that directly impact application code and architecture decisions. Operational and physical security controls are out of scope.

## Cardholder Data (CHD) Protection

### PAN (Primary Account Number) Handling

| Context | Requirement | Implementation |
|---------|-------------|----------------|
| Display | Mask: show only first 6 / last 4 digits | `maskPan("4111111111111111")` -> `411111******1111` |
| Storage | Encrypt with AES-256-GCM or tokenize | Field-level encryption or tokenization vault |
| Transit | TLS 1.2+ (TLS 1.3 preferred) | Enforce at load balancer and application level |
| Logging | **NEVER log full PAN** | PAN must be masked or truncated in all log output |
| Memory | Minimize time in memory; zero after use | Use secure byte arrays; zero on disposal |

### PAN Masking Implementation

```
// PAN masking — show first 6 and last 4 only
function maskPan(pan):
    if length(pan) < 13:
        throw ValidationException("Invalid PAN length")
    first6 = pan[0:6]
    last4 = pan[length(pan)-4:]
    masked = first6 + "*".repeat(length(pan) - 10) + last4
    return masked

// Secure PAN storage
function storePan(pan, customerId):
    // Option A: Tokenization (preferred for PCI scope reduction)
    token = tokenizationService.tokenize(pan)
    repository.save(customerId, token)

    // Option B: Encryption (when tokenization not available)
    encrypted = encryptionService.encrypt(pan, "pci-dek")
    repository.save(customerId, encrypted)
```

### Sensitive Authentication Data (SAD)

**NEVER store after authorization**, regardless of encryption:
- Full track data (magnetic stripe)
- CVV / CVC / CID
- PIN / PIN block

```
// GOOD — SAD discarded after authorization
function processPayment(cardData):
    authResult = acquirer.authorize(cardData)  // SAD used only here
    cardData.cvv = null                         // Discard SAD immediately
    cardData.track = null
    cardData.pin = null
    return authResult

// BAD — SAD persisted
function processPayment(cardData):
    repository.save(cardData)  // VIOLATION: SAD stored post-authorization
    return acquirer.authorize(cardData)
```

## Network Segmentation — Code Implications

### Cardholder Data Environment (CDE) Isolation

- Applications handling CHD must run in an isolated network segment (CDE)
- Non-CDE applications MUST NOT have direct access to CDE databases
- Use dedicated APIs (tokenization gateways) for non-CDE applications to interact with CHD

### Service Communication Pattern

```
// Architecture: Non-CDE service accessing card data via tokenization gateway
// Non-CDE Service -> Tokenization Gateway (in CDE) -> Card Vault (in CDE)

// Non-CDE service code
function getPaymentMethod(customerId):
    // Only receives tokens, never raw PAN
    token = paymentGateway.getToken(customerId)
    return { last4: token.last4, brand: token.brand, token: token.id }

// Tokenization gateway (runs inside CDE)
function getToken(customerId):
    pan = cardVault.retrieve(customerId)
    return {
        id: tokenize(pan),
        last4: pan[length(pan)-4:],
        brand: detectBrand(pan)
    }
```

### Microservice Boundaries

- Isolate payment processing into a dedicated service with its own database
- Payment service exposes only tokenized references to other services
- Implement mTLS between services that handle CHD
- Log all cross-boundary data flows involving CHD

## Access Control

### Requirement 7: Restrict Access by Business Need-to-Know

- Implement role-based access control (RBAC) for all access to CHD
- Define roles with minimum necessary privileges
- Review access rights quarterly (automated checks preferred)

```
// RBAC for cardholder data access
enum PciRole:
    PAYMENT_PROCESSOR    // Can process transactions (read CHD temporarily)
    PAYMENT_ADMIN        // Can manage payment configurations (no CHD access)
    AUDIT_VIEWER         // Can view masked CHD and audit logs
    SYSTEM_ADMIN         // Infrastructure access (no CHD access)

function accessCardData(user, operation):
    if NOT hasRole(user, PciRole.PAYMENT_PROCESSOR):
        auditLog.warn("UNAUTHORIZED_CHD_ACCESS", {user, operation})
        throw ForbiddenException("Insufficient privileges for CHD access")
    auditLog.log("CHD_ACCESS", {user, operation, timestamp})
```

### Requirement 8: Identify and Authenticate Access

- Unique ID for every user with access to CHD systems
- Multi-factor authentication for all administrative access to CDE
- Password policy: minimum 12 characters, complexity requirements, 90-day rotation
- Lock accounts after 6 failed attempts; 30-minute lockout minimum
- Session timeout: 15 minutes of inactivity for CDE applications

## Audit Trail

### Requirement 10: Track and Monitor All Access

All of the following events MUST be logged:

| Event | Required Fields |
|-------|----------------|
| Individual user access to CHD | User ID, timestamp, resource, action |
| Actions by privileged users | User ID, timestamp, action, target |
| Access to audit trails | User ID, timestamp, access type |
| Invalid authentication attempts | User ID, timestamp, source IP, reason |
| Changes to identification mechanisms | User ID, timestamp, change type |
| Initialization/stopping of audit logs | System, timestamp, action |
| Creation/deletion of system-level objects | User ID, timestamp, object type |

### Audit Log Requirements

- **Tamper-proof:** Logs must be immutable; use append-only storage (e.g., WORM storage, blockchain-backed)
- **Retention:** Minimum 1 year; 3 months immediately accessible
- **Synchronization:** NTP-synchronized timestamps across all systems
- **Protection:** Logs stored in separate, access-controlled location

```
// PCI audit log event structure
auditEvent = {
    eventId: generateUUID(),
    timestamp: utcNow(),                // NTP-synchronized
    eventType: "CHD_ACCESS",
    userId: currentUser.id,
    sourceIp: request.remoteIp,
    resource: "cardholder-data",
    action: "READ",
    result: "SUCCESS",
    details: {
        maskedPan: "411111******1111",  // Never log full PAN
        purpose: "transaction-processing"
    }
}
auditLogService.append(auditEvent)      // Append-only, immutable
```

## Vulnerability Management

### Requirement 5: Protect Against Malware

- Anti-malware on all systems commonly affected by malware
- Keep anti-malware mechanisms current and running
- Generate audit logs for anti-malware activity

### Requirement 6: Develop and Maintain Secure Systems

- Establish a process to identify and assign risk rankings to new vulnerabilities
- Patch critical vulnerabilities within 30 days of release
- Address all applicable vulnerabilities per PCI-DSS requirements

## Application Security — Requirement 6

### Req 6.2: Secure Development

- Train developers in secure coding techniques annually
- Develop software based on secure coding guidelines (OWASP)
- Review custom code before release to production (peer review or automated analysis)

### Req 6.3: Security in the SDLC

```
// Mandatory SDLC security gates
pipeline:
    stage: code-review
        - Peer review with security checklist
        - Automated SAST scan (no critical/high findings)

    stage: build
        - Dependency vulnerability scan (SCA)
        - Container image scan
        - Secret detection scan

    stage: test
        - DAST scan against staging environment
        - PCI-specific test cases executed

    stage: deploy
        - Verify all security gates passed
        - Change management approval
        - Deploy to CDE with audit trail
```

### Req 6.4: Public-Facing Web Application Protection

- Deploy a WAF (Web Application Firewall) in front of all public-facing web applications
- WAF must be actively maintained with updated rulesets
- Alternatively, perform application vulnerability assessment at least annually and after changes

### Req 6.5: Address Common Coding Vulnerabilities

All custom code must be reviewed for at minimum:
- Injection flaws (SQL, OS, LDAP, XPath)
- Buffer overflows
- Insecure cryptographic storage
- Insecure communications
- Improper error handling
- Cross-site scripting (XSS)
- Improper access control
- Cross-site request forgery (CSRF)
- Broken authentication and session management

## Scope Reduction Strategies

### Tokenization

- Replace PAN with non-reversible tokens for non-CDE systems
- Reduces PCI scope for systems that only need to reference (not process) card data
- Tokenization system itself remains in scope

### P2PE (Point-to-Point Encryption)

- Encrypt card data at the point of interaction (terminal/device)
- Data remains encrypted until it reaches the secure decryption environment
- Significantly reduces CDE scope for merchant applications

### Third-Party Payment Processors

- Use PCI-compliant third-party processors (Stripe, Adyen, Braintree)
- Never receive or store raw card data in your systems
- Validate processor PCI compliance annually (AOC/ROC)

## Anti-Patterns (FORBIDDEN)

- Store full PAN in application logs, even at DEBUG level
- Store SAD (CVV, PIN, track data) after authorization
- Allow non-CDE services direct access to cardholder data databases
- Use shared accounts for access to CDE systems
- Skip WAF for public-facing payment applications
- Deploy CHD-handling code without security review
- Use deprecated encryption for PAN storage (DES, 3DES, RC4)
- Log full card numbers in error messages or stack traces
- Store PAN and encryption keys in the same database
