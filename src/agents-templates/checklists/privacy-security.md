### When LGPD or GDPR is active, ADD these checks (10 points):

#### Data Subject Rights (36-39)
36. Personal data export endpoint exists (right of access/portability)
37. Personal data deletion/anonymization capability exists (right to erasure)
38. Consent revocation propagates to all processing systems
39. Audit trail for personal data access exists and is queryable

#### Data Minimization (40-42)
40. API responses include only necessary personal data for the use case
41. PII masked in logs, traces, and error messages
42. Data retention policies enforced (automated purge for expired data)

#### Privacy by Design (43-45)
43. PII fields annotated/marked in domain models (@PersonalData or equivalent)
44. Automated PII detection configured for log scanning
45. Cross-border data transfer restrictions respected (data residency)
