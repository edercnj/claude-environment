# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# PCI-DSS v4.0 — Code & Architecture Requirements

> **Scope:** This document covers PCI-DSS v4.0 requirements that directly impact application code, API design, and architecture. Organizational governance and physical controls are out of scope unless they have code implications.

## Requirement 1: Install and Maintain Network Security Controls (Firewalls and Segmentation)

### Network Segmentation — Code Implications

| Requirement | Implementation Pattern |
|-------------|----------------------|
| Cardholder Data Environment (CDE) isolation | Dedicated network segment; non-CDE services must not query CHD databases directly |
| Service-to-service communication | Use mTLS between payment service and other internal services; tokenization gateway for non-CDE access |
| Access control lists (ACL) | Whitelist only required ports and protocols; reject all others by default |
| Outbound restrictions | Payment service blocked from initiating outbound connections except to approved processors |

```
// Service communication in PCI architecture
// Non-CDE Service → Tokenization Gateway (in CDE) → Card Vault

// Non-CDE service code — only receives tokens
function getPaymentMethod(customerId):
    response = tokenizationGateway.call("/v1/card/{customerId}")
    if response.status != 200:
        throw ExternalServiceException("Gateway error")
    return {
        token: response.token,
        last4: response.last4,
        brand: response.brand
    }

// Tokenization gateway (inside CDE, mTLS protected)
function getCardToken(customerId):
    pan = cardVault.retrieve(customerId)
    token = tokenizationService.generateToken(pan)
    auditLog.log("TOKEN_GENERATED", {customerId, timestamp: utcNow()})
    return {
        token: token,
        last4: pan.substring(pan.length() - 4),
        brand: detectCardBrand(pan)
    }
```

## Requirement 2: Apply Secure Configurations

### Default Credentials and Hardening

| Control | Requirement | Implementation |
|---------|-------------|----------------|
| Default credentials | MUST NOT exist in any build | All credentials sourced from secrets manager; never baked in code |
| Unnecessary services | Disable all unused protocols, ports, services | Configuration via environment controls; never enabled by default |
| Security parameters | TLS 1.2 minimum, TLS 1.3 preferred | Enforce at application startup; reject connections below minimum version |
| Error messages | Do not expose system details in error responses | Return generic error; log details server-side only |
| Debug features | Disabled in all non-development environments | Debug mode requires explicit feature flag override |

```
// GOOD — Secure defaults, insecure features require explicit override
@Configuration
class SecurityConfiguration:

    @Bean
    TlsConfiguration tlsConfig():
        return TlsConfiguration.builder()
            .minVersion(TLS_1_3)           // Secure default
            .maxVersion(TLS_1_3)
            .cipherSuites(RECOMMENDED_CIPHERS)
            .enforceStrictHostnameVerification(true)
            .build()

    @Bean
    function errorHandler():
        return (exception, response) -> {
            log.error("Unexpected error", exception)   // Server-side
            response.status(500)
            response.contentType("application/json")
            return { "type": "/errors/internal-error", "status": 500 }  // Generic
        }

// BAD — Insecure defaults requiring override
function tlsConfig():
    return {
        minVersion: "TLS_1_0",         // VIOLATION: allows deprecated TLS
        debugMode: true,               // VIOLATION: debug enabled by default
        exposeStackTrace: true         // VIOLATION: details leaked in errors
    }
```

## Requirement 3: Protect Stored Cardholder Data

### PAN (Primary Account Number) Storage

| Context | Requirement | Implementation |
|---------|-------------|----------------|
| Display (UI/API) | Mask: first 6 and last 4 digits only | `maskPan("4111111111111111")` returns `411111******1111` |
| Storage | Encrypt AES-256-GCM OR tokenize (preferred) | Field-level encryption; tokenization preferred for scope reduction |
| Encryption at rest | AES-256-GCM with authenticated encryption | Never use ECB mode; always use GCM or CBC+HMAC |
| Key management | Store encryption keys in HSM or key vault | Separate from encrypted data; rotate annually |
| Backup encryption | All backups encrypted with separate keys | Keys never stored with backups |
| Tokenization | Non-reversible tokens for non-CDE systems | Token vault isolated in CDE; detokenization audit-logged |

