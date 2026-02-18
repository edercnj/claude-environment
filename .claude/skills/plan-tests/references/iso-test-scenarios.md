# ISO 8583 Test Scenario Reference

Pre-built scenario templates for common ISO 8583 testing patterns.
Use these as a starting point when generating test plans for specific stories.

## Bitmap Scenarios

| # | Scenario | Input | Expected | Category |
|---|----------|-------|----------|----------|
| 1 | Set single bit (primary) | set(3) | bit 3 on, bit 1 off | Happy |
| 2 | Set bit in secondary range | set(65) | bit 1 auto-set, bit 65 on | Happy |
| 3 | Clear last secondary bit | clear(65) when only bit 65 was in secondary | bit 1 auto-cleared | Happy |
| 4 | Set bit 0 (invalid) | set(0) | IllegalArgumentException | Error |
| 5 | Set bit 129 (overflow) | set(129) | IllegalArgumentException | Error |
| 6 | Set bit 1 directly | set(1) | Rejected or managed internally | Error |
| 7 | Bit 2 (minimum valid) | set(2) | Success | Boundary |
| 8 | Bit 64 (primary max) | set(64) | No secondary bitmap needed | Boundary |
| 9 | Bit 128 (absolute max) | set(128) | Secondary bitmap present | Boundary |
| 10 | Empty bitmap | new IsoBitmap() | No bits set, toHex = all zeros | Boundary |
| 11 | Full bitmap | set all 2-128 | All bits set, both bitmaps full | Boundary |
| 12 | Hex roundtrip | set bits → toHex → fromHex → compare | Identical bitmap | Roundtrip |
| 13 | Binary roundtrip | set bits → toBytes → fromBytes → compare | Identical bitmap | Roundtrip |

## MTI Scenarios

| # | Scenario | Input | Expected | Category |
|---|----------|-------|----------|----------|
| 1 | Parse 1987 authorization request | "0100" | ver=1987, class=AUTH, func=REQUEST | Happy |
| 2 | Parse 1993 financial request | "1200" | ver=1993, class=FINANCIAL, func=REQUEST | Happy |
| 3 | Parse 2021 3-digit MTI | "200" | ver=2021, class=FINANCIAL, func=REQUEST | Happy |
| 4 | Request → Response matching | "0200" → toResponse | "0210" | Happy |
| 5 | Null MTI string | null | NullPointerException | Error |
| 6 | Empty MTI string | "" | InvalidMTIException | Error |
| 7 | Invalid length (5 digits) | "02001" | InvalidMTIException | Error |
| 8 | Non-numeric MTI | "02XY" | InvalidMTIException | Error |
| 9 | Unknown version digit | "5200" | UnknownMtiException | Error |
| 10 | Minimum MTI (1987) | "0100" | Valid | Boundary |
| 11 | Maximum MTI (1987) | "0999" | Valid or handled | Boundary |
| 12 | 3-digit boundary (2021) | "100" | Minimum valid 2021 MTI | Boundary |
| 13 | All versions × all classes | 3 versions × 6 classes | @ParameterizedTest matrix | Parametrized |
| 14 | All request → response pairs | "x100"→"x110", "x200"→"x210", etc. | @ParameterizedTest | Parametrized |

## Field Type Charset Scenarios

| # | Type | Valid Input | Invalid Input | Padding | Category |
|---|------|-------------|---------------|---------|----------|
| 1 | a | "ABCDE" | "ABC12" | Right, space | Parametrized |
| 2 | n | "12345" | "123AB" | Left, zero | Parametrized |
| 3 | s | "!@#$%" | "ABC" | Right, space | Parametrized |
| 4 | an | "ABC123" | "ABC!@" | Right, space | Parametrized |
| 5 | as | "ABC!@#" | "123" | Right, space | Parametrized |
| 6 | ns | "123!@" | "ABC" | Right, space | Parametrized |
| 7 | ans | "Hi! 123" | (binary control chars) | Right, space | Parametrized |
| 8 | anp | "ABC123 " | (binary) | Right, space | Parametrized |
| 9 | ansb | "ABC\x00" | — | None | Parametrized |
| 10 | b | raw bytes | — | None (exact) | Parametrized |
| 11 | z | "1234=5678" | "ABC" | Right, F | Parametrized |
| 12 | x+n | "C000000010000" | "X12345" | Left, zero | Parametrized |
| 13 | xn | "D123456" | "Q12345" | Left, zero | Parametrized |

