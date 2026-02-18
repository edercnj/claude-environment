# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 06 — Git Workflow and Commits

## Branch Strategy
```
main (stable) ← feature/STORY-NNN-description
```

## Branch Naming
```
feat/STORY-NNN-short-kebab-description
```
Maximum 50 characters. Examples:
- `feat/STORY-001-socket-echo-test`
- `feat/STORY-002-debit-sale`
- `feat/STORY-009-merchant-api`
- `fix/STORY-004-reversal-de90-parse`

## Commit Format (Conventional Commits)
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types
| Type | When |
|------|------|
| feat | New feature |
| test | Tests only |
| fix | Bug fix |
| refactor | Restructuring without behavior change |
| docs | Documentation |
| build | Build, deps, CI/CD |
| chore | General maintenance |
| infra | Kubernetes, Docker, deploy configuration |

### Scopes
| Scope | Area |
|-------|------|
| socket | TCP Socket Adapter |
| rest | REST API Adapter |
| domain | Domain model and engine |
| persistence | PostgreSQL Adapter |
| k8s | Kubernetes manifests |
| docker | Dockerfile and compose |
| config | Quarkus configuration |
| migration | Flyway migrations |
| debit | Debit handler |
| credit | Credit handler |
| reversal | Reversal handler |
| voucher | Voucher handler |
| transport | Transport handler |
| preauth | Pre-authorization handler |
| merchant | Merchant/terminal API |
| echo | Echo test handler |

### Rules
- Maximum **72 characters** on first line
- Imperative mode in English: "add", "fix", "implement" (not "added", "fixing")
- One logical change per commit
- Examples:
  - `feat(socket): add TCP server with 2-byte framing`
  - `feat(debit): implement cents-based authorization rule`
  - `test(debit): add parametrized tests for all cent values`
  - `infra(k8s): add PostgreSQL StatefulSet manifest`
  - `build(docker): add multi-stage Dockerfile for native build`

## Workflow per Story
1. Create branch: `git checkout -b feat/STORY-NNN-description`
2. Implement (atomic commits)
3. Run tests: `mvn verify`
4. Push: `git push -u origin feat/STORY-NNN-description`
5. Create PR via `gh pr create`
6. Merge to main after approval

## Checklist Before Merge
- [ ] Tests passing (`mvn verify`)
- [ ] Coverage ≥ 95% line, ≥ 90% branch
- [ ] Javadoc on public classes/methods
- [ ] No compiler warnings
- [ ] Flyway migration applied and tested
- [ ] K8S manifests updated (if applicable)
- [ ] application.properties configured
- [ ] Smoke tests passing (if available — see Rule 22 and skills `smoke-test-api` / `smoke-test-socket`)
