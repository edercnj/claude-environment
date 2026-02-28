# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 51 — Insurance ACORD Domain

> This rule describes the Insurance domain following ACORD (Association for Cooperative Operations
> Research and Development) data standards, covering policy lifecycle, claims processing, underwriting,
> and regulatory compliance for both Brazilian (SUSEP) and US markets.

## Domain Overview

The insurance domain encompasses the full lifecycle of insurance products from quoting and underwriting
through policy issuance, endorsement, claims processing, and renewal. ACORD provides the industry-standard
data model and message formats for exchanging insurance information between carriers, agents, brokers,
and third-party administrators. This domain covers building insurance systems that conform to ACORD
standards while meeting regulatory requirements.

## System Role

- **Receives:** Quote requests, policy change requests, claims notifications (FNOL), underwriting submissions, regulatory filings
- **Processes:** Risk assessment, premium calculation, policy issuance, claims adjudication, reserve management, reinsurance cessions
- **Returns:** Quote responses, policy documents, claims status updates, regulatory reports, ACORD-formatted messages
- **Persists:** Policy records, claims files, underwriting workbooks, financial transactions, audit trails, regulatory submissions

## ACORD Data Standards (MANDATORY)

### Message Formats

| Format | Standard | Use Case | Transport |
|--------|----------|----------|-----------|
| ACORD XML | AL3/ACORD XML | Policy transactions, claims | SOAP/REST |
| ACORD JSON | ACORD Data Exchange | Modern API integration | REST |
| ACORD Forms | AL3 | Paper-equivalent data capture | Batch/API |
| ACORD Certificates | Certificate of Insurance | Proof of coverage | PDF + Data |

### ACORD XML Core Structure

```xml
<ACORD>
  <SignonRq>
    <SignonTransport>
      <CustId><SPName>AgencyXYZ</SPName></CustId>
    </SignonTransport>
  </SignonRq>
  <InsuranceSvcRq>
    <RqUID>uuid-v4</RqUID>
    <PolicyRq>
      <!-- Transaction-specific content -->
    </PolicyRq>
  </InsuranceSvcRq>
</ACORD>
```

### ACORD Transaction Types

| Transaction | Code | Description |
|------------|------|-------------|
| Policy Quote | PolicyQuoteInqRq/Rs | Request and receive a quote |
| New Business | PolicyAddRq/Rs | Issue a new policy |
| Endorsement | PolicyModRq/Rs | Modify existing policy |
| Renewal | PolicyRenewRq/Rs | Renew expiring policy |
| Cancellation | PolicyCancelRq/Rs | Cancel active policy |
| Reinstatement | PolicyReinstateRq/Rs | Reinstate cancelled policy |
| Claim Notice | ClaimNotificationAddRq/Rs | First Notice of Loss |
| Claim Status | ClaimInqRq/Rs | Query claim status |

### ACORD Data Model — Core Entities

| Entity | Description | Key Attributes |
|--------|-------------|----------------|
| Policy | Insurance contract | policyNumber, effectiveDate, expirationDate, status, lineOfBusiness |
| Coverage | Specific protection | coverageType, limit, deductible, premium |
| Insured | Policyholder | name, type (individual/organization), address, identification |
| Risk | Object of insurance | riskType, location, characteristics, riskScore |
| Claim | Loss notification | claimNumber, lossDate, reportDate, status, lossType |
| Producer | Agent/Broker | producerCode, name, license, commission |

## Policy Lifecycle (MANDATORY)

### Policy States

```
Policy Lifecycle:
QUOTE -> QUOTED -> BOUND -> ISSUED -> IN_FORCE -> EXPIRED
                                    -> CANCELLED -> REINSTATED -> IN_FORCE
                                    -> ENDORSED (mid-term change) -> IN_FORCE
         -> DECLINED (from QUOTE)
         -> NOT_TAKEN (from QUOTED)

EXPIRED -> RENEWED -> IN_FORCE (new term)
```

### Quote Phase

