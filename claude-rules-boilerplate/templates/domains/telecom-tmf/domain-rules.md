# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 51 — Telecom TM Forum Domain

> This rule describes the Telecom domain following TM Forum (TMF) Open API standards,
> covering catalog management, order management, inventory, billing, customer/party management,
> the SID data model, and event-driven architecture patterns.

## Domain Overview

The TM Forum provides an industry-standard framework for telecommunications business processes
and IT systems. The Open API program defines RESTful APIs based on the SID (Shared Information/Data
Model) and eTOM (enhanced Telecom Operations Map) process framework. This domain covers building
telecom BSS/OSS systems that conform to TMF Open API specifications for interoperability across
the telecom ecosystem.

## System Role

- **Receives:** API requests for catalog browsing, order placement, inventory queries, billing inquiries, customer management
- **Processes:** Product/service/resource lifecycle management, order orchestration, inventory allocation, billing calculation
- **Returns:** TMF-compliant REST API responses, event notifications, SID-conformant entity representations
- **Persists:** Catalog entries, order records, inventory items, customer/party data, billing accounts, usage records

## TMF Open APIs (MANDATORY)

### Catalog Management

| API | TMF ID | Description | Key Resources |
|-----|--------|-------------|---------------|
| Product Catalog Management | TMF620 | Manage product offerings and specifications | ProductOffering, ProductSpecification, Category |
| Service Catalog Management | TMF633 | Manage service specifications | ServiceSpecification, ServiceCandidate |
| Resource Catalog Management | TMF634 | Manage resource specifications | ResourceSpecification, ResourceCandidate |

#### TMF620 — Product Catalog Management

##### Core Resources

| Resource | Description | Key Attributes |
|----------|-------------|----------------|
| ProductOffering | A product available for purchase | id, name, description, lifecycleStatus, validFor, productOfferingPrice, productSpecification |
| ProductSpecification | Technical description of a product | id, name, brand, productNumber, characteristics |
| ProductOfferingPrice | Pricing for an offering | priceType (recurring, oneTime, usage), price, unitOfMeasure, validFor |
| Category | Hierarchical classification | id, name, parentId, subCategory, productOffering |

##### Lifecycle States

```
ProductOffering States:
IN_STUDY -> IN_DESIGN -> IN_TEST -> ACTIVE -> LAUNCHED -> RETIRED -> OBSOLETE
```

- **CATALOG-001**: Only LAUNCHED offerings are visible to customers
- **CATALOG-002**: RETIRED offerings cannot accept new orders but existing subscriptions remain active
- **CATALOG-003**: ProductSpecification changes MUST NOT break existing ProductOfferings (backward compatible)

### Order Management

| API | TMF ID | Description | Key Resources |
|-----|--------|-------------|---------------|
| Product Ordering Management | TMF622 | Manage product orders | ProductOrder, ProductOrderItem |
| Service Ordering Management | TMF641 | Manage service orders | ServiceOrder, ServiceOrderItem |
| Resource Ordering Management | TMF652 | Manage resource orders | ResourceOrder, ResourceOrderItem |

#### TMF622 — Product Ordering Management

##### Order Item Actions

| Action | Description | Requires |
|--------|-------------|----------|
| add | New product subscription | ProductOffering reference |
| modify | Change existing subscription | Product reference + changes |
| delete | Cancel/remove subscription | Product reference |
| noChange | No action (dependency marker) | Product reference |

##### Order States

```
ProductOrder States:
ACKNOWLEDGED -> IN_PROGRESS -> COMPLETED
                             -> PARTIAL
                             -> FAILED
             -> CANCELLED (from ACKNOWLEDGED or IN_PROGRESS)
             -> HELD (pending manual intervention)

ProductOrderItem States:
ACKNOWLEDGED -> IN_PROGRESS -> COMPLETED
                             -> FAILED
             -> CANCELLED
             -> HELD
```

##### Order Rules

- **ORDER-001**: Order items are processed independently — partial completion is valid
- **ORDER-002**: Order cancellation is only possible if no items have reached COMPLETED
- **ORDER-003**: Each order item MUST reference a valid ProductOffering (for `add`) or existing Product (for `modify`/`delete`)
- **ORDER-004**: Order item dependencies define execution sequence (item A depends on item B)
- **ORDER-005**: Idempotency via `externalId` — duplicate orders with same externalId return original response

### Inventory Management

| API | TMF ID | Description | Key Resources |
|-----|--------|-------------|---------------|
| Product Inventory Management | TMF637 | Track active product instances | Product |
| Service Inventory Management | TMF638 | Track active service instances | Service |
| Resource Inventory Management | TMF639 | Track resource instances | Resource |

#### TMF637/638/639 — Inventory

##### Product/Service/Resource Layered Model

```
Product Layer (Customer-facing):
  Product -> references -> ProductOffering + ProductSpecification
  Example: "Gold Internet Plan 100Mbps"

Service Layer (Service-facing):
  Service -> references -> ServiceSpecification
  Product is realized by one or more Services
  Example: "Broadband Service", "Email Service"

Resource Layer (Infrastructure):
  Resource -> references -> ResourceSpecification
  Service is supported by one or more Resources
  Example: "OLT Port", "IP Address", "CPE Device"
```

