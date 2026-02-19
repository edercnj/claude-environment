# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Express — Testing Patterns

## Unit Tests with Jest

```typescript
describe('MerchantService', () => {
  let service: MerchantService;
  let repository: jest.Mocked<MerchantRepository>;

  beforeEach(() => {
    repository = { findById: jest.fn(), create: jest.fn(), findByMid: jest.fn() } as any;
    service = new MerchantService(repository);
  });

  it('should return merchant when found', async () => {
    repository.findById.mockResolvedValue({ id: 1, mid: '123', name: 'Store' } as any);

    const result = await service.findById(1);

    expect(result).toEqual(expect.objectContaining({ mid: '123' }));
  });

  it('should throw AppError when merchant not found', async () => {
    repository.findById.mockResolvedValue(null);

    await expect(service.findById(999)).rejects.toThrow(AppError);
    await expect(service.findById(999)).rejects.toMatchObject({ statusCode: 404 });
  });
});
```

## Integration Tests with Supertest

```typescript
import request from 'supertest';
import { createApp } from '../app';

describe('Merchant API', () => {
  let app: Express;

  beforeAll(async () => {
    app = await createApp({ databaseUrl: 'sqlite::memory:' });
  });

  it('POST /api/v1/merchants creates merchant', async () => {
    const res = await request(app)
      .post('/api/v1/merchants')
      .set('X-API-Key', 'test-key')
      .send({ mid: '123456789012345', name: 'Test', document: '12345678000190', mcc: '5411' })
      .expect(201);

    expect(res.body.mid).toBe('123456789012345');
  });

  it('POST /api/v1/merchants with invalid body returns 400', async () => {
    const res = await request(app)
      .post('/api/v1/merchants')
      .set('X-API-Key', 'test-key')
      .send({ mid: '' })
      .expect(400);

    expect(res.body.type).toBe('/errors/validation-error');
  });

  it('GET /api/v1/merchants/:id returns 404 for unknown', async () => {
    await request(app)
      .get('/api/v1/merchants/99999')
      .set('X-API-Key', 'test-key')
      .expect(404);
  });
});
```

## Testing Middleware

```typescript
describe('authMiddleware', () => {
  const middleware = authMiddleware({ apiKey: 'secret' } as AppConfig);

  it('should call next() with valid key', () => {
    const req = { headers: { 'x-api-key': 'secret' } } as any;
    const res = { status: jest.fn().mockReturnThis(), json: jest.fn() } as any;
    const next = jest.fn();

    middleware(req, res, next);

    expect(next).toHaveBeenCalled();
  });

  it('should return 401 with missing key', () => {
    const req = { headers: {} } as any;
    const res = { status: jest.fn().mockReturnThis(), json: jest.fn() } as any;
    const next = jest.fn();

    middleware(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });
});
```

## Mocking with jest.mock

```typescript
jest.mock('../repositories/merchant.repository');

const MockedRepo = MerchantRepository as jest.MockedClass<typeof MerchantRepository>;

beforeEach(() => {
  MockedRepo.mockClear();
});
```

## Naming Convention

```
[methodUnderTest]_[scenario]_[expectedBehavior]
```

## Anti-Patterns

- Do NOT test Express internals -- test your handlers and middleware
- Do NOT use real databases in unit tests -- mock repositories
- Do NOT skip error path testing -- validate all error responses
- Do NOT forget to close database connections in afterAll
