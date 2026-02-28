# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# TypeScript Coding Conventions

## Strict Mode

- `"strict": true` in `tsconfig.json` is mandatory
- ESLint with `@typescript-eslint` plugin enforced
- Prettier for formatting (integrated with ESLint)

## Naming Conventions

| Element         | Convention     | Example                    |
| --------------- | -------------- | -------------------------- |
| Interface       | PascalCase     | `MerchantService`          |
| Type Alias      | PascalCase     | `TransactionResult`        |
| Class           | PascalCase     | `OrderProcessor`           |
| Enum            | PascalCase     | `OrderStatus`              |
| Enum Member     | PascalCase     | `OrderStatus.Pending`      |
| Function        | camelCase      | `processOrder()`           |
| Variable        | camelCase      | `merchantName`             |
| Constant        | UPPER_SNAKE    | `MAX_RETRY_COUNT`          |
| File (module)   | kebab-case     | `order-processor.ts`       |
| File (component)| PascalCase     | `OrderList.tsx`            |

## Type Safety

```typescript
// FORBIDDEN - never use `any`
function process(data: any): any { ... }

// CORRECT - use `unknown` when type is unclear
function process(data: unknown): Result {
    if (isValidPayload(data)) {
        return handle(data);
    }
    throw new ValidationError("Invalid payload");
}
```

## Interfaces vs Types

```typescript
// CORRECT - interface for object shapes (extendable)
interface Merchant {
    id: string;
    name: string;
    status: MerchantStatus;
}

interface PremiumMerchant extends Merchant {
    tier: string;
}

// CORRECT - type for unions, intersections, mapped types
type Result = Success | Failure;
type ReadonlyMerchant = Readonly<Merchant>;
```

## Functions

```typescript
// CORRECT - arrow functions for callbacks
const filtered = items.filter((item) => item.active);

// CORRECT - named functions for exports
export function calculateDiscount(price: number, rate: number): number {
    return price * rate;
}

// CORRECT - destructuring for parameters
export function createOrder({ merchantId, amount, currency }: CreateOrderParams): Order {
    return { merchantId, amount, currency, status: OrderStatus.Pending };
}
```

## Null Handling

```typescript
// CORRECT - optional chaining + nullish coalescing
const city = merchant?.address?.city ?? "Unknown";

// CORRECT - explicit null checks
function findMerchant(id: string): Merchant | undefined {
    return merchants.get(id);
}
```

## Exports

```typescript
// FORBIDDEN - default exports
export default class OrderService { ... }

// CORRECT - named exports only
export class OrderService { ... }
export function createOrder(params: CreateOrderParams): Order { ... }
export interface OrderRepository { ... }
```

## Error Handling

```typescript
// CORRECT - custom Error classes with context
export class MerchantNotFoundError extends Error {
    constructor(public readonly merchantId: string) {
        super(`Merchant not found: ${merchantId}`);
        this.name = "MerchantNotFoundError";
    }
}

// FORBIDDEN - throwing plain strings
throw "Something went wrong";
```

## Size Limits

- Max **25 lines** per function
- Max **250 lines** per file
- Max **4 parameters** per function (use object destructuring for more)

## Import Ordering

```typescript
// 1. Node builtins
import { readFile } from "node:fs/promises";

// 2. External packages
import { z } from "zod";
import express from "express";

// 3. Internal modules (absolute paths)
import { MerchantService } from "@/services/merchant-service";

// 4. Relative imports
import { createMerchantSchema } from "./schemas";
```

## Mapper Pattern

```typescript
// CORRECT - pure functions in dedicated mapper files
// merchant.mapper.ts
export function toMerchantResponse(merchant: Merchant): MerchantResponse {
    return {
        id: merchant.id,
        name: merchant.name,
        documentMasked: maskDocument(merchant.document),
        status: merchant.status,
        createdAt: merchant.createdAt.toISOString(),
    };
}

export function toDomain(request: CreateMerchantRequest): Merchant {
    return {
        mid: request.mid,
        name: request.name,
        document: request.document,
        status: MerchantStatus.Active,
    };
}
```

## Anti-Patterns (FORBIDDEN)

- `any` type anywhere in codebase
- Default exports
- `var` keyword (use `const` or `let`)
- String concatenation with `+` (use template literals)
- Nested ternaries deeper than 1 level
- `console.log` for application logging (use structured logger)
- Mutable global state
- `@ts-ignore` without explanation comment