```
// Secure PAN storage — Option A: Tokenization (preferred)
function storePan(pan, customerId):
    // 1. Validate PAN length
    if length(pan) < 13 OR length(pan) > 19:
        throw ValidationException("Invalid PAN length")

    // 2. Generate non-reversible token
    token = tokenizationVault.tokenize(pan)

    // 3. Store token (not PAN) in database
    repository.save(customerId, {
        paymentToken: token,
        last4: pan.substring(length(pan) - 4),
        brand: detectCardBrand(pan),
        tokenizedAt: utcNow()
    })

    // 4. Audit the tokenization
    auditLog.log("PAN_TOKENIZED", {
        customerId: customerId,
        token: token,
        timestamp: utcNow()
    })

// Secure PAN storage — Option B: Encryption (when tokenization unavailable)
function storePanEncrypted(pan, customerId):
    // 1. Encrypt PAN with field-level encryption
    encryptionKey = keyStore.getLatestKey("pci-pan-encryption")
    encryptedPan = aes256gcm.encrypt(pan, encryptionKey)

    // 2. Store encrypted data with key version
    repository.save(customerId, {
        panEncrypted: encryptedPan,
        keyVersion: encryptionKey.version,
        last4: pan.substring(length(pan) - 4),
        encryptedAt: utcNow()
    })

    // 3. Audit the encryption
    auditLog.log("PAN_ENCRYPTED", {
        customerId: customerId,
        keyVersion: encryptionKey.version,
        timestamp: utcNow()
    })

// PAN masking — always for display
function maskPan(pan):
    if length(pan) < 13:
        throw ValidationException("Invalid PAN: too short")
    first6 = pan.substring(0, 6)
    last4 = pan.substring(length(pan) - 4)
    masked = first6 + "*".repeat(length(pan) - 10) + last4
    return masked
```

### Sensitive Authentication Data (SAD) — NEVER Store

Regardless of encryption status, the following MUST NOT be persisted:

| Data | Constraint |
|------|-----------|
| Full track data (magnetic stripe) | Discard immediately after authorization |
| CVV / CVC / CID (3-4 digit code) | NEVER store, even encrypted |
| PIN or PIN block | NEVER store, even encrypted |
| Chip CVC2 / iCVV | NEVER store, even encrypted |

```
// GOOD — SAD discarded immediately
function processPayment(cardData, amount):
    // 1. Authorize with payment processor (SAD transmitted securely)
    authResult = paymentProcessor.authorize({
        pan: cardData.pan,
        expiry: cardData.expiry,
        cvv: cardData.cvv,        // SAD transmitted only for auth
        amount: amount
    })

    // 2. Discard SAD immediately
    cardData.pan = null
    cardData.cvv = null
    cardData.track = null
    cardData.pin = null

    // 3. Store only tokenized result
    repository.save({
        authorizationId: authResult.id,
        amount: amount,
        token: tokenizeFromAuthResult(authResult),
        authorizedAt: utcNow()
    })

    return authResult

// BAD — SAD persisted
function processPayment(cardData, amount):
    repository.save(cardData)          // VIOLATION: SAD persisted
    return paymentProcessor.authorize(cardData)
```

## Requirement 4: Protect Cardholder Data in Transit

### Transport Layer Security (TLS)

| Requirement | Standard | Enforcement |
|-------------|----------|-------------|
| TLS version | TLS 1.3 minimum; TLS 1.2 acceptable | Reject connections below minimum at protocol layer |
| Certificate validation | Validate certificate chain; reject self-signed in production | Enforce via framework; log certificate errors |
| HSTS (HTTP Strict Transport Security) | `max-age=31536000; includeSubDomains; preload` | Set on all responses carrying CHD or payment context |
| Perfect Forward Secrecy (PFS) | All TLS connections use ephemeral keys | Cipher suite configuration; audit quarterly |
| Certificate pinning (mobile) | Pin issuing CA or leaf certificate | With backup pins; rotation plan required |

