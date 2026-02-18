# Encoding Tables — ISO 8583

## ASCII Encoding

Standard ASCII. Each character = 1 byte.

| Character | Hex | Decimal |
|-----------|-----|---------|
| `0` | 0x30 | 48 |
| `1` | 0x31 | 49 |
| `2` | 0x32 | 50 |
| ... | ... | ... |
| `9` | 0x39 | 57 |
| `A` | 0x41 | 65 |
| `B` | 0x42 | 66 |
| ... | ... | ... |
| `F` | 0x46 | 70 |
| `a` | 0x61 | 97 |
| space | 0x20 | 32 |

**Example:** MTI `"0200"` in ASCII = `[0x30, 0x32, 0x30, 0x30]` (4 bytes)

## BCD (Binary-Coded Decimal) Encoding

Two decimal digits packed into one byte. Only works for numeric data.

| Digits | BCD byte | Hex |
|--------|----------|-----|
| `00` | 0000 0000 | 0x00 |
| `01` | 0000 0001 | 0x01 |
| `12` | 0001 0010 | 0x12 |
| `42` | 0100 0010 | 0x42 |
| `99` | 1001 1001 | 0x99 |

**Example:** MTI `"0200"` in BCD = `[0x02, 0x00]` (2 bytes — half the size of ASCII)

**Odd-length values:** When a numeric value has an odd number of digits, pad with a leading `0` before encoding.
- `"123"` → `"0123"` → `[0x01, 0x23]`

### BCD Conversion Algorithm

```
Encode: digit_pair → byte = (high_digit << 4) | low_digit
Decode: byte → digit_pair = (byte >> 4) + "" + (byte & 0x0F)
```

## EBCDIC Encoding

IBM mainframe character encoding. Same 1-byte-per-character as ASCII, but different byte values.

| Character | EBCDIC Hex | ASCII Hex |
|-----------|-----------|-----------|
| `0` | 0xF0 | 0x30 |
| `1` | 0xF1 | 0x31 |
| `2` | 0xF2 | 0x32 |
| `3` | 0xF3 | 0x33 |
| `4` | 0xF4 | 0x34 |
| `5` | 0xF5 | 0x35 |
| `6` | 0xF6 | 0x36 |
| `7` | 0xF7 | 0x37 |
| `8` | 0xF8 | 0x38 |
| `9` | 0xF9 | 0x39 |
| `A` | 0xC1 | 0x41 |
| `B` | 0xC2 | 0x42 |
| `C` | 0xC3 | 0x43 |
| `D` | 0xC4 | 0x44 |
| `E` | 0xC5 | 0x45 |
| `F` | 0xC6 | 0x46 |
| space | 0x40 | 0x20 |

**Example:** MTI `"0200"` in EBCDIC = `[0xF0, 0xF2, 0xF0, 0xF0]` (4 bytes)

## Bitmap Encoding

Two options:

### Hex String (ASCII)
Each nibble (4 bits) is represented as a hex character (ASCII encoded).
- 64 bits → 16 hex chars → 16 bytes
- Example: bits 2,3,4 set → `7000000000000000` → 16 ASCII bytes

### Binary (Raw)
Each bit is a literal bit in a byte array.
- 64 bits → 8 bytes
- Example: bits 2,3,4 set → `[0x70, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]` → 8 bytes

## Three Encoding Axes

The encoding of each part of the message is independently configurable:

```
Message = [MTI encoding] + [Bitmap encoding] + [Field encoding]
```

| Configuration | Typical Production | Test/Debug |
|---------------|-------------------|------------|
| MTI | BCD | ASCII |
| Bitmap | Binary (8 bytes) | Hex String (16 chars) |
| Fields | BCD (numeric), ASCII (alpha) | ASCII (all) |

The `IsoDialect` object holds all three encoding configurations. Different payment networks (Visa, Mastercard) may use different combinations.

## Length Prefix Encoding

For variable-length fields (LLVAR, LLLVAR, etc.), the length prefix can also be encoded differently:

| Encoding | LLVAR "Hello" (len=5) | Wire bytes |
|----------|----------------------|------------|
| ASCII | `"05Hello"` | `[0x30, 0x35, 0x48, 0x65, 0x6C, 0x6C, 0x6F]` |
| BCD | `[0x05] + "Hello"` | `[0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F]` |

Note: The length prefix encoding typically follows the field encoding axis, but some dialects override this.