## Length Type Boundary Scenarios

| # | Length Type | Min | Max | Over Max | Category |
|---|-----------|-----|-----|----------|----------|
| 1 | FIXED | exact size | exact size | exact+1 → FieldOverflow | Boundary |
| 2 | LVAR | 0 (empty) | 9 | 10 → FieldOverflow | Boundary |
| 3 | LLVAR | 0 (empty) | 99 | 100 → FieldOverflow | Boundary |
| 4 | LLLVAR | 0 (empty) | 999 | 1000 → FieldOverflow | Boundary |
| 5 | LLLLVAR | 0 (empty) | 9999 | 10000 → FieldOverflow | Boundary |

## Encoding Matrix

For stories involving encoding, test the cross product:

| Encoding Axis | Options | Combinations |
|---------------|---------|-------------|
| MTI encoding | ASCII, BCD, EBCDIC | 3 |
| Bitmap encoding | HEX_STRING, BINARY_RAW | 2 |
| Field encoding | ASCII, BCD, EBCDIC | 3 |
| **Total combinations** | | **18** |

Not all 18 need individual tests. Focus on:
1. ASCII × HEX_STRING × ASCII (default, most common)
2. BCD × BINARY_RAW × BCD (packed, performance-oriented)
3. EBCDIC × HEX_STRING × EBCDIC (legacy mainframe)
4. Mixed: ASCII MTI × BINARY_RAW bitmap × BCD fields (real-world Visa-like)

## Roundtrip Message Templates

Standard messages for pack→unpack roundtrip testing:

### Minimal Message (3 fields)
```
MTI: 0200
Fields: {3: "003000", 11: "000001", 41: "TERM0001"}
```

### Financial Authorization (10+ fields)
```
MTI: 1200
Fields: {
  2: "4111111111111111",
  3: "003000",
  4: "000000015050",
  7: "0215143052",
  11: "000001",
  14: "2612",
  22: "051",
  25: "00",
  37: "000000000001",
  41: "TERM0001",
  42: "MERCH00000000001",
  43: "Loja Centro             Sao Paulo    BR"
}
```

### Message with Secondary Bitmap (fields 65+)
```
MTI: 0200
Fields: {
  2: "4111111111111111",
  3: "003000",
  4: "000000015050",
  11: "000001",
  41: "TERM0001",
  55: "<EMV TLV data>",
  70: "301"
}
```

### Network Management Message
```
MTI: 0800
Fields: {
  7: "0215143052",
  11: "000001",
  70: "301"
}
```

## Exception → Test Mapping

Quick reference for which exceptions to test per story layer:

### Layer 1 (Primitives: STORY-001, 002, 004)
| Exception | Trigger |
|-----------|---------|
| IllegalArgumentException | Invalid bit number, null parameters |
| InvalidFieldValueException | Wrong charset for field type |
| InvalidMTIException | Malformed MTI string |

### Layer 2 (Engine: STORY-003, 005, 006, 007)
| Exception | Trigger |
|-----------|---------|
| IsoParseException | Malformed message buffer |
| UnexpectedEndOfMessageException | Truncated buffer |
| InvalidBitmapException | Non-hex chars in bitmap |
| InvalidLengthPrefixException | Non-numeric length prefix |
| UnknownFieldException | Bit set but no definition in registry |
| FieldOverflowException | Value exceeds max length |
| MissingMandatoryFieldException | Required field not present |
| IsoPackException | General packing error |
| VersionMismatchException | LLLLVAR in 1987 dialect |