- **INV-001**: Creating a Product triggers Service activation which triggers Resource allocation
- **INV-002**: Deleting a Product triggers Service deactivation and Resource deallocation
- **INV-003**: Inventory records MUST maintain referential integrity across layers
- **INV-004**: Resource status changes propagate upward: Resource failure -> Service degraded -> Product impacted

##### Inventory States

```
Product/Service/Resource States:
CREATED -> ACTIVE -> SUSPENDED -> TERMINATED
                  -> ABORTED (from CREATED)
```

### Billing Management

| API | TMF ID | Description | Key Resources |
|-----|--------|-------------|---------------|
| Customer Bill Management | TMF678 | Manage customer bills | CustomerBill, AppliedCustomerBillingRate |
| Prepay Balance Management | TMF654 | Manage prepaid balances | BucketBalance, TopupBalance |
| Usage Management | TMF635 | Track usage records | Usage, UsageSpecification |

#### TMF678 — Customer Bill Management

| Resource | Description | Key Attributes |
|----------|-------------|----------------|
| CustomerBill | A bill for a billing period | billDate, billingPeriod, amountDue, state, billDocument |
| AppliedCustomerBillingRate | Rated charge on a bill | type (recurring, oneTime, usage), appliedTax, taxAmount |
| BillingCycleSpecification | Defines billing cycle | frequency, dateShift, billingDateShift |

##### Bill States

```
CustomerBill States:
NEW -> ON_HOLD -> VALIDATED -> SENT -> SETTLED -> PARTIALLY_PAID
```

- **BILL-001**: Bill amounts are calculated in minor currency units (cents) to avoid floating-point errors
- **BILL-002**: Prorated charges calculated by day: `(monthly_charge / days_in_period) * days_used`
- **BILL-003**: Tax calculation MUST use the tax rules valid on the charge date, not the bill date
- **BILL-004**: Credit notes reference the original bill via `relatedParty`

### Customer / Party Management

| API | TMF ID | Description | Key Resources |
|-----|--------|-------------|---------------|
| Party Management | TMF632 | Manage individuals and organizations | Individual, Organization |
| Customer Management | TMF629 | Manage customer relationships | Customer |
| Account Management | TMF666 | Manage billing and financial accounts | BillingAccount, FinancialAccount |
| Party Role Management | TMF669 | Manage party roles | PartyRole |

#### TMF632 — Party Management

| Resource | Description | Key Attributes |
|----------|-------------|----------------|
| Individual | A person | givenName, familyName, birthDate, contactMedium, identification |
| Organization | A company/entity | tradingName, organizationType, contactMedium, identification |

- **PARTY-001**: A Party can have multiple roles (Customer, Employee, Partner) simultaneously
- **PARTY-002**: Contact medium (email, phone) validation is MANDATORY before activation
- **PARTY-003**: Party merge operations MUST preserve all historical references

## SID — Shared Information/Data Model (MANDATORY)

### Entity Relationship Overview

```
Party (Individual/Organization)
  |-- has --> PartyRole (Customer, Partner, Employee)
  |              |-- has --> Account (BillingAccount, FinancialAccount)
  |              |-- owns --> Product (active subscription)
  |                              |-- realized by --> Service
  |                                                    |-- supported by --> Resource
  |
  |-- browses --> ProductOffering (from Catalog)
                     |-- priced by --> ProductOfferingPrice
                     |-- specified by --> ProductSpecification
                                            |-- references --> ServiceSpecification
                                                                  |-- references --> ResourceSpecification
```

### SID Domains

| Domain | Entities | Description |
|--------|----------|-------------|
| Market/Sales | ProductOffering, Category, Promotion | What is sold |
| Customer | Customer, Account, Contact | Who buys |
| Product | Product, ProductCharacteristic | What is subscribed |
| Service | Service, ServiceCharacteristic | What is delivered |
| Resource | Resource, ResourceCharacteristic | What supports delivery |
| Engagement | Interaction, TroubleTicket | Customer touchpoints |

## Event-Driven Architecture — TMF688 (MANDATORY)

### TMF Event Notification Pattern

All TMF APIs follow a consistent event notification pattern:

#### Event Structure

```json
{
  "eventId": "uuid-v4",
  "eventTime": "2024-01-15T10:30:00.000Z",
  "eventType": "ProductOrderCreateEvent",
  "correlationId": "uuid-v4",
  "domain": "productOrdering",
  "title": "Product Order Created",
  "description": "A new product order has been created",
  "priority": "normal",
  "event": {
    "productOrder": {
      "id": "order-123",
      "href": "/tmf-api/productOrderingManagement/v4/productOrder/order-123",
      "externalId": "ext-456",
      "state": "acknowledged"
    }
  }
}
```

#### Event Types (per API)

