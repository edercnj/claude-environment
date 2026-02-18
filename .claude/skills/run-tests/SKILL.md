---
name: run-tests
description: "Use this skill whenever writing, running, or analyzing tests for the b8583 project. Triggers include: any mention of test, JUnit, AssertJ, JaCoCo, coverage, TDD, test-driven, unit test, integration test, parametrized test, test pattern, assertion, should/when naming, coverage report, test failure, red-green-refactor, or test-first. Also trigger when the user asks to validate an implementation, check coverage, write test cases for a class, or wants to ensure the Definition of Done (DoD) coverage thresholds are met (line ≥ 95%, branch ≥ 90%). If in doubt, trigger this skill — untested code does not ship in this project."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[ClassName or package]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Java Test Skill — b8583 (JUnit 5 + AssertJ + JaCoCo)

## Purpose

Testing is 50% of the work in b8583. The project enforces strict coverage thresholds (line ≥ 95%, branch ≥ 90%) via JaCoCo. Every public method, every branch, every edge case needs a test. This skill guides test creation, execution, and coverage analysis.

## Test Framework Stack

| Tool              | Version | Role                                                |
| ----------------- | ------- | --------------------------------------------------- |
| JUnit 5 (Jupiter) | 5.11+   | Test execution, lifecycle, parametrized tests       |
| AssertJ           | 3.26+   | Fluent assertions (preferred over JUnit assertions) |
| JaCoCo            | 0.8.12+ | Coverage measurement and enforcement                |

No mocks. The project has zero runtime dependencies — there's nothing to mock. All tests are pure unit tests operating on in-memory objects.

## Test File Location & Naming

```
src/test/java/com/bifrost/b8583/
├── type/       → IsoFieldTypeTest.java, FormatterTest.java
├── bitmap/     → IsoBitmapTest.java
├── mti/        → MessageTypeIndicatorTest.java
├── registry/   → DataElementRegistryTest.java
├── pack/       → IsoPackerTest.java
├── unpack/     → IsoUnpackerTest.java, IsoCursorTest.java
├── mapper/     → IsoMapperTest.java
└── ...         (mirrors main package structure)
```

**Naming rules:**

- Test class: `<ClassUnderTest>Test` (e.g., `IsoBitmapTest`)
- Test method: `should<ExpectedResult>_when<Condition>` (e.g., `shouldSetBit1_whenSecondaryBitmapRequired`)

## AssertJ — The Assertion Standard

Always use AssertJ, never JUnit's `assertEquals`/`assertTrue`. AssertJ provides better error messages and fluent chaining.

```java
// GOOD — AssertJ fluent assertions
assertThat(bitmap.isSet(3)).isTrue();
assertThat(result).isEqualTo("0200");
assertThat(fields).hasSize(5).containsKeys(2, 3, 4, 11, 41);
assertThat(packed).startsWith("0200");

// BAD — Don't use JUnit assertions
assertEquals("0200", result);       // Less readable
assertTrue(bitmap.isSet(3));         // Poor error message
```

### Assertion Patterns by Type

| Testing... | AssertJ Pattern                                                                                      |
| ---------- | ---------------------------------------------------------------------------------------------------- |
| Equality   | `assertThat(x).isEqualTo(y)`                                                                         |
| Null check | `assertThat(x).isNotNull()` / `.isNull()`                                                            |
| Boolean    | `assertThat(x).isTrue()` / `.isFalse()`                                                              |
| String     | `assertThat(s).startsWith("02").hasSize(16).matches("[0-9A-F]+")`                                    |
| Collection | `assertThat(list).hasSize(3).contains(a, b).doesNotContain(c)`                                       |
| Map        | `assertThat(map).containsEntry(key, value).hasSize(n)`                                               |
| Exception  | `assertThatThrownBy(() -> ...).isInstanceOf(IsoPackException.class).hasMessageContaining("field 3")` |
| Optional   | `assertThat(opt).isPresent().contains(value)`                                                        |
| byte[]     | `assertThat(bytes).hasSize(16).startsWith(0x30, 0x32)`                                               |

## Test Structure — Arrange-Act-Assert (AAA)

Every test method follows the AAA pattern with clear separation:

