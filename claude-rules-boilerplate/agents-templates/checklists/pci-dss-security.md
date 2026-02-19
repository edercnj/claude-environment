### When PCI-DSS is active, ADD these checks (15 points):

#### Cardholder Data (21-25)
21. PAN never stored in full (masked first 6 + last 4, or tokenized)
22. CVV/CVC/PIN NEVER persisted after authorization
23. PAN never appears in logs, traces, error messages at ANY level
24. Cardholder data encrypted at rest with AES-256 minimum
25. Audit log records ALL access to cardholder data (who, what, when, where)

#### CDE Security (26-30)
26. Service in Cardholder Data Environment uses mTLS for service-to-service
27. No direct internet access from CDE services (proxy/gateway only)
28. Session timeout configured (15 minutes inactivity)
29. Unique user ID for all access (no shared/generic service accounts)
30. MFA enforced for administrative access paths

#### Application Security — PCI Req 6 (31-35)
31. SAST scan results available and clean (no critical/high findings)
32. Error messages generic to users (no internal details, stack traces, SQL)
33. WAF configuration appropriate for public-facing endpoints
34. Code review completed as merge gate (not optional)
35. Secure coding training tracked (annual requirement)
