---
name: troubleshoot
description: "Use this skill whenever troubleshooting errors, failures, or unexpected behavior in the b8583 project. Triggers include: any mention of error, bug, fix, debug, stacktrace, exception, failure, failing test, broken build, compilation error, NullPointerException, ClassCastException, assertion failure, test failure, coverage gap, encoding problem, performance issue, or any situation where something isn't working as expected. Also trigger when Maven build fails, tests fail, JaCoCo thresholds are not met, or the user says something like 'it's not working', 'I got an error', or 'why is this failing'. This skill helps diagnose problems fast and fix them correctly."
allowed-tools: Read, Bash, Grep, Glob
argument-hint: "[error-description or test-name]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Java Debug Skill — b8583

## Purpose

Debugging in the b8583 project often involves ISO 8583-specific challenges: encoding mismatches, bitmap inconsistencies, field padding errors, and length prefix problems. This skill provides a systematic approach to diagnose and fix issues quickly.

## Debug Workflow

```
1. REPRODUCE  → Get the exact error (stacktrace, test output, build log)
2. LOCATE     → Find where the error originates
3. UNDERSTAND → Why is it failing? What's the expected vs actual behavior?
4. FIX        → Write a test that reproduces the bug, then fix the code
5. VERIFY     → Run the full test suite to ensure no regressions
```

Always follow this order. Never skip step 4's "write a test first" — the bug-reproducing test prevents regressions.

## Common Error Categories

### 1. Compilation Errors

```bash
# Get full compilation output
mvn clean compile 2>&1 | head -100
```

| Error                        | Likely Cause                       | Fix                                                   |
| ---------------------------- | ---------------------------------- | ----------------------------------------------------- |
| `cannot find symbol`         | Missing import, typo in class name | Check package structure, run IDE auto-import          |
| `incompatible types`         | Wrong type in assignment/return    | Check Java 21 type inference, explicit cast if needed |
| `sealed type not permitted`  | Missing `permits` clause           | Add the implementing class to the sealed interface    |
| `record component not found` | Wrong accessor name                | Records use component name directly (not getX())      |
| `module not found`           | Missing `requires` in module-info  | Add the module dependency                             |
| `package does not exist`     | Wrong package declaration          | Verify directory matches package name                 |

### 2. Test Failures

```bash
# Run failing test with verbose output
mvn test -Dtest=ClassName#methodName -Dsurefire.useFile=false

# See surefire reports
cat target/surefire-reports/com.bifrost.b8583.*.txt
```

| Failure Type                           | Diagnosis                        | Fix                                         |
| -------------------------------------- | -------------------------------- | ------------------------------------------- |
| `AssertionError: expected X but was Y` | Logic bug in production code     | Compare expected vs actual, trace the logic |
| `NullPointerException` in test         | Missing setup in @BeforeEach     | Initialize all objects the test needs       |
| `AssertionError` on byte[] comparison  | Encoding mismatch                | Check if comparing ASCII vs BCD vs EBCDIC   |
| Test passes alone, fails in suite      | Shared mutable state             | Ensure @BeforeEach creates fresh objects    |
| `IsoPackException` in test             | Invalid field value for the type | Check field type (a, n, ans) vs test data   |

### 3. Build Failures

```bash
# Full build with stack trace
mvn clean verify -e
```

| Error                                          | Cause                  | Fix                                                                         |
| ---------------------------------------------- | ---------------------- | --------------------------------------------------------------------------- |
| JaCoCo threshold failure                       | Coverage below 95%/90% | Write more tests — check the JaCoCo report                                  |
| Surefire fork crash                            | JVM issue in test      | Check for infinite loops or memory leaks                                    |
| `source release 21 requires target release 21` | Java version mismatch  | Set JAVA_HOME to JDK 21                                                     |
| `encoding unmappable character`                | Non-UTF-8 source file  | Ensure `<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>` |

### 4. ISO 8583-Specific Bugs

These are the hardest to diagnose because they involve domain-specific encoding rules.

#### Bitmap Errors

```
Expected: field 3 present
Actual:   field 3 not found in unpacked message
```

**Diagnosis:** Print the bitmap hex and verify bit positions manually.

```java
System.out.println("Bitmap hex: " + bitmap.toHexString());
System.out.println("Bit 1 (secondary): " + bitmap.isSet(1));
System.out.println("Bit 3: " + bitmap.isSet(3));
```

**Common cause:** Off-by-one in bit numbering. ISO 8583 bits are 1-indexed.

#### Encoding Mismatch

```
Expected: "0200" (4 bytes ASCII)
Actual:   [0x02, 0x00] (2 bytes BCD)
```

