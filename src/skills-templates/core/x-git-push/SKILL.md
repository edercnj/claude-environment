---
name: x-git-push
description: "Git operations: branch creation, atomic commits (Conventional Commits), push, and PR creation. Use for any git workflow task including branching, committing, pushing, creating PRs, or managing version control."
allowed-tools: Bash, Read
argument-hint: "[branch-name or commit-message]"
---

## Global Output Policy

- **Language**: English ONLY.
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.

# Skill: Commit and Push

## Purpose

Standardizes the Git workflow for {{PROJECT_NAME}}. Every feature starts with a branch and ends with a clean commit history following Conventional Commits.

## Branch Strategy

```
main (stable, always green)
  +-- feat/STORY-NNN-short-description
```

### Branch Naming

**Pattern:** `feat/STORY-NNN-short-kebab-description`

**Rules:**
- Always prefix with `feat/` (or `fix/`, `refactor/` as appropriate)
- Include the story/issue identifier
- Short description in kebab-case (English)
- Maximum 50 characters total

### Creating a Branch

```bash
git checkout main
git pull origin main
git checkout -b feat/STORY-NNN-description
```

## Commit Convention (Conventional Commits)

### Format

```
<type>(<scope>): <subject>

<optional body>

<optional footer>
```

### Types

| Type       | When to use                                |
| ---------- | ------------------------------------------ |
| `feat`     | New feature                                |
| `test`     | Adding or modifying tests only             |
| `fix`      | Bug fix                                    |
| `refactor` | Restructuring without behavior change      |
| `docs`     | Documentation changes                      |
| `build`    | Build system changes                       |
| `chore`    | Maintenance tasks                          |
| `infra`    | Infrastructure and deployment changes      |

### Scopes

Use the module, package, or component name as scope. Define project-specific scopes based on the architecture (e.g., `domain`, `rest`, `persistence`, `config`).

### Rules

1. **Atomic commits** -- One logical change per commit
2. **Subject line** -- Max 72 characters, imperative mood ("add" not "added"), no period at end
3. **Body** -- Optional. Explain "why" not "what". Wrap at 72 characters
4. **Tests with features** -- Feature commits should include their tests

## Workflow Per Story

### Starting a Story

```bash
git checkout main
git pull origin main
git checkout -b feat/STORY-NNN-description
git status
```

### During Implementation

Make frequent, atomic commits:

```bash
git add src/main/path/to/Feature.{{LANGUAGE}}
git add src/test/path/to/FeatureTest.{{LANGUAGE}}
git commit -m "feat(scope): add feature description"
```

### Finishing a Story

```bash
# 1. Run full build
{{BUILD_COMMAND}}

# 2. Review changes
git log --oneline main..HEAD
git diff main...HEAD --stat

# 3. Push
git push -u origin feat/STORY-NNN-description
```

## Pull Request

### PR Creation

```bash
gh pr create \
  --title "feat(scope): implement STORY-NNN -- title" \
  --body "$(cat <<'EOF'
## Summary
<1-3 bullet points describing what was built>

## Test plan
- [ ] Build passes (`{{BUILD_COMMAND}}`)
- [ ] Coverage thresholds met
- [ ] All acceptance criteria covered
EOF
)"
```

### PR Title Convention

- **Format:** `feat(scope): implement STORY-NNN -- short title`
- **Max length:** 70 characters

### Useful Commands

```bash
gh pr list
gh pr view <number>
gh pr checks <number>
gh pr merge <number> --squash --delete-branch
```

## Tagging Releases

```bash
git tag -a v0.1.0 -m "Milestone description"
git push origin v0.1.0
```

## Integration Notes

- Used by `x-dev-lifecycle` during Phase 0 (branch) and Phase 5 (push + PR)
- Can be used standalone for any git workflow task
- Commit message scopes should match the project's package/module structure
