# ISO 8583 Message Bitmap Reference — Complete Transaction Types

> **Purpose:** This is the single source of truth for all ISO 8583 message bitmap definitions in the authorizer-simulator. Agents MUST use this reference to construct and validate messages without errors.
>
> **Critical Rule:** This reference applies to ALL ISO 8583 versions supported (1987, 1993, 2021). Version differences are noted where applicable.

---

## 1. Transaction Types Matrix

The authorizer-simulator MUST support the following transaction types (MTI classes):

| MTI | Version | Class | Function | Origin | Direction | Type | Description | Use Case |
|-----|---------|-------|----------|--------|-----------|------|-------------|----------|
| **0100** | 1987/1993 | 1 (Auth) | 0 (Request) | 0 (Acquirer) | → | Request | Authorization Request | Card authorization (debit/credit) |
| **0110** | 1987/1993 | 1 (Auth) | 1 (Response) | 0 (Acquirer) | ← | Response | Authorization Response | Response to 0100 |
| **0200** | 1987/1993 | 2 (Financial) | 0 (Request) | 0 (Acquirer) | → | Request | Financial Transaction | Purchase, payment, cash advance |
| **0210** | 1987/1993 | 2 (Financial) | 1 (Response) | 0 (Acquirer) | ← | Response | Financial Transaction Response | Response to 0200 |
| **0400** | 1987/1993 | 4 (Reversal) | 0 (Request) | 0 (Acquirer) | → | Request | Reversal Request | Desfazimento (reversal) |
| **0410** | 1987/1993 | 4 (Reversal) | 1 (Response) | 0 (Acquirer) | ← | Response | Reversal Response | Response to 0400 |
| **0420** | 1987/1993 | 4 (Reversal) | 2 (Advice) | 0 (Acquirer) | → | Advice | Reversal Advice | Unconfirmed reversal notification |
| **0430** | 1987/1993 | 4 (Reversal) | 3 (Advice Response) | 0 (Acquirer) | ← | Advice Response | Reversal Advice Response | Response to 0420 |
| **0800** | 1987/1993 | 8 (Network) | 0 (Request) | 0 (Acquirer) | → | Request | Network Management | Echo test, connection keep-alive |
| **0810** | 1987/1993 | 8 (Network) | 1 (Response) | 0 (Acquirer) | ← | Response | Network Management Response | Response to 0800 |
| **100** | 2021 | 1 (Auth) | 0 (Request) | — | → | Request | Authorization Request (2021) | Same as 0100, 3-digit format |
| **110** | 2021 | 1 (Auth) | 1 (Response) | — | ← | Response | Authorization Response (2021) | Same as 0110, 3-digit format |
| **200** | 2021 | 2 (Financial) | 0 (Request) | — | → | Request | Financial Transaction (2021) | Same as 0200, 3-digit format |
| **210** | 2021 | 2 (Financial) | 1 (Response) | — | ← | Response | Financial Transaction Response (2021) | Same as 0210, 3-digit format |

### MTI Matching Rules
- Request ↔ Response: Add 10 to request MTI to get response MTI
  - `0100` (request) ↔ `0110` (response)
  - `0200` (request) ↔ `0210` (response)
  - `0400` (request) ↔ `0410` (response)
  - `0420` (advice) ↔ `0430` (advice response)
- Versions 1987/1993 use 4-digit MTI; 2021 uses 3-digit MTI
- Version prefix (V) in 1987/1993: `V=0` (1987) or `V=1` (1993)

---

## 2. Bitmap Tables by Message Type

### 2.1 MTI 0100 — Authorization Request

**Bitmap:** Primary only (secondary when bits 65-128 are used)

| Bit | DE | Name | Type | Length | M/C/O | Description | Notes |
|-----|----|----|------|--------|-------|-------------|-------|
| 2 | 2 | Primary Account Number (PAN) | n | LLVAR (up to 19) | M | Card number (PAN) | 13–19 digits, card brand-specific |
| 3 | 3 | Processing Code | n | 6 (FIXED) | M | Transaction type | 6 digits: TTSSCC (Type, Service, Subservice) |
| 4 | 4 | Transaction Amount | n | 12 (FIXED) | M | Transaction amount in minor units | Right-justified, zero-padded; **centavos determine RC** |
| 7 | 7 | Transmission Date/Time | n | 10 (FIXED) | M | Transmission timestamp | Format: MMDDhhmmss |
| 11 | 11 | System Trace Audit Number (STAN) | n | 6 (FIXED) | M | Unique transaction identifier | Per terminal per day; used for matching requests/responses |
| 12 | 12 | Local Transaction Time | n | 6 (FIXED) | M | Local time of transaction | Format: hhmmss |
| 13 | 13 | Local Transaction Date | n | 4 (FIXED) | M | Local date of transaction | Format: MMDD |
| 14 | 14 | Card Expiration Date | n | 4 (FIXED) | M | Card expiry in YYMM format | Must not be expired |
| 22 | 22 | Point of Service Entry Mode | n | 3 (FIXED) | M | How card was captured | 01=Manual, 02=Magnetic stripe, 05=Chip (EMV), etc. |
| 23 | 23 | Card Sequence Number | n | 3 (FIXED) | C | Sequence number from card | Conditional; required if card is present |
| 25 | 25 | POS Condition Code | n | 2 (FIXED) | M | Merchant point-of-sale status | 00=Normal, 05=Recurring, 06=Installment, etc. |
| 26 | 26 | POS PIN Capture Code | n | 2 (FIXED) | C | PIN entry capability/capture | 0=No PIN, 1=PIN entered, 2=Unable to capture, etc. |
| 32 | 32 | Acquiring Institution ID | n | LLVAR (up to 11) | C | Acquirer identification | Bank code or acquirer code |
| 35 | 35 | Track 2 Data | z | LLVAR (up to 37) | C | Magnetic stripe (Track 2) | Format: PAN=EXPDATE (sentinel `=`, ends with `?`) |
| 37 | 37 | Retrieval Reference Number (RRN) | an | 12 (FIXED) | M | Unique reference for this transaction | Used for traceability and audit |
| 38 | 38 | Authorization Identification Response | an | 6 (FIXED) | O | Auth code (if pre-authorized) | Response-only in requests; set by issuer in responses |
| 39 | 39 | Response Code | an | 2 (FIXED) | O | Transaction result code | Response-only in requests; determined by simulator |
| 41 | 41 | Card Acceptor Terminal ID | ans | 8 (FIXED) | M | Terminal identifier (TID) | Unique per terminal; identifies where transaction occurred |
| 42 | 42 | Card Acceptor ID Code | ans | 15 (FIXED) | M | Merchant identifier (MID) | Unique per merchant; identifies who accepted the card |
| 43 | 43 | Card Acceptor Name/Location | ans | 40 (FIXED) | M | Merchant info (composite field) | Format: NAME(25) + CITY(13) + STATE(2) + COUNTRY(2) |
| 48 | 48 | Additional Data | ans | LLLVAR (up to 999) | O | Network-specific data | Custom TLV or free-form; varies by acquirer/network |
| 49 | 49 | Currency Code | n | 3 (FIXED) | M | Transaction currency ISO 4217 | 986=BRL (Brazil), 840=USD (USA), etc. |
| 52 | 52 | PIN Data | b | 8 (FIXED) | C | Encrypted PIN block | **NEVER log this field**; only if PIN was captured |
| 54 | 54 | Additional Amounts | n | LLLVAR (up to 999) | O | Additional amounts (surcharge, etc.) | Format varies; often used for tips, taxes |
| 55 | 55 | ICC System Related Data (EMV) | b | LLLVAR (up to 999) | C | EMV/chip card data (TLV-encoded) | BER-TLV format; only present if DE-22 indicates chip |
| **Hexadecimal Bitmap** | — | — | — | — | — | — | (Computed at runtime) |

