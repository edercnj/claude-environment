# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Application Security

## OWASP Top 10 (2021) — Implementation Guidelines

### A01:2021 — Broken Access Control

- Deny by default: every endpoint requires explicit authorization
- Enforce server-side access control; never rely on client-side checks
- Disable directory listing; remove default credentials
- Rate-limit API and controller access to minimize automated attacks
- Invalidate JWT/session tokens on logout; use short-lived access tokens
- Implement RBAC or ABAC consistently across all endpoints

```
// GOOD — Explicit authorization check before resource access
function getResource(userId, resourceId):
    resource = repository.find(resourceId)
    if resource.ownerId != userId AND NOT hasRole(userId, "ADMIN"):
        throw ForbiddenException("Access denied")
    return resource

// BAD — Relies on client-side filtering
function getResource(resourceId):
    return repository.find(resourceId)  // No ownership check
```

### A02:2021 — Cryptographic Failures

- Classify data processed, stored, or transmitted; apply controls per classification
- Never store sensitive data unnecessarily; discard it as soon as possible
- Encrypt all sensitive data at rest (AES-256-GCM minimum)
- Enforce TLS 1.3 for all data in transit; disable older protocols
- Use strong adaptive hashing for passwords (argon2id, bcrypt cost >= 12)
- Never use deprecated algorithms (MD5, SHA-1, DES, RC4)

### A03:2021 — Injection

- Use parameterized queries / prepared statements for ALL database access
- Use ORM with parameterized bindings; never concatenate user input into queries
- Apply server-side input validation using allowlists
- Escape output based on context (HTML, JS, URL, CSS, LDAP)
- Limit query result sets with `LIMIT` to prevent mass data disclosure

```
// GOOD — Parameterized query
query = "SELECT * FROM users WHERE email = ? AND status = ?"
result = db.execute(query, [email, status])

// BAD — String concatenation
query = "SELECT * FROM users WHERE email = '" + email + "'"
result = db.execute(query)
```

### A04:2021 — Insecure Design

- Use threat modeling for critical business flows (STRIDE, PASTA)
- Establish secure design patterns library for the team
- Implement rate limiting on resource-intensive operations
- Integrate security into user stories with abuse cases
- Use defense in depth: validate at every architectural layer

### A05:2021 — Security Misconfiguration

- Automate hardened environment configuration (IaC)
- Remove unused features, frameworks, components, and documentation
- Review and update all security configurations as part of patch management
- Segment application architecture; isolate tenants and components
- Send security directives to clients via security headers (see below)
- Disable XML external entity (XXE) processing in all XML parsers

### A06:2021 — Vulnerable and Outdated Components

- Remove unused dependencies, features, and components
- Continuously inventory client-side and server-side component versions
- Monitor CVE databases (NVD, GitHub Advisories) for vulnerabilities
- Obtain components only from official sources over secure links
- Pin exact dependency versions; use lock files
- See **Dependency Security** section below for CVE policy

### A07:2021 — Identification and Authentication Failures

- Implement multi-factor authentication where possible
- Never ship or deploy default credentials
- Implement weak-password checks against top 10,000 breached passwords list
- Harden all authentication paths: login, registration, password reset
- Limit failed authentication attempts with exponential backoff and account lockout
- Use secure session management: server-side, high-entropy, invalidate on logout

```
// GOOD — Rate-limited authentication with lockout
function authenticate(username, password):
    if rateLimiter.isBlocked(username):
        throw TooManyRequestsException("Account temporarily locked")
    user = userRepository.findByUsername(username)
    if NOT passwordEncoder.matches(password, user.hashedPassword):
        rateLimiter.recordFailure(username)
        throw UnauthorizedException("Invalid credentials")
    rateLimiter.reset(username)
    return sessionManager.createSession(user)
```

### A08:2021 — Software and Data Integrity Failures

