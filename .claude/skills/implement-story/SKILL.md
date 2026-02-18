---
name: implement-story
description: "Use this skill whenever implementing a feature or story for the b8583 project. Triggers include: any mention of implement, implementar, coding, develop, story, STORY-NNN, feature, build a class, create a package, write code, coding session, or start working on. Also trigger when the user says 'let's start STORY-X', 'implement the packer', 'create the bitmap class', or any request that involves writing production Java code for the b8583 library. This is the central orchestrator skill — it coordinates with java-maven, run-tests, commit-and-push, and iso8583-domain skills to execute the full development cycle. Use it for ANY implementation task, even small ones, because the project has strict conventions that must be followed."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[STORY-NNN]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Java Implementation Skill — b8583 Story Orchestrator

## Purpose

This is the central orchestrator skill for the b8583 ISO 8583 library. It covers the full coding cycle: read the story → check dependencies → create branch → implement → test → validate DoD → commit. For code review after implementation, use `/review` (7 specialist reviewers) and `/review-pr` (Tech Lead holistic review).

## The Implementation Workflow

```
1. PREPARE    → Read story, check dependencies, create branch
2. UNDERSTAND → Read relevant ADRs, understand domain context
3. IMPLEMENT  → Write code following patterns and conventions
4. TEST       → Write tests, run them, check coverage
5. VALIDATE   → Verify DoD checklist (global + story-specific)
6. COMMIT     → Atomic commits following conventions
```

## Arguments

When invoked with `/implement-story STORY-005`, the argument `$ARGUMENTS` resolves to `STORY-005`.
If no argument is provided, ask the user which story to implement.

## Step 1: PREPARE

Before writing any code:

### 1a. Read the Story

```bash
# Read the story file (use $ARGUMENTS if provided, otherwise ask)
cat stories/$ARGUMENTS.md
```

Extract from the story:

- **Gherkin scenarios** — These become test cases
- **Sub-tasks** — These become the implementation plan
- **Acceptance criteria** — These define "done"
- **Blocked By** — These must be implemented first
- **Blocks** — These depend on this story

### 1b. Verify Dependencies

Check that all stories in `Blocked By` are already implemented:

```bash
# Check if dependency branches are merged
git log --oneline main | grep "STORY-NNN"
```

If a dependency is not merged, STOP. Implement the dependency first.

### 1c. Create Feature Branch

Follow the `commit-and-push` skill conventions:

```bash
git checkout main
git pull origin main
git checkout -b feature/STORY-NNN-short-description
```

## Step 2: UNDERSTAND

### 2a. Read Relevant ADRs

Each story maps to specific ADRs. Read them before coding:

| Layer         | Stories            | Key ADRs                                                        |
| ------------- | ------------------ | --------------------------------------------------------------- |
| Primitives    | 001, 002, 004      | ADR-001 (Java 21), ADR-008 (Encoding)                           |
| Engine        | 003, 005, 006, 007 | ADR-002 (Registry), ADR-003 (Dialects), ADR-005 (Thread-safety) |
| Annotations   | 008                | ADR-002 (Annotation-driven)                                     |
| Mapper        | 009, 010, 011      | ADR-009 (POJO mapping), ADR-010 (Converters)                    |
| Cross-cutting | 012                | ADR-004 (Error handling), ADR-011 (Validation)                  |
| Utilities     | 013                | ADR-008 (Wire format)                                           |

### 2b. Review Existing Code

Before adding new code, understand what exists:

```bash
# List existing classes in the package you'll work on
find src/main/java/com/bifrost/b8583/<package> -name "*.java"

# Review existing tests
find src/test/java/com/bifrost/b8583/<package> -name "*Test.java"
```

## Step 3: IMPLEMENT

### Code Conventions

**Language:** All code (class names, methods, variables, Javadoc, comments) in English.

**Package placement:** Every class goes in its designated package per ADR-007:

```
com.bifrost.b8583.type        → IsoFieldType, Formatter classes
com.bifrost.b8583.bitmap      → IsoBitmap
com.bifrost.b8583.mti         → MessageTypeIndicator
com.bifrost.b8583.registry    → DataElementDef, DataElementRegistry
com.bifrost.b8583.dialect     → IsoDialect, IsoVersion
com.bifrost.b8583.pack        → IsoPacker
com.bifrost.b8583.unpack      → IsoUnpacker, IsoCursor
com.bifrost.b8583.annotation  → @IsoMessage, @IsoField, @DataElement
com.bifrost.b8583.mapper      → IsoMapper, IsoMessageMetadata
com.bifrost.b8583.converter   → FieldConverter, built-in converters
com.bifrost.b8583.exception   → IsoException, IsoPackException, etc.
com.bifrost.b8583.util        → IsoDump, HexDump, IsoMessageLogger
```

### Java 21 Patterns (Mandatory)

These are architectural decisions, not suggestions:

**Records for value objects:**

```java
public record DataElementDef(
    int bit,
    String name,
    IsoFieldType type,
    int length,
    LengthType lengthType
) {
    public DataElementDef {
        if (bit < 1 || bit > 128) throw new IllegalArgumentException("Bit must be 1-128");
    }
}
```

**Sealed interfaces for type hierarchies:**