#### 0100 Bitmap Example
**If bits 2, 3, 4, 7, 11, 12, 13, 14, 22, 25, 32, 37, 41, 42, 43, 49 are set:**
- Primary bitmap (bits 1-64): `0x72000810180C0001C04C0120` (16 hex chars)
- Secondary bitmap: Not needed (all fields in bits 1-64)

#### 0100 Mandatory Fields Checklist
- [ ] DE-2: PAN (card number)
- [ ] DE-3: Processing Code (e.g., `000000` for purchase)
- [ ] DE-4: Amount (in minor units, e.g., `000000000100` for 1.00)
- [ ] DE-7: Transmission Date/Time (MMDDhhmmss)
- [ ] DE-11: STAN (unique per day per terminal)
- [ ] DE-12: Local Transaction Time (hhmmss)
- [ ] DE-13: Local Transaction Date (MMDD)
- [ ] DE-14: Card Expiration (YYMM, must be future date)
- [ ] DE-22: POS Entry Mode (e.g., `02` for magnetic stripe, `05` for chip)
- [ ] DE-25: POS Condition Code (e.g., `00` for normal)
- [ ] DE-37: RRN (12 chars, unique reference)
- [ ] DE-41: Terminal ID (TID, 8 chars)
- [ ] DE-42: Merchant ID (MID, 15 chars)
- [ ] DE-43: Merchant Name/Location (40 chars, composite)
- [ ] DE-49: Currency Code (e.g., `986` for BRL)

#### 0100 Conditional Fields
- DE-23: Card Sequence Number — required if card brand specifies
- DE-26: POS PIN Capture Code — required if PIN was captured/attempted
- DE-32: Acquiring Institution ID — conditional on network
- DE-35: Track 2 Data — required if card was swiped (magnetic stripe)
- DE-38: Authorization Code — optional in request (may be pre-set)
- DE-39: Response Code — typically not set in request (set by responder)
- DE-48: Additional Data — network/acquirer-specific
- DE-52: PIN Block — required only if PIN was captured
- DE-54: Additional Amounts — required for specific transaction types (tips, taxes)
- DE-55: ICC Data — required only if chip card (DE-22 = `05`)

---

### 2.2 MTI 0110 — Authorization Response

**Bitmap:** Mirrors 0100, with DE-38 and DE-39 MANDATORY

| Bit | DE | Name | Type | Length | M/C/O | Description | Notes |
|-----|----|----|------|--------|-------|-------------|-------|
| 2 | 2 | Primary Account Number (PAN) | n | LLVAR (up to 19) | O | Card number (echo from request) | Optional in response |
| 3 | 3 | Processing Code | n | 6 (FIXED) | M | Echo of request processing code | Must match request |
| 4 | 4 | Transaction Amount | n | 12 (FIXED) | M | Echo of request amount | Must match request |
| 7 | 7 | Transmission Date/Time | n | 10 (FIXED) | M | Response transmission timestamp | Format: MMDDhhmmss |
| 11 | 11 | System Trace Audit Number (STAN) | n | 6 (FIXED) | M | Echo of request STAN | Must match request STAN |
| 12 | 12 | Local Transaction Time | n | 6 (FIXED) | O | Local time of transaction | Same as request or response time |
| 13 | 13 | Local Transaction Date | n | 4 (FIXED) | O | Local date of transaction | Same as request or response date |
| 14 | 14 | Card Expiration Date | n | 4 (FIXED) | O | Echo of card expiry | Same as request |
| 22 | 22 | Point of Service Entry Mode | n | 3 (FIXED) | O | Echo of request entry mode | May be included |
| 25 | 25 | POS Condition Code | n | 2 (FIXED) | O | Echo of request condition code | May be included |
| 32 | 32 | Acquiring Institution ID | n | LLVAR (up to 11) | O | Acquirer identification | May echo request |
| 37 | 37 | Retrieval Reference Number (RRN) | an | 12 (FIXED) | M | Unique reference (echo from request) | Must match request RRN |
| **38** | **38** | **Authorization Identification Response** | **an** | **6 (FIXED)** | **M** | **Authorization code** | **Assigned by simulator/issuer** |
| **39** | **39** | **Response Code** | **an** | **2 (FIXED)** | **M** | **Transaction result code** | **Determined by cents rule** |
| 41 | 41 | Card Acceptor Terminal ID | ans | 8 (FIXED) | M | Echo of TID | Must match request |
| 42 | 42 | Card Acceptor ID Code | ans | 15 (FIXED) | M | Echo of MID | Must match request |
| 43 | 43 | Card Acceptor Name/Location | ans | 40 (FIXED) | O | Merchant info (may echo request) | May be included |
| 49 | 49 | Currency Code | n | 3 (FIXED) | M | Echo of currency code | Must match request |
| 55 | 55 | ICC System Related Data (EMV) | b | LLLVAR (up to 999) | O | EMV data (if applicable) | May be included in response |

#### 0110 Mandatory Response Fields
- [ ] DE-3: Processing Code (echo request)
- [ ] DE-4: Amount (echo request)
- [ ] DE-7: Transmission Date/Time (response time)
- [ ] DE-11: STAN (echo request)
- [ ] DE-37: RRN (echo request)
- [ ] **DE-38: Authorization Code** (assigned by authorizer)
- [ ] **DE-39: Response Code** (00=approved, 51=insufficient funds, 05=error, etc.)
- [ ] DE-41: Terminal ID (TID, echo request)
- [ ] DE-42: Merchant ID (MID, echo request)
- [ ] DE-49: Currency Code (echo request)

---

### 2.3 MTI 0200 — Financial Transaction Request

**Bitmap:** Similar to 0100 with additional financial-specific fields

| Bit | DE | Name | Type | Length | M/C/O | Description | Notes |
|-----|----|----|------|--------|-------|-------------|-------|
| 2 | 2 | Primary Account Number (PAN) | n | LLVAR (up to 19) | M | Card number | 13–19 digits |
| 3 | 3 | Processing Code | n | 6 (FIXED) | M | Transaction type | 000000=Purchase, 003000=Purchase+Cashback, 200000=Refund, 280000=Payment, 310000=Balance |
| 4 | 4 | Transaction Amount | n | 12 (FIXED) | M | Amount in minor units | **Centavos rule applies** |
| 7 | 7 | Transmission Date/Time | n | 10 (FIXED) | M | Transmission timestamp | MMDDhhmmss |
| 11 | 11 | System Trace Audit Number (STAN) | n | 6 (FIXED) | M | Unique transaction ID | Per terminal per day |
| 12 | 12 | Local Transaction Time | n | 6 (FIXED) | M | Local time | hhmmss |
| 13 | 13 | Local Transaction Date | n | 4 (FIXED) | M | Local date | MMDD |
| 14 | 14 | Card Expiration Date | n | 4 (FIXED) | M | Card expiry | YYMM |
| 22 | 22 | Point of Service Entry Mode | n | 3 (FIXED) | M | Card capture method | 01=Manual, 02=Magnetic, 05=Chip, etc. |
| 25 | 25 | POS Condition Code | n | 2 (FIXED) | M | POS status | 00=Normal, 05=Recurring, etc. |
| 28 | 28 | Transaction Fee | n | 9 (FIXED) | C | Fee amount in minor units | Conditional for specific transaction types |
| 32 | 32 | Acquiring Institution ID | n | LLVAR (up to 11) | C | Acquirer code | Conditional on network |
| 35 | 35 | Track 2 Data | z | LLVAR (up to 37) | C | Magnetic stripe | Required if card swiped |
| 37 | 37 | Retrieval Reference Number (RRN) | an | 12 (FIXED) | M | Unique reference | Used for matching |
| 41 | 41 | Card Acceptor Terminal ID | ans | 8 (FIXED) | M | Terminal ID (TID) | Unique per terminal |
| 42 | 42 | Card Acceptor ID Code | ans | 15 (FIXED) | M | Merchant ID (MID) | Unique per merchant |
| 43 | 43 | Card Acceptor Name/Location | ans | 40 (FIXED) | M | Merchant info (composite) | NAME(25) + CITY(13) + STATE(2) + COUNTRY(2) |
| 48 | 48 | Additional Data | ans | LLLVAR (up to 999) | O | Network-specific data | Custom TLV or free-form |
| 49 | 49 | Currency Code | n | 3 (FIXED) | M | Currency ISO 4217 | 986=BRL, 840=USD, etc. |
| 52 | 52 | PIN Data | b | 8 (FIXED) | C | Encrypted PIN block | **NEVER log**; only if PIN captured |
| 54 | 54 | Additional Amounts | n | LLLVAR (up to 999) | O | Tips, taxes, surcharge | Format varies |
| 55 | 55 | ICC System Related Data (EMV) | b | LLLVAR (up to 999) | C | EMV chip data (TLV) | Only if chip card (DE-22 = 05) |