```
// TLS configuration for PCI compliance
@Configuration
class TlsSecurityConfiguration:

    @Bean
    SSLContext sslContext():
        sslContext = SSLContext.getInstance("TLSv1.3")
        sslContext.init(keyManagerFactory.getKeyManagers(),
                        trustManagerFactory.getTrustManagers(),
                        secureRandom)
        return sslContext

    @Bean
    RestTemplate restTemplate(RestTemplateBuilder builder):
        return builder
            .requestFactory(HttpComponentsClientHttpRequestFactory.class)
                .sslContext(sslContext())
                .build()

    @Bean
    SecurityHeadersFilter securityHeaders():
        return (request, response, chain) -> {
            response.setHeader("Strict-Transport-Security",
                "max-age=31536000; includeSubDomains; preload")
            response.setHeader("X-Content-Type-Options", "nosniff")
            response.setHeader("X-Frame-Options", "DENY")
            chain.doFilter(request, response)
        }

// Mutual TLS (mTLS) for service-to-service communication in CDE
function configureClientMtls():
    return HttpClient.newBuilder()
        .sslContext(loadClientSslContext(
            clientCertPath: "/etc/ssl/client.crt",
            clientKeyPath: "/etc/ssl/client.key",
            trustedCaCert: "/etc/ssl/internal-ca.pem"
        ))
        .build()
```

## Requirement 5: Protect Against Malicious Software

### Input Validation and File Upload Controls

| Control | Implementation |
|---------|----------------|
| Malware detection | All uploaded files scanned before acceptance |
| File type validation | Validate by content (magic bytes), not extension |
| File size limits | Enforce maximum upload size (1 MB default for images) |
| Uploaded file storage | Store outside web root; non-executable permissions |
| Content-Disposition header | Always set `attachment` to prevent browser rendering |
| Metadata stripping | Remove EXIF and other metadata from images/documents |

```
// File upload validation pattern
function handleFileUpload(file):
    // 1. Size check
    if file.size > MAX_UPLOAD_SIZE:
        throw ValidationException("File exceeds maximum size")

    // 2. Content-type validation (magic bytes, not extension)
    detectedMime = MagicBytes.detect(file.content)
    if detectedMime NOT IN ALLOWED_MIME_TYPES:
        auditLog.warn("MALICIOUS_FILE_DETECTED", {
            filename: file.name,
            detectedMime: detectedMime
        })
        throw ValidationException("File type not allowed")

    // 3. Extension validation
    if file.extension NOT IN ALLOWED_EXTENSIONS:
        throw ValidationException("File extension not allowed")

    // 4. Antivirus scan
    scanResult = antivirusEngine.scan(file.content)
    if scanResult.isMalicious:
        auditLog.error("INFECTED_FILE_UPLOAD", {
            filename: file.name,
            threat: scanResult.threatName
        })
        throw ValidationException("File failed security scan")

    // 5. Metadata stripping
    cleanedContent = metadataStripper.strip(file.content, detectedMime)

    // 6. Store with generated name in non-executable location
    storagePath = "/storage/uploads/" + generateUUID() + "." + safeExtension(detectedMime)
    fileStorage.store(cleanedContent, storagePath, {
        contentDisposition: "attachment; filename=" + sanitize(file.name),
        cacheControl: "private, no-cache",
        contentType: detectedMime
    })

    return { path: storagePath, originalName: sanitize(file.name) }
```

## Requirement 6: Develop and Maintain Secure Systems

### Secure Development Lifecycle (SDLC) with Code-Level Implications

| Phase | Requirement | Implementation |
|-------|-------------|----------------|
| Secure coding training | Annual training for all developers | Track completion; refresh on security incidents |
| Code review | All code reviewed for security issues before deployment | Mandatory peer review; security checklist completion |
| Vulnerability scanning | SAST on every commit; DAST before release | Block merge on critical/high findings |
| Dependency scanning | SCA on dependencies; CVE tracking | Patch critical within 30 days |
| Penetration testing | Minimum annually; after major changes | Authorized testing; results tracked to remediation |

