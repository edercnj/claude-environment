## IaC Checklist (Conditional — when infrastructure.iac != none) — 6 points

### State & Security (29-31)
29. Remote state backend configured (S3+DynamoDB, GCS, Azure Blob)
30. State file encrypted at rest
31. No secrets in .tf/.yaml files (use variables + vault)

### Quality (32-34)
32. Modules used for reusable infrastructure components
33. Outputs defined for cross-module references
34. Plan reviewed before apply (CI runs plan on PR)