- Verify software and data integrity via digital signatures
- Ensure CI/CD pipelines have proper segregation, configuration, and access control
- Do not send unsigned or unencrypted serialized data to untrusted clients
- Use dependency integrity verification (checksums, signed packages)
- Implement code review process for all changes to code and infrastructure

### A09:2021 — Security Logging and Monitoring Failures

- Log all authentication events (success and failure)
- Log all access control failures
- Log all server-side input validation failures
- Ensure logs have enough context for forensic analysis
- Ensure logs are not vulnerable to injection attacks
- Implement alerting thresholds for suspicious activity patterns
- Never log sensitive data (passwords, tokens, PII) — see Rule 07

### A10:2021 — Server-Side Request Forgery (SSRF)

- Validate and sanitize ALL client-supplied URLs
- Enforce allowlist of permitted URL schemes (https only where possible)
- Block requests to private/internal IP ranges (10.x, 172.16.x, 192.168.x, 127.x, 169.254.x)
- Disable HTTP redirects for server-side requests
- Do not return raw responses from server-side requests to the client

```
// GOOD — URL validation with allowlist
function fetchExternalResource(url):
    parsed = parseUrl(url)
    if parsed.scheme NOT IN ["https"]:
        throw ValidationException("Only HTTPS allowed")
    if isPrivateIp(parsed.host):
        throw ValidationException("Internal addresses not allowed")
    if parsed.host NOT IN allowedDomains:
        throw ValidationException("Domain not in allowlist")
    return httpClient.get(url, followRedirects=false, timeout=5s)
```

## Security Headers

All HTTP services MUST include the following response headers:

| Header | Value | Purpose |
|--------|-------|---------|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | Force HTTPS for 1 year, include subdomains |
| `Content-Security-Policy` | Per application needs (strict) | Prevent XSS, clickjacking, data injection |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME type sniffing |
| `X-Frame-Options` | `DENY` or `SAMEORIGIN` | Prevent clickjacking |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Control referrer information leakage |
| `Permissions-Policy` | Disable unused features: `camera=(), microphone=(), geolocation=()` | Restrict browser feature access |
| `Cache-Control` | `no-store` for sensitive endpoints; `public, max-age=N` for static | Prevent sensitive data caching |
| `X-Request-ID` | UUID per request (generated or forwarded) | Distributed tracing correlation |

### CSP Configuration Example

```
# API-only services (strictest)
Content-Security-Policy: default-src 'none'; frame-ancestors 'none'

# Web applications (adjust per requirements)
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self' https://api.example.com; frame-ancestors 'none'; base-uri 'self'; form-action 'self'
```

### Implementation Pattern

```
// Middleware / Filter pattern for security headers
function securityHeadersMiddleware(request, response, next):
    response.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload")
    response.setHeader("X-Content-Type-Options", "nosniff")
    response.setHeader("X-Frame-Options", "DENY")
    response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin")
    response.setHeader("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
    response.setHeader("X-Request-ID", request.getHeader("X-Request-ID") OR generateUUID())
    next(request, response)
```

## Secrets Management

### Hierarchy (least to most secure)

| Level | Method | When Acceptable |
|-------|--------|----------------|
| 1 | Environment variables | Local development only |
| 2 | Encrypted config files | CI/CD pipelines with encrypted storage |
| 3 | Platform secrets (K8s Secrets, AWS Parameter Store) | Staging environments |
| 4 | Secrets vault (HashiCorp Vault, AWS Secrets Manager) | **Production (preferred)** |

### Mandatory Rules

- **Never in source:** No secrets in code, configuration files, or container images
- **Environment variables:** Acceptable minimum; vault integration is preferred
- **Vault preferred:** Use centralized secrets management in production
- **Rotation:** Implement automated rotation policies per secret type
- **Short-lived credentials:** Prefer dynamic secrets with TTL (database credentials, API tokens)
- **Per-environment secrets:** Never share secrets across environments (dev, staging, prod)
- **Access audit:** Log all secret access; alert on anomalous patterns

### Rotation Policy

