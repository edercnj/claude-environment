# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule — {DOMAIN_NAME} Domain

<!-- TEMPLATE INSTRUCTIONS:
     This file captures domain-specific knowledge that the AI must understand
     to produce correct code. It is NOT about coding patterns (that is in the
     coding profile) — it is about the BUSINESS DOMAIN.

     Replace all {PLACEHOLDER} values and remove instruction comments. -->

## Domain Overview

<!-- Describe WHAT this domain is about in 3-5 sentences.
     Include: the problem being solved, the role of this system in the
     larger ecosystem, and who the primary users/consumers are. -->

{DOMAIN_OVERVIEW}

## System Role

<!-- Define what this system DOES within the domain.
     Use active verbs: receives, processes, transforms, decides, persists, etc. -->

- **Receives:** {WHAT_IT_RECEIVES}
- **Processes:** {WHAT_IT_PROCESSES}
- **Returns:** {WHAT_IT_RETURNS}
- **Persists:** {WHAT_IT_PERSISTS}

## Domain Model

<!-- List the core entities, value objects, aggregates, and their relationships.
     This is the ubiquitous language of the domain — every developer must use
     these exact terms. -->

### Core Entities

<!-- Example:
| Entity | Description | Key Attributes |
|--------|-------------|----------------|
| Order | A customer purchase request | id, status, total, items, customerId |
| Product | An item available for sale | id, sku, name, price, stock |
| Customer | A registered buyer | id, email, name, tier |
-->

{ENTITIES_TABLE}

### Value Objects

<!-- Immutable objects defined by their attributes, not identity.
     Example: Money(amount, currency), Address(street, city, zip), DateRange(start, end) -->

{VALUE_OBJECTS}

### Aggregates and Boundaries

<!-- Define aggregate roots and their boundaries.
     Which entities are always loaded/saved together? -->

{AGGREGATES}

## Business Rules

<!-- These are the domain rules that determine system behavior.
     Each rule should have: an ID, a description, and the decision logic.
     Rules should be testable and deterministic. -->

### {RULE_ID_1}: {RULE_NAME_1}

<!-- Example:
### RULE-001: Order Total Calculation
- Line item total = quantity x unit price
- Subtotal = sum of all line item totals
- Tax = subtotal x tax rate (based on shipping address state)
- Discount = apply best matching promotion (only one promotion per order)
- Total = subtotal + tax - discount
- Total MUST be >= 0 (discount cannot exceed subtotal + tax)
-->

{RULE_1_DESCRIPTION}

### {RULE_ID_2}: {RULE_NAME_2}

{RULE_2_DESCRIPTION}

<!-- Add more rules as needed. Each rule should be self-contained
     and reference specific domain concepts from the model above. -->

## Domain States and Transitions

<!-- Define the state machine for key entities.
     What states can they be in? What events trigger transitions? -->

<!-- Example:
```
Order States:
DRAFT → SUBMITTED → CONFIRMED → SHIPPED → DELIVERED
                  → CANCELLED (from SUBMITTED or CONFIRMED)
                  → RETURNED (from DELIVERED, within 30 days)
```
-->

{STATE_MACHINES}

## Communication Protocols

<!-- If the domain involves specific wire protocols, message formats,
     or integration patterns, document them here.

     Examples:
     - ISO 8583 message format for payment processing
     - HL7 FHIR for healthcare interoperability
     - FIX protocol for financial trading
     - MQTT topics for IoT devices

     Skip this section if not applicable. -->

{PROTOCOLS}

## Sensitive Data

<!-- Define domain-specific data classification BEYOND generic security rules.
     What data in THIS domain requires special handling?

     Use this table format: -->

<!-- Example:
| Data | Classification | Can Log? | Can Persist? | Can Return in API? |
|------|---------------|----------|--------------|-------------------|
| Credit Card Number | PROHIBITED | Masked only | Tokenized only | Last 4 digits |
| SSN | RESTRICTED | NEVER | Encrypted | NEVER |
| Email | PII | Yes | Yes | Yes (to owner only) |
| Order Total | Internal | Yes | Yes | Yes |
-->

{SENSITIVE_DATA_TABLE}

### Data Handling Rules

<!-- Specific rules for how sensitive data must be handled in this domain.
     Example: PAN masking algorithm, tokenization strategy, encryption at rest. -->

{DATA_HANDLING_RULES}

## Domain-Specific Test Scenarios

<!-- Define the test scenarios that validate domain correctness.
     These should map 1:1 to business rules above. -->

### Unit Test Scenarios

<!-- Example:
| Scenario | Input | Expected Output | Rule |
|----------|-------|-----------------|------|
| Standard order total | 2 items, no discount | subtotal + tax | RULE-001 |
| Order with promotion | 1 item + PROMO10 code | 10% discount applied | RULE-001 |
| Negative total prevention | discount > subtotal | total = 0 | RULE-001 |
-->

{UNIT_TEST_SCENARIOS}

### Integration Test Scenarios

<!-- End-to-end flows that exercise the domain through real adapters. -->

{INTEGRATION_TEST_SCENARIOS}

## Domain Anti-Patterns

<!-- Things that are WRONG in this specific domain. Not generic coding anti-patterns
     (those are in the coding profile), but domain-specific mistakes. -->

<!-- Example:
- Allowing order total to go negative
- Processing payment before inventory check
- Shipping to an unverified address
- Applying multiple exclusive promotions to same order
-->

{DOMAIN_ANTI_PATTERNS}

## Glossary

<!-- Domain-specific terms that have precise meaning in this context.
     This prevents ambiguity and ensures consistent naming in code. -->

<!-- Example:
| Term | Definition |
|------|-----------|
| SKU | Stock Keeping Unit — unique product identifier |
| Fulfillment | The process of picking, packing, and shipping an order |
| Backorder | An order for an item that is temporarily out of stock |
-->

{GLOSSARY}
