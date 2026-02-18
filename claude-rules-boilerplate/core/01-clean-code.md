# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 01 — Clean Code

## Principles
Clean Code is the foundation of maintainable software. Every rule below is **mandatory** — not aspirational.

## CC-01: Names That Reveal Intent

**Naming Rules:**
- Names should reveal intent: `elapsedTimeInMs` not `d`
- Avoid misinformation: don't use `accountList` if not a `List` — use `accounts` or `accountGroup`
- Meaningful distinctions: `source` / `destination` not `a1` / `a2`
- Pronounceable names: `createdAt` not `crtdTmst`
- Searchable names: named constants, not literal values scattered in code
- No Hungarian prefixes: `name` not `strName`, `count` not `iCount`
- No mental mapping: `merchant` not `m`, `transaction` not `t` (except short lambdas with obvious context)
- Verbs for methods/functions: `processTransaction()`, `extractAmount()`, `buildResponse()`
- Nouns for classes/types: `TransactionHandler`, `DecisionEngine`, `MerchantRepository`

```
// BAD
Object process(Object msg)
int d;
String a1, a2;

// GOOD
TransactionResult authorizeTransaction(Message request)
int elapsedTimeInMs;
String source, destination;
```

## CC-02: Functions Do ONE Thing

- Maximum **25 lines** per method/function (relaxed from 20 to include framework boilerplate)
- Maximum **4 parameters** (relaxed from 3 to include injected dependencies)
- If more needed, create a parameter object (record, struct, DTO)
- **One level of abstraction per function** (Stepdown Rule): read the function top-to-bottom as a narrative
- **FORBIDDEN**: boolean flag as parameter — create two distinct functions
- **FORBIDDEN**: hidden side effects: `validateTransaction()` MUST NOT persist data

```
// GOOD — one level of abstraction, reads as narrative
function authorizeDebitTransaction(request):
    amount = extractAmount(request)
    responseCode = decisionEngine.decide(amount)
    transaction = buildTransaction(request, responseCode)
    persistence.save(transaction)
    return buildResponse(request, responseCode, transaction)

// BAD — mixes abstraction levels
function authorizeDebitTransaction(request):
    rawField = request.getField(4)
    amountStr = decodeAscii(rawField)
    amount = parseDecimal(amountStr).movePointLeft(2)
    // ... 30 lines mixing low-level parsing with business logic

// BAD — flag argument
function processTransaction(msg, isReversal): ...
// GOOD — separate functions
function processDebitSale(msg): ...
function processReversal(msg): ...
```

## CC-03: Single Responsibility

- Maximum **250 lines** per class/module (relaxed from 200 for entities with ORM annotations)
- One class/module = one reason to change

## CC-04: No Magic Values

```
// GOOD
RESPONSE_APPROVED = "00"
TIMEOUT_SECONDS = 35

// BAD
if responseCode == "00": ...
sleep(35000)
```

All literal values used more than once or with non-obvious meaning MUST be named constants or enums.

## CC-05: DRY (Don't Repeat Yourself)

- If you copy code, extract a function or utility
- Three identical lines of code is the threshold for extraction

## CC-06: Rich Error Handling

- NEVER return `null` — use `Optional<T>`, `Maybe`, `Result`, or empty collection
- NEVER pass `null` as argument — use overloads or optional parameters
- Prefer unchecked/runtime exceptions — checked exceptions pollute signatures
- Catch at the right level: capture exceptions where you can handle them, not where it's convenient
- Exceptions MUST carry context (the values that caused the error)

```
// GOOD — Exception with context
throw new TransactionProcessingException(
    "Failed to authorize transaction",
    context: {mti: mti, stan: stan, merchantId: mid}
)

// BAD — Generic exception without context
throw new Error("Something went wrong")
```

## CC-07: Self-Documenting Code

- Comments ONLY when explaining the **why**, never the **what**
- If method/function name already explains what it does, do NOT add documentation
- **FORBIDDEN**: obvious comments that repeat what the code says
- **FORBIDDEN**: empty boilerplate documentation (`@param name the name`, `@return the result`)

```
// BAD — comment that repeats the code
// Returns the response code
function getResponseCode(): return responseCode

// GOOD — no comment, the name explains everything
function processDebitTransaction(request): ...

// GOOD — comment explains non-obvious business rule
// Cents .00 to .50 = approved, .51+ maps to specific RC (RULE-001)
responseCode = centsDecisionEngine.decide(amount)
```

## CC-08: Vertical Formatting

**Blank lines separate CONCEPTS. No blank lines group RELATED items.**

| Where | Blank line? | Reason |
|-------|:-----------:|--------|
| Between constant groups and fields | Yes | Separates configuration from state |
| Between fields and constructor | Yes | Separates state from initialization |
| Between constructor and public methods | Yes | Separates init from behavior |
| Between methods/functions | Always | Each method is a concept |
| Within method: between logical blocks | Yes | Separates processing stages |
| Within method: related lines | No | Maintains visual cohesion |
| Between import/dependency groups | Yes | Separates origin |
| After class/module opening brace | No | Blank line right after is noise |
| Before closing brace | No | Blank line before is noise |

**Ordering within class/module (Newspaper Rule):**
1. Constants
2. Logger / module-level state
3. Instance fields
4. Constructor(s)
5. Public methods (class API)
6. Package-private / internal methods
7. Private methods (in order called by public methods)

## CC-09: Law of Demeter (Don't Talk to Strangers)

```
// BAD — train wreck, couples 3 objects
mcc = transaction.getMerchant().getTerminal().getMcc()

// GOOD — ask directly from who knows
mcc = transaction.getMerchantMcc()
```

A method should only call methods on:
- Its own object (`this` / `self`)
- Objects passed as parameters
- Objects it created
- Its direct component objects

## CC-10: Class Organization

- Classes should be **small** — measured by responsibilities, not lines
- High cohesion: methods use most fields of the class
- If a method subset uses only a field subset, extract a new class
- Prefer many small classes/modules to few large ones

## Formatting Rules

| Rule | Standard |
|------|----------|
| Maximum line width | **120 characters** |
| Braces / blocks | Opening on same line (K&R style) or language convention |
| Imports / dependencies | No wildcards, organized by origin |
| Method signatures | Fit on ONE line unless exceeding max width |

> **Note:** Indentation style (spaces vs tabs, count) is defined per language profile.

## Anti-Patterns (FORBIDDEN)

- Magic numbers/strings — use constants or enums
- Functions longer than 25 lines
- Classes longer than 250 lines
- More than 4 parameters without a parameter object
- Boolean flags as function parameters
- `null` returns or `null` arguments
- Comments that repeat what the code already says
- Mutable global state
- God classes (classes that do everything)
- Train wrecks (chained method calls across different objects)