```java
public sealed interface SubElementParser
    permits PositionalParser, TlvParser, BerTlvParser, BitmappedParser {
    Map<String, String> parse(byte[] data);
}
```

**Builder pattern for complex objects:**

```java
public final class DataElementRegistry {
    // ... immutable fields

    public static Builder builder() { return new Builder(); }

    public static final class Builder {
        public Builder add(DataElementDef def) { ... }
        public DataElementRegistry build() { ... }
    }
}
```

### Resilience Patterns (Rule 24)

When implementing handlers, use cases, or adapters that interact with external resources (DB, network):

- Apply `@CircuitBreaker`, `@Retry`, `@Timeout`, `@Bulkhead`, `@Fallback` (MicroProfile Fault Tolerance) as defined in **Rule 24**
- All fallbacks MUST follow fail-secure principle (RC 96 for ISO, 503 for REST — NEVER approve on failure)
- Rate limiting (Bucket4j) is applied at adapter inbound level (REST filter, TCP handler)

### Thread-Safety Rules (ADR-005)

- All public types are **immutable after construction**
- Builder is mutable during construction, immutable once `build()` is called
- Use `Collections.unmodifiableMap()` or `Map.copyOf()` for internal collections
- No `static` mutable state anywhere
- Message POJOs (Layer 3) are mutable during construction, immutable after `IsoMapper.unpack()` returns

### Javadoc Requirements

Every public class and method must have Javadoc:

```java
/**
 * Manages ISO 8583 primary and secondary bitmaps (128 bits).
 *
 * <p>The bitmap tracks which data elements are present in a message.
 * Bit 1 is automatically managed: set when any bit 65-128 is active
 * (indicating secondary bitmap presence), cleared otherwise.</p>
 *
 * <p>This class is immutable and thread-safe.</p>
 *
 * @see DataElementRegistry
 * @since 0.1.0
 */
public final class IsoBitmap { ... }
```

## Step 4: TEST

Follow the `run-tests` skill for detailed test patterns. Key points:

1. **Write tests alongside code** — Not after. Ideally write the test first (TDD).
2. **One test class per production class** — `IsoBitmap` → `IsoBitmapTest`
3. **Cover all Gherkin scenarios** — Each scenario from the story = at least one test
4. **Parametrized tests for ISO types** — Field types, encodings, MTI variants
5. **Round-trip tests** — pack → unpack → compare (essential for Layer 2+)
6. **Exception tests** — Every error path must be tested

```bash
# Run tests after implementing
mvn test

# Check coverage
mvn test jacoco:report
```

## Step 5: VALIDATE (Definition of Done)

Before committing, verify both the Global DoD and Story-specific DoD.

### Global DoD (from EPIC-000)

| Criterion                        | How to verify                                          |
| -------------------------------- | ------------------------------------------------------ |
| All Gherkin scenarios have tests | Compare story scenarios vs test methods                |
| Line coverage ≥ 95%              | `mvn test jacoco:report` → check report                |
| Branch coverage ≥ 90%            | Same JaCoCo report                                     |
| Performance < 5ms P99            | Write a quick benchmark test if applicable             |
| Thread-safe                      | Review: no mutable static state, immutable after build |
| Javadoc on all public API        | Check every public class and method                    |
| Zero runtime dependencies        | Check pom.xml — only test-scope deps                   |
| Code compiles cleanly            | `mvn clean compile` with no warnings                   |

### Story-Specific DoD

Read the story's own acceptance criteria section and verify each point.

## Step 6: COMMIT

Follow the `commit-and-push` skill. Make atomic commits:

```bash
# Stage specific files (not git add .)
git add src/main/java/com/bifrost/b8583/bitmap/IsoBitmap.java
git add src/test/java/com/bifrost/b8583/bitmap/IsoBitmapTest.java
git commit -m "feat(bitmap): add primary/secondary bitmap management"
```

## Story → Package Mapping

Quick reference for which package each story implements:

| Story     | Package(s)             | Key Classes                                           |
| --------- | ---------------------- | ----------------------------------------------------- |
| STORY-000 | (all)                  | Project setup, pom.xml, module-info                   |
| STORY-001 | `type`                 | IsoFieldType, Formatter, Encoding                     |
| STORY-002 | `bitmap`               | IsoBitmap                                             |
| STORY-003 | `registry`             | DataElementDef, DataElementRegistry, SubElementParser |
| STORY-004 | `mti`                  | MessageTypeIndicator                                  |
| STORY-005 | `pack`                 | IsoPacker                                             |
| STORY-006 | `unpack`               | IsoUnpacker, IsoCursor                                |
| STORY-007 | `dialect`              | IsoDialect, IsoVersion, DialectBuilder                |
| STORY-008 | `annotation`           | @DataElement, AnnotationRegistryLoader                |
| STORY-009 | `mapper`, `annotation` | IsoMapper, @IsoMessage, @IsoField                     |
| STORY-010 | `converter`            | FieldConverter, built-in converters                   |
| STORY-011 | `annotation`, `mapper` | @CompositeField, @SubField, @TlvField                 |
| STORY-012 | `exception`            | IsoException hierarchy, ValidationMode                |
| STORY-013 | `util`                 | IsoDump, HexDump, IsoMessageLogger                    |

For detailed per-story implementation guidance, read `references/story-workflow.md`.