| TMF API | Create Event | State Change Event | Delete Event | Attribute Value Change |
|---------|-------------|-------------------|-------------|----------------------|
| TMF620 | ProductOfferingCreateEvent | ProductOfferingStateChangeEvent | ProductOfferingDeleteEvent | ProductOfferingAttributeValueChangeEvent |
| TMF622 | ProductOrderCreateEvent | ProductOrderStateChangeEvent | ProductOrderDeleteEvent | ProductOrderAttributeValueChangeEvent |
| TMF637 | ProductCreateEvent | ProductStateChangeEvent | ProductDeleteEvent | ProductAttributeValueChangeEvent |
| TMF632 | IndividualCreateEvent | IndividualStateChangeEvent | IndividualDeleteEvent | IndividualAttributeValueChangeEvent |

#### Hub/Listener Pattern (TMF630)

```
1. Consumer registers a listener (callback URL) at the Hub:
   POST /tmf-api/productOrderingManagement/v4/hub
   {
     "callback": "https://consumer.example.com/listener",
     "query": "eventType=ProductOrderStateChangeEvent"
   }

2. Producer sends events to all registered listeners:
   POST https://consumer.example.com/listener
   { ...event payload... }

3. Consumer acknowledges with 2xx, or producer retries (exponential backoff)
```

- **EVENT-001**: Events MUST be delivered at-least-once — consumers MUST be idempotent
- **EVENT-002**: Event ordering is NOT guaranteed — use `eventTime` for sequencing
- **EVENT-003**: Failed delivery retries: 3 attempts with exponential backoff (1s, 5s, 30s)
- **EVENT-004**: Dead letter queue for events that exhaust retries
- **EVENT-005**: Hub registration supports filtering by `eventType` and entity attributes

## TMF API Common Patterns

### Pagination

```
GET /tmf-api/productCatalogManagement/v4/productOffering?offset=0&limit=20

Response Headers:
X-Total-Count: 150
X-Result-Count: 20
Link: <...?offset=20&limit=20>; rel="next"
```

### Filtering

```
# Equality
GET /productOffering?lifecycleStatus=active

# Partial match (contains)
GET /productOffering?name=*Internet*

# Range
GET /productOrder?orderDate.gt=2024-01-01&orderDate.lt=2024-02-01

# Selection (comma-separated)
GET /productOrder?fields=id,state,orderDate
```

### PATCH (JSON Merge Patch)

- TMF APIs use JSON Merge Patch (RFC 7396), NOT JSON Patch (RFC 6902)
- `Content-Type: application/merge-patch+json`
- To remove a field, set it to `null`
- Arrays are replaced entirely (not merged)

## Sensitive Data — NEVER Log in Plaintext

| Data | Classification | Can Log? | Can Persist? | Can Return in API? |
|------|---------------|----------|--------------|-------------------|
| Customer Name | PII | Audit only | Yes (encrypted) | Yes (authorized) |
| National ID (CPF/SSN) | PII / RESTRICTED | NEVER | Encrypted | Masked |
| Phone Number | PII | Last 4 digits | Yes | Yes (authorized) |
| Email | PII | Masked | Yes | Yes (authorized) |
| Billing Address | PII | NEVER in detail | Encrypted | Yes (authorized) |
| Payment Card | PCI | NEVER | Tokenized | Last 4 digits |
| Account Balance | FINANCIAL | NEVER | Yes | Yes (account owner) |
| Usage Records | BEHAVIORAL | Aggregate only | Yes | Yes (account owner) |
| Location Data | PII / SENSITIVE | NEVER | Encrypted | With consent only |

## Domain Anti-Patterns

- Implementing order management without the Product/Service/Resource layered model
- Using synchronous processing for order orchestration (MUST be asynchronous/event-driven)
- Hardcoding product characteristics instead of using catalog-driven configuration
- Billing calculations using floating-point arithmetic (MUST use integer cents)
- Skipping the Hub/Listener pattern and polling APIs for state changes
- Treating TMF API resources as flat entities instead of SID-conformant hierarchies
- Implementing PATCH with JSON Patch (RFC 6902) instead of JSON Merge Patch (RFC 7396)
- Coupling service activation logic to specific product types (use specification-driven approach)
- Allowing inventory state transitions that skip intermediate states
- Not implementing event idempotency in consumers (at-least-once delivery guarantee)

## Glossary

| Term | Definition |
|------|-----------|
| TMF | TM Forum — industry association defining telecom standards |
| SID | Shared Information/Data Model — canonical data model for telecom |
| eTOM | enhanced Telecom Operations Map — business process framework |
| BSS | Business Support System — customer-facing systems (CRM, billing, ordering) |
| OSS | Operations Support System — network-facing systems (inventory, activation, assurance) |
| CPE | Customer Premises Equipment — hardware at the customer site (router, modem) |
| OLT | Optical Line Terminal — fiber network equipment |
| NNI | Network-to-Network Interface — interconnection between operators |
| MVNO | Mobile Virtual Network Operator — operator without own radio network |
| Hub | TMF event subscription endpoint — consumers register callback URLs |
| Listener | TMF event receiver endpoint — URL that receives event notifications |