#### 0200 vs 0100 Differences
- **Processing Code (DE-3):** More varied in 0200 (refunds, payments, balance inquiry)
- **DE-28:** Transaction Fee field is financial-specific

---

### 2.4 MTI 0210 — Financial Transaction Response

**Bitmap:** Mirrors 0200 with DE-38 and DE-39 mandatory

| Bit | DE | Name | Type | Length | M/C/O | Description | Notes |
|-----|----|----|------|--------|-------|-------------|-------|
| 3 | 3 | Processing Code | n | 6 (FIXED) | M | Echo of request | Must match request |
| 4 | 4 | Transaction Amount | n | 12 (FIXED) | M | Echo of request | Must match request |
| 7 | 7 | Transmission Date/Time | n | 10 (FIXED) | M | Response timestamp | MMDDhhmmss |
| 11 | 11 | System Trace Audit Number (STAN) | n | 6 (FIXED) | M | Echo of request STAN | Must match request |
| 37 | 37 | Retrieval Reference Number (RRN) | an | 12 (FIXED) | M | Echo of request RRN | Must match request |
| **38** | **38** | **Authorization Identification Response** | **an** | **6 (FIXED)** | **M** | **Authorization code** | **Assigned by simulator** |
| **39** | **39** | **Response Code** | **an** | **2 (FIXED)** | **M** | **Transaction result** | **00, 51, 05, 14, 43, 57, 96** |
| 41 | 41 | Card Acceptor Terminal ID | ans | 8 (FIXED) | M | Echo of TID | Must match request |
| 42 | 42 | Card Acceptor ID Code | ans | 15 (FIXED) | M | Echo of MID | Must match request |
| 49 | 49 | Currency Code | n | 3 (FIXED) | M | Echo of currency | Must match request |

---

### 2.5 MTI 0400 — Reversal Request

**Bitmap:** Similar to 0100/0200 but includes reversal-specific fields

| Bit | DE | Name | Type | Length | M/C/O | Description | Notes |
|-----|----|----|------|--------|-------|-------------|-------|
| 2 | 2 | Primary Account Number (PAN) | n | LLVAR (up to 19) | M | Card number | Same as original transaction |
| 3 | 3 | Processing Code | n | 6 (FIXED) | M | Transaction type | Usually `200000` for reversal |
| 4 | 4 | Transaction Amount | n | 12 (FIXED) | M | Amount to reverse | Usually matches original |
| 7 | 7 | Transmission Date/Time | n | 10 (FIXED) | M | Reversal transmission time | MMDDhhmmss |
| 11 | 11 | System Trace Audit Number (STAN) | n | 6 (FIXED) | M | STAN of reversal message | New STAN, not original |
| 12 | 12 | Local Transaction Time | n | 6 (FIXED) | M | Local time of reversal | hhmmss |
| 13 | 13 | Local Transaction Date | n | 4 (FIXED) | M | Local date of reversal | MMDD |
| 25 | 25 | POS Condition Code | n | 2 (FIXED) | M | POS condition | Usually `00` |
| 37 | 37 | Retrieval Reference Number (RRN) | an | 12 (FIXED) | M | Reversal RRN | New RRN for reversal |
| **38** | **38** | **Authorization Identification Response** | **an** | **6 (FIXED)** | **M** | **Original auth code** | **From original transaction** |
| **39** | **39** | **Response Code** | **an** | **2 (FIXED)** | **M** | **Original response code** | **From original transaction** |
| 41 | 41 | Card Acceptor Terminal ID | ans | 8 (FIXED) | M | Terminal ID (TID) | Same as original |
| 42 | 42 | Card Acceptor ID Code | ans | 15 (FIXED) | M | Merchant ID (MID) | Same as original |
| 49 | 49 | Currency Code | n | 3 (FIXED) | M | Currency | Same as original |
| **56** | **56** | **Original Data Elements** | **ans** | **LLLVAR (up to 999)** | **M** | **Original transaction fields** | **MANDATORY for reversals; see DE-56 format** |
| 90 | 90 | Original Data Elements | ans | LLLVAR (up to 999) | C | Alternative original data format | Either DE-56 OR DE-90, not both |
| 95 | 95 | Replacement Amounts | n | LLLVAR (up to 999) | C | Partial reversal amounts | Only for partial reversals |

#### 0400 Special Rules
- **DE-38 & DE-39:** MUST contain original authorization code and response code
- **DE-56 or DE-90:** MANDATORY — one must contain original transaction data to identify which transaction is being reversed
- **DE-90:** Alternative to DE-56; both should not be present
- **Matching:** Original transaction identified by STAN (DE-11) and date (DE-13) from original message

---

### 2.6 MTI 0410 — Reversal Response

**Bitmap:** Mirrors 0400

| Bit | DE | Name | Type | Length | M/C/O | Description | Notes |
|-----|----|----|------|--------|-------|-------------|-------|
| 3 | 3 | Processing Code | n | 6 (FIXED) | M | Echo of reversal processing code | Must be `200000` |
| 4 | 4 | Transaction Amount | n | 12 (FIXED) | M | Echo of reversal amount | Must match request |
| 7 | 7 | Transmission Date/Time | n | 10 (FIXED) | M | Response timestamp | MMDDhhmmss |
| 11 | 11 | System Trace Audit Number (STAN) | n | 6 (FIXED) | M | Echo of reversal STAN | Must match request |
| 37 | 37 | Retrieval Reference Number (RRN) | an | 12 (FIXED) | M | Echo of reversal RRN | Must match request |
| **38** | **38** | **Authorization Identification Response** | **an** | **6 (FIXED)** | **M** | **Reversal auth code** | **Assigned for reversal** |
| **39** | **39** | **Response Code** | **an** | **2 (FIXED)** | **M** | **Reversal result** | **00=approved, 77=original not found** |
| 41 | 41 | Card Acceptor Terminal ID | ans | 8 (FIXED) | M | Echo of TID | Must match request |
| 42 | 42 | Card Acceptor ID Code | ans | 15 (FIXED) | M | Echo of MID | Must match request |
| 49 | 49 | Currency Code | n | 3 (FIXED) | M | Echo of currency | Must match request |

---

### 2.7 MTI 0420 — Reversal Advice

**Bitmap:** Similar to 0400 but used when reversal confirmation is uncertain

