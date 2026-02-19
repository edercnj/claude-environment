# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# NestJS — Testing Patterns

## Unit Tests with Jest

```typescript
describe('MerchantService', () => {
  let service: MerchantService;
  let repository: jest.Mocked<MerchantRepository>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MerchantService,
        { provide: MerchantRepository, useValue: { findByMid: jest.fn(), create: jest.fn() } },
      ],
    }).compile();

    service = module.get(MerchantService);
    repository = module.get(MerchantRepository);
  });

  it('should return merchant when found by MID', async () => {
    const merchant = { id: 1, mid: '123', name: 'Store' };
    repository.findByMid.mockResolvedValue(merchant as any);

    const result = await service.findByMid('123');

    expect(result).toEqual(merchant);
    expect(repository.findByMid).toHaveBeenCalledWith('123');
  });

  it('should throw NotFoundException when merchant not found', async () => {
    repository.findByMid.mockResolvedValue(null);

    await expect(service.findByMid('unknown')).rejects.toThrow(NotFoundException);
  });
});
```

## E2E Tests with Supertest

```typescript
describe('MerchantController (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrismaService)
      .compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('POST /api/v1/merchants should create merchant', () => {
    return request(app.getHttpServer())
      .post('/api/v1/merchants')
      .send({ mid: '123456789012345', name: 'Test Store', document: '12345678000190', mcc: '5411' })
      .expect(201)
      .expect((res) => {
        expect(res.body.mid).toBe('123456789012345');
      });
  });

  it('POST /api/v1/merchants with invalid body should return 400', () => {
    return request(app.getHttpServer())
      .post('/api/v1/merchants')
      .send({ mid: '' })
      .expect(400);
  });
});
```

## Testing Guards and Interceptors

```typescript
describe('ApiKeyGuard', () => {
  let guard: ApiKeyGuard;

  beforeEach(() => {
    const config = { get: jest.fn().mockReturnValue('valid-key') } as any;
    guard = new ApiKeyGuard(config);
  });

  it('should allow request with valid API key', () => {
    const context = createMockExecutionContext({ headers: { 'x-api-key': 'valid-key' } });
    expect(guard.canActivate(context)).toBe(true);
  });

  it('should reject request with missing API key', () => {
    const context = createMockExecutionContext({ headers: {} });
    expect(guard.canActivate(context)).toBe(false);
  });
});
```

## Naming Convention

```
[methodUnderTest]_[scenario]_[expectedBehavior]
```

Examples:
- `findByMid_existingMid_returnsMerchant`
- `create_duplicateMid_throwsConflict`
- `list_emptyDatabase_returnsEmptyArray`

## Anti-Patterns

- Do NOT test private methods directly -- test via public API
- Do NOT use real database in unit tests -- mock the repository layer
- Do NOT skip `afterAll` cleanup -- always close the NestJS application
- Do NOT rely on test execution order -- each test must be independent
