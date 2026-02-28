# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# TypeScript Libraries

## Mandatory

| Library   | Purpose          | Justification                                      |
| --------- | ---------------- | -------------------------------------------------- |
| zod       | Validation       | Runtime type validation, schema inference           |
| pino      | Logging          | Structured JSON logging, high performance           |
| vitest    | Testing          | Fast, ESM-native, Jest-compatible API               |

### Zod (Validation)

```typescript
import { z } from "zod";

const CreateMerchantSchema = z.object({
    mid: z.string().min(1).max(15),
    name: z.string().min(1).max(100),
    document: z.string().regex(/^\d{11,14}$/),
    mcc: z.string().length(4).regex(/^\d{4}$/),
});

type CreateMerchantRequest = z.infer<typeof CreateMerchantSchema>;

// Usage
const parsed = CreateMerchantSchema.parse(requestBody);
```

### Pino (Logging)

```typescript
import pino from "pino";

const logger = pino({
    level: process.env.LOG_LEVEL ?? "info",
    transport: process.env.NODE_ENV === "development"
        ? { target: "pino-pretty" }
        : undefined,
});

logger.info({ merchantId, action: "created" }, "Merchant created");
```

## Recommended

| Library           | Purpose             | When to Use                          |
| ----------------- | ------------------- | ------------------------------------ |
| class-validator   | Decorator validation| NestJS projects                      |
| class-transformer | DTO transformation  | NestJS projects                      |
| helmet            | Security headers    | Express/Fastify applications         |
| cors              | CORS middleware      | REST APIs with browser clients       |
| date-fns          | Date manipulation   | Date operations beyond native Date   |
| axios             | HTTP client         | External API calls with interceptors |
| prisma            | ORM                 | Database access with type safety     |
| drizzle-orm       | ORM                 | Lightweight SQL-first ORM            |

### Date-fns Example

```typescript
import { format, addDays, differenceInDays } from "date-fns";

const dueDate = addDays(new Date(), 30);
const formatted = format(dueDate, "yyyy-MM-dd");
```

## Prohibited

| Library    | Reason                                      | Alternative              |
| ---------- | ------------------------------------------- | ------------------------ |
| moment.js  | Deprecated, mutable API, large bundle       | date-fns or dayjs        |
| lodash     | Native JS covers most use cases             | Native Array/Object APIs |
| request    | Deprecated                                  | fetch (native) or axios  |
| express     | Legacy callback patterns for new projects   | Fastify or Hono          |
| winston    | Heavier, slower than pino                   | pino                     |

### Native Alternatives to Lodash

```typescript
// FORBIDDEN: lodash
import { map, filter, find } from "lodash";

// CORRECT: native JS
const names = merchants.map((m) => m.name);
const active = merchants.filter((m) => m.status === "Active");
const found = merchants.find((m) => m.mid === targetMid);
const unique = [...new Set(items)];
const grouped = Object.groupBy(items, (item) => item.category);
const cloned = structuredClone(original);
```

## Package Manager

- **pnpm** recommended (faster, disk-efficient)
- Lock file (`pnpm-lock.yaml`) MUST be committed
- Exact versions in `package.json` (no `^` or `~`)

## Security

- Run `pnpm audit` regularly
- No packages with known critical vulnerabilities
- Pin transitive dependencies via lock file