| Bit | DE | Name | Type | Length | M/C/O | Description | Notes |
|-----|----|----|------|--------|-------|-------------|-------|
| 2 | 2 | Primary Account Number (PAN) | n | LLVAR (up to 19) | M | Card number | Same as original |
| 3 | 3 | Processing Code | n | 6 (FIXED) | M | Transaction type | Usually `200000` for reversal |
| 4 | 4 | Transaction Amount | n | 12 (FIXED) | M | Amount to reverse | Usually matches original |
| 7 | 7 | Transmission Date/Time | n | 10 (FIXED) | M | Reversal transmission time | MMDDhhmmss |
| 11 | 11 | System Trace Audit Number (STAN) | n | 6 (FIXED) | M | STAN of advice message | New STAN |
| 12 | 12 | Local Transaction Time | n | 6 (FIXED) | M | Local time | hhmmss |
| 13 | 13 | Local Transaction Date | n | 4 (FIXED) | M | Local date | MMDD |
| 25 | 25 | POS Condition Code | n | 2 (FIXED) | M | POS condition | Usually `00` |
| 37 | 37 | Retrieval Reference Number (RRN) | an | 12 (FIXED) | M | Advice RRN | New RRN |
| **38** | **38** | **Authorization Identification Response** | **an** | **6 (FIXED)** | **M** | **Original auth code** | **From original transaction** |
| **39** | **39** | **Response Code** | **an** | **2 (FIXED)** | **M** | **Original response code** | **From original transaction** |
| 41 | 41 | Card Acceptor Terminal ID | ans | 8 (FIXED) | M | Terminal ID (TID) | Same as original |
| 42 | 42 | Card Acceptor ID Code | ans | 15 (FIXED) | M | Merchant ID (MID) | Same as original |
| 49 | 49 | Currency Code | n | 3 (FIXED) | M | Currency | Same as original |
| **56** | **56** | **Original Data Elements** | **ans** | **LLLVAR (up to 999)** | **M** | **Original transaction fields** | **MANDATORY; identifies transaction** |

---

### 2.8 MTI 0430 — Reversal Advice Response

**Bitmap:** Mirrors 0420

| Bit | DE | Name | Type | Length | M/C/O | Description | Notes |
|-----|----|----|------|--------|-------|-------------|-------|
| 3 | 3 | Processing Code | n | 6 (FIXED) | M | Echo of advice processing code | Must be `200000` |
| 4 | 4 | Transaction Amount | n | 12 (FIXED) | M | Echo of advice amount | Must match request |
| 7 | 7 | Transmission Date/Time | n | 10 (FIXED) | M | Response timestamp | MMDDhhmmss |
| 11 | 11 | System Trace Audit Number (STAN) | n | 6 (FIXED) | M | Echo of advice STAN | Must match request |
| 37 | 37 | Retrieval Reference Number (RRN) | an | 12 (FIXED) | M | Echo of advice RRN | Must match request |
| **38** | **38** | **Authorization Identification Response** | **an** | **6 (FIXED)** | **M** | **Advice response auth code** | **Assigned** |
| **39** | **39** | **Response Code** | **an** | **2 (FIXED)** | **M** | **Advice result** | **00=received, 77=transaction not found** |
| 41 | 41 | Card Acceptor Terminal ID | ans | 8 (FIXED) | M | Echo of TID | Must match request |
| 42 | 42 | Card Acceptor ID Code | ans | 15 (FIXED) | M | Echo of MID | Must match request |
| 49 | 49 | Currency Code | n | 3 (FIXED) | M | Echo of currency | Must match request |

---

### 2.9 MTI 0800 — Network Management Request (Echo Test)

**Bitmap:** Minimal, only network-specific fields

| Bit | DE | Name | Type | Length | M/C/O | Description | Notes |
|-----|----|----|------|--------|-------|-------------|-------|
| 7 | 7 | Transmission Date/Time | n | 10 (FIXED) | M | Echo request timestamp | MMDDhhmmss |
| 11 | 11 | System Trace Audit Number (STAN) | n | 6 (FIXED) | M | Unique identifier | Per terminal per day |
| 70 | 70 | Network Management Code | n | 3 (FIXED) | M | Type of network management | 001=Echo test, 301=Logon, 302=Logoff, etc. |

#### 0800 Echo Test Example
- MTI: `0800`
- DE-7: `0216143000` (Feb 16, 2026, 14:30:00)
- DE-11: `000001` (STAN)
- DE-70: `001` (Echo test code)

---

### 2.10 MTI 0810 — Network Management Response (Echo Test)

**Bitmap:** Mirrors 0800 with response code added

| Bit | DE | Name | Type | Length | M/C/O | Description | Notes |
|-----|----|----|------|--------|-------|-------------|-------|
| 7 | 7 | Transmission Date/Time | n | 10 (FIXED) | M | Echo response timestamp | MMDDhhmmss (may differ from request) |
| 11 | 11 | System Trace Audit Number (STAN) | n | 6 (FIXED) | M | Echo of request STAN | Must match request |
| **39** | **39** | **Response Code** | **an** | **2 (FIXED)** | **M** | **Echo result** | **00=success, 96=error** |
| 70 | 70 | Network Management Code | n | 3 (FIXED) | M | Echo of network management code | Must be `001` for echo test |

---

## 3. Processing Codes (DE-3) Matrix

**Format:** 6 digits (TTSSCC) where:
- TT = Transaction Type (2 digits)
- SS = Service (2 digits)
- CC = Confirmation (2 digits)

| Code | Transaction Type | Description | Use Case | Direction |
|------|------------------|-------------|----------|-----------|
| **000000** | Debit/Purchase | Compra à vista (debit) | Card payment, immediate debit | Request |
| **003000** | Debit + Cashback | Compra + troco | Cashback at point of sale | Request |
| **020000** | Debit Reversal | Estorno de débito | Undo a debit transaction | Request |
| **200000** | Credit/Refund | Estorno/Reembolso | Credit to card (refund) | Request/Reversal |
| **280000** | Payment | Pagamento (boleto) | Payment of bills/boleto | Request |
| **310000** | Balance Inquiry | Consulta de saldo | Check account balance | Request |
| **400000** | Transfer | Transferência | Inter-account transfer | Request |
| **500000** | Loan | Crédito/Empréstimo | Loan advance | Request |
| **600000** | Cash Advance | Saque de crédito | Cash advance on credit card | Request |
| **700000** | Financial Inquiry | Consulta financeira | Balance/limit inquiry | Request |

**Important:** Processing code determines transaction type behavior. Reversal (0400/0420) typically uses `200000`, but the original transaction's processing code should be referenced in DE-56/DE-90.

---

## 4. Response Codes (DE-39) Matrix — The "Cents Rule"

**CRITICAL RULE (RULE-001):** The authorizer-simulator uses the **cents rule** where the centavos portion of the transaction amount (DE-4, last 2 digits) determines the response code:

| Centavos (last 2 of DE-4) | Response Code | ISO Meaning | Description | Decision |
|---------------------------|---------------|------------|-------------|----------|
| `.00` – `.50` | `00` | Approved | Transaction approved | **APPROVE** |
| `.51` | `51` | Insufficient Funds | Card has insufficient balance | **DENY** |
| `.05` | `05` | Do Not Honor | Generic card decline | **DENY** |
| `.14` | `14` | Invalid Card Number | PAN check digit or format invalid | **DENY** |
| `.43` | `43` | Stolen Card | Card flagged as stolen | **DENY** |
| `.57` | `57` | Transaction Not Allowed | Card or merchant restrictions | **DENY** |
| `.96` | `96` | System Malfunction | Simulator/network error | **DENY** |
| Any other | `.96` | System Malfunction | Default error for unmapped values | **DENY** |

