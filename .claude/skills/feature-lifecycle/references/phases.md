# Phase Reference — Feature Lifecycle

Detailed guidance for each phase of the feature lifecycle.

## Phase 0: Preparation — Decision Matrix

### Story → Package Mapping

| Story | Package(s) | Key Classes | Layer |
|-------|-----------|-------------|-------|
| STORY-000 | (all) | Project setup, pom.xml, module-info | Infra |
| STORY-001 | `type` | IsoFieldType, Formatter, Encoding, LengthType | 1 |
| STORY-002 | `bitmap` | IsoBitmap | 1 |
| STORY-003 | `registry` | DataElementDef, DataElementRegistry, SubElementParser | 2 |
| STORY-004 | `mti` | MessageTypeIndicator | 1 |
| STORY-005 | `pack` | IsoPacker | 2 |
| STORY-006 | `unpack` | IsoUnpacker, IsoCursor | 2 |
| STORY-007 | `dialect` | IsoDialect, IsoVersion, DialectBuilder | 2 |
| STORY-008 | `annotation` | @DataElement, AnnotationRegistryLoader | 2 |
| STORY-009 | `mapper`, `annotation` | IsoMapper, @IsoMessage, @IsoField, IsoMessageMetadata | 3 |
| STORY-010 | `converter` | FieldConverter, built-in converters | 3 |
| STORY-011 | `annotation`, `mapper` | @CompositeField, @SubField, @TlvField | 3 |
| STORY-012 | `exception` | IsoException hierarchy, ValidationMode | Cross |
| STORY-013 | `util` | IsoDump, HexDump, IsoMessageLogger | Cross |

### Story → ADR Mapping

| Story | ADRs to Read |
|-------|-------------|
| STORY-000 | ADR-001, ADR-007 |
| STORY-001 | ADR-001, ADR-008 |
| STORY-002 | ADR-001, ADR-008 |
| STORY-003 | ADR-002, ADR-005 |
| STORY-004 | ADR-001, ADR-003, ADR-008 |
| STORY-005 | ADR-002, ADR-003, ADR-005, ADR-008 |
| STORY-006 | ADR-002, ADR-003, ADR-005, ADR-008 |
| STORY-007 | ADR-003, ADR-005 |
| STORY-008 | ADR-002 |
| STORY-009 | ADR-009, ADR-005 |
| STORY-010 | ADR-010 |
| STORY-011 | ADR-009 |
| STORY-012 | ADR-004, ADR-011 |
| STORY-013 | ADR-008 |

## Phase 1: Architecture Review Guidance

The architect reviewer should focus on:

### For Layer 1 Stories (001, 002, 004)
- Are value objects modeled as records?
- Are enums used for fixed sets (field types, length types, encodings)?
- Is validation in compact constructors?
- No dependencies on Layer 2 or 3

### For Layer 2 Stories (003, 005, 006, 007, 008)
- Is the builder pattern used for Registry and Dialect?
- Is SubElementParser a sealed interface?
- Is IsoCursor safe (bounds checking on every read)?
- Are encoding axes independent (MTI, bitmap, field)?

### For Layer 3 Stories (009, 010, 011)
- Is reflection cached in IsoMessageMetadata?
- Are FieldConverters stateless?
- Is @IsoMessage → IsoDialect mapping correct?
- Can IsoMapper handle multiple message types?

## Phase 1B: Test Scenario Planning

The Test Scenario Planner runs AFTER the architecture review and BEFORE implementation. It uses Opus to deeply analyze the story and produce a comprehensive test strategy.

### When to Spawn

- ALWAYS after Phase 1 (Architecture Review)
- ALWAYS before Phase 2 (Implementation)
- Can also be invoked standalone for test auditing or refactoring

### Context to Include

```
Story: STORY-NNN
Architecture plan: [output from Phase 1 architect]
Testing rules: .claude/rules/03-testing.md
Exception hierarchy: .claude/rules/05-architecture.md
Domain rules: .claude/rules/04-iso8583-domain.md
ISO test scenarios reference: .claude/skills/plan-tests/references/iso-test-scenarios.md
```

### Test Categories to Plan (All 5 Mandatory)

