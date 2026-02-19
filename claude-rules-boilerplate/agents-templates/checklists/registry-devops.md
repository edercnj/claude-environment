## Container Registry Checklist (Conditional — when infrastructure.registry != none) — 4 points

40. Image tagging: {service}:{version}-{git-sha-short} (never latest in prod)
41. Tag immutability enabled
42. Vulnerability scanning on push
43. Retention policy configured (auto-delete old/untagged images)
