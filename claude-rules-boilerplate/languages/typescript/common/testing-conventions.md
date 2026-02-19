# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# TypeScript Testing Conventions

## Framework

- **Jest** or **Vitest** as test framework
- `expect()` assertions exclusively (no `assert`)
- Test files: `*.test.ts` or `*.spec.ts`

## Coverage Thresholds

| Metric          | Minimum |
| --------------- | ------- |
| Line Coverage   | >= 95%  |
| Branch Coverage | >= 90%  |

## Test Structure

```typescript
describe("MerchantService", () => {
    describe("createMerchant", () => {
        it("should create a merchant with valid payload", () => {
            // Arrange
            const request = createMerchantRequest({ mid: "MID001" });

            // Act
            const result = service.createMerchant(request);

            // Assert
            expect(result.mid).toBe("MID001");
            expect(result.status).toBe(MerchantStatus.Active);
        });

        it("should throw MerchantAlreadyExistsError for duplicate MID", () => {
            // Arrange
            const request = createMerchantRequest({ mid: "EXISTING" });
            repository.findByMid.mockResolvedValue(existingMerchant);

            // Act & Assert
            expect(() => service.createMerchant(request))
                .toThrow(MerchantAlreadyExistsError);
        });
    });
});
```

## Naming Convention

```typescript
// Pattern: describe('ClassName/FunctionName') + it('should ...')
describe("OrderProcessor", () => {
    it("should calculate total with tax", () => { ... });
    it("should reject negative quantities", () => { ... });
    it("should apply discount for premium merchants", () => { ... });
});
```

## Mocking

```typescript
// Jest
jest.mock("@/repositories/merchant-repository");
const mockRepository = jest.mocked(MerchantRepository);

// Vitest
vi.mock("@/repositories/merchant-repository");
const mockRepository = vi.mocked(MerchantRepository);

// CORRECT - mock external dependencies only
const mockHttpClient = {
    get: vi.fn(),
    post: vi.fn(),
};

// FORBIDDEN - mocking domain logic
vi.mock("@/domain/calculate-discount"); // Never mock pure domain functions
```

## Fixtures

```typescript
// CORRECT - factory functions for test data
export function createMerchant(overrides?: Partial<Merchant>): Merchant {
    return {
        id: "merchant-001",
        mid: "MID000000000001",
        name: "Test Store",
        document: "12345678000190",
        status: MerchantStatus.Active,
        createdAt: new Date("2026-01-01T00:00:00Z"),
        ...overrides,
    };
}

export function createMerchantRequest(overrides?: Partial<CreateMerchantRequest>): CreateMerchantRequest {
    return {
        mid: "MID000000000001",
        name: "Test Store",
        document: "12345678000190",
        mcc: "5411",
        ...overrides,
    };
}

// Usage in tests
const merchant = createMerchant({ status: MerchantStatus.Inactive });
```

## HTTP Testing

```typescript
import supertest from "supertest";
import { app } from "@/app";

describe("POST /api/v1/merchants", () => {
    it("should return 201 for valid payload", async () => {
        const response = await supertest(app)
            .post("/api/v1/merchants")
            .send(createMerchantRequest())
            .expect(201);

        expect(response.body.mid).toBeDefined();
        expect(response.body.status).toBe("Active");
    });

    it("should return 400 for invalid payload", async () => {
        const response = await supertest(app)
            .post("/api/v1/merchants")
            .send({ mid: "" })
            .expect(400);

        expect(response.body.type).toBe("/errors/validation-error");
    });

    it("should return 409 for duplicate MID", async () => {
        await supertest(app)
            .post("/api/v1/merchants")
            .send(createMerchantRequest({ mid: "DUPLICATE" }))
            .expect(201);

        await supertest(app)
            .post("/api/v1/merchants")
            .send(createMerchantRequest({ mid: "DUPLICATE" }))
            .expect(409);
    });
});
```

## Directory Structure

```
src/
├── services/
│   └── merchant-service.ts
├── repositories/
│   └── merchant-repository.ts
tests/
├── services/
│   └── merchant-service.test.ts
├── repositories/
│   └── merchant-repository.test.ts
├── fixtures/
│   ├── merchant.fixture.ts
│   └── order.fixture.ts
└── helpers/
    └── test-utils.ts
```

## Type Safety in Tests

```typescript
// FORBIDDEN - `any` in tests
const result = service.process({} as any);

// CORRECT - use proper fixtures
const result = service.process(createValidRequest());
```

## Async Testing

```typescript
it("should resolve with merchant data", async () => {
    const merchant = await service.findByMid("MID001");
    expect(merchant).toBeDefined();
    expect(merchant?.name).toBe("Test Store");
});

it("should reject with NotFoundError", async () => {
    await expect(service.findByMid("NONEXISTENT"))
        .rejects
        .toThrow(MerchantNotFoundError);
});
```

## Anti-Patterns

- `any` casts to bypass type errors in tests
- Tests that depend on execution order
- Shared mutable state between tests
- Testing implementation details instead of behavior
- `console.log` debugging left in test files
- Tests without assertions (empty `it` blocks)
