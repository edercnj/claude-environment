# Test Patterns — b8583

Advanced test patterns specific to the b8583 ISO 8583 library.

## Round-Trip Testing

The most critical test pattern for b8583. Verifies that pack → unpack produces the original data:

```java
@ParameterizedTest
@MethodSource("provideRoundTripMessages")
void shouldRoundTrip_packThenUnpack(String mti, Map<Integer, String> fields) {
    // Pack
    byte[] packed = packer.pack(mti, fields);

    // Unpack
    IsoMessage unpacked = unpacker.unpack(packed);

    // Verify
    assertThat(unpacked.getMti()).isEqualTo(mti);
    assertThat(unpacked.getFields()).isEqualTo(fields);
}

static Stream<Arguments> provideRoundTripMessages() {
    return Stream.of(
        // Minimal message: MTI + 1 field
        Arguments.of("0200", Map.of(3, "000000")),

        // Authorization request
        Arguments.of("0100", Map.of(
            2, "4111111111111111",   // PAN (LLVAR)
            3, "000000",             // Processing Code (FIXED 6)
            4, "000000001000",       // Amount (FIXED 12)
            11, "123456",            // STAN (FIXED 6)
            41, "TERM0001",          // Terminal ID (FIXED 8)
            49, "986"                // Currency (FIXED 3)
        )),

        // Message with secondary bitmap (field > 64)
        Arguments.of("0200", Map.of(
            2, "4111111111111111",
            3, "000000",
            70, "001"                // Network Management Code
        ))
    );
}
```

## Encoding Matrix Testing

Test all encoding combinations using a parametrized matrix:

```java
@ParameterizedTest
@EnumSource(Encoding.class)
void shouldPackMti_inAllEncodings(Encoding encoding) {
    var dialect = DialectBuilder.base()
        .mtiEncoding(encoding)
        .build();
    var packer = new IsoPacker(dialect);

    byte[] packed = packer.packMti("0200");

    switch (encoding) {
        case ASCII -> assertThat(packed).isEqualTo(new byte[]{0x30, 0x32, 0x30, 0x30});
        case BCD -> assertThat(packed).isEqualTo(new byte[]{0x02, 0x00});
        case EBCDIC -> assertThat(packed).isEqualTo(new byte[]{(byte)0xF0, (byte)0xF2, (byte)0xF0, (byte)0xF0});
    }
}
```

## Charset Validation Matrix

Test every field type with valid and invalid inputs:

```java
@ParameterizedTest
@CsvSource({
    // type, value, expected valid
    "a,    HELLO,      true",
    "a,    HELLO123,   false",
    "a,    Hello World, false",
    "n,    12345,      true",
    "n,    123AB,      false",
    "n,    '',         true",
    "an,   ABC123,     true",
    "an,   ABC 123,    false",
    "ans,  Hello! @#,  true",
    "s,    !@#$%,      true",
    "s,    ABC,        false",
    "z,    1234=5678,  true",
    "z,    1234A5678,  false",
})
void shouldValidateCharset(String type, String value, boolean expected) {
    var fieldType = IsoFieldType.of(type);
    assertThat(fieldType.isValid(value))
        .as("Type '%s' should %s value '%s'", type, expected ? "accept" : "reject", value)
        .isEqualTo(expected);
}
```

## Exception Testing

Verify that errors produce rich context:

```java
@Test
void shouldThrowWithContext_whenFieldValueExceedsMaxLength() {
    var registry = registryWithField(2, "n", 19, LengthType.LLVAR);
    var packer = new IsoPacker(dialectWith(registry));

    assertThatThrownBy(() -> packer.pack("0200", Map.of(2, "1".repeat(20))))
        .isInstanceOf(IsoPackException.class)
        .hasMessageContaining("field 2")
        .hasMessageContaining("max length 19")
        .hasMessageContaining("actual length 20")
        .extracting("fieldNumber")
        .isEqualTo(2);
}

@Test
void shouldThrowWithPosition_whenUnpackEncountersCorruptData() {
    byte[] corrupt = new byte[]{0x30, 0x32, 0x30, 0x30, 0xFF};

    assertThatThrownBy(() -> unpacker.unpack(corrupt))
        .isInstanceOf(IsoUnpackException.class)
        .hasMessageContaining("position")
        .extracting("bytePosition")
        .isNotNull();
}
```

## Boundary Value Testing

For numeric fields, test min/max/boundary values:

```java
@ParameterizedTest
@CsvSource({
    "0,    000000000000",   // Zero amount
    "1,    000000000001",   // Minimum positive
    "999999999999, 999999999999", // Maximum for n12
})
void shouldFormatAmount(long amount, String expected) {
    var formatter = new NumericFormatter(12, PadDirection.LEFT);
    assertThat(formatter.format(String.valueOf(amount))).isEqualTo(expected);
}
```

## Bitmap-Specific Tests

```java
@Test
void shouldAutomaticallySetBit1_whenSecondaryBitmapNeeded() {
    var bitmap = new IsoBitmap();
    bitmap.set(70);  // Secondary bitmap territory

    assertThat(bitmap.isSet(1))
        .as("Bit 1 (continuation bit) should be auto-set")
        .isTrue();
    assertThat(bitmap.toHexString()).hasSize(32); // 16 primary + 16 secondary
}

@Test
void shouldAutomaticallyClearBit1_whenNoSecondaryBitsSet() {
    var bitmap = new IsoBitmap();
    bitmap.set(70);
    bitmap.clear(70);

    assertThat(bitmap.isSet(1))
        .as("Bit 1 should be auto-cleared when no secondary bits are set")
        .isFalse();
    assertThat(bitmap.toHexString()).hasSize(16); // Primary only
}
```

## Performance Micro-Benchmarks

For verifying the < 5ms P99 requirement:

```java
@Test
void shouldPackWithin5ms() {
    var message = createTypicalAuthorizationMessage();
    var packer = createDefaultPacker();

    // Warm up
    for (int i = 0; i < 1000; i++) {
        packer.pack(message.mti(), message.fields());
    }

    // Measure
    long[] durations = new long[10000];
    for (int i = 0; i < durations.length; i++) {
        long start = System.nanoTime();
        packer.pack(message.mti(), message.fields());
        durations[i] = System.nanoTime() - start;
    }

    Arrays.sort(durations);
    long p99Nanos = durations[(int)(durations.length * 0.99)];
    long p99Millis = p99Nanos / 1_000_000;

    assertThat(p99Millis)
        .as("P99 pack latency should be < 5ms")
        .isLessThan(5);
}
```

## Thread-Safety Tests

Verify immutability under concurrent access:

```java
@Test
void shouldBeThreadSafe_concurrentUnpack() throws Exception {
    var unpacker = createDefaultUnpacker();
    byte[] message = createPackedMessage();
    int threads = 10;
    int iterations = 1000;

    var executor = Executors.newFixedThreadPool(threads);
    var errors = new CopyOnWriteArrayList<Throwable>();

    for (int t = 0; t < threads; t++) {
        executor.submit(() -> {
            for (int i = 0; i < iterations; i++) {
                try {
                    IsoMessage result = unpacker.unpack(message);
                    assertThat(result.getMti()).isEqualTo("0200");
                } catch (Throwable e) {
                    errors.add(e);
                }
            }
        });
    }

    executor.shutdown();
    executor.awaitTermination(30, TimeUnit.SECONDS);
    assertThat(errors).isEmpty();
}
```
