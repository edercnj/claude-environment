---
description: "Review API gateway configuration for best practices"
argument-hint: "[gateway config files or PR]"
---

# API Gateway Review

## Purpose
Reviews API gateway configuration against the patterns defined in the project's gateway knowledge pack.

## Workflow
1. Read the active gateway knowledge pack from `skills/knowledge-packs/api-gateway.md`
2. Identify gateway configuration files in the change
3. Verify routing rules, authentication, rate limiting, CORS
4. Check security headers and TLS configuration
5. Validate observability integration (access logs, tracing)
6. Produce a gateway review report

## Output Format
```
## Gateway Review — [Change Description]

### Gateway Type: [Kong/Istio/AWS APIGW/Traefik]

### Findings
1. [Finding with file, line, remediation]

### Verdict: APPROVE / REQUEST CHANGES
```
