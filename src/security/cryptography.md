# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Cryptography

## Encryption in Transit

### TLS Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Protocol version | TLS 1.2 | **TLS 1.3** |
| Certificate type | RSA 2048-bit | ECDSA P-256 or RSA 4096-bit |
| Certificate validity | 1 year max | 90 days (auto-renewed via ACME) |
| OCSP stapling | Recommended | **Required** |

### Disabled Protocols and Features

- **Disabled protocols:** SSL 2.0, SSL 3.0, TLS 1.0, TLS 1.1
- **Disabled features:** Compression (CRIME attack), renegotiation (unless secure), 0-RTT replay-vulnerable data
- **Disabled cipher suites:** NULL, EXPORT, DES, RC4, 3DES, MD5-based MACs

### Approved TLS 1.3 Cipher Suites

```
TLS_AES_256_GCM_SHA384
TLS_AES_128_GCM_SHA256
TLS_CHACHA20_POLY1305_SHA256
```

### Approved TLS 1.2 Cipher Suites (when 1.3 not available)

```
TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
```

### Certificate Management

- Automate certificate issuance and renewal (cert-manager, ACME, Let's Encrypt)
- Store private keys in secrets manager or HSM; never in source code
- Monitor certificate expiration; alert at 30, 14, and 7 days before expiry
- Implement certificate pinning only for mobile apps (with backup pins and rotation plan)
- Use separate certificates per environment (dev, staging, production)

### Mutual TLS (mTLS)

- Use mTLS for service-to-service communication in zero-trust networks
- Issue short-lived client certificates (24h-7d) via service mesh or internal CA
- Validate both client and server certificate chains
- Implement certificate rotation without downtime (dual certificate support)

```
// mTLS configuration pattern
tlsConfig:
    minVersion: TLS_1_3
    clientAuth: RequireAndVerifyClientCert
    clientCAs: /etc/ssl/internal-ca.pem
    certificates:
        certFile: /etc/ssl/service.crt
        keyFile: /etc/ssl/service.key
```

## Encryption at Rest

### Approaches

| Approach | Scope | Use When |
|----------|-------|----------|
| Transparent Data Encryption (TDE) | Full database/disk | Default for all persistent storage |
| Application-level encryption | Specific fields/columns | Sensitive fields (PII, financial data) |
| File-level encryption | Individual files | Backups, exports, file storage |

### Requirements

- **Algorithm:** AES-256-GCM (authenticated encryption) for all new implementations
- **Key management:** Use Customer-Managed Keys (CMK) via KMS; never embed keys in application code
- **Backup encryption:** ALL backups must be encrypted with separate keys from primary data
- **Key hierarchy:** Use envelope encryption (data key encrypted by master key)

### Envelope Encryption Pattern

```
// Encrypt data using envelope encryption
function encryptData(plaintext):
    // 1. Generate a unique Data Encryption Key (DEK)
    dek = kms.generateDataKey(masterKeyId)

    // 2. Encrypt the plaintext with the DEK
    ciphertext = aes256gcm.encrypt(plaintext, dek.plaintext)

    // 3. Store encrypted DEK alongside ciphertext
    return {
        encryptedData: ciphertext,
        encryptedDek: dek.ciphertext,  // DEK encrypted by master key
        masterKeyId: masterKeyId,
        algorithm: "AES-256-GCM",
        iv: ciphertext.iv
    }

// Decrypt data
function decryptData(encryptedPayload):
    // 1. Decrypt the DEK using the master key
    dek = kms.decrypt(encryptedPayload.encryptedDek, encryptedPayload.masterKeyId)

    // 2. Decrypt the data using the plaintext DEK
    plaintext = aes256gcm.decrypt(encryptedPayload.encryptedData, dek)
    return plaintext
```

### Application-Level Field Encryption

```
// Encrypt sensitive fields before persistence
@Entity
class Customer:
    id: UUID
    name: String                           // Not encrypted (INTERNAL classification)

    @Encrypted(algorithm="AES-256-GCM")
    email: String                          // Encrypted at rest (RESTRICTED)

    @Encrypted(algorithm="AES-256-GCM")
    taxId: String                          // Encrypted at rest (RESTRICTED)

    @Encrypted(algorithm="AES-256-GCM")
    phoneNumber: String                    // Encrypted at rest (RESTRICTED)
```

## Hashing

### Password Hashing

| Algorithm | Parameters | Use Case |
|-----------|-----------|----------|
| **argon2id** (preferred) | Memory: 64MB, Iterations: 3, Parallelism: 4 | Password storage |
| **bcrypt** (acceptable) | Cost factor: >= 12 | Password storage (legacy systems) |
| **scrypt** (acceptable) | N: 2^17, r: 8, p: 1 | Password storage (alternative) |

**FORBIDDEN for passwords:** MD5, SHA-1, SHA-256 (unsalted), plain text

### Integrity Hashing

| Algorithm | Use Case |
|-----------|----------|
| SHA-256 | File integrity, checksums, content addressing |
| SHA-3 (SHA3-256) | New implementations requiring NIST standard |
| BLAKE3 | High-performance integrity verification |

### HMAC (Message Authentication)

- Use **HMAC-SHA256** for message authentication and API request signing
- Key length must be at least 256 bits
- Use constant-time comparison to prevent timing attacks

```
// GOOD — Constant-time HMAC verification
function verifyWebhook(payload, signature, secret):
    expected = hmacSha256(payload, secret)
    return constantTimeEquals(expected, signature)  // Timing-safe comparison

// BAD — Timing-vulnerable comparison
function verifyWebhook(payload, signature, secret):
    expected = hmacSha256(payload, secret)
    return expected == signature  // Vulnerable to timing attack
```

### Token Generation

- Use **CSPRNG** (Cryptographically Secure Pseudo-Random Number Generator) for all token generation
- Minimum token entropy: 128 bits (32 hex chars or 22 base64 chars)
- Never use `Math.random()`, `rand()`, or similar non-cryptographic PRNGs for security tokens

```
// GOOD — CSPRNG token generation
token = cryptoSecureRandom(32)  // 256-bit token
sessionId = base64UrlEncode(cryptoSecureRandom(32))

// BAD — Predictable token
token = md5(timestamp + username)
sessionId = base64(Math.random().toString())
```

## Key Management

### Centralized Key Management

- Use a centralized key management system: **HashiCorp Vault**, **AWS KMS**, **Azure Key Vault**, **GCP Cloud KMS**
- Never store encryption keys alongside encrypted data
- Never embed keys in application source code or configuration files
- All key operations must be audited

### Key Rotation Policy

| Key Type | Rotation Frequency | Versioning |
|----------|-------------------|------------|
| Data encryption keys | 90 days | Mandatory — keep old versions to decrypt existing data |
| Signing keys | 365 days | Mandatory — old key verifies existing signatures |
| TLS certificates | 90 days | Auto-renewed via ACME |
| API signing keys | 180 days | Versioned (key ID in header) |
| Master keys (KMS) | Annual review | Managed by KMS provider |

### Key Versioning

```
// Key versioning for seamless rotation
function decrypt(ciphertext, metadata):
    keyVersion = metadata.keyVersion
    key = keyStore.getKey(metadata.keyId, keyVersion)
    return aes256gcm.decrypt(ciphertext, key)

// Always encrypt with latest version
function encrypt(plaintext, keyId):
    latestKey = keyStore.getLatestKey(keyId)
    ciphertext = aes256gcm.encrypt(plaintext, latestKey.material)
    return {
        ciphertext: ciphertext,
        keyId: keyId,
        keyVersion: latestKey.version
    }
```

### Separation of Duties

- Key administrators cannot use keys for encryption/decryption
- Application operators cannot create or manage keys
- Audit team has read-only access to key usage logs
- Emergency revocation requires multi-party approval (M-of-N)

### HSM (Hardware Security Module)

- Use HSM for master key storage in high-security environments (PCI-DSS, financial)
- HSM-backed keys never leave the hardware boundary
- FIPS 140-2 Level 3 minimum for production master keys

### Emergency Revocation

```
// Emergency key revocation procedure
function emergencyRevoke(keyId, reason):
    // 1. Disable key immediately
    keyStore.disableKey(keyId)

    // 2. Log revocation event
    auditLog.critical("KEY_REVOKED", {keyId, reason, revokedBy, timestamp})

    // 3. Alert security team
    alerting.sendCritical("Encryption key revoked: " + keyId)

    // 4. Trigger re-encryption with new key (async)
    reEncryptionService.scheduleReEncryption(keyId)
```

## Digital Signatures

### API Request Signing

- Sign API requests using HMAC-SHA256 or RSA/ECDSA for non-repudiation
- Include timestamp in signed payload to prevent replay attacks
- Reject requests with timestamps older than 5 minutes

```
// API request signing pattern
function signRequest(method, path, body, timestamp, secretKey):
    payload = method + "\n" + path + "\n" + timestamp + "\n" + sha256(body)
    signature = hmacSha256(payload, secretKey)
    return base64Encode(signature)

// Headers
X-Timestamp: 1700000000
X-Signature: base64(hmac-sha256(payload, key))
X-Key-Id: key-version-identifier
```

### JWT Signing

| Algorithm | Key Type | Use When |
|-----------|----------|----------|
| **RS256** | RSA 2048+ | Widely supported, asymmetric verification needed |
| **ES256** | ECDSA P-256 | Smaller tokens, modern systems |
| **EdDSA** | Ed25519 | Highest performance, modern systems |

**FORBIDDEN JWT algorithms:** `none`, HS256 with public key confusion, RSA with key < 2048 bits

```
// JWT best practices
jwt.create({
    issuer: "auth-service",
    audience: "api-service",
    subject: userId,
    expiration: now() + 15.minutes,       // Short-lived access tokens
    notBefore: now(),
    jwtId: generateUUID(),                 // Unique token ID for revocation
    algorithm: "ES256",
    key: signingPrivateKey
})
```

### Code Signing

- Sign all release artifacts (binaries, container images, packages)
- Verify signatures in CI/CD pipelines before deployment
- Use cosign/sigstore for container image signing
- Store signing keys in HSM or vault

### Webhook Signatures

- Sign all outgoing webhooks with HMAC-SHA256
- Include signature in header (`X-Signature-256`)
- Document signature verification for consumers
- Rotate webhook secrets on a regular schedule

## Tokenization

### Principles

- **Non-reversible tokens:** Tokenization must not be reversible without access to the token vault
- **Isolated vault:** Token-to-value mapping stored in a separate, hardened database
- **Detokenization audit:** Every detokenization operation must be logged with requester identity and purpose
- **Format-preserving:** Tokens maintain the format of the original data (e.g., 16-digit token for a 16-digit PAN)

### Tokenization Pattern

```
// Tokenize sensitive data
function tokenize(sensitiveValue, format):
    // 1. Generate format-preserving token
    token = tokenVault.generateToken(format)

    // 2. Store mapping in isolated vault
    tokenVault.store(token, encrypt(sensitiveValue))

    // 3. Audit the tokenization event
    auditLog.log("TOKENIZED", {format, requester, timestamp})

    return token

// Detokenize (restricted access)
function detokenize(token, purpose, requester):
    // 1. Verify requester authorization
    if NOT authorized(requester, "DETOKENIZE"):
        throw ForbiddenException("Not authorized to detokenize")

    // 2. Retrieve and decrypt original value
    encryptedValue = tokenVault.retrieve(token)
    originalValue = decrypt(encryptedValue)

    // 3. Audit the detokenization event
    auditLog.log("DETOKENIZED", {token, purpose, requester, timestamp})

    return originalValue
```

### Use Cases

| Data Type | Tokenization Format | Example |
|-----------|-------------------|---------|
| PAN (Credit Card) | Format-preserving (16 digits) | `4111111111111111` -> `9832748291038472` |
| SSN | Format-preserving (NNN-NN-NNNN) | `123-45-6789` -> `987-65-4321` |
| Bank Account | Random token with prefix | `ACCT-a8f3b9c2e1d4` |
| Email | Random token | `TOK-7f8a9b3c2d1e` |

## Deprecated/Forbidden Algorithms

| Algorithm | Status | Replacement |
|-----------|--------|-------------|
| MD5 | **FORBIDDEN** | SHA-256 or SHA-3 |
| SHA-1 | **FORBIDDEN** | SHA-256 or SHA-3 |
| DES / 3DES | **FORBIDDEN** | AES-256-GCM |
| RC4 | **FORBIDDEN** | AES-256-GCM or ChaCha20 |
| RSA < 2048 bits | **FORBIDDEN** | RSA 4096 or ECDSA P-256 |
| ECB mode | **FORBIDDEN** | GCM or CBC with HMAC |
| PKCS#1 v1.5 padding | **DEPRECATED** | OAEP (RSA) |
| bcrypt cost < 12 | **FORBIDDEN** | bcrypt cost >= 12 or argon2id |

## Anti-Patterns (FORBIDDEN)

- Use deprecated or broken cryptographic algorithms
- Store encryption keys in source code, config files, or alongside encrypted data
- Use ECB mode for any encryption operation
- Generate security tokens with non-cryptographic PRNGs
- Compare HMAC values using non-constant-time functions
- Implement custom cryptographic algorithms or protocols
- Skip certificate validation in production
- Use the same encryption key across environments
- Store password hashes using fast hash algorithms (SHA-256, MD5)
- Hardcode initialization vectors (IVs) or reuse IVs with the same key