- **QUOTE-001**: Quote validity period: configurable per product (default: 30 days)
- **QUOTE-002**: Quote MUST include all mandatory coverages for the line of business
- **QUOTE-003**: Multiple quote options allowed (basic, standard, premium tiers)
- **QUOTE-004**: Quote comparison: side-by-side coverage and premium comparison required
- **QUOTE-005**: Indicative vs. firm quote: indicative quotes are non-binding, firm quotes are binding upon acceptance

### Bind Phase

- **BIND-001**: Binding converts a quote into a contractual obligation
- **BIND-002**: Binder valid for configurable period (default: 60 days) until policy issuance
- **BIND-003**: Binder MUST capture payment method and initial premium
- **BIND-004**: Effective date cannot be retroactive more than 30 days without underwriter approval

### Issue Phase

- **ISSUE-001**: Policy document generation with all endorsement forms
- **ISSUE-002**: Policy number format: `{LOB}-{YEAR}-{SEQUENCE}` (configurable)
- **ISSUE-003**: All coverages, exclusions, conditions, and declarations MUST be documented
- **ISSUE-004**: Digital signature or e-signature for policy acceptance

### Endorsement Phase

- **ENDORSE-001**: Mid-term policy changes require re-rating
- **ENDORSE-002**: Premium adjustment calculated pro-rata for remaining term
- **ENDORSE-003**: Endorsement effective date MUST be within the policy period
- **ENDORSE-004**: Endorsement types: coverage change, limit change, additional insured, address change, vehicle change
- **ENDORSE-005**: Each endorsement generates a new policy version (immutable history)

### Renewal Phase

- **RENEW-001**: Renewal processing starts at configurable days before expiration (default: 60 days)
- **RENEW-002**: Renewal re-rating considers claims history, market conditions, regulatory changes
- **RENEW-003**: Non-renewal notice required per state/regulatory requirements
- **RENEW-004**: Renewal creates a new policy term linked to the original policy
- **RENEW-005**: Automatic renewal vs. manual renewal: configurable per product

### Cancellation Phase

- **CANCEL-001**: Cancellation reasons: non-payment, insured request, underwriting, material misrepresentation
- **CANCEL-002**: Earned premium calculated: short-rate (penalty) or pro-rata
- **CANCEL-003**: Cancellation notice period: per state regulation (typically 10-60 days)
- **CANCEL-004**: Return premium calculated and refund processed
- **CANCEL-005**: Flat cancellation (ab initio): full premium returned, policy treated as if never issued

## Claims Processing (MANDATORY)

### Claims States

```
FNOL -> ACKNOWLEDGED -> UNDER_INVESTIGATION -> UNDER_ADJUSTMENT -> RESERVE_SET
     -> SETTLED (full or partial)
     -> DENIED
     -> CLOSED
     -> REOPENED (from CLOSED, within statute of limitations)

SUBROGATION (parallel track): IDENTIFIED -> IN_PROGRESS -> RECOVERED -> CLOSED
```

### FNOL (First Notice of Loss)

- **FNOL-001**: Capture minimum required data: policy number, loss date, loss type, description, claimant contact
- **FNOL-002**: Assign claim number immediately: `CLM-{YEAR}-{SEQUENCE}`
- **FNOL-003**: Validate coverage: confirm policy was in force on loss date
- **FNOL-004**: Trigger automated fraud indicators check
- **FNOL-005**: Route to appropriate adjuster based on: loss type, amount, complexity, location

### Investigation

- **INV-001**: Document gathering: police reports, medical records, photos, statements
- **INV-002**: Coverage determination: verify loss is covered, check exclusions and conditions
- **INV-003**: Liability determination: assign fault percentage (comparative negligence)
- **INV-004**: Special Investigation Unit (SIU) referral criteria: configurable rules
- **INV-005**: Subrogation identification: determine if third party is liable

### Adjustment

