# Frequently Asked Questions

## General

### What is this?

A modular collection of `.claude/rules/` files for Claude Code. Instead of writing rules from scratch for every project, you select your tech stack and get a set of opinionated, battle-tested rules.

### Who is this for?

Teams using Claude Code who want consistent, high-quality engineering standards enforced by AI. Works for solo developers and large teams alike.

### Can I mix profiles?

Not currently. Each profile is designed for a specific language + framework combination. However, you can manually copy relevant sections from multiple profiles into your rules.

### What if my framework doesn't have a profile?

The core rules (Layer 1) work with any technology. Generate rules with just the core, then create your own profile following [CONTRIBUTING.md](CONTRIBUTING.md). Consider contributing it back.

### Do I need to follow everything?

Rules are opinionated by design — that's what makes them effective with Claude Code. However, you can modify any generated file to match your team's preferences. The core rules represent widely-accepted software engineering best practices.

## Setup

### How long does setup take?

Interactive mode: ~2 minutes. Config file mode: instant.

### Can I re-run setup without losing changes?

No. The generator overwrites existing files. Back up your customized rules before re-running. The planned `update.sh` script (future) will handle incremental updates.

### How do I update core rules when the boilerplate updates?

Currently: manually diff and merge. Future: an `update.sh` script will update core rules without overwriting domain customizations.

## Rules

### Why are rules files so long?

Claude Code loads all `.claude/rules/` files into its context window. Longer, more detailed rules produce more consistent behavior. The tradeoff is context window usage vs. rule adherence.

### Can I have too many rules?

Yes. If your total rules exceed ~50K tokens, Claude Code may start losing fidelity on some rules. The boilerplate is designed to stay within reasonable limits (~30K tokens for core + one profile).

### Why tables instead of prose?

Tables are the most reliably followed format by Claude Code. A table with "FORBIDDEN" / "MANDATORY" columns is followed more consistently than equivalent prose.

### Why pseudocode in core instead of real code?

Core rules must be language-agnostic. Using pseudocode ensures they apply to any technology stack. Profiles provide real, framework-specific code examples.

## Contributing

### How do I add a new profile?

See [CONTRIBUTING.md](CONTRIBUTING.md). Create the ~9 files following the existing `java21-quarkus` profile as reference.

### How do I report issues?

Open an issue on the repository with:
1. Which rule file has the problem
2. What Claude Code did wrong
3. What the expected behavior was

### Can I request a new profile?

Yes! Open an issue describing the language + framework combination you need. Even better: contribute it.