### Examples

| Amount | Centavos | Extracted | Response Code | Decision |
|--------|----------|-----------|---------------|----------|
| 100.00 | 00 | 0 | 00 | APPROVE |
| 100.51 | 51 | 51 | 51 | DENY (insufficient funds) |
| 50.05 | 05 | 5 | 05 | DENY (do not honor) |
| 1000.14 | 14 | 14 | 14 | DENY (invalid card) |
| 999.43 | 43 | 43 | 43 | DENY (stolen card) |
| 1.57 | 57 | 57 | 57 | DENY (not allowed) |
| 123.96 | 96 | 96 | 96 | DENY (system error) |
| 75.99 | 99 | 99 | 96 | DENY (unmapped → system error) |

### Complete Response Code Reference (ISO 8583:1987/1993)

| RC | ISO Name | Decision | Meaning |
|----|---------|---------|----|
| **00** | Approved | APPROVE | Transaction approved — funds deducted |
| **01** | Refer to Card Issuer | DENY | Customer should contact card issuer |
| **02** | Refer to Card Issuer (Special Condition) | DENY | Special condition at issuer |
| **03** | Invalid Merchant | DENY | Merchant not valid or inactive |
| **04** | Pick Up Card | DENY | Card to be retained (fraud) |
| **05** | Do Not Honor | DENY | Generic decline (no specific reason) |
| **06** | Error in Processing | DENY | Error during processing |
| **07** | Pick Up Card (Fraud) | DENY | Card flagged for fraud |
| **08** | Honor with ID | DENY | Requires ID verification |
| **09** | Request in Progress | PENDING | Transaction still being processed |
| **10** | Partial Approval | PARTIAL | Approved for partial amount |
| **12** | Invalid Transaction | DENY | Transaction format/amount invalid |
| **13** | Invalid Amount | DENY | Amount out of acceptable range |
| **14** | Invalid Card Number | DENY | PAN failed validation (Luhn, brand) |
| **15** | No Such Issuer | DENY | Card issuer not found |
| **19** | Re-enter Transactions | DENY | Retry transaction |
| **21** | No Action Taken | DENY | No action could be performed |
| **25** | Unable to Locate Record | DENY | Original transaction not found (reversal) |
| **28** | File Temporarily Unavailable | DENY | Database unavailable |
| **29** | File Permanently Unavailable | DENY | Database permanently down |
| **31** | Bank Not Supported By Switch | DENY | Routing/switching error |
| **33** | Expired Card | DENY | Card expiration date passed |
| **34** | Suspected Fraud | DENY | Fraud detection triggered |
| **35** | Card Acceptor Contact Acquirer | DENY | Merchant should contact acquirer |
| **36** | Restricted Card | DENY | Card restrictions prevent transaction |
| **37** | Card Acceptor Call Acquirer Security | DENY | Security issue |
| **38** | Exceeds PIN Retries | DENY | Too many wrong PINs |
| **39** | No Credit Account | DENY | Credit line unavailable |
| **40** | Requested Function Not Supported | DENY | Feature not available |
| **41** | Lost Card | DENY | Card reported lost |
| **42** | No Universal Account | DENY | Account incompatible with transaction |
| **43** | Stolen Card | DENY | Card reported stolen |
| **44** | No Investment Account | DENY | Investment account unavailable |
| **45** | Domestic Debit Only | DENY | Only domestic debit allowed |
| **46** | Debit Not Supported | DENY | Debit transactions not allowed |
| **47** | Cash Not Available | DENY | Insufficient cash in ATM/POS |
| **48** | Crypto Not Supported | DENY | Cryptocurrency not accepted |
| **49** | Transaction Type Not Supported | DENY | Transaction type not allowed |
| **50** | Decline — Do Not Retry | DENY | Permanent decline — do not retry |
| **51** | Insufficient Funds | DENY | Cardholder balance insufficient |
| **52** | PIN Incorrect | DENY | Wrong PIN entered |
| **53** | No Checking Account | DENY | Checking account not available |
| **54** | Expired Card | DENY | Card expiration passed |
| **55** | Incorrect PIN | DENY | PIN validation failed |
| **56** | Card Not on File | DENY | Card not registered |
| **57** | Transaction Not Allowed | DENY | Card/merchant restrictions |
| **58** | Not Permitted on Card | DENY | Card cannot perform this transaction |
| **59** | Suspected Fraud | DENY | Fraud suspected |
| **60** | Card Acceptor Contact Acquirer | DENY | Merchant contact required |
| **61** | Exceeds Withdrawal Limit | DENY | Daily/monthly withdrawal exceeded |
| **62** | Restricted Card | DENY | Card use restricted |
| **63** | Security Violation | DENY | Security breach detected |
| **64** | Original Amount Incorrect | DENY | Reversal amount mismatch |
| **65** | Exceeds Withdrawal Frequency | DENY | Too many withdrawals |
| **66** | Card Acceptor Call Acquirer Security | DENY | Security issue at merchant |
| **67** | Hard Capture | DENY | Card to be captured (hard) |
| **68** | Response Received Too Late | DENY | Response timeout |
| **69** | Advice Received Too Late | DENY | Advice timeout |
| **70** | Not Permitted Without PIN | DENY | PIN entry required |
| **71** | Insufficient Funds for Withdrawal | DENY | Insufficient balance for cash |
| **72** | Incorrect PIN | DENY | Invalid PIN |
| **73** | Exceeded PIN Retries | DENY | Too many PIN attempts |
| **74** | Card Blocked | DENY | Card blocked by issuer |
| **75** | Allowable PIN Retries Exceeded | DENY | PIN retry limit exceeded |
| **76** | Unable to Verify PIN | DENY | PIN verification failed |
| **77** | Transaction Not Permitted — Cardholder | DENY | Cardholder restricted |
| **78** | Transaction Cannot be Completed | DENY | Cannot process at this time |
| **79** | Not Permitted — Changes to PAN | DENY | Card number change not allowed |
| **80** | Network Error | DENY | Network/routing error |
| **81** | PIN Cryptogram Error | DENY | PIN encryption error |
| **82** | Negative CAM DCB CVC2 CID | DENY | Cryptogram validation failed |
| **83** | Host Unavailable | DENY | Host system unavailable |
| **84** | Issuer Down | DENY | Card issuer system down |
| **85** | No Reason to Decline | DENY | Generic decline (no specific reason) |
| **86** | Unable to Verify PIN | DENY | PIN verification not possible |
| **87** | Purchase Amount Only | DENY | Only purchase amounts allowed |
| **88** | Cryptographic Failure | DENY | Encryption/crypto error |
| **89** | CVM Check Required | DENY | Cardholder verification required |
| **90** | Cutoff in Progress | DENY | System cutoff — retry later |
| **91** | Card Issuer or Switching Network Unavailable | DENY | Issuer/network down |
| **92** | Unable to Locate Previous Transaction | DENY | Original transaction not found |
| **93** | Transaction Cannot be Reversed | DENY | Reversal not allowed |
| **94** | Duplicate Transaction | DENY | Transaction already processed |
| **95** | Reconciliation Error | DENY | Settlement/reconciliation error |
| **96** | System Malfunction | DENY | System error or exception |
| **97** | Message Format Error | DENY | ISO message malformed |
| **98** | Routing Error | DENY | Message routing failed |
| **99** | General Error | DENY | Unspecified error |

---

## 5. Hex Bitmap Examples

### Computing Hexadecimal Bitmaps

**Bitmap Structure:**
- 64 bits (8 bytes) for primary bitmap
- Each bit represents a data element (bit 1 = DE-1, bit 2 = DE-2, etc.)
- Bit 1 is reserved as the "continuation bit" (set if secondary bitmap is present)
- Bits are stored left-to-right, MSB first (big-endian)

