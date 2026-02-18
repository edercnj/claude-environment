---
name: java-maven
description: "Java 21 + Maven build conventions: pom.xml structure, dependencies, plugins, compiler settings, build profiles. Referenced internally by agents needing build context."
user-invocable: false
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Java 21 + Maven Build Skill — b8583

## Purpose

This skill manages the entire Maven build lifecycle for the b8583 ISO 8583 library. The project is a zero-dependency Java 21 JAR — only JDK 21 at runtime, with JUnit 5 + AssertJ in test scope. Every build decision flows from this constraint.

## Project Coordinates

```xml
<groupId>com.bifrost</groupId>
<artifactId>b8583</artifactId>
<version>0.1.0-SNAPSHOT</version>
<packaging>jar</packaging>
```

**Java version:** 21 (source, target, and release)
**Encoding:** UTF-8 everywhere

## Quick Commands

```bash
# Full build (clean + compile + test)
mvn clean verify

# Compile only
mvn clean compile

# Run all tests
mvn test

# Run single test class
mvn test -Dtest=IsoBitmapTest

# Run single test method
mvn test -Dtest=IsoBitmapTest#shouldSetSecondaryBitmap_whenBitAbove64IsSet

# Coverage report (after tests)
mvn test jacoco:report
# Report at: target/site/jacoco/index.html

# Package JAR
mvn clean package -DskipTests

# Javadoc
mvn javadoc:javadoc
```

## Project Structure

The project follows the standard Maven layout with Java 21 module system:

```
b8583/
├── pom.xml
├── src/
│   ├── main/
│   │   └── java/
│   │       ├── module-info.java
│   │       └── com/bifrost/b8583/
│   │           ├── type/        — ISO field types, charset validation
│   │           ├── bitmap/      — Bitmap management (primary/secondary)
│   │           ├── mti/         — MTI parsing, matching, version detection
│   │           ├── registry/    — DataElementDef, DataElementRegistry, SubElementParser
│   │           ├── dialect/     — IsoDialect, IsoVersion, DialectBuilder
│   │           ├── pack/        — IsoPacker (serializer)
│   │           ├── unpack/      — IsoUnpacker, IsoCursor (deserializer)
│   │           ├── annotation/  — @DataElement, @IsoMessage, @IsoField, etc.
│   │           ├── mapper/      — IsoMapper, IsoMessageMetadata
│   │           ├── converter/   — FieldConverter, built-in converters
│   │           ├── exception/   — IsoException hierarchy, ValidationMode
│   │           └── util/        — IsoDump, HexDump, IsoMessageLogger
│   └── test/
│       └── java/
│           └── com/bifrost/b8583/
│               └── (mirrors main structure)
├── docs/
├── stories/
└── CLAUDE.md
```

## POM Configuration Rules

When creating or modifying `pom.xml`, follow these principles:

1. **Zero runtime dependencies.** The `<dependencies>` section contains ONLY test-scoped artifacts:
   - `junit-jupiter` (test)
   - `assertj-core` (test)

2. **Java 21 compiler settings** with `--release 21` to guarantee forward compatibility.

3. **Required plugins:**
   - `maven-compiler-plugin` — Java 21, `-parameters` flag (for annotation processing)
   - `maven-surefire-plugin` — JUnit 5 execution
   - `jacoco-maven-plugin` — Coverage enforcement (line ≥ 95%, branch ≥ 90%)
   - `maven-javadoc-plugin` — Javadoc generation
   - `maven-jar-plugin` — JAR packaging with module-info

4. **JaCoCo enforcement** must fail the build if thresholds are not met.

For the complete pom.xml template, read `references/pom-template.md`.

## Module System (module-info.java)

The project uses Java Platform Module System (JPMS). The `module-info.java` exports all public packages and requires no external modules at runtime:

```java
module com.bifrost.b8583 {
    exports com.bifrost.b8583.type;
    exports com.bifrost.b8583.bitmap;
    exports com.bifrost.b8583.mti;
    exports com.bifrost.b8583.registry;
    exports com.bifrost.b8583.dialect;
    exports com.bifrost.b8583.pack;
    exports com.bifrost.b8583.unpack;
    exports com.bifrost.b8583.annotation;
    exports com.bifrost.b8583.mapper;
    exports com.bifrost.b8583.converter;
    exports com.bifrost.b8583.exception;
    exports com.bifrost.b8583.util;
}
```

Test modules don't need a separate `module-info.java` — Maven surefire handles this automatically.

## Java 21 Patterns to Use

The b8583 project leverages Java 21 features extensively. These are not optional — they are architectural decisions (ADR-001):

- **Records** for immutable value objects (`DataElementDef`, `IsoMessage`, `ValidationWarning`)
- **Sealed interfaces** for restricted type hierarchies (`SubElementParser`, `IsoVersion`)
- **Pattern matching** with `switch` expressions and `instanceof`
- **Builder pattern** for complex construction (`DialectBuilder`, `DataElementRegistry.Builder`)
- **`Optional`** for nullable returns (never return null from public API)
- **Text blocks** for multi-line strings in tests

For detailed Java 21 patterns and examples, read `references/java21-patterns.md`.

## Common Build Issues

| Problem                                        | Cause                   | Fix                                                                      |
| ---------------------------------------------- | ----------------------- | ------------------------------------------------------------------------ |
| `source release 21 requires target release 21` | Mismatched Java version | Set `<release>21</release>` in compiler plugin                           |
| `module-info.java` compilation error           | Module not found        | Verify module name matches directory structure                           |
| `unmappable character for encoding`            | Non-UTF-8 source        | Add `<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>` |
| JaCoCo threshold failure                       | Coverage below 95%/90%  | Write more tests — no exceptions to the threshold                        |
| Surefire not finding tests                     | Wrong JUnit version     | Ensure `junit-jupiter` 5.x, not JUnit 4                                  |

## When Creating the Project from Scratch (STORY-000)

If this is the initial project setup:

1. Create directory structure (all 12 packages under `com.bifrost.b8583`)
2. Write `pom.xml` from the template in `references/pom-template.md`
3. Write `module-info.java`
4. Add a placeholder class and test to validate the build works
5. Run `mvn clean verify` to confirm everything compiles and tests run
6. Verify JaCoCo report generates at `target/site/jacoco/index.html`
