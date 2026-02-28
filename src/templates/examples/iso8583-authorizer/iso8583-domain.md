# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 04 — ISO 8583 Domain (Authorizer Simulator Context)

> This rule describes the ISO 8583 domain in the context of the authorizer simulator.
> The simulator uses the `com.bifrost:b8583` library for parsing and packing messages.
> The simulator implements the ROLE OF AUTHORIZER (receives requests, returns responses).

## Simulator Role
- **Receives:** ISO 8583 request messages (1100, 1200, 1420, 1804)
- **Returns:** ISO 8583 response messages (1110, 1210, 1430, 1814)
- **Decides:** Response Code (DE-39) based on configurable rules
- **Persists:** All transactions in PostgreSQL for audit trail

## Multi-Version ISO 8583 Support (MANDATORY)

The simulator MUST support the **3 versions** of the ISO 8583 standard:

| Version | Year | MTI | LLLLVAR | Notes |
|---------|------|-----|---------|-------|
| ISO 8583:1987 | 1987 | 4 digits (VFCO) | Does not exist | Original version |
| ISO 8583:1993 | 1993 | 4 digits (VFCO) | Does not exist | Most widely used in Brazil |
| ISO 8583:2021 | 2021 | 3 digits (FCO) | Supported | Modern version |

### Version Detection
- The version is determined by the **Dialect** configured in b8583
- Each TCP connection can use a different dialect
- The simulator detects the version by the received MTI:
  - 4 digits: 1987 or 1993
  - 3 digits: 2021

### Critical Differences Between Versions
| Aspect | 1987/1993 | 2021 |
|--------|-----------|------|
| MTI | 4 digits (0200, 0210) | 3 digits (200, 210) |
| Length prefix | LVAR, LLVAR, LLLVAR | + LLLLVAR |
| DE-48 | LLLVAR (max 999) | LLLLVAR (max 9999) |
| Composite fields | Basic | Expanded (4.4.3) |
| Annex J corrections | Applicable | Native |

### Version Configuration
```properties
simulator.iso.default-version=1993
simulator.iso.supported-versions=1987,1993,2021
simulator.iso.dialect.default=base-1993
```

### Impact on b8583 Library
- The b8583 library already supports multi-version via `IsoVersion` enum
- The simulator configures the `IsoDialect` with the appropriate version
- The `applyAnnexJ` flag controls backward compatibility

## Cross-Cutting Rules (EPIC-001)

### RULE-001: Cents Rule
The cents of the transaction amount (DE-4) determine the Response Code:

| Cents | RC | Description |
|-------|-----|-------------|
| .00 to .50 | 00 | Approved |
| .51 | 51 | Insufficient funds |
| .05 | 05 | Generic error |
| .14 | 14 | Invalid card |
| .43 | 43 | Stolen card |
| .57 | 57 | Transaction not allowed |
| .96 | 96 | System error |

### RULE-002: Timeout Rule
If the TID/MID has a timeout flag, the simulator waits 35 seconds before responding.

## Structure of an ISO 8583 Message

```
[Header (optional)] [MTI 4 bytes] [Primary Bitmap 16 hex] [Secondary Bitmap 16 hex if Bit 1 set] [Fields in increasing bit order]
```

## MTI (Message Type Indicator)

- Versions 1987/1993: 4 digits (ex: `0200`, `0210`, `0800`)
- Version 2021: 3 digits (ex: `200`, `210`, `800`)
- Composition: Version + Class + Function + Origin
- Matching: request `x200` <-> response `x210` (function +10)

## Bitmaps

- Primary Bitmap: bits 1-64 (16 hex chars or 8 bytes)
- Secondary Bitmap: bits 65-128 (present only if Bit 1 is set)
- **Bit 1 is managed AUTOMATICALLY** by the library
  - If any bit 65-128 is set: Bit 1 must be set
  - If no bit 65-128 is set: Bit 1 must be unset
- Bit 0 is INVALID (never use)
- Valid range: bits 2 to 128