**Algorithm:**

```
Input: Set of data elements (e.g., {2, 3, 4, 7, 11})
Output: Hex bitmap string (16 characters for primary only)

Step 1: Create 64-bit array, all zeros
Step 2: For each DE number in set:
        - Set bit at position DE number to 1
        - Example: DE-2 → set bit 2
Step 3: Group bits into 8 nibbles (4 bits each)
        - Bits 1-4 → nibble 1
        - Bits 5-8 → nibble 2
        - ... bits 61-64 → nibble 8
Step 4: Convert each nibble to hex (0-15 → 0-F)
Step 5: Concatenate hex nibbles (left-to-right)
```

### Examples

#### Example 1: MTI 0800 (Echo Test)
**Data Elements Present:** 7, 11, 70
**Note:** DE-70 is in secondary bitmap (bits 65-128), so bit 1 must be set.

**Bit Layout:**
```
Bit:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 ...
Val:  1  0  0  0  0  0  1  0  0  0  1  0  0  0  0  0  0  0  0  0 ...
```

- Bits 1-4: `1000` → 0x8
- Bits 5-8: `0001` → 0x1
- Bits 9-12: `0100` → 0x4
- Bits 13-16: `0000` → 0x0
- Bits 17-20: `0000` → 0x0
- Bits 21-24: `0000` → 0x0
- Bits 25-28: `0000` → 0x0
- Bits 29-32: `0000` → 0x0
- Bits 33-36: `0000` → 0x0
- Bits 37-40: `0000` → 0x0
- Bits 41-44: `0000` → 0x0
- Bits 45-48: `0000` → 0x0
- Bits 49-52: `0000` → 0x0
- Bits 53-56: `0000` → 0x0
- Bits 57-60: `0000` → 0x0
- Bits 61-64: `0000` → 0x0

**Primary Bitmap:** `8140000000000000` (16 hex chars)
**Secondary Bitmap Present:** Yes (bit 1 set)

**Secondary Bitmap (for DE-70):**
```
Bit: 65 66 67 68 69 70 71 72 ...
Val:  0  0  0  0  0  1  0  0 ... (DE-70 is bit 70 of full bitmap, or bit 6 of secondary)
```

- Bits 1-4: `0000` → 0x0
- Bits 5-8: `1000` → 0x8
- Bits 9-64: all `0000` → 0x0 for each nibble

**Secondary Bitmap:** `0800000000000000` (16 hex chars)

**Full MTI 0800 Message Bitmap:**
```
[Primary]     8140000000000000
[Secondary]   0800000000000000
```

#### Example 2: MTI 0100 (Authorization Request)
**Data Elements Present:** 2, 3, 4, 7, 11, 12, 13, 14, 22, 25, 32, 35, 37, 41, 42, 43, 49, 52, 55

**Bit Layout (compact notation):**
```
Bit:   1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 ...
Pres:  0  1  1  1  0  0  0  0  0  0  1  1  1  1  0  0  0  0  0  0  0  1  1  0 ...
       |------ nibble 0 ------| |------ nibble 1 ------| ... nibble 5 ...
```

Let me compute the exact hex:

**Nibbles (bits grouped in 4):**
1. Bits 1-4: `0111` → 0x7
2. Bits 5-8: `0000` → 0x0
3. Bits 9-12: `1111` → 0xF
4. Bits 13-16: `1000` → 0x8
5. Bits 17-20: `0001` → 0x1
6. Bits 21-24: `1001` → 0x9
7. Bits 25-28: `0001` → 0x1
8. Bits 29-32: `1000` → 0x8
9. Bits 33-36: `0000` → 0x0
10. Bits 37-40: `1000` → 0x8
11. Bits 41-44: `0001` → 0x1
12. Bits 45-48: `0001` → 0x1
13. Bits 49-52: `1000` → 0x8
14. Bits 53-56: `0000` → 0x0
15. Bits 57-60: `0000` → 0x0
16. Bits 61-64: `0000` → 0x0

**Primary Bitmap:** `70F89189080118800000`
**Secondary Bitmap Needed?** Yes (DE-52 and DE-55 are > 64)

**Secondary Bitmap (bits 65-128, for DE-52, DE-55):**
- DE-52 = bit 52 primary = secondary bit (52-64) = bit 52 of secondary (invalid)
- Actually, DE-52 and DE-55 are primary bits. Let me recalculate...

Actually, bits 1-64 cover DE 1-64, so:
- DE-2 = bit 2 ✓
- DE-3 = bit 3 ✓
- DE-4 = bit 4 ✓
- ...
- DE-52 = bit 52 ✓
- DE-55 = bit 55 ✓

No secondary bitmap needed for this example. All fields fit in primary.

**Primary Bitmap:** `70F8918908111800` (recalculated correctly)

---

## 6. Multi-Version Differences (1987 vs 1993 vs 2021)

| Aspect | 1987 | 1993 | 2021 | Impact on Bitmaps |
|--------|------|------|------|-------------------|
| **MTI Format** | 4 digits (VFCO) | 4 digits (VFCO) | 3 digits (FCO) | No bitmap difference, only MTI parsing |
| **Version Prefix** | V=0 | V=1 | Implicit (no digit) | Handled by dialect detection |
| **Length Types** | LVAR, LLVAR, LLLVAR | LVAR, LLVAR, LLLVAR | LVAR, LLVAR, LLLVAR, LLLLVAR | DE-48, DE-52, DE-55 may use LLLLVAR in 2021 |
| **DE-48** | LLLVAR max 999 | LLLVAR max 999 | LLLLVAR max 9999 | Wire format changes in 2021 |
| **DE-55** | LLLVAR max 999 | LLLVAR max 999 | LLLVAR max 999 | Same length, but more fields supported |
| **Composite Fields** | Basic | Basic | Expanded (4.4.3) | DE-43 may have sub-fields in 2021 |
| **Annex J** | N/A | N/A | Used for field reassignments | Field mappings change |
| **Data Elements Count** | 128 | 128 | 128+ (extended in Annex J) | Same bitmap size, different semantics |

### No Changes to Bitmap Structure Across Versions
- Primary bitmap always 64 bits (8 bytes)
- Secondary bitmap (if needed) always 64 bits (8 bytes)
- Bit positions remain the same
- **Version difference is mainly in field encoding, not in which bits are used**

### Field-Specific Differences

| DE | 1987 | 1993 | 2021 | Simulator Support |
|----|----|------|------|------------------|
| 48 | LLLVAR 999 | LLLVAR 999 | LLLLVAR 9999 | LLLVAR (backward compatible) |
| 52 | FIXED 8 (PIN) | FIXED 8 (PIN) | FIXED 8 (PIN) | FIXED 8 |
| 55 | LLLVAR 999 (EMV) | LLLVAR 999 (EMV) | LLLVAR 999 (EMV) | LLLVAR 999 |
| 127 | Not defined | LLLVAR 999 (private) | LLLVAR 999 (expanded) | If secondary bitmap used |
| 128 | Not defined | LLLVAR 999 (private) | LLLVAR 999 (expanded) | If secondary bitmap used |

---

## 7. Validation Rules

### Field Dependency Matrix

**If DE-X is present, then DE-Y MUST also be present:**

