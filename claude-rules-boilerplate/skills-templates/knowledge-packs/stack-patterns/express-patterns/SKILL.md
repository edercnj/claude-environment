---
name: express-patterns
description: "Express-specific patterns: middleware architecture, manual/tsyringe/inversify DI, Prisma/TypeORM/Knex data access, express.Router, centralized error handling, dotenv config, supertest testing. Internal reference for agents producing Express code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Express Patterns

## Purpose

Provides Express-specific implementation patterns that supplement the generic layer templates. Agents reference this pack when generating code for a TypeScript + Express project.

---

## 1. Middleware Architecture

### Middleware Chain Order

```
auth → validation → handler → error
```

### Application-Level Middleware

```typescript
const app = express();

// 1. Body parsing
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true }));

// 2. Security headers
app.use(helmet());

// 3. CORS
app.use(cors({ origin: process.env.CORS_ORIGIN, credentials: true }));

// 4. Request logging
app.use(requestLogger);

// 5. Routes
app.use('/api/v1/merchants', merchantRouter);
app.use('/api/v1/transactions', transactionRouter);

// 6. 404 handler (after all routes)
app.use(notFoundHandler);

// 7. Error handler (MUST be last, 4-arg signature)
app.use(errorHandler);
```

### Router-Level Middleware

```typescript
const merchantRouter = Router();

// Auth middleware for all routes in this router
merchantRouter.use(authenticate);

// Validation middleware per route
merchantRouter.post('/', validateBody(CreateMerchantSchema), merchantController.create);
merchantRouter.get('/', merchantController.list);
merchantRouter.get('/:id', validateParams(IdParamSchema), merchantController.findById);
merchantRouter.delete('/:id', authorize('admin'), merchantController.delete);
```

### Error Middleware (4-arg Signature)

```typescript
function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction,
): void {
  const problem = toProblemDetail(err, req.originalUrl);

  logger.error({ err, path: req.originalUrl, method: req.method }, 'Request error');

  res.status(problem.status).json(problem);
}
```

### Async Handler Wrapper

```typescript
function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<void>,
): RequestHandler {
  return (req, res, next) => {
    fn(req, res, next).catch(next);
  };
}

// Usage — errors are forwarded to error middleware
merchantRouter.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const merchant = await merchantService.findById(req.params.id);
    res.json(MerchantMapper.toResponse(merchant));
  }),
);
```

---

## 2. DI Pattern (manual or tsyringe/inversify)

### tsyringe

```typescript
import { injectable, inject, container } from 'tsyringe';

@injectable()
export class MerchantService {
  constructor(
    @inject('MerchantRepository') private readonly repository: MerchantRepository,
    @inject('Logger') private readonly logger: Logger,
  ) {}

  async findById(id: string): Promise<Merchant> {
    const merchant = await this.repository.findById(id);
    if (!merchant) {
      throw new NotFoundError(`Merchant ${id} not found`);
    }
    return merchant;
  }
}

// Registration
container.register('MerchantRepository', { useClass: PrismaMerchantRepository });
container.register('Logger', { useValue: pinoLogger });

// Resolution
const service = container.resolve(MerchantService);
```

### inversify

```typescript
import { injectable, inject, Container } from 'inversify';

const TYPES = {
  MerchantRepository: Symbol.for('MerchantRepository'),
  MerchantService: Symbol.for('MerchantService'),
  Logger: Symbol.for('Logger'),
} as const;

@injectable()
export class MerchantService {
  constructor(
    @inject(TYPES.MerchantRepository) private readonly repository: MerchantRepository,
    @inject(TYPES.Logger) private readonly logger: Logger,
  ) {}
}

// Binding
const container = new Container();
container.bind<MerchantRepository>(TYPES.MerchantRepository).to(PrismaMerchantRepository);
container.bind<MerchantService>(TYPES.MerchantService).to(MerchantService);
container.bind<Logger>(TYPES.Logger).toConstantValue(pinoLogger);
```

### Manual (Factory Functions)

```typescript
export function createMerchantService(deps: {
  repository: MerchantRepository;
  logger: Logger;
}): MerchantService {
  return new MerchantServiceImpl(deps.repository, deps.logger);
}

// Composition root
export function createApp(): Express {
  const prisma = new PrismaClient();
  const logger = pino();
  const repository = new PrismaMerchantRepository(prisma);
  const merchantService = createMerchantService({ repository, logger });
  const merchantController = new MerchantController(merchantService);

  const app = express();
  app.use('/api/v1/merchants', createMerchantRouter(merchantController));
  return app;
}
```

---

## 3. Data Access

### Prisma (Recommended)