```
// CI/CD pipeline gates aligned with Requirement 6
pipeline:
    stage: pre-commit
        - Secret detection scan (block on findings)
        - Code formatting check

    stage: build
        - SAST scan (SonarQube, Semgrep, CodeQL)
            gate: fail on critical/high findings
        - SCA scan (Snyk, Dependabot, OWASP Dependency-Check)
            gate: fail on critical vulnerabilities
        - Container image scan (Trivy, Grype)
            gate: fail on critical findings
        - Build application binary

    stage: test
        - Unit tests (coverage >= 95% line, >= 90% branch)
        - Integration tests with real database
        - API security tests (OWASP Top 10 validation)
        - DAST scan against staging environment

    stage: deploy
        - Verify all gates passed
        - Security approval review
        - Deploy with immutable image tag
        - Post-deployment smoke tests

// Code review checklist for security
codeReviewSecurityChecklist:
    ✓ No hardcoded credentials or secrets
    ✓ Input validation on all external input
    ✓ Output encoding for rendering contexts
    ✓ SQL parameterization (no string concatenation)
    ✓ Authentication and authorization checks
    ✓ Sensitive data not logged
    ✓ Error handling does not expose details
    ✓ OWASP Top 10 issues addressed
    ✓ Cryptography per Rule 15 standards
    ✓ No deprecated algorithms or protocols
```

## Requirement 7: Restrict Access to Cardholder Data by Business Need-to-Know

### Role-Based Access Control (RBAC) for CHD Systems

| Role | Permissions | Example Users |
|------|-----------|--------------|
| `PAYMENT_PROCESSOR` | Can process transactions; read PAN during authorization only | Payment service, transaction handlers |
| `PAYMENT_ADMIN` | Can manage payment configurations, audit logs; no CHD access | Operations team, finance |
| `SECURITY_AUDITOR` | Can view masked CHD, audit logs, access reports; no modification | Internal audit, compliance |
| `SYSTEM_ADMIN` | Infrastructure/platform access; no CHD access | DevOps, infrastructure team |
| `NO_CHD_ACCESS` | Default; no cardholder data access | All other users |

```
// Access control enforcement for CHD
@PreAuthorize
function accessCardholderData(user, operation, context):
    // 1. Verify user has CHD role
    if NOT user.hasRole("PAYMENT_PROCESSOR"):
        auditLog.warn("UNAUTHORIZED_CHD_ACCESS", {
            userId: user.id,
            operation: operation,
            timestamp: utcNow()
        })
        throw ForbiddenException("User not authorized for CHD access")

    // 2. Verify operation is within scope
    if NOT isOperationAllowed(user, operation):
        auditLog.warn("PROHIBITED_OPERATION", {
            userId: user.id,
            operation: operation
        })
        throw ForbiddenException("Operation not allowed")

    // 3. Log the access
    auditLog.log("CHD_ACCESS", {
        userId: user.id,
        operation: operation,
        context: context,
        timestamp: utcNow()
    })

    // 4. Perform operation
    return executeOperation(operation, context)
```

## Requirement 8: Identify and Authenticate Access

### Authentication Hardening

| Requirement | Implementation |
|-------------|----------------|
| Unique user ID | One ID per person; no shared accounts | Active Directory, SSO, or user management system |
| Multi-factor authentication | MFA for all administrative access and CDE access | TOTP, SMS, hardware keys; TOTP preferred |
| Password policy | 12+ chars, mixed case, numbers, symbols, 90-day rotation | Enforce at directory/application level |
| Account lockout | Lock after 6 failed attempts; 30-minute minimum lockout | Automatic unlock or manual review |
| Session management | Server-side sessions; 15-minute inactivity timeout | Secure cookies: HttpOnly, Secure, SameSite=Strict |