```java
@Test
void shouldPackFixedNumericField_whenValueIsValid() {
    // Arrange
    var formatter = new NumericFormatter(12, PadDirection.LEFT);
    var value = "123456";

    // Act
    var packed = formatter.format(value);

    // Assert
    assertThat(packed).isEqualTo("000000123456");
    assertThat(packed).hasSize(12);
}
```

## Parametrized Tests

Use parametrized tests heavily for ISO 8583 type validation. Each field type has many valid/invalid charset combinations:

```java
@ParameterizedTest
@CsvSource({
    "a,   'ABCDE',     true",   // alphabetic only
    "a,   'ABC12',     false",  // digits not allowed in 'a'
    "n,   '12345',     true",   // numeric only
    "n,   '123AB',     false",  // alpha not allowed in 'n'
    "an,  'ABC123',    true",   // alphanumeric
    "ans, 'Hi! @#',    true",   // alpha + numeric + special
})
void shouldValidateCharset(String type, String value, boolean expected) {
    assertThat(IsoFieldType.of(type).isValid(value)).isEqualTo(expected);
}
```

Also use `@MethodSource` for complex objects:

```java
@ParameterizedTest
@MethodSource("provideRoundTripCases")
void shouldRoundTrip_packThenUnpack(String mti, Map<Integer, String> fields) {
    byte[] packed = packer.pack(mti, fields);
    IsoMessage unpacked = unpacker.unpack(packed);
    assertThat(unpacked.getMti()).isEqualTo(mti);
    assertThat(unpacked.getFields()).isEqualTo(fields);
}
```

## Key Test Categories for b8583

### 1. Charset Validation Tests (Layer 1)

Test every field type (a, n, s, an, as, ns, ans, anp, ansb, b, z, x+n, xn) with valid and invalid inputs. Cover padding, alignment, and encoding.

### 2. Bitmap Tests (Layer 1)

Test setting/clearing individual bits, automatic Bit 1 management, hex serialization, round-trip.

### 3. MTI Tests (Layer 1)

Test parsing for 1987/1993 (4-digit) and 2021 (3-digit). Test request↔response matching. Test invalid MTIs.

### 4. Registry Tests (Layer 2)

Test field definitions, LLVAR/LLLVAR length parsing, dialect inheritance, sub-element parsers.

### 5. Packer/Unpacker Round-Trip Tests (Layer 2)

The most critical tests. Pack a message → unpack it → compare. Cover all encodings (ASCII, BCD, EBCDIC).

### 6. IsoMapper Tests (Layer 3)

Test POJO → byte[] → POJO round-trip with annotations. Test type converters, composite fields, lifecycle callbacks.

### 7. Exception Tests (Cross-cutting)

Test that every error path produces the right exception type with correct context (field number, position, raw data).

### 8. Resilience Tests (Rule 24)

Test circuit breaker state transitions, rate limiter rejection, bulkhead capacity, timeout triggers, retry strategies, and degradation level escalation. All fallbacks MUST be tested to confirm fail-secure behavior — **never approve on failure**. For ISO 8583 (TCP): RC 96 (System Error). For REST API: HTTP 429 (rate limit) or 503 (circuit open/bulkhead full/timeout). See **Rule 24 — Resilience Tests** for naming convention and scenarios.

## Running Tests

```bash
# All tests
mvn test

# Specific test class
mvn test -Dtest=IsoBitmapTest

# Specific method
mvn test -Dtest=IsoBitmapTest#shouldSetBit1_whenSecondaryBitmapRequired

# With coverage report
mvn test jacoco:report

# Verbose output (see individual test names)
mvn test -Dsurefire.useFile=false
```

## Coverage Analysis

After running `mvn test jacoco:report`, check `target/site/jacoco/index.html`.

**Thresholds (build fails if not met):**

- Line coverage ≥ 95%
- Branch coverage ≥ 90%

**Common coverage gaps and solutions:**

| Gap                           | Solution                                               |
| ----------------------------- | ------------------------------------------------------ |
| Uncovered `else` branch       | Add test for the negative case                         |
| Uncovered exception path      | Use `assertThatThrownBy` to test error paths           |
| Uncovered `default` in switch | Add test with unexpected input                         |
| Uncovered record accessor     | Usually covered indirectly — add direct test if needed |
| Uncovered builder validation  | Test builder with invalid inputs                       |

For advanced test patterns (round-trip testing, encoding matrix tests, performance benchmarks), read `references/test-patterns.md`.
