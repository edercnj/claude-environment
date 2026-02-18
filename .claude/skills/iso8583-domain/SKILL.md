---
name: iso8583-domain
description: "ISO 8583 domain knowledge: MTI, bitmaps, field types, encoding, versioning, dialects. Referenced internally by agents needing ISO 8583 context."
user-invocable: false
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# ISO 8583 Domain Knowledge — b8583

## Purpose

ISO 8583 is the international standard for financial transaction messaging. This skill provides the domain expertise needed to implement the b8583 library correctly. Every field type, encoding rule, and message structure decision should be informed by this knowledge.

## Message Structure

An ISO 8583 message has three parts, always in this order:

```
┌──────────┬──────────────────────┬──────────────────────────────┐
│   MTI    │      Bitmap(s)       │    Data Elements (fields)    │
│ 4 bytes  │ 16 hex (+ 16 if     │ In ascending bit order       │
│ (or 3    │  secondary present)  │                              │
│  for     │                      │                              │
│  2021)   │                      │                              │
└──────────┴──────────────────────┴──────────────────────────────┘
```

### MTI (Message Type Indicator)

The MTI identifies the message purpose. It encodes four pieces of information:

**4-digit format (1987/1993):** `VFCO`

- V = Version (0=1987, 1=1993, 2=2021)
- F = Message class (function)
- C = Message function
- O = Message origin

**3-digit format (2021):** `FCO` (version is implicit)

| Class (F) | Meaning             |
| --------- | ------------------- |
| 1         | Authorization       |
| 2         | Financial           |
| 3         | File action         |
| 4         | Reversal/Chargeback |
| 5         | Reconciliation      |
| 6         | Administrative      |
| 7         | Fee collection      |
| 8         | Network management  |

| Function (C) | Meaning          |
| ------------ | ---------------- |
| 0            | Request          |
| 1            | Request response |
| 2            | Advice           |
| 3            | Advice response  |

**Request ↔ Response matching:** Add 10 to the MTI. `0100` → `0110`, `0200` → `0210`.

### Bitmaps

The bitmap indicates which data elements (fields) are present in the message.

- **Primary bitmap** (bits 1-64): Always present. 64 bits = 16 hex characters.
- **Secondary bitmap** (bits 65-128): Present only when Bit 1 of primary is set.
- **Bit 1** is the "continuation bit" — automatically set/cleared based on whether any bit 65-128 is active.

Example: A message with fields 2, 3, 4, 11, 41 has primary bitmap:

```
Bit:  1  2  3  4  5  6  7  8  9  10 11 ... 41 ...
      0  1  1  1  0  0  0  0  0  0  1  ... 1  ...
Hex:  7  2  0  0  0  0  0  0  0  0  4  0  0  0  0  0
```

### Data Elements

128 possible data elements (1-128). Each has a defined type, length, and encoding. The most commonly used:

| DE  | Name                         | Type | Length           | Notes                  |
| --- | ---------------------------- | ---- | ---------------- | ---------------------- |
| 2   | Primary Account Number (PAN) | n    | LLVAR (up to 19) | Card number            |
| 3   | Processing Code              | n    | 6 (FIXED)        | Transaction type       |
| 4   | Transaction Amount           | n    | 12 (FIXED)       | Amount in minor units  |
| 7   | Transmission Date/Time       | n    | 10 (FIXED)       | MMDDhhmmss             |
| 11  | System Trace Audit Number    | n    | 6 (FIXED)        | Unique per transaction |
| 12  | Local Transaction Time       | n    | 6 (FIXED)        | hhmmss                 |
| 13  | Local Transaction Date       | n    | 4 (FIXED)        | MMDD                   |
| 14  | Expiration Date              | n    | 4 (FIXED)        | YYMM                   |
| 22  | Point of Service Entry Mode  | n    | 3 (FIXED)        | How card was read      |
| 25  | POS Condition Code           | n    | 2 (FIXED)        |                        |
| 35  | Track 2 Data                 | z    | LLVAR (up to 37) | Magnetic stripe data   |
| 37  | Retrieval Reference Number   | an   | 12 (FIXED)       |                        |
| 38  | Authorization Code           | an   | 6 (FIXED)        |                        |
| 39  | Response Code                | an   | 2 (FIXED)        | "00" = approved        |
| 41  | Card Acceptor Terminal ID    | ans  | 8 (FIXED)        |                        |
| 42  | Card Acceptor ID Code        | ans  | 15 (FIXED)       |                        |
| 43  | Card Acceptor Name/Location  | ans  | 40 (FIXED)       | Composite field        |
| 48  | Additional Data              | ans  | LLLVAR           | Network-specific       |
| 49  | Currency Code                | n    | 3 (FIXED)        | ISO 4217               |
| 55  | ICC Related Data             | b    | LLLVAR           | EMV TLV data           |
| 60  | Private Use                  | ans  | LLLVAR           |                        |
| 70  | Network Management Code      | n    | 3 (FIXED)        |                        |

## Field Types

ISO 8583 defines specific character sets for each field type:

