---
name: commit-and-push
description: "Use this skill for all Git operations in the b8583 project. Triggers include: any mention of branch, commit, merge, push, pull request, PR, rebase, tag, release, git flow, git log, git status, cherry-pick, conventional commits, or version control. Also trigger when starting work on a new STORY (need to create a feature branch), finishing a story (need to commit and prepare for merge), or when the user asks about the commit history or branching strategy. Use this skill proactively at the START and END of every implementation task — branching at the start, committing at the end."
allowed-tools: Bash, Read
argument-hint: "[branch-name or commit-message]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Git Workflow Skill — b8583

## Purpose

This skill standardizes the Git workflow for the b8583 project. Every feature starts with a branch and ends with a clean commit history. Following these conventions makes the project history readable and traceable to stories.

## Branch Strategy

The project uses a simplified Git Flow:

```code
main (stable, always green)
  └── feature/STORY-NNN-short-description
```

### Branch Naming

**Pattern:** `feature/STORY-<NNN>-<short-kebab-description>`

```bash
# Examples
feature/STORY-000-project-setup
feature/STORY-001-primitive-types
feature/STORY-002-bitmap-engine
feature/STORY-005-packer
feature/STORY-009-iso-mapper
```

**Rules:**

- Always prefix with `feature/`
- Always include the STORY number (3 digits, zero-padded)
- Short description in kebab-case (English)
- Maximum 50 characters total

### Creating a Branch

```bash
# Always branch from main
git checkout main
git pull origin main
git checkout -b feature/STORY-NNN-description
```

## Commit Convention

The project uses **Conventional Commits** adapted for ISO 8583 domain:

### Format

```code
<type>(<scope>): <subject>

<optional body>

<optional footer>
```

### Types

| Type       | When to use                                         |
| ---------- | --------------------------------------------------- |
| `feat`     | New feature (new class, new method, new capability) |
| `test`     | Adding or modifying tests only                      |
| `fix`      | Bug fix                                             |
| `refactor` | Code restructuring without behavior change          |
| `docs`     | Documentation changes (Javadoc, CLAUDE.md, stories) |
| `build`    | Build system changes (pom.xml, plugins)             |
| `chore`    | Maintenance tasks (cleanup, formatting)             |

### Scopes

Use the package name as scope:

| Scope        | Package                        |
| ------------ | ------------------------------ |
| `type`       | `com.bifrost.b8583.type`       |
| `bitmap`     | `com.bifrost.b8583.bitmap`     |
| `mti`        | `com.bifrost.b8583.mti`        |
| `registry`   | `com.bifrost.b8583.registry`   |
| `dialect`    | `com.bifrost.b8583.dialect`    |
| `pack`       | `com.bifrost.b8583.pack`       |
| `unpack`     | `com.bifrost.b8583.unpack`     |
| `mapper`     | `com.bifrost.b8583.mapper`     |
| `converter`  | `com.bifrost.b8583.converter`  |
| `exception`  | `com.bifrost.b8583.exception`  |
| `annotation` | `com.bifrost.b8583.annotation` |
| `util`       | `com.bifrost.b8583.util`       |
| `build`      | pom.xml, module-info           |
| `project`    | Multi-package changes          |

### Examples

```bash
# Feature commits
feat(bitmap): add primary/secondary bitmap management
feat(type): implement numeric field formatter with BCD encoding
feat(mapper): add @IsoField annotation processing

# Test commits
test(bitmap): add round-trip tests for 128-bit bitmap
test(type): add parametrized charset validation for all field types

# Fix commits
fix(pack): correct LLVAR length prefix for BCD encoding
fix(mti): handle 3-digit MTI for ISO 8583:2021

# Build commits
build: configure Maven with Java 21 and JaCoCo enforcement
build: add AssertJ 3.26 dependency

# Refactor
refactor(registry): extract SubElementParser to sealed interface
```

### Commit Rules

1. **Atomic commits** — One logical change per commit. Don't mix a feature with a refactor.
2. **Subject line** — Max 72 characters, imperative mood ("add" not "added"), no period at end.
3. **Body** — Optional. Explain "why" not "what". Wrap at 72 characters.
4. **Tests with features** — Commits adding a feature should include its tests in the same commit (or in the immediately following commit).

## Workflow Per Story

### Starting a Story

```bash
# 1. Ensure main is up to date
git checkout main
git pull origin main

# 2. Create feature branch
git checkout -b feature/STORY-NNN-description

# 3. Verify clean state
git status
```

### During Implementation

Make frequent, atomic commits as you progress:

```bash
# After implementing a class + its tests
git add src/main/java/com/bifrost/b8583/bitmap/IsoBitmap.java
git add src/test/java/com/bifrost/b8583/bitmap/IsoBitmapTest.java
git commit -m "feat(bitmap): add primary bitmap with 64-bit management"

# After adding more tests
git add src/test/java/com/bifrost/b8583/bitmap/IsoBitmapTest.java
git commit -m "test(bitmap): add secondary bitmap activation tests"
```

### Finishing a Story

Before merging, ensure the DoD checklist:

```bash
# 1. Run full build
mvn clean verify

# 2. Check coverage
mvn test jacoco:report

# 3. Review all changes
git log --oneline main..HEAD
git diff main...HEAD --stat

# 4. Push
git push -u origin feature/STORY-NNN-description
```

## Pull Request

After pushing the branch, create a Pull Request using the GitHub CLI:

### PR Creation

```bash
gh pr create \
  --title "feat(<scope>): implement STORY-NNN — <title>" \
  --body "$(cat <<'EOF'
## Summary
<1-3 bullet points describing what was built>

## Test plan
- [ ] `mvn clean verify` passes
- [ ] Line coverage ≥ 95%
- [ ] Branch coverage ≥ 90%
- [ ] All Gherkin scenarios covered

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### PR Title Convention

- **Format:** `feat(<scope>): implement STORY-NNN — <short title>`
- **Max length:** 70 characters
- **Scope:** Same as commit scope (package name)

### PR Body

Use the template above. If specialist reviews (`/review`) or Tech Lead review (`/review-pr`) have been run, consider including a summary of review results in the PR body.

### PR Useful Commands

```bash
# List open PRs
gh pr list

# View a specific PR
gh pr view <number>

# Check PR status (CI checks)
gh pr checks <number>

# Merge after approval
gh pr merge <number> --squash --delete-branch
```

---

## Tagging Releases

When a milestone is complete (e.g., Layer 1 done):

```bash
git tag -a v0.1.0 -m "Layer 1: Primitives (types, bitmaps, MTI)"
git push origin v0.1.0
```

**Versioning:** Follow semantic versioning:

- `0.x.0` — Pre-release (during development)
- `0.1.0` — Layer 1 complete
- `0.2.0` — Layer 2 complete
- `0.3.0` — Layer 3 complete
- `1.0.0` — First stable release

## Useful Git Commands

```bash
# See what changed since branching
git diff main...HEAD

# Compact log of feature branch
git log --oneline main..HEAD

# Amend last commit (only if not pushed)
git commit --amend -m "new message"

# Interactive rebase to clean up history (only if not pushed)
git rebase -i main
```
