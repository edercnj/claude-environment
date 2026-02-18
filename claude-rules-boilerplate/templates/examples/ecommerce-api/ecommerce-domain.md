# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule — E-Commerce Domain

## Domain Overview

ShopWave is an e-commerce backend that manages the full purchase lifecycle: product catalog browsing, shopping cart management, order placement, payment processing, and inventory tracking. The system acts as the backend API consumed by web and mobile frontends. It integrates with Stripe for payment processing and an S3-compatible service for product image storage.

## System Role

- **Receives:** HTTP requests from frontend clients (web, mobile)
- **Processes:** Catalog queries, cart mutations, order workflows, payment intents
- **Returns:** JSON responses with product data, cart state, order confirmations
- **Persists:** Products, orders, customers, inventory levels in PostgreSQL; sessions in Redis

## Domain Model

### Core Entities

| Entity | Description | Key Attributes |
|--------|-------------|----------------|
| Product | An item available for sale | id, sku, name, description, price, stock, categoryId, status |
| Category | Product classification | id, name, slug, parentId |
| Cart | A customer's shopping basket | id, customerId, items[], expiresAt |
| CartItem | A line item in a cart | productId, quantity, priceAtAdd |
| Order | A confirmed purchase | id, customerId, items[], total, status, paymentId |
| OrderItem | A line item in an order | productId, quantity, unitPrice, subtotal |
| Customer | A registered buyer | id, email, name, addresses[], tier |
| Payment | A payment transaction | id, orderId, stripePaymentIntentId, amount, status |
| Inventory | Stock tracking per product | productId, availableQty, reservedQty |

### Value Objects

| Value Object | Attributes | Used By |
|-------------|-----------|---------|
| Money | amountCents (integer), currency (ISO 4217) | Product, Order, Payment |
| Address | street, city, state, zipCode, country | Customer, Order |
| PriceSnapshot | unitPrice, quantity, subtotal | CartItem, OrderItem |

### Aggregates

- **Product Aggregate:** Product + Inventory (always loaded together)
- **Cart Aggregate:** Cart + CartItem[] (transient, expires after 24h)
- **Order Aggregate:** Order + OrderItem[] + Payment (immutable after confirmation)

## Business Rules

### RULE-001: Inventory Reservation

When a customer adds a product to cart:
1. Check `availableQty - reservedQty > 0`
2. Increment `reservedQty` by requested quantity
3. If cart expires without checkout, release reservation (decrement `reservedQty`)
4. On order confirmation, decrement `availableQty` and `reservedQty`
5. NEVER allow `availableQty` to go negative

### RULE-002: Order Total Calculation

- Line item subtotal = quantity x unit price at time of order (NOT current price)
- Subtotal = sum of all line item subtotals
- Shipping = calculated by weight/distance (flat rate for MVP: $5.99)
- Tax = subtotal x tax rate (based on shipping address state)
- Discount = apply best matching promotion (only ONE promotion per order)
- Total = subtotal + shipping + tax - discount
- Total MUST be >= 0

### RULE-003: Payment Flow

1. Create Stripe PaymentIntent with order total
2. Return client_secret to frontend
3. Frontend completes payment (3D Secure if needed)
4. Webhook confirms payment: update order status to CONFIRMED
5. If payment fails: release inventory reservations, set order to PAYMENT_FAILED
6. NEVER confirm order without confirmed payment

### RULE-004: Price Consistency

- Cart stores `priceAtAdd` for each item (snapshot at add time)
- On checkout, compare `priceAtAdd` with current product price
- If price increased > 5%, warn customer and require re-confirmation
- If price decreased, use the lower price (benefit customer)

## Domain States and Transitions

```
Order States:
DRAFT -> PENDING_PAYMENT -> CONFIRMED -> PROCESSING -> SHIPPED -> DELIVERED
                         -> PAYMENT_FAILED (terminal)
         PENDING_PAYMENT -> CANCELLED (customer-initiated, within 5 min)
                            CONFIRMED -> CANCELLED (admin only, before PROCESSING)
                            DELIVERED -> RETURN_REQUESTED -> RETURNED (within 30 days)
```

```
Inventory States:
AVAILABLE (availableQty > 0, can be purchased)
LOW_STOCK (availableQty <= threshold, trigger alert)
OUT_OF_STOCK (availableQty == 0, hide "Add to Cart")
RESERVED (reservedQty > 0, held for active carts)
```

## Sensitive Data

| Data | Classification | Can Log? | Can Persist? | Can Return in API? |
|------|---------------|----------|--------------|-------------------|
| Email | PII | Masked | Yes (encrypted at rest) | Yes (to owner) |
| Full Name | PII | Yes | Yes | Yes (to owner) |
| Address | PII | City only | Yes | Yes (to owner) |
| Credit Card | PROHIBITED | NEVER | NEVER (Stripe handles) | Last 4 digits only |
| Password | SECRET | NEVER | Hashed (bcrypt) | NEVER |
| JWT Token | SECRET | NEVER | Redis only (sessions) | In auth header only |
| Order Total | Internal | Yes | Yes | Yes |

### Data Handling Rules
- Credit card data NEVER touches our servers (Stripe.js tokenization on frontend)
- Passwords hashed with bcrypt, minimum 12 rounds
- PII fields encrypted at rest in PostgreSQL (pgcrypto)
- Customer data deleted on account deletion (GDPR right to erasure)

## Domain-Specific Test Scenarios

### Unit Test Scenarios

| Scenario | Input | Expected Output | Rule |
|----------|-------|-----------------|------|
| Order total with tax | 2 items + CA address | subtotal + 7.25% tax | RULE-002 |
| Order with discount | 1 item + PROMO10 | 10% discount applied | RULE-002 |
| Negative total prevention | discount > subtotal | total = 0 | RULE-002 |
| Inventory reservation | add to cart, qty=2 | reservedQty += 2 | RULE-001 |
| Out of stock rejection | add to cart, stock=0 | error: out of stock | RULE-001 |
| Price change warning | priceAtAdd=10, current=12 | warn: price increased | RULE-004 |

### Integration Test Scenarios

| Scenario | Flow | Validates |
|----------|------|-----------|
| Happy path checkout | Browse -> Cart -> Order -> Pay -> Confirm | Full lifecycle |
| Payment failure | Cart -> Order -> Stripe fails -> Inventory released | RULE-003 |
| Cart expiration | Add to cart -> Wait 24h -> Inventory released | RULE-001 |
| Concurrent purchase | 2 users, 1 stock -> 1 succeeds, 1 fails | RULE-001 |

## Domain Anti-Patterns

- Allowing inventory to go negative (overselling)
- Storing raw credit card numbers anywhere in the system
- Confirming order before payment is verified
- Using current product price instead of price-at-add-time for order total
- Applying multiple exclusive promotions to the same order
- Allowing order cancellation after it has been shipped
- Cart items without price snapshot (leads to pricing disputes)
- Deleting orders (soft delete only; financial records must be preserved)

## Glossary

| Term | Definition |
|------|-----------|
| SKU | Stock Keeping Unit -- unique product variant identifier |
| PriceSnapshot | The price of an item captured at a specific moment (add-to-cart or checkout) |
| Reservation | Temporary hold on inventory for items in active carts |
| PaymentIntent | Stripe object representing a payment attempt |
| Idempotency Key | Client-generated key ensuring a request is processed at most once |
| Soft Delete | Marking a record as deleted without physically removing it from the database |