- **ADJ-001**: Damage assessment: repair estimate, replacement cost, actual cash value
- **ADJ-002**: Reserve setting: initial reserve based on claim type averages, adjusted as information develops
- **ADJ-003**: Reserve adequacy review: periodic (default: every 30 days for open claims)
- **ADJ-004**: Payment authorization levels: configurable by amount and claim type

### Settlement

- **SETTLE-001**: Settlement types: lump sum, structured settlement, periodic payments
- **SETTLE-002**: Settlement requires claimant release/agreement
- **SETTLE-003**: Payment methods: check, EFT, direct repair program (DRP)
- **SETTLE-004**: Deductible application: verify correct deductible amount per coverage
- **SETTLE-005**: Salvage and subrogation recovery tracked against claim

## Underwriting (MANDATORY)

### Risk Assessment

| Risk Factor | Data Source | Weight | LOB Applicability |
|-------------|-----------|--------|-------------------|
| Loss History | Claims database, CLUE/A-PLUS | High | All |
| Credit Score | Credit bureaus (where permitted) | Medium | Personal lines |
| Location | Geocoding, catastrophe models | High | Property |
| Occupancy/Use | Application, inspection | Medium | Commercial |
| Driving Record | MVR (Motor Vehicle Record) | High | Auto |
| Financial Statements | D&B, annual reports | Medium | Commercial |

### Rating Engine Patterns

- **RATE-001**: Base rate x rating factors = calculated premium
- **RATE-002**: Rating factors are multiplicative (not additive)
- **RATE-003**: Territory/zip code rating tables MUST be versioned (effective date ranges)
- **RATE-004**: Minimum premium applies regardless of calculated amount
- **RATE-005**: Rounding: premiums rounded to nearest cent, factors to 4 decimal places

### Rating Calculation

```
Calculated Premium = Base Rate
  x Territory Factor
  x Class Factor
  x Experience Modification Factor
  x Schedule Credit/Debit
  x Increased Limits Factor
  + Policy Fee
  + Taxes and Surcharges
```

### Underwriting Rules

- **UW-001**: Automated underwriting for standard risks (straight-through processing)
- **UW-002**: Referral to underwriter for non-standard risks (configurable rules)
- **UW-003**: Decline criteria: configurable per product and jurisdiction
- **UW-004**: Moratorium: ability to suspend new business by geography/product (catastrophe response)
- **UW-005**: Reinsurance: automatic treaty application based on policy limits and LOB

## Regulatory Compliance (MANDATORY)

### SUSEP — Brazil (Superintendencia de Seguros Privados)

| Requirement | Description | Frequency |
|-------------|-------------|-----------|
| FIP | Formulario de Informacoes Periodicas | Monthly |
| SES | Sistema de Estatisticas da SUSEP | Quarterly |
| Capital Requirements | Minimum capital and solvency margins | Continuous |
| Product Registration | New product approval with SUSEP | Per product |
| Claims Reporting | Loss ratio and claims statistics | Monthly |
| Anti-Money Laundering | Transaction monitoring and SAR reporting | Continuous |

### US State-Specific Compliance

| Requirement | Description | Variation |
|-------------|-------------|-----------|
| Rate Filing | File rates with state DOI before use | File & Use, Prior Approval, Use & File |
| Form Filing | File policy forms for approval | State-specific requirements |
| Cancellation Notice | Minimum notice period for cancellation | 10-60 days (varies by state) |
| Free Look Period | Policy cancellation without penalty | 10-30 days (varies by state) |
| Claims Settlement | Maximum days to settle or deny | 30-60 days (varies by state) |
| Data Privacy | State privacy law compliance | CA (CCPA), NY (DFS), etc. |

### Regulatory Rules

- **REG-001**: All policy forms MUST be approved by the relevant regulator before use
- **REG-002**: Rate filings MUST include actuarial justification
- **REG-003**: Complaint tracking and response: per regulatory requirements (typically 15-30 days)
- **REG-004**: Market conduct exam readiness: maintain all records for minimum 5 years (7 years recommended)
- **REG-005**: Anti-fraud program: mandatory in most jurisdictions, including SIU and fraud reporting