| Category | What to Plan | Minimum Scenarios |
|----------|-------------|-------------------|
| Happy Path | One per public method | 1 per method |
| Error Path | One per applicable exception type | 1 per exception |
| Boundary | Triplet (at-min, at-max, past-max) per boundary | 3 per boundary value |
| Parametrized | Type × value matrices with @CsvSource/@EnumSource | Full matrix |
| Roundtrip | Pack → unpack → compare (if applicable) | 3+ (minimal, typical, maximal) |

### Output Usage

The test plan document is used by:

| Phase | How it uses the test plan |
|-------|--------------------------|
| Phase 2 (Implementation) | Developers write tests following the plan, checking off scenarios |
| Phase 3 (QA Reviewer) | QA reviewer validates all planned scenarios were implemented |
| Phase 5 (Tech Lead) | Tech Lead checks test completeness against the plan |

### Story-Specific Test Focus

| Story Layer | Primary Test Focus |
|-------------|-------------------|
| Layer 1 (001, 002, 004) | Charset validation, padding, boundary values, enum coverage |
| Layer 2 (003, 005, 006, 007) | Registry correctness, pack/unpack roundtrip, encoding matrix |
| Layer 3 (009, 010, 011) | POJO mapping, converter accuracy, annotation validation |
| Cross-cutting (012, 013) | Exception context richness, log output format, sensitive data masking |

---

## Phase 2: Implementation Patterns

### Record with Compact Constructor

```java
public record DataElementDef(
    int bit, String name, IsoFieldType type,
    int length, LengthType lengthType
) {
    public DataElementDef {
        if (bit < 1 || bit > 128)
            throw new IllegalArgumentException("Bit must be 1-128, got: " + bit);
        Objects.requireNonNull(name, "name");
        Objects.requireNonNull(type, "type");
        Objects.requireNonNull(lengthType, "lengthType");
    }
}
```

### Sealed Interface

```java
public sealed interface SubElementParser
    permits PositionalParser, TlvParser, BerTlvParser, BitmappedParser {
    Map<String, String> parse(byte[] data);
    byte[] pack(Map<String, String> subFields);
}
```

### Builder Pattern

```java
public final class DataElementRegistry {
    private final Map<Integer, DataElementDef> elements;

    private DataElementRegistry(Map<Integer, DataElementDef> elements) {
        this.elements = Map.copyOf(elements);
    }

    public static Builder builder() { return new Builder(); }

    public static final class Builder {
        private final Map<Integer, DataElementDef> elements = new LinkedHashMap<>();
        public Builder add(DataElementDef def) { elements.put(def.bit(), def); return this; }
        public DataElementRegistry build() { return new DataElementRegistry(elements); }
    }
}
```

## Phase 3: Reviewer Spawn Template

When spawning reviewers, include this context in each Task prompt:

```
Project: b8583 — ISO 8583 Java 21 library
Story being implemented: STORY-NNN
Files to review: [complete list]
Working directory: [pwd]

Read the agent definition at .claude/agents/<persona>-reviewer.md
Then review the listed files following the instructions in the agent definition.
Output your review in the format specified in the agent definition.
```

## Phase 4: Fix Priority Order

1. **CRITICAL from Security** → Fix immediately (input validation, buffer bounds)
2. **CRITICAL from Architect** → Fix immediately (layer violations, ADR breaks)
3. **CRITICAL from QA** → Fix immediately (missing critical test coverage)
4. **HIGH from Security** → Fix (sensitive data protection)
5. **HIGH from Performance** → Fix (P99 violations)
6. **HIGH from Architect** → Fix (design issues)
7. **HIGH from QA** → Fix (missing edge case tests)
8. **MEDIUM from all** → Fix if time permits
9. **LOW from all** → Note for future improvement

## Phase 5: Tech Lead Validation

The Tech Lead agent performs the final quality gate. Key points:

### When to Spawn

- ALWAYS after Phase 4 (Consolidation and Fixes)
- ALWAYS before Phase 6 (Commit)
- NEVER skip this phase — it is mandatory for every story

### Context to Include

```
Project: b8583 — ISO 8583 Java 21 library
Story being implemented: STORY-NNN
Files to review: [complete list of production + test files]
Working directory: [pwd]
Build status: [mvn clean verify output summary]

Read the agent definition at .claude/agents/tech-lead.md
Then execute the FULL 32-point checklist.
Print the checklist to the screen.
Make a GO/NO-GO decision.
```

### Decision Handling

