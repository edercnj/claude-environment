# Story Implementation Workflow — b8583

Detailed step-by-step guide for implementing each story.

## Pre-Implementation Checklist

Before starting any story, verify:

- [ ] All `Blocked By` stories are merged into `main`
- [ ] You have read the story file (`stories/STORY-NNN.md`)
- [ ] You have read the relevant ADRs (listed in the story)
- [ ] You have created a feature branch (`feature/STORY-NNN-description`)
- [ ] `mvn clean compile` passes on main (baseline is green)

## Story → Implementation Guide

### STORY-000: Project Setup

**What to create:**
1. `pom.xml` (from java-maven skill template)
2. `src/main/java/module-info.java`
3. All 12 package directories under `com.bifrost.b8583`
4. A placeholder class (e.g., `B8583.java` with version constant)
5. A placeholder test validating the build works

**Validation:** `mvn clean verify` passes.

### STORY-001: Primitive Types and Formatting

**Package:** `com.bifrost.b8583.type`

**Key classes:**
- `IsoFieldType` — Enum or sealed type for a, n, s, an, as, ns, ans, anp, ansb, b, z, x+n, xn
- `Formatter` — Format/validate field values per type
- `Encoding` — Enum: ASCII, BCD, EBCDIC, HEX_STRING, BINARY_RAW
- `LengthType` — Enum: FIXED, LVAR, LLVAR, LLLVAR, LLLLVAR
- `PadDirection` — Enum: LEFT, RIGHT, NONE

**Key tests:**
- Charset validation for all 13 field types (parametrized)
- Padding (left-zero for numeric, right-space for alpha)
- BCD encoding/decoding
- EBCDIC encoding/decoding

### STORY-002: Bitmap Engine

**Package:** `com.bifrost.b8583.bitmap`

**Key classes:**
- `IsoBitmap` — 128-bit bitmap with primary/secondary management

**Key behaviors:**
- Set/clear/check individual bits (1-128)
- Auto-manage Bit 1 (continuation bit)
- Serialize to hex string (16 or 32 chars)
- Parse from hex string or byte array

### STORY-003: Data Element Registry

**Package:** `com.bifrost.b8583.registry`

**Key classes:**
- `DataElementDef` — Record: bit, name, type, length, lengthType, optional SubElementParser
- `DataElementRegistry` — Immutable map of 128 element definitions, with Builder
- `SubElementParser` — Sealed interface: PositionalParser, TlvParser, BerTlvParser, BitmappedParser

### STORY-004: MTI Processor

**Package:** `com.bifrost.b8583.mti`

**Key classes:**
- `MessageTypeIndicator` — Parse/validate/match MTI codes
- Support both 4-digit (1987/1993) and 3-digit (2021)
- Request ↔ response matching (0100 → 0110)

### STORY-005: Packer (Serializer)

**Package:** `com.bifrost.b8583.pack`

**Key classes:**
- `IsoPacker` — Takes MTI + Map<Integer, String> → byte[]
- Uses DataElementRegistry for field definitions
- Uses IsoDialect for encoding configuration

**Algorithm:**
1. Encode MTI
2. Build bitmap from present fields
3. Encode bitmap
4. For each set bit (ascending), encode field value per its definition

### STORY-006: Unpacker (Deserializer)

**Package:** `com.bifrost.b8583.unpack`

**Key classes:**
- `IsoUnpacker` — Takes byte[] → IsoMessage
- `IsoCursor` — Safe cursor with bounds checking over byte array

**Algorithm:**
1. Read MTI (4 or 3 bytes depending on version)
2. Read primary bitmap
3. If Bit 1 set, read secondary bitmap
4. For each set bit (ascending), read field per its definition

### STORY-007: Dialect Management

**Package:** `com.bifrost.b8583.dialect`

**Key classes:**
- `IsoDialect` — Record: name, version, registry, encodings, applyAnnexJ
- `IsoVersion` — Sealed interface: Iso1987, Iso1993, Iso2021
- `DialectBuilder` — Fluent builder with dialect inheritance (base → Visa)

### STORY-008: Annotation-Based Registry Loading

**Package:** `com.bifrost.b8583.annotation`

**Key classes:**
- `@DataElement` — Annotation for field definitions
- `AnnotationRegistryLoader` — Reads @DataElement annotations → DataElementRegistry

### STORY-009: IsoMapper (The Hibernate Layer)

**Package:** `com.bifrost.b8583.mapper`, `com.bifrost.b8583.annotation`

**Key classes:**
- `IsoMapper` — Central API: pack(pojo) → byte[], unpack(byte[], Class) → pojo
- `@IsoMessage` — Class-level (mti, dialect)
- `@IsoField` — Field-level (bit, converter)
- `IsoMessageMetadata` — Cached reflection metadata per class

### STORY-010: Type Converters

**Package:** `com.bifrost.b8583.converter`

**Key classes:**
- `FieldConverter<J, I>` — Interface: toIso(J) → String, fromIso(String) → J
- Built-in: AmountConverter, DateTimeConverter, ExpirationDateConverter, CurrencyConverter, BooleanConverter, EnumConverter

### STORY-011: Composite Field Mapping

**Package:** `com.bifrost.b8583.annotation`, `com.bifrost.b8583.mapper`

**Key annotations:**
- `@CompositeField` — Marks a nested POJO for composite data elements
- `@SubField` — Position-based sub-field mapping
- `@TlvField` — TLV/BER-TLV sub-field mapping

### STORY-012: Exception Hierarchy

**Package:** `com.bifrost.b8583.exception`

**Key classes:**
- `IsoException` (base) with field number, position, raw data context
- `IsoPackException`, `IsoUnpackException`
- `IsoFieldException`, `IsoBitmapException`, `IsoMtiException`
- `ValidationMode` enum: STRICT, LENIENT

### STORY-013: Debug Utilities

**Package:** `com.bifrost.b8583.util`

**Key classes:**
- `HexDump` — Format byte arrays as hex dump with ASCII sidebar
- `IsoDump` — Pretty-print parsed ISO messages
- `IsoMessageLogger` — Logging with field masking (PAN, Track 2)

## Post-Implementation Checklist

After implementing a story:

- [ ] All Gherkin scenarios from the story have corresponding tests
- [ ] `mvn test` passes (all green)
- [ ] `mvn test jacoco:report` shows line ≥ 95%, branch ≥ 90%
- [ ] All public classes and methods have Javadoc
- [ ] No runtime dependencies added to pom.xml
- [ ] `mvn clean verify` passes (full build + coverage check)
- [ ] Commits follow conventional format
- [ ] Branch is pushed