| DE-X | DE-Y (Required) | Condition | Example |
|------|-----------------|-----------|---------|
| 52 (PIN) | 26 (PIN Capture Code) | PIN block present → PIN capture code required | If PIN=8 bytes, then DE-26 must indicate "PIN captured" |
| 55 (EMV) | 22 (POS Entry Mode) | EMV data → Entry mode must be chip | If DE-55 present, DE-22 must start with `05` (chip) |
| 56 (Original Data) | 11 (STAN) + 13 (Date) | Reversal → must identify original by STAN + date | For 0400/0420, DE-56 or DE-90 MANDATORY |
| 90 (Original Data Alt) | 11 (STAN) + 13 (Date) | Reversal → must identify original | Alternative to DE-56 |
| 95 (Replacement Amounts) | 4 (Amount) | Partial reversal → amount should be less than original | Only for partial reversals (0400/0420) |
| 28 (Fee) | 3 (Processing Code) | Fee present → must be applicable transaction type | 000000, 003000, etc. |

### Mutual Exclusions (NEVER together)

| DE-X | DE-Y | Reason |
|------|------|--------|
| 56 | 90 | Only ONE format for original data elements |
| 35 (Track 2) | 52 (PIN) + 55 (EMV) | Cannot have both magnetic stripe AND chip data |
| 14 (Exp Date) | Chipless transaction | Card expiry only if card is used |

### Mandatory Field Combinations by Transaction Type

#### 0100/0110 — Authorization
- **ALL:** 2, 3, 4, 7, 11, 12, 13, 14, 22, 25, 37, 41, 42, 43, 49
- **Response (0110) ADDS:** 38, 39

#### 0200/0210 — Financial Transaction
- **ALL:** 2, 3, 4, 7, 11, 12, 13, 14, 22, 25, 37, 41, 42, 43, 49
- **Response (0210) ADDS:** 38, 39

#### 0400/0410 — Reversal
- **ALL:** 3, 4, 7, 11, 25, 37, 38, 39, 41, 42, 49
- **MANDATORY:** 56 or 90 (original data elements)

#### 0800/0810 — Network Management
- **0800:** 7, 11, 70
- **0810:** 7, 11, 39, 70

### Request-Response Matching Rules

When sending request and receiving response, VALIDATE:

| Field | Rule |
|-------|------|
| DE-3 (Processing Code) | Response must ECHO request value |
| DE-4 (Amount) | Response must ECHO request value |
| DE-11 (STAN) | Response must ECHO request value |
| DE-37 (RRN) | Response must ECHO request value |
| DE-41 (TID) | Response must ECHO request value |
| DE-42 (MID) | Response must ECHO request value |
| DE-49 (Currency) | Response must ECHO request value |
| DE-38 (Auth Code) | Response MUST be present and populated |
| DE-39 (RC) | Response MUST be present (00, 51, 05, 14, 43, 57, 96, etc.) |

### Bitmap Validation Checklist

Before PACKING a message:

- [ ] MTI is valid (0100, 0110, 0200, 0210, 0400, 0410, 0420, 0430, 0800, 0810)
- [ ] All mandatory DEs for MTI type are present
- [ ] Bitmap is computed correctly (bits set only for present DEs)
- [ ] Bit 1 is set IFF secondary bitmap is present (any bit 65-128 set)
- [ ] No conflicting DEs (DE-56 + DE-90, Track 2 + EMV + PIN)
- [ ] If reversals (0400/0420): DE-56 or DE-90 is MANDATORY
- [ ] If EMV (DE-55): DE-22 entry mode indicates chip
- [ ] If PIN (DE-52): DE-26 is present
- [ ] Amount (DE-4) is 12 digits (with leading zeros if < 100)
- [ ] Dates/times are in correct format (MMDD, MMDDHHMMSS, etc.)
- [ ] RRN (DE-37) is exactly 12 characters
- [ ] Terminal ID (DE-41) is exactly 8 characters
- [ ] Merchant ID (DE-42) is exactly 15 characters
- [ ] Response code (DE-39) is 2 characters (for responses)

---

## 8. Reversal Flow (DE-56 / DE-90 Details)

### DE-56 Format (Original Data Elements)

**Purpose:** Contains the original transaction's key fields for matching and reversal purposes.

**Format:** LLLVAR (typically contains a sub-bitmap + sub-fields)

**Sub-Structure:**
```
[Length: 3 digits] [Sub-bitmap: variable] [Sub-fields in bitmap order]
```

**Typical Original Data Elements to Include:**
- Original STAN (DE-11)
- Original date (DE-13)
- Original amount (DE-4)
- Original processing code (DE-3)
- Original auth code (DE-38)
- Original response code (DE-39)
- Original RRN (DE-37)

**Example DE-56 construction:**
```
Field Length: 034
Sub-bitmap: 2040000000000000 (bits 3, 4, 11, 13, 37, 38, 39 set)
Field Data:
  - DE-3: 000000 (processing code)
  - DE-4: 000000001000 (amount 10.00)
  - DE-11: 123456 (STAN)
  - DE-13: 0216 (date)
  - DE-37: ABCDEF123456 (RRN)
  - DE-38: 000001 (auth code)
  - DE-39: 00 (response code)
```

### DE-90 Format (Alternative Original Data Elements)

**Purpose:** Alternative format for original data, used when DE-56 is not suitable.

**Format:** LLLVAR (typically 42 bytes fixed)

**Structure:**
```
[Original STAN: 6 digits]
[Original Transmission Date/Time: 10 digits]
[Original System Trace: 6 digits]
[Original Transmission Time: 6 digits]
[Original Settlement Date: 4 digits]
[Filler: 4 bytes]
```

### Reversal Matching Algorithm

**When simulator receives 0400/0420:**

1. Extract original STAN from DE-11 of reversal message (or from DE-56/DE-90)
2. Extract reversal date from DE-13 of reversal message
3. Query database: `SELECT * FROM transactions WHERE stan = ? AND local_date = ? AND terminal_id = ?`
4. If found: validate original auth code (DE-38) and response code (DE-39)
5. If matched: process reversal (set transaction.reversed = true, create reversal record)
6. If not found: return RC `77` (original transaction not found)

---

## 9. Simulator Decision Engine Reference

### Entry Point: 0100/0200 Request Processing

**Input:** Request message (0100/0200)
**Output:** Response message (0110/0210) with Response Code

**Decision Flow:**

```
ENTRY: 0100/0200 Request
  ↓
1. PARSE message → extract DE-2, DE-3, DE-4, DE-41, DE-42, etc.
  ↓
2. VALIDATE message → check mandatory fields, format, types
  ↓
3. LOOKUP MERCHANT → find merchant by MID (DE-42)
  ↓
4. CHECK TIMEOUT FLAG → if enabled, sleep 35 seconds
  ↓
5. APPLY CENTS RULE → extract centavos from DE-4, determine RC
  ↓
6. PERSIST TRANSACTION → save to database with RC
  ↓
7. BUILD RESPONSE → construct 0110/0210 with DE-38, DE-39
  ↓
8. PACK RESPONSE → encode to ISO 8583 wire format
  ↓
EXIT: Response message sent to client
```

### Cents Rule Implementation

```python
def get_response_code(amount_cents: int) -> str:
    """
    Extract response code from transaction amount using cents rule.

    amount_cents: amount in minor units (e.g., 10050 = 100.50 BRL)

    Returns: response code as 2-digit string
    """
    centavos = amount_cents % 100  # Get last 2 digits

    mapping = {
        0: "00",    # 0.00 to 0.50 BRL
        51: "51",   # 51 centavos → insufficient funds
        5: "05",    # 5 centavos → do not honor
        14: "14",   # 14 centavos → invalid card
        43: "43",   # 43 centavos → stolen card
        57: "57",   # 57 centavos → not allowed
        96: "96",   # 96 centavos → system error
    }

    return mapping.get(centavos, "96")  # Default to 96 for unmapped
```

---

## 10. Common Integration Errors and Prevention

### Error 1: Missing Mandatory Field in Response