### Layer 3 (Mapper: STORY-009, 010, 011)
| Exception | Trigger |
|-----------|---------|
| AnnotationValidationException | Invalid annotation config |
| FieldMissingException | @IsoField bit not in message |
| ValidationException | Custom validation rule failure |

## Persistent Connection Test Scenarios

TCP connections are long-lived and accept multiple messages sequentially.
Test both the individual message handling and the connection state management.

### Scenarios for Persistent Connections

| # | Scenario | Setup | Messages | Expected | Category |
|---|----------|-------|----------|----------|----------|
| 1 | Single message | Client connects | 1 message (0200) | Response, connection open | Happy |
| 2 | Two messages | Client connects | Msg 1 (0200), Msg 2 (0200) | 2 responses, connection open | Happy |
| 3 | Multiple fast messages | Client connects | 10x 0200 rapid fire | 10 responses, no loss, connection open | Happy |
| 4 | Mixed message types | Client connects | 0200, 0100, 0400, 0800 | Correct responses for each, connection open | Happy |
| 5 | Reversal on same connection | Client connects | 0200 (approved), 0400 (reversal of same) | Both in DB linked, connection open | Happy |
| 6 | Idle between messages | Client connects, Msg 1, wait 5s, Msg 2 | Time gap > 5s | Both processed, connection maintained | Happy |
| 7 | Message after idle timeout | Client connects, idle > 300s, send msg | After idle timeout | Connection closed OR msg rejected | Boundary |
| 8 | Malformed message 1 | Client connects, Msg 1 bad, Msg 2 good | Msg 1 invalid, Msg 2 0200 | Error response for Msg 1, valid response for Msg 2, connection open | Error |
| 9 | Backpressure test | Client connects | 100 messages very fast | All processed in order, no buffer overflow | Performance |
| 10 | Connection reset by client | Client connects, Msg 1, client closes | Client abrupt close | Connection closed cleanly on server | Error |
| 11 | Timeout rule on connection | Client connects (timeout terminal) | 0200 with timeout flag, then 0200 normal | First delayed 35s, second fast, connection open | Happy |
| 12 | Multiple terminals same connection | Client connects as terminal A | 5x 0200 as A, 5x 0200 as B (diff TID) | All processed separately, connection open | Happy |

### Multi-Message Scenarios in E2E Tests

#### Scenario: 5 Sequential Purchases
```
Message 1: Purchase 100.00 (RC=00)
Message 2: Purchase 150.51 (RC=51)
Message 3: Purchase 200.05 (RC=05)
Message 4: Purchase 250.00 (RC=00)
Message 5: Purchase 300.14 (RC=14)

Expected: All 5 responses returned, all 5 in DB with correct RC, connection open for more
```

#### Scenario: Reversal Pair on Same Connection
```
Message 1: 0200 Purchase 100.00 (RC=00)
Message 2: 0400 Reversal of Msg 1 (RC=00)

Expected: Both in DB, linked by STAN, Msg 1 status=REVERSED, connection open
```

#### Scenario: Echo Interspersed with Purchases
```
Message 1: 0200 Purchase 100.00
Message 2: 0800 Echo test
Message 3: 0200 Purchase 150.00

Expected: Msg 1 and 3 in DB, Msg 2 not persisted, all responses valid, connection open
```

#### Scenario: Timeout Does Not Block Other Messages
```
Message 1: 0200 Purchase with timeout terminal (35s delay expected)
Message 2: 0200 Purchase normal terminal (immediate response)
Message 3: 0200 Purchase normal terminal

Expected: Msg 2 and 3 respond immediately, Msg 1 responds after 35s, all processed, connection open
```

#### Scenario: Malformed Message Does Not Kill Connection
```
Message 1: Valid 0200 Purchase
Message 2: Garbage bytes (invalid ISO frame)
Message 3: Valid 0200 Purchase

Expected: Msg 1 success, Msg 2 error response (RC=96), Msg 3 success, connection remains open
```

#### Scenario: High-Frequency Message Rate
```
50 rapid 0200 messages (< 100ms between each)

Expected: All 50 processed successfully in order, p95 latency < 200ms, no messages lost, connection open
```
