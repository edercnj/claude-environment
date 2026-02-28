# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 17 — Version-Specific Features

> Extends: `languages/java/common/coding-conventions.md`

## Mandatory Features

| Feature                      | Usage                                      | Since  |
| ---------------------------- | ------------------------------------------ | ------ |
| Records                      | DTOs, Value Objects, Events, Responses    | Java 16 |
| Sealed Interfaces            | Decision strategies, handler hierarchies  | Java 17 |
| Pattern Matching (instanceof)| Type guards, safe casting                  | Java 16 |
| Text Blocks                  | Complex SQL queries, log templates, JSON   | Java 13 |
| Optional                     | Search returns (NEVER return null)         | Java 8  |
| var                          | Local variables with obvious type          | Java 10 |

## Records — Mandatory for DTOs

Same as Java 21. Records are available since Java 16.

## Sealed Interfaces — Available

Same as Java 21. Sealed interfaces are available since Java 17.

## Pattern Matching instanceof (NOT switch)

Pattern matching `switch` is only a preview in Java 17. Use `instanceof` pattern matching instead:

```java
// ✅ GOOD (Java 17) — instanceof pattern matching
if (exception instanceof MerchantNotFoundException e) {
    return ProblemDetail.notFound(e.getMessage(), path);
} else if (exception instanceof DuplicateException e) {
    return ProblemDetail.conflict(e.getMessage(), path);
} else {
    LOG.error("Unexpected error", exception);
    return ProblemDetail.internalError("Internal error", path);
}

// ❌ BAD (Java 17) — switch pattern matching is preview, not stable
var result = switch (exception) { ... }; // Requires --enable-preview
```

## Text Blocks

Same as Java 21. Available since Java 13.

## NOT Available in Java 17

| Feature | Available Since | Alternative |
|---------|----------------|-------------|
| Pattern Matching (switch) | Java 21 | Use `if-else instanceof` chain |
| Virtual Threads | Java 21 | Use reactive or thread pools |
| Sequenced Collections | Java 21 | Use `list.get(0)` / `list.get(list.size()-1)` |
| String Templates | Preview (Java 21) | Use `String.formatted()` |