```
// Authentication with hardened requirements
function authenticate(credentials):
    // 1. Rate limit check
    if rateLimiter.isLocked(credentials.username):
        auditLog.warn("ACCOUNT_LOCKED", {
            username: credentials.username,
            reason: "too_many_failures"
        })
        throw AccountLockedException("Account locked for 30 minutes")

    // 2. Credential verification with strong hashing
    user = userRepository.findByUsername(credentials.username)
    if user == null OR NOT argon2id.verify(credentials.password, user.passwordHash):
        rateLimiter.recordFailure(credentials.username)
        auditLog.warn("AUTH_FAILED", {
            username: credentials.username,
            sourceIp: request.remoteIp
        })
        throw AuthenticationException("Invalid credentials")

    // 3. MFA verification (mandatory for CDE access)
    if NOT mfaService.verify(user, credentials.mfaCode, credentials.mfaMethod):
        auditLog.warn("MFA_FAILED", {
            userId: user.id,
            mfaMethod: credentials.mfaMethod
        })
        throw AuthenticationException("MFA verification failed")

    // 4. Create secure session
    rateLimiter.reset(credentials.username)
    session = sessionManager.create(user, {
        maxAge: 15.minutes,
        secure: true,
        httpOnly: true,
        sameSite: "Strict"
    })
    auditLog.log("AUTH_SUCCESS", {
        userId: user.id,
        sessionId: session.id,
        sourceIp: request.remoteIp
    })

    return session
```

## Requirement 10: Log and Monitor All Access to Network Resources

### Audit Logging Requirements

| Event Type | Mandatory Fields | Retention |
|-----------|-----------------|-----------|
| CHD access | User ID, timestamp, resource, action, result | 1 year |
| Authentication (success/failure) | User ID, timestamp, source IP, result | 1 year |
| Authorization decisions | User ID, resource, action, decision, reason | 1 year |
| Privileged access | Admin ID, action, timestamp, affected resource | 1 year |
| Configuration changes | User ID, change type, before/after, timestamp | 1 year |
| Log initialization/stopping | System, timestamp, user ID (if manual) | 1 year |

```
// Audit log structure aligned with Requirement 10
class AuditLogEvent:
    eventId: UUID                        // Unique event identifier
    timestamp: Instant                   // ISO-8601, NTP-synchronized
    eventType: AuditEventType            // Enum: CHD_ACCESS, AUTH_SUCCESS, etc.
    userId: String                       // Unique user identifier
    sourceIp: String                     // Client IP address
    resource: String                     // Resource accessed (PAN reference masked)
    action: String                       // Action performed (READ, WRITE, DELETE)
    result: OperationResult              // SUCCESS, FAILURE, with error code if failed
    details: Map<String, String>         // Additional context (never includes full PAN)

// Append-only, tamper-proof logging
@Component
class TamperProofAuditLogger:

    function log(event: AuditLogEvent):
        // 1. Serialize to JSON
        json = objectMapper.writeValueAsString(event)

        // 2. Hash for integrity verification
        hash = sha256(json + lastEventHash)  // Chain-hash for tampering detection

        // 3. Write to append-only storage (WORM, blockchain-backed, or dedicated audit DB)
        auditStore.append({
            eventJson: json,
            hash: hash,
            timestamp: event.timestamp
        })

        // 4. Write to SIEM integration
        siemConnector.publish(event)

        lastEventHash = hash
```

### Tamper-Evident Logs

- Logs stored in append-only (WORM) storage
- Cryptographic hash chain for tampering detection
- Separate access controls from application database
- Immutable storage (blockchain-backed or dedicated audit database)
- Minimum 1 year retention; 3 months immediately accessible

## Requirement 11: Test Security Systems Regularly

### Testing and Validation

| Testing Type | Frequency | Requirement |
|-------------|-----------|-------------|
| Penetration testing | Annual minimum; after major changes | Document findings; track to remediation |
| Vulnerability scanning | Quarterly minimum; after patches | Address critical/high findings within 30 days |
| WAF rule updates | Continuous monitoring; update rules with threats | Test rule changes in staging first |
| Configuration review | Quarterly | Verify hardened configuration maintained |

