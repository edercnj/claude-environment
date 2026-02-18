# Java 21 Patterns — b8583

This reference documents the Java 21 patterns used throughout the b8583 project. These are architectural decisions (ADR-001), not optional.

## Records (Immutable Value Objects)

Use records for all data-carrying objects that have no mutable state after construction:

```java
// Simple record
public record DataElementDef(
    int bit,
    String name,
    IsoFieldType type,
    int length,
    LengthType lengthType
) {
    // Compact constructor for validation
    public DataElementDef {
        if (bit < 1 || bit > 128) {
            throw new IllegalArgumentException("Bit must be 1-128, got: " + bit);
        }
        Objects.requireNonNull(name, "name must not be null");
        Objects.requireNonNull(type, "type must not be null");
        Objects.requireNonNull(lengthType, "lengthType must not be null");
        if (length < 0) {
            throw new IllegalArgumentException("Length must be non-negative, got: " + length);
        }
    }
}

// Record with derived fields
public record IsoMessage(
    String mti,
    Map<Integer, String> fields,
    byte[] rawBitmap
) {
    public IsoMessage {
        Objects.requireNonNull(mti);
        fields = Map.copyOf(fields);  // Defensive copy
        rawBitmap = rawBitmap.clone(); // Defensive copy
    }
}

// Record as builder result (immutable after build)
public record IsoDialect(
    String name,
    IsoVersion version,
    DataElementRegistry registry,
    Encoding mtiEncoding,
    Encoding bitmapEncoding,
    Encoding fieldEncoding,
    boolean applyAnnexJ
) { }
```

**When to use records:**
- Data element definitions, field metadata
- Parsed messages (IsoMessage)
- Configuration/dialect objects
- Exception context data
- Type converter results

**When NOT to use records:**
- Builder pattern (mutable during construction)
- Classes with complex behavior (IsoBitmap — needs mutation during construction)

## Sealed Interfaces

Use sealed interfaces when a type has a fixed, known set of implementations:

```java
// SubElementParser — exactly 4 implementations, no extension allowed
public sealed interface SubElementParser
    permits PositionalParser, TlvParser, BerTlvParser, BitmappedParser {

    Map<String, String> parse(byte[] data);
    byte[] pack(Map<String, String> subFields);
}

public record PositionalParser(List<SubFieldDef> positions) implements SubElementParser {
    @Override
    public Map<String, String> parse(byte[] data) { ... }
    @Override
    public byte[] pack(Map<String, String> subFields) { ... }
}

// IsoVersion — exactly 3 versions
public sealed interface IsoVersion permits Iso1987, Iso1993, Iso2021 {
    int mtiDigits();
    String versionPrefix();
}

public record Iso1987() implements IsoVersion {
    @Override public int mtiDigits() { return 4; }
    @Override public String versionPrefix() { return "0"; }
}
```

**When to use sealed interfaces:**
- Type hierarchies with known implementations
- Parser types (SubElementParser)
- Version enums with behavior (IsoVersion)
- Exception subtypes (when using sealed classes)

## Pattern Matching

Use pattern matching with `switch` expressions and `instanceof`:

```java
// Switch expression with sealed types
public int getMtiLength(IsoVersion version) {
    return switch (version) {
        case Iso1987 v -> 4;
        case Iso1993 v -> 4;
        case Iso2021 v -> 3;
    };
    // Compiler enforces exhaustiveness — no default needed
}

// Pattern matching with instanceof
public String format(Object value) {
    return switch (value) {
        case String s -> s;
        case Integer i -> String.valueOf(i);
        case BigDecimal bd -> bd.toPlainString();
        case null -> throw new NullPointerException("value must not be null");
        default -> value.toString();
    };
}

// Guard patterns
public void validate(DataElementDef def) {
    switch (def.lengthType()) {
        case FIXED when def.length() <= 0 ->
            throw new IllegalArgumentException("FIXED fields must have positive length");
        case LLVAR when def.length() > 99 ->
            throw new IllegalArgumentException("LLVAR max length is 99");
        case LLLVAR when def.length() > 999 ->
            throw new IllegalArgumentException("LLLVAR max length is 999");
        default -> { /* valid */ }
    }
}
```

## Builder Pattern

For objects that need complex construction but must be immutable once built:

```java
public final class DataElementRegistry {
    private final Map<Integer, DataElementDef> elements;

    private DataElementRegistry(Map<Integer, DataElementDef> elements) {
        this.elements = Map.copyOf(elements); // Immutable
    }

    public Optional<DataElementDef> get(int bit) {
        return Optional.ofNullable(elements.get(bit));
    }

    public static Builder builder() {
        return new Builder();
    }

    public static final class Builder {
        private final Map<Integer, DataElementDef> elements = new LinkedHashMap<>();

        public Builder add(DataElementDef def) {
            elements.put(def.bit(), def);
            return this;
        }

        public Builder addAll(DataElementRegistry other) {
            elements.putAll(other.elements);
            return this;
        }

        public DataElementRegistry build() {
            if (elements.isEmpty()) {
                throw new IllegalStateException("Registry must have at least one element");
            }
            return new DataElementRegistry(elements);
        }
    }
}
```

## Enums with Behavior

```java
public enum LengthType {
    FIXED(0),
    LVAR(1),
    LLVAR(2),
    LLLVAR(3),
    LLLLVAR(4);

    private final int prefixDigits;

    LengthType(int prefixDigits) {
        this.prefixDigits = prefixDigits;
    }

    public int prefixDigits() { return prefixDigits; }

    public int maxLength() {
        return (int) Math.pow(10, prefixDigits) - 1;
    }
}
```

## Optional (Never Return Null)

All public API methods that might not have a value return `Optional`:

```java
// GOOD
public Optional<DataElementDef> get(int bit) {
    return Optional.ofNullable(elements.get(bit));
}

// BAD — never do this
public DataElementDef get(int bit) {
    return elements.get(bit); // Could return null!
}
```

## Text Blocks (In Tests)

Use text blocks for multi-line test data:

```java
@Test
void shouldParseCompleteMessage() {
    var hexMessage = """
        0200\
        7230000000000000\
        1649111111111111\
        000000\
        000000001000\
        """.replaceAll("\\s", "");

    var result = unpacker.unpack(hexToBytes(hexMessage));
    assertThat(result.getMti()).isEqualTo("0200");
}
```