```typescript
export class PrismaMerchantRepository implements MerchantRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<Merchant | null> {
    return this.prisma.merchant.findUnique({ where: { id } });
  }

  async findAll(page: number, limit: number): Promise<[Merchant[], number]> {
    const [merchants, total] = await this.prisma.$transaction([
      this.prisma.merchant.findMany({
        orderBy: { createdAt: 'desc' },
        skip: page * limit,
        take: limit,
      }),
      this.prisma.merchant.count(),
    ]);
    return [merchants, total];
  }

  async create(data: CreateMerchantData): Promise<Merchant> {
    return this.prisma.merchant.create({ data });
  }
}
```

### TypeORM

```typescript
export class TypeORMMerchantRepository implements MerchantRepository {
  constructor(private readonly repo: Repository<MerchantEntity>) {}

  async findById(id: string): Promise<MerchantEntity | null> {
    return this.repo.findOne({ where: { id } });
  }

  async findAll(page: number, limit: number): Promise<[MerchantEntity[], number]> {
    return this.repo.findAndCount({
      order: { createdAt: 'DESC' },
      skip: page * limit,
      take: limit,
    });
  }
}
```

### Knex (Query Builder)

```typescript
export class KnexMerchantRepository implements MerchantRepository {
  constructor(private readonly knex: Knex) {}

  async findById(id: string): Promise<Merchant | undefined> {
    return this.knex<Merchant>('merchants').where({ id }).first();
  }

  async findAll(page: number, limit: number): Promise<[Merchant[], number]> {
    const merchants = await this.knex<Merchant>('merchants')
      .orderBy('created_at', 'desc')
      .offset(page * limit)
      .limit(limit);

    const [{ count }] = await this.knex<Merchant>('merchants').count('* as count');
    return [merchants, Number(count)];
  }

  async create(data: CreateMerchantData): Promise<Merchant> {
    const [merchant] = await this.knex<Merchant>('merchants').insert(data).returning('*');
    return merchant;
  }
}
```

### Transaction Management

```typescript
// Prisma
await prisma.$transaction(async (tx) => {
  await tx.account.update({ where: { id: fromId }, data: { balance: { decrement: amount } } });
  await tx.account.update({ where: { id: toId }, data: { balance: { increment: amount } } });
});

// Knex
await knex.transaction(async (trx) => {
  await trx('accounts').where({ id: fromId }).decrement('balance', amount);
  await trx('accounts').where({ id: toId }).increment('balance', amount);
});
```

---

## 4. Web/HTTP

### Router Setup

```typescript
export function createMerchantRouter(controller: MerchantController): Router {
  const router = Router();

  router.get('/', asyncHandler(controller.list.bind(controller)));
  router.post('/', validateBody(CreateMerchantSchema), asyncHandler(controller.create.bind(controller)));
  router.get('/:id', validateParams(IdParamSchema), asyncHandler(controller.findById.bind(controller)));
  router.delete('/:id', validateParams(IdParamSchema), asyncHandler(controller.delete.bind(controller)));

  return router;
}
```

### Request Validation with Zod

```typescript
import { z } from 'zod';

export const CreateMerchantSchema = z.object({
  mid: z.string().min(1).max(15),
  name: z.string().min(1).max(100),
  category: z.enum(['RETAIL', 'FOOD', 'SERVICES']).optional(),
});

export type CreateMerchantDto = z.infer<typeof CreateMerchantSchema>;

function validateBody(schema: z.ZodSchema): RequestHandler {
  return (req: Request, _res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      throw new ValidationError(result.error.flatten().fieldErrors);
    }
    req.body = result.data;
    next();
  };
}
```

### Request Validation with express-validator

```typescript
import { body, validationResult } from 'express-validator';

export const createMerchantValidation = [
  body('mid').isString().notEmpty().isLength({ max: 15 }),
  body('name').isString().notEmpty().isLength({ max: 100 }),
  body('category').optional().isIn(['RETAIL', 'FOOD', 'SERVICES']),
];

function handleValidation(req: Request, _res: Response, next: NextFunction): void {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new ValidationError(errors.array());
  }
  next();
}
```

### Centralized Error Middleware (RFC 7807)

```typescript
interface ProblemDetail {
  type: string;
  title: string;
  status: number;
  detail: string;
  instance: string;
  errors?: Record<string, string[]>;
}

function toProblemDetail(err: Error, instance: string): ProblemDetail {
  if (err instanceof NotFoundError) {
    return { type: 'about:blank', title: 'Not Found', status: 404, detail: err.message, instance };
  }
  if (err instanceof ConflictError) {
    return { type: 'about:blank', title: 'Conflict', status: 409, detail: err.message, instance };
  }
  if (err instanceof ValidationError) {
    return { type: 'about:blank', title: 'Bad Request', status: 400, detail: 'Validation failed', instance, errors: err.fieldErrors };
  }
  return { type: 'about:blank', title: 'Internal Server Error', status: 500, detail: 'Internal processing error', instance };
}
```

