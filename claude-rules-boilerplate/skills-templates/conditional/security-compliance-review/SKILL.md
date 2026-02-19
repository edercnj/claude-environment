---
description: "Review code changes for compliance with selected security frameworks"
argument-hint: "[PR number or file paths]"
---

# Security Compliance Review

## Purpose
Reviews code changes against the compliance frameworks selected in the project configuration.

## Active Compliance Frameworks
Check `rules/18-compliance-*.md` files to determine which frameworks are active.

## Workflow
1. Identify which compliance rules are loaded (PCI-DSS, LGPD, GDPR, HIPAA, SOX)
2. For each active framework, verify the change against framework-specific requirements
3. Check sensitive data handling (classification, masking, encryption)
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