| Secret Type | Rotation Frequency | Method |
|-------------|-------------------|--------|
| Database passwords | 90 days | Automated via vault |
| API keys | 180 days | Automated via vault |
| TLS certificates | 90 days (or auto via ACME) | Automated via cert-manager |
| Encryption keys | 365 days | Automated via KMS |
| Service account tokens | 24 hours (dynamic) | Vault dynamic secrets |

## Input Validation Framework

### Principles

- **Validate at boundary:** All validation occurs at the entry point (API handler, message consumer, event listener)
- **Allowlist over denylist:** Define what IS allowed, not what is NOT
- **Type/range/format:** Validate data type, acceptable range, and format
- **Sanitize for output context:** Escape data based on where it will be rendered (HTML, SQL, JS, URL)
- **Max length on everything:** Every string field has an explicit maximum length
- **Content-type validation:** Validate file uploads by content inspection, not just extension

### Validation Layers

| Layer | Validates | Example |
|-------|-----------|---------|
| Transport | Size, encoding, content-type header | Max body 1MB, UTF-8 only |
| Schema | Structure, required fields, types | JSON Schema, OpenAPI, Protobuf |
| Business | Domain constraints, cross-field rules | Amount > 0, startDate < endDate |
| Output | Context-appropriate escaping | HTML encoding, SQL parameterization |

### File Upload Validation

```
function validateUpload(file):
    // 1. Check file size
    if file.size > MAX_UPLOAD_SIZE:
        reject("File exceeds maximum size")

    // 2. Validate content-type by inspecting magic bytes, not extension
    detectedType = detectMimeType(file.content)
    if detectedType NOT IN ALLOWED_MIME_TYPES:
        reject("File type not allowed")

    // 3. Validate extension matches content
    if NOT extensionMatchesMime(file.extension, detectedType):
        reject("Extension does not match content")

    // 4. Strip metadata (EXIF, etc.)
    sanitized = stripMetadata(file)

    // 5. Store with generated name, never use original filename
    storedName = generateUUID() + "." + mimeToExtension(detectedType)
    storage.store(sanitized, storedName)
```

## Dependency Security

### Lock Files

- **Always commit lock files** (`package-lock.json`, `pom.xml` with versions, `go.sum`, `Cargo.lock`, `poetry.lock`)
- Never use floating version ranges in production (`^`, `~`, `*`)
- Pin exact versions for all direct dependencies
- Review lock file diffs in code review

### Automated Scanning

- Run dependency vulnerability scanning in CI/CD (Snyk, Dependabot, Trivy, OWASP Dependency-Check)
- Scan on every pull request and on a daily schedule
- Scan both direct and transitive dependencies
- Scan container images for OS-level vulnerabilities

### CVE Response Policy

| Severity | SLA | Action |
|----------|-----|--------|
| **Critical (CVSS >= 9.0)** | Block merge / deploy immediately | Patch or mitigate within 24 hours |
| **High (CVSS 7.0-8.9)** | Block merge / deploy | Patch within 7 days |
| **Medium (CVSS 4.0-6.9)** | Warning, do not block | Patch within 30 days |
| **Low (CVSS < 4.0)** | Informational | Patch within 90 days |

### Private Registry

- Use a private registry / proxy for dependency resolution (Nexus, Artifactory, GitHub Packages)
- Cache approved versions to prevent supply-chain attacks
- Verify package signatures where available
- Block publication of internal packages to public registries

## Anti-Patterns (FORBIDDEN)

- Disable security headers "for convenience"
- Store secrets in source code, environment files committed to VCS, or container images
- Accept user input without validation at the boundary
- Use denylist-based validation instead of allowlist
- Trust file extensions for upload validation
- Use floating dependency versions in production
- Ignore CVE alerts or suppress vulnerability scanner findings
- Skip security headers for internal/microservice APIs
- Hardcode CORS `Access-Control-Allow-Origin: *` on authenticated endpoints