**Diagnosis:** Hex-dump the raw bytes to see the actual encoding.

```java
System.out.println(HexDump.format(rawBytes));
```

**Common cause:** MTI encoding configured as BCD but test expects ASCII.

#### Length Prefix Errors (LLVAR/LLLVAR)

```
IsoUnpackException: Field 2 length prefix says 19 but only 12 bytes remain
```

**Diagnosis:** The length prefix encoding doesn't match the field encoding.

**Common cause:** Length prefix encoded in BCD but data in ASCII (or vice versa).

#### Padding Errors

```
Expected: "000000001234" (left-padded numeric)
Actual:   "1234        " (right-padded with spaces)
```

**Common cause:** Numeric field formatted with alphabetic padding rules.

### 5. Performance Issues

```bash
# Quick performance test
mvn test -Dtest=PerformanceTest -Dsurefire.useFile=false
```

The DoD requires < 5ms P99 for full message pack/unpack. If performance is degrading:

| Symptom               | Likely Cause                   | Fix                                      |
| --------------------- | ------------------------------ | ---------------------------------------- |
| Pack > 5ms            | String concatenation in a loop | Use `StringBuilder` or `byte[]` directly |
| Unpack > 5ms          | Excessive array copying        | Use `IsoCursor` with offset tracking     |
| Mapper > 5ms overhead | Reflection on every call       | Cache `IsoMessageMetadata` per class     |

### 6. Resilience Issues (Rule 24)

| Symptom                                | Likely Cause                         | Fix                                                                     |
| -------------------------------------- | ------------------------------------ | ----------------------------------------------------------------------- |
| RC 96 on all transactions              | Circuit breaker OPEN                 | Check DB connectivity, wait for half-open recovery                      |
| 429 on REST API                        | Rate limit exceeded                  | Increase `simulator.resilience.rate-limit.rest-per-ip` or check for DoS |
| 503 on REST API                        | Circuit open or bulkhead full        | Check DB health, increase bulkhead capacity                             |
| Transactions approved during DB outage | Fallback not fail-secure             | Fix fallback to return RC 96, NEVER approve                             |
| Timeout on normal transactions         | Bulkhead queue full, threads starved | Check timeout simulation not blocking main pool                         |
| Degradation stuck in EMERGENCY         | Metrics not recovering               | Check DB circuit, verify evaluation interval                            |

## Debugging Tools Available

### HexDump Utility (STORY-013)

Once implemented, use the project's own debug utilities:

```java
// Visual hex dump of a packed message
String dump = HexDump.format(packedBytes);
// 00000000  30 32 30 30 72 30 00 00  00 00 04 00 00 00 00 00  |0200r0..........|

// Structured ISO message dump
String isoDump = IsoDump.dump(isoMessage);
// MTI: 0200
// Bitmap: 7230000000040000
// DE-002 [PAN]:  4111111111111111
// DE-003 [Proc]: 000000
```

### Manual Hex Analysis

Before STORY-013 is implemented, debug encoding issues with:

```java
// Print raw bytes as hex
System.out.println(Arrays.toString(bytes));

// Or use a helper method
private static String toHex(byte[] bytes) {
    var sb = new StringBuilder();
    for (byte b : bytes) {
        sb.append(String.format("%02X ", b));
    }
    return sb.toString().trim();
}
```

## The Fix-First-Test Pattern

For every bug found:

```java
@Test
void shouldNotThrow_whenFieldValueIsEmpty() {
    // This test was added for bug #NNN
    // Previously threw NullPointerException when field value was empty string

    // Arrange
    var packer = createDefaultPacker();
    var fields = Map.of(3, "");  // empty field

    // Act & Assert — should NOT throw
    assertThatCode(() -> packer.pack("0200", fields))
        .doesNotThrowAnyException();
}
```

First write the test that reproduces the bug (it should fail). Then fix the code. Then verify the test passes.

## Quick Diagnosis Checklist

When something fails, check in this order:

1. **Is it a compilation error?** → Read the error message carefully. Usually a typo or missing import.
2. **Is it a test failure?** → Read the expected vs actual. Run just that one test in isolation.
3. **Is it a coverage failure?** → Check the JaCoCo HTML report. Find the uncovered branches.
4. **Is it an encoding issue?** → Hex-dump the bytes. Compare expected vs actual byte-by-byte.
5. **Is it a domain issue?** → Re-read the ISO 8583 spec (the `docs/` directory has all annexes). Verify your understanding of the field type, length type, and encoding.
6. **Is it intermittent?** → Suspect shared mutable state. Check for `static` fields. Ensure tests create fresh objects.