## ISO Field Types

```
a      -- alphabetic (A-Z, a-z, space)
n      -- numeric (0-9)
s      -- special characters
an     -- alphanumeric
as     -- alphabetic + special characters
ns     -- numeric + special characters
ans    -- alphanumeric + special characters
anp    -- alphanumeric + padding
ansb   -- alphanumeric + special characters + binary
b      -- binary (raw bytes)
z      -- track 2 (0-9, =, D, F)
x+n    -- sign (C/D) + numeric
xn     -- sign in prefix + numeric
```

## Padding and Alignment

- Numeric types (`n`, `x+n`, `xn`): RIGHT-justified, zero-padded on the left
- Alphanumeric types (`a`, `an`, `ans`, etc.): LEFT-justified, space-padded on the right
- Binary type (`b`): no padding, exact size
- Track type (`z`): right-padded with `F`

## Length Types

```
FIXED   -- fixed size, no prefix
LVAR    -- 1-digit prefix, max 9
LLVAR   -- 2-digit prefix, max 99
LLLVAR  -- 3-digit prefix, max 999
LLLLVAR -- 4-digit prefix, max 9999 (version 2021 only)
```

## Encodings

Three independent encoding axes:
1. **MTI encoding**: how the MTI is represented on the wire (ASCII, BCD, EBCDIC)
2. **Bitmap encoding**: how the bitmap is represented (HEX string, binary raw)
3. **Field encoding**: how the fields are represented (ASCII, BCD, EBCDIC)

Each axis is configurable independently per dialect.

## Multi-Version (Annex J)

The library must support ISO 8583 versions 1987, 1993 and 2021:
- Use recommended bit re-assignments for reserved fields
- Adopt Composite type (4.4.3) even in older versions
- Expand LLLVAR to LLLLVAR where recommended (bits 55/56/110/111/112/115)
- The `applyAnnexJ` flag in the dialect controls whether Annex J corrections are applied

## Dialects

- Dialect = Registry + IsoVersion + Encoding Config + applyAnnexJ flag
- Support for inheritance: Base ISO -> Visa/Mastercard/Cielo/Rede
- Dialects are IMMUTABLE after construction (ADR-005)

## Message Headers

Pluggable via sealed interface `MessageHeader`:
- `NoHeader` -- default, no header
- `LengthPrefixHeader` -- length prefix 2 or 4 bytes
- `TpduHeader` -- TPDU header 5 bytes
- `IsoProtocolHeader` -- variable ASCII header
- `FixedLengthHeader` -- opaque header fixed size

## Sensitive Data -- NEVER Log

- Complete PAN (field 2) -- mask with `****`
- PIN Block (field 52) -- NEVER log, not even in TRACE
- CVV/CVC -- NEVER log
- Track Data (fields 35, 36) -- mask partially

## Important Fields (Quick Reference)

```
DE-2:   PAN (Primary Account Number) -- LLVAR n..19
DE-3:   Processing Code -- n 6
DE-4:   Amount, Transaction -- n 12
DE-7:   Transmission Date/Time -- n 10
DE-11:  STAN (Systems Trace Audit Number) -- n 6
DE-12:  Local Transaction Time -- n 6
DE-14:  Date, Expiration -- n 4 (YYMM)
DE-25:  Point of Service Condition Code -- n 2
DE-35:  Track 2 Data -- LLVAR z..37
DE-37:  Retrieval Reference Number -- an 12
DE-38:  Authorization Identification Response -- an 6
DE-39:  Response Code -- an 2
DE-41:  Card Acceptor Terminal ID -- ans 8
DE-42:  Card Acceptor ID Code -- ans 15
DE-43:  Card Acceptor Name/Location -- ans 40 (composite)
DE-48:  Additional Data -- LLLVAR ans..999
DE-52:  PIN Data -- b 8 (NEVER LOG)
DE-55:  ICC System Related Data -- LLLVAR b..999 (EMV TLV)
```