### Response Helpers

```typescript
export class MerchantController {
  constructor(private readonly service: MerchantService) {}

  async list(req: Request, res: Response): Promise<void> {
    const page = parseInt(req.query.page as string) || 0;
    const limit = parseInt(req.query.limit as string) || 20;
    const [merchants, total] = await this.service.findAll(page, limit);
    res.json(PaginatedResponse.of(merchants.map(MerchantMapper.toResponse), page, limit, total));
  }

  async create(req: Request, res: Response): Promise<void> {
    const merchant = await this.service.create(req.body);
    res.status(201).json(MerchantMapper.toResponse(merchant));
  }

  async findById(req: Request, res: Response): Promise<void> {
    const merchant = await this.service.findById(req.params.id);
    res.json(MerchantMapper.toResponse(merchant));
  }

  async delete(req: Request, res: Response): Promise<void> {
    await this.service.deactivate(req.params.id);
    res.status(204).send();
  }
}
```

---

## 5. Configuration

### dotenv with Typed Config

```typescript
import 'dotenv/config';
import { z } from 'zod';

const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  CORS_ORIGIN: z.string().default('*'),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
});

export type AppConfig = z.infer<typeof EnvSchema>;

export function loadConfig(): AppConfig {
  const result = EnvSchema.safeParse(process.env);
  if (!result.success) {
    console.error('Invalid environment variables:', result.error.flatten().fieldErrors);
    process.exit(1);
  }
  return result.data;
}
```

### Config Package for Environment Files

```typescript
import config from 'config';

interface DatabaseConfig {
  url: string;
  poolSize: number;
}

// config/default.json → config/development.json → config/production.json
const dbConfig = config.get<DatabaseConfig>('database');
```

### Usage

```typescript
const appConfig = loadConfig();

const app = express();
app.listen(appConfig.PORT, () => {
  console.log(`Server running on port ${appConfig.PORT} [${appConfig.NODE_ENV}]`);
});
```

---

## 6. Testing

### HTTP Integration with Supertest

```typescript
describe('MerchantController', () => {
  let app: Express;
  let mockService: jest.Mocked<MerchantService>;

  beforeEach(() => {
    mockService = {
      findById: jest.fn(),
      findAll: jest.fn(),
      create: jest.fn(),
      deactivate: jest.fn(),
    } as any;

    app = createTestApp(mockService);
  });

  it('GET /api/v1/merchants/:id should return merchant', async () => {
    const merchant = { id: '1', mid: 'MID001', name: 'Test', status: 'ACTIVE' };
    mockService.findById.mockResolvedValue(merchant);

    const res = await request(app)
      .get('/api/v1/merchants/1')
      .expect(200);

    expect(res.body.mid).toBe('MID001');
    expect(mockService.findById).toHaveBeenCalledWith('1');
  });

  it('POST /api/v1/merchants should reject invalid body', async () => {
    const res = await request(app)
      .post('/api/v1/merchants')
      .send({ mid: '' })
      .expect(400);

    expect(res.body.title).toBe('Bad Request');
  });

  it('GET /api/v1/merchants/:id should return 404 for missing merchant', async () => {
    mockService.findById.mockRejectedValue(new NotFoundError('Merchant not found'));

    await request(app)
      .get('/api/v1/merchants/999')
      .expect(404);
  });
});
```

### Test Helper

```typescript
function createTestApp(service: MerchantService): Express {
  const app = express();
  app.use(express.json());
  const controller = new MerchantController(service);
  app.use('/api/v1/merchants', createMerchantRouter(controller));
  app.use(errorHandler);
  return app;
}
```

### Mock DI Container (tsyringe)

```typescript
beforeEach(() => {
  container.clearInstances();
  container.register('MerchantRepository', { useValue: mockRepository });
  container.register('Logger', { useValue: mockLogger });
});
```

---

## Anti-Patterns (Express-Specific)

- Callback-based async code (use `async/await` with `asyncHandler` wrapper)
- Business logic in route handlers (move to service layer)
- Missing async error handling (unhandled promise rejections crash the process)
- Global mutable state (use DI or request-scoped context)
- `console.log` in production (use structured logger like pino or winston)
- Missing `Content-Type` validation (always parse and validate request bodies)
- Not calling `next(err)` in error paths (swallows errors silently)
- Using `app.use(express.json())` without size limits (DoS vector)
- Relying on middleware ordering without explicit documentation
- Missing `helmet()` and `cors()` security middleware
