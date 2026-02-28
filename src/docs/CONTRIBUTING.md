# Contributing to Claude Rules Boilerplate

## Adding a New Profile

A profile contains technology-specific patterns for a language + framework combination.

### Structure

```
profiles/{language}-{framework}/
├── coding-patterns.md            # Language features, DI, naming, formatting
├── testing-patterns.md           # Test frameworks, assertions, fixtures
├── configuration.md              # Config management, profiles, environments
├── api-patterns.md               # HTTP framework, error handling, validation
├── database-patterns.md          # ORM, migrations, repository patterns
├── resilience-patterns.md        # Resilience library, circuit breaker, retry
├── observability-patterns.md     # Tracing/metrics SDK, health checks, logging
├── infrastructure-patterns.md    # Dockerfile, build tooling, K8s specifics
└── native-build.md               # (optional) AOT/native compilation rules
```

### Guidelines

1. **Every file starts with the Global Behavior header** (see any existing file)
2. **Include concrete code examples** — profiles are opinionated and specific
3. **Reference the core rule it extends** — e.g., "Extends core/01-clean-code.md"
4. **Focus on the HOW** — core defines WHAT/WHY, profiles define HOW with this tech
5. **Include anti-patterns** — what's FORBIDDEN in this specific stack

### Checklist for New Profile

- [ ] All 8-9 files created with consistent structure
- [ ] Every file has Global Behavior header
- [ ] Code examples compile/run correctly
- [ ] No overlap with core rules (no universal principles)
- [ ] References to core rules where extending them
- [ ] Anti-patterns section in each file
- [ ] Tested: generator produces valid output with this profile

### Cross-Validation

After creating a profile, verify:
1. Core rules work without changes with the new profile
2. If core needs changes, the core was too coupled — fix core first
3. Profile covers all topics in the existing profile (compare with `java21-quarkus`)

## Adding a New Domain Example

### Structure

```
templates/examples/{domain-name}/
├── project-identity.md           # Filled-in project template
├── {domain}-domain.md            # Domain rules, business logic
├── security-{domain}.md          # (optional) Domain-specific security
├── smoke-tests.md                # (optional) Domain-specific smoke tests
└── {protocol}.md                 # (optional) Protocol-specific rules
```

### Guidelines

1. **project-identity.md** — Fill in the template with realistic values
2. **domain rules** — Document business rules, decision logic, data models
3. **Keep it focused** — Only domain-specific content (not universal principles)
4. **Include tables** — Business rules as tables are easy to reference

## Rule Quality Checklist

Every rule file should:

- [ ] Start with Global Behavior & Language Policy header
- [ ] Have a clear, descriptive title (`# Rule NN — Topic`)
- [ ] Include a Principles section (3-5 bullet points)
- [ ] Use tables for structured information
- [ ] Provide concrete examples (GOOD vs BAD)
- [ ] End with Anti-Patterns section
- [ ] Be self-contained (no external links that may break)
- [ ] Be concise — avoid repetition, eliminate fluff

## What Works Well with Claude Code

Based on experience, these patterns are most effective in rules:

### Do
- **Tables** — Claude follows tabular rules very consistently
- **Code examples** with `// GOOD` and `// BAD` markers
- **Explicit FORBIDDEN** — state what NOT to do
- **Naming conventions** — clear patterns with examples
- **Checklists** — before-merge, before-deploy lists
- **Default values** — "if not specified, use X"

### Don't
- Extremely long rules (> 500 lines) — split into multiple files
- Vague guidance ("use good practices") — be specific
- External links only — inline the critical information
- Conflicting rules across files — maintain consistency