| Type   | Allowed Characters                            | Example           |
| ------ | --------------------------------------------- | ----------------- |
| `a`    | Alphabetic only (A-Z, a-z)                    | Names             |
| `n`    | Numeric only (0-9)                            | Amounts, codes    |
| `s`    | Special characters only                       | Punctuation       |
| `an`   | Alphabetic + numeric                          | Reference numbers |
| `as`   | Alphabetic + special                          |                   |
| `ns`   | Numeric + special                             |                   |
| `ans`  | Alphabetic + numeric + special                | Free text         |
| `anp`  | Alphabetic + numeric + pad (space)            | Padded text       |
| `ansb` | ans + binary                                  | Mixed data        |
| `b`    | Binary (raw bytes)                            | EMV/TLV data      |
| `z`    | Track data (0-9, =, D, F)                     | Magnetic stripe   |
| `x+n`  | Numeric with 'C' or 'D' prefix (credit/debit) | Amounts with sign |
| `xn`   | Hex-encoded numeric                           |                   |

### Padding Rules

| Type             | Padding | Direction       | Pad char |
| ---------------- | ------- | --------------- | -------- |
| `n` (numeric)    | LEFT    | Leading zeros   | `0`      |
| `a`, `an`, `ans` | RIGHT   | Trailing spaces | ` `      |

## Length Types

| Type    | Prefix digits | Max length | How it works                            |
| ------- | ------------- | ---------- | --------------------------------------- |
| FIXED   | 0             | Predefined | Length is known from the registry       |
| LVAR    | 1             | 9          | 1-digit length prefix (e.g., `5Hello`)  |
| LLVAR   | 2             | 99         | 2-digit length prefix (e.g., `05Hello`) |
| LLLVAR  | 3             | 999        | 3-digit length prefix                   |
| LLLLVAR | 4             | 9999       | 4-digit length prefix                   |

Example of LLVAR field: Field value `"Hello"` → Wire format `05Hello` (length prefix + data).

## Encodings

The library must support multiple wire-format encodings. There are three independent encoding axes:

| Axis            | Options                                  | Notes                           |
| --------------- | ---------------------------------------- | ------------------------------- |
| MTI encoding    | ASCII, BCD, EBCDIC                       | How the MTI bytes are encoded   |
| Bitmap encoding | ASCII (hex string), Binary (raw 8 bytes) | How bitmap bits are represented |
| Field encoding  | ASCII, BCD, EBCDIC                       | How field values are encoded    |

**ASCII:** Each character = 1 byte. `"0200"` = `[0x30, 0x32, 0x30, 0x30]` (4 bytes)

**BCD (Binary-Coded Decimal):** Two digits per byte. `"0200"` = `[0x02, 0x00]` (2 bytes). Only for numeric fields.

**EBCDIC:** IBM mainframe character encoding. Different byte values than ASCII. Still 1 byte per character.

For detailed encoding tables and conversion logic, read `references/encoding-tables.md`.

## Composite Fields

Some data elements contain structured sub-elements. Four parser types handle this:

| Parser           | Used for                  | Format                    |
| ---------------- | ------------------------- | ------------------------- |
| PositionalParser | DE-43 (Merchant Location) | Fixed-position sub-fields |
| TlvParser        | Network-specific fields   | Tag-Length-Value          |
| BerTlvParser     | DE-55 (EMV/ICC data)      | BER-encoded TLV           |
| BitmappedParser  | Some private fields       | Sub-bitmap + sub-fields   |

### DE-43 (Positional) Example

```
"LOJA CENTRO         SAO PAULO      SP BR"
 ├─ Name (25 chars) ─┤├─ City (13) ─┤├──┤├┤
                                      State Country
```

### DE-55 (BER-TLV) Example

EMV chip data with nested TLV structures:

```
9F26 08 A1B2C3D4E5F6A7B8   (Application Cryptogram, 8 bytes)
9F27 01 80                   (Cryptogram Type, 1 byte)
9F10 07 0110A00003220000     (Issuer Application Data, 7 bytes)
```

## Dialects

Different payment networks customize the base ISO 8583 specification:

| Dialect        | Key Differences                                          |
| -------------- | -------------------------------------------------------- |
| Base ISO       | Standard 128 data elements                               |
| Visa           | Custom fields 60-63, specific TLV in DE-55               |
| Mastercard     | Different DE-48 sub-fields, specific processing codes    |
| Cielo (Brazil) | Custom private fields (60-63), Portuguese merchant names |
| Rede (Brazil)  | Similar to Cielo, different private field layout         |

Dialects are implemented via **inheritance**: Base → Network-specific overrides.

## ISO 8583 Versions

| Version | MTI format          | Key differences                     |
| ------- | ------------------- | ----------------------------------- |
| 1987    | 4-digit (VFCO), V=0 | Original standard, most widely used |
| 1993    | 4-digit (VFCO), V=1 | Added new DEs, minor changes        |
| 2021    | 3-digit (FCO)       | Major restructure, Annex J mapping  |

**Annex J** provides a mapping table from 2021 data elements to 1987/1993 equivalents. The `applyAnnexJ` flag in `IsoDialect` controls whether this mapping is active.

For the complete field reference table and Annex mappings, read `references/field-reference.md`.
