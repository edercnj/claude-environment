# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 04 — Git Workflow and Commits

## Branch Strategy

```
main (stable) <- feature/{TICKET}-description
```

## Branch Naming

```
feat/{TICKET}-short-kebab-description
fix/{TICKET}-short-kebab-description
```

Maximum 50 characters. Examples:
- `feat/STORY-001-user-authentication`
- `feat/STORY-009-merchant-api`
- `fix/STORY-004-parsing-error`

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
| build | Build, dependencies, CI/CD |
| chore | General maintenance |
| infra | Infrastructure, deployment configuration |

### Scopes

Define scopes based on your project's bounded contexts and layers. Examples:

| Scope | Area |
|-------|------|
| domain | Domain model and business logic |
| api | REST / GraphQL / gRPC API |
| persistence | Database adapter |
| config | Application configuration |
| migration | Database migrations |
| docker | Dockerfile and compose |
| k8s | Kubernetes manifests |

> **Customize:** Add domain-specific scopes for your project (e.g., `auth`, `billing`, `notifications`, `{protocol-name}`).

### Rules

- Maximum **72 characters** on first line
- Imperative mode in English: "add", "fix", "implement" (not "added", "fixing")
- One logical change per commit
- Examples:
  - `feat(api): add merchant CRUD endpoints`
  - `feat(domain): implement cents-based authorization rule`
  - `test(domain): add parametrized tests for decision engine`
  - `infra(k8s): add database StatefulSet manifest`
  - `build(docker): add multi-stage Dockerfile`

## Workflow per Story/Ticket

1. Create branch: `git checkout -b feat/{TICKET}-description`
2. Implement (atomic commits)
3. Run tests: `{BUILD_TOOL} verify` / `{BUILD_TOOL} test`
4. Push: `git push -u origin feat/{TICKET}-description`
5. Create PR via `gh pr create`
6. Merge to main after approval

## Checklist Before Merge

- [ ] Tests passing (full test suite)
- [ ] Coverage >= 95% line, >= 90% branch
- [ ] No compiler/linter warnings
- [ ] Database migration applied and tested (if applicable)
- [ ] Infrastructure manifests updated (if applicable)
- [ ] Application configuration updated (if applicable)
- [ ] Smoke tests passing (if available)

## Anti-Patterns

- Commits mixing unrelated changes
- Commit messages in past tense ("added" instead of "add")
- Commits without scope when scope is obvious
- Force-pushing to shared branches
- Merging without passing CI
- Committing generated files, secrets, or large binaries