| Decision | Action |
|----------|--------|
| **GO** | Proceed to Phase 6 (Commit) |
| **CONDITIONAL GO** | Proceed, note items for next iteration |
| **NO-GO** | Return to Phase 4, fix items, re-run Phase 5 |

### Clean Code Checks (Non-Negotiable)

The Tech Lead verifies these Clean Code principles:

| Check | Threshold | Reference |
|-------|-----------|-----------|
| Variable names | All intention-revealing | Clean Code Cap. 2 |
| Method size | <= 20 lines | Clean Code Cap. 3 |
| Method params | <= 3 parameters | Clean Code Cap. 3 |
| Class size | <= 200 lines (250 enum max) | Clean Code Cap. 10 |
| Magic values | Zero tolerance | Clean Code Cap. 17 |
| Code duplication | Zero tolerance | Clean Code Cap. 12 |

### SOLID Checks (Non-Negotiable)

| Principle | What to Verify |
|-----------|---------------|
| SRP | Each class has one reason to change |
| OCP | New types added without modifying existing code |
| LSP | Sealed interface implementations are interchangeable |
| ISP | No fat interfaces |
| DIP | Dependencies injected, not looked up |

## Phase 6: Commit Message Templates

### Single-commit story

```
feat(<package>): implement <story title>

Implements STORY-NNN: <full title from story>

Key changes:
- <change 1>
- <change 2>
- <change 3>

Coverage: line XX%, branch XX%
Reviewed-by: architect, security, qa, performance
```

### Multi-commit story

```
feat(<package>): add <component 1>
feat(<package>): add <component 2>
test(<package>): add tests for <component>
fix(<package>): address review findings
```

## Phase 7: Pull Request Guidelines

### PR Title Format

```
feat(<package>): implement STORY-NNN — <story title>
```

Keep under 70 characters. The title should match the main commit message scope.

### PR Body Sections

| Section | Purpose | Required |
|---------|---------|----------|
| Summary | What was built and why | Yes |
| Key Changes | Bullet list of main changes | Yes |
| Architecture Decisions | Layer, patterns, ADRs | Yes |
| Test Results | Pass count, coverage % | Yes |
| Code Review Summary | Table of findings by reviewer | Yes |
| Remaining MEDIUM/LOW | Deferred findings | Only if exist |
| Checklist | DoD verification | Yes |
| Stories | Implements/Unblocks/Depends on | Yes |

### PR Scope per Story

| Story | PR Scope | Estimated Size |
|-------|----------|---------------|
| STORY-000 | Project setup — pom.xml, module-info, package dirs | S |
| STORY-001 | IsoFieldType enum, formatters, Encoding, LengthType | M |
| STORY-002 | IsoBitmap — primary/secondary, bit management | S |
| STORY-003 | DataElementDef, Registry, SubElementParser (sealed) | L |
| STORY-004 | MTI parser, version detection, request↔response | M |
| STORY-005 | IsoPacker serializer | M |
| STORY-006 | IsoUnpacker + IsoCursor deserializer | M |
| STORY-007 | IsoDialect, IsoVersion, DialectBuilder | M |
| STORY-008 | @DataElement annotation, AnnotationRegistryLoader | M |
| STORY-009 | IsoMapper, @IsoMessage, @IsoField — full Hibernate layer | L |
| STORY-010 | FieldConverter interface + 7 built-in converters | M |
| STORY-011 | @CompositeField, @SubField, nested POJO mapping | L |
| STORY-012 | IsoException hierarchy, ValidationMode | S |
| STORY-013 | IsoDump, HexDump, IsoMessageLogger | S |

### PR Labels (if repository supports)

- `layer-1`, `layer-2`, `layer-3`, `cross-cutting` — by story layer
- `size/S`, `size/M`, `size/L` — by estimated scope
- `needs-review` — default on creation
- `ready-to-merge` — after human approval

### Error Handling for PR Phase

| Scenario | Action |
|----------|--------|
| `gh` CLI not authenticated | Print: `Run gh auth login to authenticate` |
| Remote `origin` not configured | Print: `Run git remote add origin <url>` |
| Push rejected (out of date) | `git pull --rebase origin main`, re-push |
| PR creation fails | Show error, print manual `gh pr create` command |
| Branch already has open PR | Print existing PR URL, ask user if should update |