```
// Automated security testing in CI/CD
@Component
class SecurityTestingOrchestrator:

    function runSecurityTests():
        // 1. Static analysis (SAST)
        sastResults = sonarqubeClient.runAnalysis()
        if sastResults.hasCriticalFindings():
            blockBuild("SAST found critical issues")

        // 2. Dependency vulnerability scan (SCA)
        scaResults = snykClient.scanDependencies()
        if scaResults.hasCriticalVulnerabilities():
            blockBuild("SCA found critical vulnerabilities")

        // 3. Container image scan
        imageResults = trivyScanner.scanImage(dockerImage)
        if imageResults.hasCriticalVulnerabilities():
            blockBuild("Container image has critical vulnerabilities")

        // 4. DAST (scheduled; more thorough)
        dastResults = owasp_zap.activeScan(stagingUrl)
        if dastResults.hasCriticalFindings():
            notifySecurityTeam("DAST found critical issues")
```

## Implementation Patterns

### PAN Tokenization Pattern

Tokenization is the preferred mechanism for scope reduction, moving CHD handling into a dedicated CDE with tokenized references in non-CDE systems.

```
// Token vault service (in CDE)
@Service
class TokenVault:

    function tokenize(pan):
        // Generate format-preserving token (16 digits for consistency)
        token = generateFormatPreservingToken(pan)

        // Store PAN encrypted under this token
        tokenStore.put(token, encryptWithMasterKey(pan))

        // Log tokenization
        auditLog.log("PAN_TOKENIZED", {
            token: token,
            timestamp: utcNow()
        })

        return token

    function detokenize(token):
        // Restricted: only payment processor can detokenize
        if NOT currentUser.hasRole("PAYMENT_PROCESSOR"):
            throw ForbiddenException("Detokenization not allowed")

        // Retrieve and decrypt
        pan = decryptWithMasterKey(tokenStore.get(token))

        // Audit the detokenization
        auditLog.log("PAN_DETOKENIZED", {
            token: token,
            timestamp: utcNow(),
            user: currentUser.id
        })

        return pan
```

### Key Rotation Pattern

```
// Automated key rotation for encryption keys
@Configuration
@EnableScheduling
class KeyRotationConfiguration:

    @Scheduled(cron = "0 0 1 1 *")  // Monthly on the 1st
    function rotateEncryptionKeys():
        // 1. Generate new key
        newKey = keyStore.generateNewKey("pci-pan-encryption")

        // 2. Mark old key as deprecated (still valid for decryption)
        oldKey = keyStore.getLatestKey("pci-pan-encryption")
        keyStore.deprecateKey(oldKey.id)

        // 3. Schedule re-encryption job (async)
        reEncryptionService.scheduleReEncryptionWithNewKey(newKey)

        // 4. Audit the rotation
        auditLog.log("KEY_ROTATED", {
            keyName: "pci-pan-encryption",
            newKeyId: newKey.id,
            timestamp: utcNow()
        })
```

### Audit Log Service Pattern

```
// Dedicated audit log service for immutable recording
@Service
class AuditLogService:

    function log(event: SecurityEvent):
        // 1. Serialize with versioning
        auditRecord = {
            version: "1.0",
            timestamp: utcNow(),
            eventType: event.type,
            userId: event.userId,
            sourceIp: event.sourceIp,
            resource: event.resource,
            action: event.action,
            result: event.result,
            details: event.details
        }

        // 2. Append to immutable log (database, WORM storage, or blockchain)
        auditStore.append(auditRecord)

        // 3. Publish to SIEM
        siemConnector.publish(auditRecord)

        // 4. Verify integrity
        if NOT verifyIntegrity(auditRecord):
            alerting.critical("AUDIT_LOG_TAMPERING_DETECTED")
```

## Anti-Patterns (FORBIDDEN)

- Log full PAN in application logs, even at DEBUG level
- Store Sensitive Authentication Data (CVV, PIN, track data) after authorization
- Allow non-CDE services direct database access to CHD
- Use shared accounts for CDE system access
- Deploy payment applications without security review and testing
- Use deprecated encryption for PAN (DES, 3DES, RC4, or ECB mode)
- Store PAN and encryption keys in the same database
- Transmit CHD over unencrypted connections
- Rely on client-side input validation only; skip server-side validation
- Disable security logging to reduce operational overhead
- Share encryption keys across multiple environments (dev, staging, prod)
- Deploy without automated security testing gates in CI/CD
- Store database backups without encryption
- Implement tokenization without audit logging
- Allow PAN to remain in memory longer than necessary; fail to zero-fill