## Financial Calculations (MANDATORY)

### Premium Accounting

- **FIN-001**: All monetary values stored as integer cents (minor units) — NO floating-point
- **FIN-002**: Written premium: total premium on policy as written
- **FIN-003**: Earned premium: portion of written premium for elapsed coverage period
- **FIN-004**: Unearned premium: portion for future coverage period (liability)
- **FIN-005**: Currency: always explicit, never assumed (ISO 4217 codes)

### Reserve Types

| Reserve Type | Description | Calculation |
|-------------|-------------|-------------|
| Case Reserve | Estimated cost of individual claim | Adjuster assessment |
| IBNR | Incurred But Not Reported | Actuarial methods (chain ladder, BF) |
| IBNER | Incurred But Not Enough Reserved | Development factor analysis |
| Bulk Reserve | Group reserve for similar claims | Statistical average |
| Catastrophe Reserve | Reserve for catastrophic events | Catastrophe model output |

## Sensitive Data — NEVER Log in Plaintext

| Data | Classification | Can Log? | Can Persist? | Can Return in API? |
|------|---------------|----------|--------------|-------------------|
| SSN / CPF | PII / RESTRICTED | NEVER | Encrypted | Masked (last 4) |
| Driver's License | PII | NEVER | Encrypted | Masked |
| Medical Records | PHI / RESTRICTED | NEVER | Encrypted, access-controlled | Authorized only |
| Bank Account | FINANCIAL | NEVER | Encrypted | Masked |
| Credit Score | PII / RESTRICTED | NEVER | Encrypted | Score range only |
| Policy Number | BUSINESS | Yes (masked in prod) | Yes | Yes (authorized) |
| Claim Details | PII / BUSINESS | Summary only | Yes | Yes (authorized) |
| Loss Location | PII | Address only (no GPS) | Yes | Yes (authorized) |
| Claimant Contact | PII | NEVER | Encrypted | Authorized only |

## Domain Anti-Patterns

- Using floating-point arithmetic for premium or reserve calculations (MUST use integer cents)
- Modeling policy endorsements as in-place updates instead of immutable versions
- Skipping coverage verification during FNOL (must validate policy was in force)
- Hardcoding rating factors instead of using versioned rating tables
- Processing claims without checking for duplicate FNOL submissions
- Calculating earned premium without accounting for endorsement mid-term changes
- Implementing cancellation without state-specific notice period validation
- Allowing reserve changes without audit trail (who, when, amount, reason)
- Mixing up "loss date" and "report date" in claims processing
- Processing renewals without re-evaluating risk factors and claims history
- Storing regulatory filings without version control and submission tracking

## Glossary

| Term | Definition |
|------|-----------|
| ACORD | Association for Cooperative Operations Research and Development — insurance data standards body |
| LOB | Line of Business — insurance category (auto, property, liability, health, life) |
| FNOL | First Notice of Loss — initial claim report |
| SIU | Special Investigation Unit — fraud investigation team |
| CLUE | Comprehensive Loss Underwriting Exchange — claims history database (US) |
| MVR | Motor Vehicle Record — driving history report |
| DRP | Direct Repair Program — network of pre-approved repair shops |
| IBNR | Incurred But Not Reported — actuarial reserve for unreported claims |
| SUSEP | Superintendencia de Seguros Privados — Brazilian insurance regulator |
| DOI | Department of Insurance — US state insurance regulator |
| AL3 | ACORD Level 3 — data standard for insurance transactions |
| Subrogation | Recovery of claim payment from responsible third party |
| Salvage | Recovery of value from damaged property |
| Pro-rata | Proportional calculation based on time elapsed |
| Short-rate | Cancellation calculation with penalty (higher than pro-rata) |
| Earned Premium | Premium for coverage already provided |
| Written Premium | Total premium on the policy as issued |
| Binder | Temporary proof of insurance before policy issuance |
