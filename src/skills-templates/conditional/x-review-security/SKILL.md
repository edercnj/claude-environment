---
name: x-review-security
description: "Review code changes for compliance with selected security frameworks"
argument-hint: "[PR number or file paths]"
---
name: x-review-security

# Security Compliance Review

## Purpose
Reviews code changes against the compliance frameworks selected in the project configuration.

## Knowledge Pack References

Read these before starting the review:
- `skills/security/references/security-principles.md` — data classification, input validation, fail-secure patterns
- `skills/security/references/application-security.md` — OWASP Top 10, security headers, secrets management
- `skills/compliance/SKILL.md` → then read each file in `skills/compliance/references/` for active frameworks

## Workflow
1. Read `skills/compliance/references/` to identify active frameworks (PCI-DSS, LGPD, GDPR, HIPAA, SOX)
2. For each active framework, verify the change against framework-specific requirements
3. Check sensitive data handling (classification, masking, encryption) per `skills/security/references/cryptography.md`
4. Verify audit trail requirements are met
5. Check access control patterns
6. Produce a compliance review report

## Output Format
```
## Compliance Review — [Change Description]

### Active Frameworks: [list]

### Per-Framework Results

#### [Framework Name]
- [x] Requirement met / [ ] Gap identified
- Finding: [description + remediation]

### Overall Verdict: COMPLIANT / NON-COMPLIANT / NEEDS REVIEW
```
