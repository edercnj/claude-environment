---
name: compliance
description: "Compliance frameworks (conditionally included): GDPR, HIPAA, LGPD, PCI-DSS, SOX. Data classification, rights enforcement, processing records, international transfers, security measures, audit logging, and framework-specific requirements."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Compliance

## Purpose

Provides compliance framework guidance for {{LANGUAGE}} {{FRAMEWORK}} projects subject to regulatory requirements. Includes data classification schemes, enforcement of data subject rights, processing record management, international transfer controls, security measure implementation, and audit logging patterns. Frameworks included based on project configuration: GDPR, HIPAA, LGPD, PCI-DSS, SOX.

## Quick Reference (always in context)

See `skills/security/references/security-principles.md` for the security and data classification summary (data classification, sensitive data handling, fail-secure patterns).

## Detailed References

Read these files for framework-specific compliance patterns:

| Reference | Content |
|-----------|---------|
| `security/compliance/gdpr.md` | Lawful basis determination (Art. 6), data subject rights implementation (Art. 17-22), data minimization (Art. 5), processing records (Art. 37), international transfers (Art. 33-36), security measures (Art. 46), incident response (Art. 48) |
| `security/compliance/hipaa.md` | PHI identification and classification, access control by role, encryption at rest (AES-256) and in transit (TLS 1.3), audit logging and monitoring, breach notification procedures, business associate agreements, minimum necessary principle |
| `security/compliance/lgpd.md` | Lawful basis enforcement, data subject rights API endpoints, data minimization patterns, processing records (ROPA generation), international transfer controls with legal basis, retention engine implementation, anonymization techniques, consent service |
| `security/compliance/pci-dss.md` | PAN (Primary Account Number) tokenization vs encryption, secure transmission (TLS, no storage in logs/memory), access control to cardholder data, multi-factor authentication, monitoring and logging, vulnerability management, annual assessment |
| `security/compliance/sox.md` | Financial data integrity controls, audit trail immutability, change management (segregation of duties), access controls (least privilege), system monitoring, compliance reporting and reconciliation, disaster recovery and business continuity |
| `security/application-security.md` | OWASP Top 10 implementation (A01-A10), security headers, input validation framework, dependency security, CVE response policy, penetration testing readiness |
| `security/cryptography.md` | Encryption in transit (TLS 1.3), encryption at rest (AES-256-GCM), hashing algorithms (argon2id for passwords, SHA-256 for integrity), key management (KMS, rotation), digital signatures, tokenization patterns |