**Mistake:** Sending 0110/0210 without DE-39 (Response Code)

**Prevention:**
- Use this checklist before packing response
- Simulator ALWAYS sets DE-38 and DE-39 in responses
- Bitmap validation should reject missing DE-39

### Error 2: Incorrect STAN Matching

**Mistake:** Response STAN differs from request STAN

**Prevention:**
- Response must ECHO request STAN exactly
- Extract STAN from request, place in response unchanged
- Validate during packing: `request.STAN == response.STAN`

### Error 3: Amount Mismatch in Reversal

**Mistake:** Reversal amount differs from original transaction

**Prevention:**
- Extract original amount from database lookup (DE-56/DE-90)
- Validate: `reversal_amount == original_amount` (unless partial reversal)
- Set DE-95 (Replacement Amounts) only for partial reversals

### Error 4: Secondary Bitmap Incorrectly Set

**Mistake:** Bit 1 set but no secondary bitmap, or vice versa

**Prevention:**
- **Bit 1 must be set IFF any bit 65-128 is used**
- **Bit 1 must be unset IFF no bit 65-128 is used**
- Bitmap calculation should be automated, not manual
- Validation: check presence of secondary bitmap against bit 1 state

### Error 5: Invalid Processing Code in Reversal

**Mistake:** 0400 has processing code other than 200000 or original code

**Prevention:**
- Reversals typically use `200000` (credit/refund) as processing code
- Original processing code should be referenced in DE-56/DE-90
- Validate: DE-3 in 0400 should match expected reversal pattern

### Error 6: Expiration Date Validation

**Mistake:** Card expired; transaction still processed

**Prevention:**
- Extract DE-14 (expiry in YYMM format)
- Compare with current date: if YY < current_year OR (YY == current_year AND MM < current_month), card is expired
- Response code should be RC `54` (Expired Card) or allow simulator to decide based on cents rule

### Error 7: Missing Currency Code

**Mistake:** DE-49 not set in response

**Prevention:**
- Always include currency code (e.g., `986` for BRL)
- Response must ECHO request currency
- Validation: `request.currency == response.currency`

---

## 11. Examples of Complete Message Construction

### Example 1: 0100 Authorization Request (Full Bitmap)

**Scenario:** Customer swipes card at POS, authorization requested

```
MTI: 0100

Data Elements:
  DE-2:  4916737596370136 (PAN, 16 digits)
  DE-3:  000000 (purchase)
  DE-4:  000000001050 (10.50 BRL)
  DE-7:  0216143000 (Feb 16, 2026, 14:30:00)
  DE-11: 000001 (STAN)
  DE-12: 143000 (local time)
  DE-13: 0216 (local date)
  DE-14: 2612 (expires Dec 2026)
  DE-22: 02 (magnetic stripe)
  DE-25: 00 (normal POS)
  DE-32: 123 (acquirer code, optional)
  DE-35: 4916737596370136=2612101000000001? (track 2)
  DE-37: STORE001TXN001 (RRN)
  DE-41: STORE001 (TID)
  DE-42: MERCHANT123456789 (MID, 15 chars)
  DE-43: LOJA CENTRO         SAO PAULO      SP BR (40 chars)
  DE-49: 986 (BRL)

Bitmap: 0x72004810180C0001C04C0120 (computed)
```

### Example 2: 0110 Authorization Response

```
MTI: 0110

Data Elements:
  DE-3:  000000 (echo)
  DE-4:  000000001050 (echo)
  DE-7:  0216143001 (response time, slightly later)
  DE-11: 000001 (echo STAN)
  DE-37: STORE001TXN001 (echo RRN)
  DE-38: AUTH001 (authorization code, assigned)
  DE-39: 00 (APPROVED — centavos .50 → RC 00)
  DE-41: STORE001 (echo TID)
  DE-42: MERCHANT123456789 (echo MID)
  DE-49: 986 (echo currency)

Bitmap: 0x70F8918908111800 (computed)
```

### Example 3: 0400 Reversal Request

```
MTI: 0400

Data Elements:
  DE-3:  200000 (reversal/credit)
  DE-4:  000000001050 (amount to reverse, same as original)
  DE-7:  0216150000 (reversal transmission time)
  DE-11: 000002 (NEW STAN for reversal)
  DE-25: 00 (normal)
  DE-37: STORE001TXN002 (NEW RRN for reversal)
  DE-38: AUTH001 (ORIGINAL auth code from original transaction)
  DE-39: 00 (ORIGINAL response code from original transaction)
  DE-41: STORE001 (TID, same as original)
  DE-42: MERCHANT123456789 (MID, same as original)
  DE-49: 986 (currency, same as original)
  DE-56: [034][2040000000000000]000000000000001050000001021600STORE001TXN001AUTH00100
         (3-digit length, sub-bitmap, original fields)

Bitmap: 0x7004C08118011C0C (computed, includes bit 1 for secondary)
```

---

## 12. Quick Reference by Use Case

### Use Case: Simple Debit Purchase (0100 → 0110)

**Request (0100):**
- Mandatory: DE-2, DE-3 (000000), DE-4, DE-7, DE-11, DE-12, DE-13, DE-14, DE-22, DE-25, DE-37, DE-41, DE-42, DE-43, DE-49
- Optional: DE-32, DE-35, DE-52, DE-55

**Response (0110):**
- Mandatory: DE-3, DE-4, DE-7, DE-11, DE-37, **DE-38, DE-39**, DE-41, DE-42, DE-49
- Response code determined by cents rule

### Use Case: Reversal of Previous Transaction (0400 → 0410)

**Request (0400):**
- Mandatory: DE-3 (200000), DE-4, DE-7, DE-11, DE-25, DE-37, DE-38 (original), DE-39 (original), DE-41, DE-42, DE-49, **DE-56 or DE-90**
- DE-56 MUST contain original transaction's key fields for matching

**Response (0410):**
- Mandatory: DE-3 (200000), DE-4, DE-7, DE-11, DE-37, DE-38, DE-39, DE-41, DE-42, DE-49
- Response code: 00 if reversal successful, 77 if original not found

### Use Case: Network Echo Test (0800 → 0810)

**Request (0800):**
- Mandatory: DE-7, DE-11, DE-70 (001)
- Minimal message for keep-alive

**Response (0810):**
- Mandatory: DE-7, DE-11, **DE-39, DE-70**
- Response code: 00 if echo successful, 96 if error

---

## Appendix A: Field Type Reference

| Type | Allowed Chars | Padding | Encoding | Examples |
|------|---|---------|----------|----------|
| `n` | 0-9 | LEFT (zeros) | BCD or ASCII | Amount, STAN, codes |
| `a` | A-Z, a-z, space | RIGHT (spaces) | ASCII only | Names |
| `an` | A-Z, a-z, 0-9 | RIGHT (spaces) | ASCII | Auth codes, RRN |
| `ans` | A-Z, a-z, 0-9, special | RIGHT (spaces) | ASCII | Merchant names, addresses |
| `anp` | A-Z, a-z, 0-9, space | RIGHT (spaces) | ASCII | Padded text |
| `b` | Any byte 0-255 | NONE | Binary/raw | EMV data, PIN block |
| `z` | 0-9, =, D, F | RIGHT (F) | ASCII | Track 2 data |
| `x+n` | C/D prefix + 0-9 | LEFT (zeros) | ASCII | Signed amounts |
| `xn` | Hex-encoded 0-9 | LEFT (zeros) | BCD/Hex | Hex numeric |

---

**END OF BITMAP REFERENCE**

> This document is the authoritative source for all ISO 8583 bitmap definitions in the authorizer-simulator project. Agents should reference this document for every message construction, validation, and testing task.
