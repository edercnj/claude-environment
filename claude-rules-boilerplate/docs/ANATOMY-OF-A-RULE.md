# Anatomy of a Rule

Every rule file in the boilerplate follows a consistent structure optimized for Claude Code consumption.

## Standard Structure

```markdown
# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff.
- **Priority**: Maintain 100% fidelity to the technical constraints defined below.

# Rule {NN} — {Topic Title}

## Principles
- 3-5 bullet points defining the WHY

## {Section 1 — Main Content}

### Tables for Structured Rules
| Column A | Column B | Column C |
|----------|----------|----------|
| Value    | Value    | Value    |

### Code Examples
```{language}
// GOOD — explain why this is correct
goodExample()

// BAD — explain why this is wrong
badExample()
```

## {Section N — Additional Sections}

## Anti-Patterns (FORBIDDEN)
- List of explicit prohibitions
```

## Key Sections

### Global Behavior Header (MANDATORY)

Every file starts with this header. It ensures Claude Code:
1. Responds in English only
2. Eliminates conversational fluff
3. Follows the rules exactly as written

### Principles Section

3-5 bullet points that establish the WHY behind the rule. Helps Claude Code make judgment calls when specific scenarios aren't covered.

### Tables

Tables are the most reliable format for Claude Code to follow. Use for:
- Naming conventions
- Configuration differences across environments
- Classification matrices
- Mapping between concepts

### Code Examples (GOOD / BAD)

Always show both correct and incorrect patterns. Claude Code follows positive examples and avoids negative ones when clearly marked.

### Anti-Patterns Section (MANDATORY)

End every file with explicit prohibitions. This is surprisingly effective — Claude Code avoids listed anti-patterns even in edge cases.

## File Numbering

| Range | Layer | Purpose |
|-------|-------|---------|
| 01-11 | Core | Universal principles (language/framework agnostic) |
| 20-29 | Profile | Technology-specific patterns |
| 30-39 | Domain | Project-specific rules |
| 40+ | Extensions | Additional custom rules |

## Writing Tips

1. **Be opinionated** — "use X" is better than "consider X or Y"
2. **Be specific** — "maximum 25 lines per function" not "keep functions short"
3. **Include defaults** — "use 4 spaces for indentation (Java)" not "choose consistent indentation"
4. **Use FORBIDDEN/MANDATORY** — strong language is respected by Claude Code
5. **Keep files under 500 lines** — split if longer
6. **Inline critical info** — don't rely on external links
7. **Avoid conditional language** — "if you want" suggests optional; "ALWAYS" is definitive
