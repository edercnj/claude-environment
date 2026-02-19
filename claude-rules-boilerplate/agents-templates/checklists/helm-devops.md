## Helm Checklist (Conditional — when infrastructure.templating == helm) — 8 points

### Chart Quality (21-24)
21. Chart.yaml has semantic version (appVersion ≠ chart version)
22. values.yaml: every value documented with comments
23. Templates use _helpers.tpl for reusable snippets
24. helm test defined for post-deployment validation

### Security & Operations (25-28)
25. Secrets not in values.yaml (use external secrets or sealed secrets)
26. Resource requests/limits defined in default values
27. PDB and HPA configurable via values
28. No `helm install` in production (GitOps: ArgoCD/Flux)
