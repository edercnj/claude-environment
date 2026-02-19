---
name: nestjs-patterns
description: "NestJS-specific patterns: DI with @Injectable, Prisma/TypeORM data access, Controllers with Guards/Interceptors/Pipes, @nestjs/config, Testing module, Docker build. Internal reference for agents producing NestJS code."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: NestJS Patterns

## Purpose

Provides NestJS-specific implementation patterns that supplement the generic layer templates. Agents reference this pack when generating code for a TypeScript + NestJS project.

---

## 1. Dependency Injection

### Constructor Injection (Mandatory)

```typescript
@Injectable()
export class TransactionService {
  constructor(
    private readonly transactionRepository: TransactionRepository,
    private readonly authorizationEngine: AuthorizationEngine,
  ) {}
}
```

### Module-Scoped Providers

```typescript
@Module({
  imports: [PrismaModule],
  controllers: [MerchantController],
  providers: [MerchantService, MerchantRepository],
  exports: [MerchantService],
})
export class MerchantModule {}
```

### Custom Providers

```typescript
@Module({
  providers: [
    // useClass — swap implementation
    { provide: PaymentGateway, useClass: StripeGateway },

    // useValue — static config or mock
    { provide: 'APP_CONFIG', useValue: { retries: 3, timeout: 5000 } },

    // useFactory — async or conditional creation
    {
      provide: 'CACHE_CLIENT',
      useFactory: async (config: ConfigService) => {
        const client = new Redis(config.get('REDIS_URL'));
        await client.ping();
        return client;
      },
      inject: [ConfigService],
    },

    // useExisting — alias an existing provider
    { provide: 'AuditLogger', useExisting: LoggerService },
  ],
})
export class PaymentModule {}
```

### Scope Selection

| Scope | When | Lifecycle |
|-------|------|-----------|
| `DEFAULT` (singleton) | Stateless services, repositories | One instance shared across app |
| `REQUEST` | Per-request state, tenant context | New instance per incoming request |
| `TRANSIENT` | Lightweight, non-shared utilities | New instance per injection point |

```typescript
@Injectable({ scope: Scope.REQUEST })
export class TenantContext {
  tenantId: string;
}
```

### FORBIDDEN

- Circular dependencies without `forwardRef(() => ServiceClass)`
- Direct `new ServiceClass()` instantiation of injectable services
- Field injection or property assignment instead of constructor injection

---

## 2. Data Access (Prisma / TypeORM)

### Prisma Path

#### PrismaService

```typescript
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
```

#### Repository Pattern (Prisma)

```typescript
@Injectable()
export class MerchantRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findById(id: string): Promise<Merchant | null> {
    return this.prisma.merchant.findUnique({ where: { id } });
  }

  async findByStatus(status: string, page: number, limit: number): Promise<Merchant[]> {
    return this.prisma.merchant.findMany({
      where: { status },
      orderBy: { createdAt: 'desc' },
      skip: page * limit,
      take: limit,
    });
  }

  async create(data: CreateMerchantData): Promise<Merchant> {
    return this.prisma.merchant.create({ data });
  }

  async countByStatus(status: string): Promise<number> {
    return this.prisma.merchant.count({ where: { status } });
  }
}
```

#### Transactions (Prisma)

```typescript
async transferFunds(fromId: string, toId: string, amount: number): Promise<void> {
  await this.prisma.$transaction(async (tx) => {
    const sender = await tx.account.update({
      where: { id: fromId },
      data: { balance: { decrement: amount } },
    });
    if (sender.balance < 0) {
      throw new BadRequestException('Insufficient funds');
    }
    await tx.account.update({
      where: { id: toId },
      data: { balance: { increment: amount } },
    });
  });
}
```

#### Migrations (Prisma)

```bash
# Create migration
npx prisma migrate dev --name add_merchant_table

# Apply in production
npx prisma migrate deploy

# Generate client
npx prisma generate
```

### TypeORM Path

#### Entity

```typescript
@Entity('merchants')
export class MerchantEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, length: 15 })
  mid: string;

  @Column({ length: 100 })
  name: string;

  @Column({ default: 'ACTIVE', length: 20 })
  status: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => TransactionEntity, (tx) => tx.merchant)
  transactions: TransactionEntity[];
}
```

#### Repository (TypeORM)

```typescript
@Injectable()
export class MerchantRepository {
  constructor(
    @InjectRepository(MerchantEntity)
    private readonly repo: Repository<MerchantEntity>,
  ) {}

  async findByMid(mid: string): Promise<MerchantEntity | null> {
    return this.repo.findOne({ where: { mid } });
  }

  async findByStatus(status: string, page: number, limit: number): Promise<MerchantEntity[]> {
    return this.repo.find({
      where: { status },
      order: { createdAt: 'DESC' },
      skip: page * limit,
      take: limit,
    });
  }

  async createMerchant(data: Partial<MerchantEntity>): Promise<MerchantEntity> {
    const entity = this.repo.create(data);
    return this.repo.save(entity);
  }
}
```

#### QueryBuilder (TypeORM)

```typescript
async searchMerchants(query: string, status?: string): Promise<MerchantEntity[]> {
  const qb = this.repo
    .createQueryBuilder('merchant')
    .where('merchant.name ILIKE :query', { query: `%${query}%` });

  if (status) {
    qb.andWhere('merchant.status = :status', { status });
  }

  return qb.orderBy('merchant.createdAt', 'DESC').limit(50).getMany();
}
```

#### Migrations (TypeORM)

```bash
# Generate migration from entity changes
npx typeorm migration:generate src/migrations/AddMerchantTable -d src/data-source.ts

# Run migrations
npx typeorm migration:run -d src/data-source.ts
```

---

## 3. Web/HTTP (Express/Fastify)

### Controller

```typescript
@Controller('api/v1/merchants')
export class MerchantController {
  constructor(private readonly merchantService: MerchantService) {}

  @Get()
  async list(
    @Query('page', new DefaultValuePipe(0), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ): Promise<PaginatedResponse<MerchantResponseDto>> {
    const [merchants, total] = await this.merchantService.findAll(page, limit);
    return PaginatedResponse.of(
      merchants.map(MerchantMapper.toResponse),
      page,
      limit,
      total,
    );
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(
    @Body() dto: CreateMerchantDto,
  ): Promise<MerchantResponseDto> {
    const merchant = await this.merchantService.create(dto);
    return MerchantMapper.toResponse(merchant);
  }

  @Get(':id')
  async findById(@Param('id', ParseUUIDPipe) id: string): Promise<MerchantResponseDto> {
    const merchant = await this.merchantService.findById(id);
    return MerchantMapper.toResponse(merchant);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(@Param('id', ParseUUIDPipe) id: string): Promise<void> {
    await this.merchantService.deactivate(id);
  }
}
```

### DTOs with class-validator / class-transformer

```typescript
export class CreateMerchantDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(15)
  mid: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsEnum(MerchantCategory)
  category?: MerchantCategory;
}

export class MerchantResponseDto {
  id: string;
  mid: string;
  name: string;
  status: string;
  createdAt: Date;
}
```

### Global ValidationPipe

```typescript
async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );
  await app.listen(3000);
}
```

### Guards

```typescript
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext): boolean | Promise<boolean> {
    return super.canActivate(context);
  }
}

// Usage on controller or method
@UseGuards(JwtAuthGuard)
@Controller('api/v1/merchants')
export class MerchantController {}
```

### Interceptors

```typescript
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger(LoggingInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest();
    const { method, url } = request;
    const start = Date.now();

    return next.handle().pipe(
      tap(() => {
        const elapsed = Date.now() - start;
        this.logger.log(`${method} ${url} ${elapsed}ms`);
      }),
    );
  }
}
```

### Exception Filter (RFC 7807)

```typescript
@Catch()
export class ProblemDetailFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const problem = this.toProblemDetail(exception, request.url);

    response.status(problem.status).json(problem);
  }

  private toProblemDetail(exception: unknown, instance: string): ProblemDetail {
    if (exception instanceof NotFoundException) {
      return { type: 'about:blank', title: 'Not Found', status: 404, detail: exception.message, instance };
    }
    if (exception instanceof ConflictException) {
      return { type: 'about:blank', title: 'Conflict', status: 409, detail: exception.message, instance };
    }
    return { type: 'about:blank', title: 'Internal Server Error', status: 500, detail: 'Internal processing error', instance };
  }
}
```

---

## 4. Configuration

### ConfigModule Setup

```typescript
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: [`.env.${process.env.NODE_ENV}`, '.env'],
      load: [appConfig, databaseConfig],
      validationSchema: Joi.object({
        NODE_ENV: Joi.string().valid('development', 'production', 'test').default('development'),
        PORT: Joi.number().default(3000),
        DATABASE_URL: Joi.string().required(),
        JWT_SECRET: Joi.string().required(),
      }),
    }),
  ],
})
export class AppModule {}
```

### Typed Config with registerAs

```typescript
// config/app.config.ts
export const appConfig = registerAs('app', () => ({
  port: parseInt(process.env.PORT ?? '3000', 10),
  environment: process.env.NODE_ENV ?? 'development',
  cors: {
    origin: process.env.CORS_ORIGIN ?? '*',
  },
}));

// config/database.config.ts
export const databaseConfig = registerAs('database', () => ({
  url: process.env.DATABASE_URL,
  poolSize: parseInt(process.env.DB_POOL_SIZE ?? '10', 10),
}));
```

### Usage in Services

```typescript
@Injectable()
export class AppService {
  constructor(
    @Inject(appConfig.KEY)
    private readonly config: ConfigType<typeof appConfig>,
  ) {}

  getPort(): number {
    return this.config.port;
  }
}
```

### Profile-Based .env Files

| File | Purpose |
|------|---------|
| `.env` | Base shared defaults |
| `.env.development` | Local dev overrides |
| `.env.test` | Test overrides (in-memory DB, mock keys) |
| `.env.production` | Production overrides (real secrets via vault) |

---

## 5. Testing

### Unit Test with Testing Module

```typescript
describe('MerchantService', () => {
  let service: MerchantService;
  let repository: jest.Mocked<MerchantRepository>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MerchantService,
        {
          provide: MerchantRepository,
          useValue: {
            findById: jest.fn(),
            create: jest.fn(),
            findByStatus: jest.fn(),
            countByStatus: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<MerchantService>(MerchantService);
    repository = module.get(MerchantRepository);
  });

  it('should return merchant by id', async () => {
    const merchant = { id: '1', mid: 'MID001', name: 'Test', status: 'ACTIVE' };
    repository.findById.mockResolvedValue(merchant as any);

    const result = await service.findById('1');

    expect(result).toEqual(merchant);
    expect(repository.findById).toHaveBeenCalledWith('1');
  });

  it('should throw NotFoundException when merchant not found', async () => {
    repository.findById.mockResolvedValue(null);

    await expect(service.findById('999')).rejects.toThrow(NotFoundException);
  });
});
```

### Override Providers

```typescript
const module: TestingModule = await Test.createTestingModule({
  imports: [MerchantModule],
})
  .overrideProvider(PrismaService)
  .useValue(mockPrismaService)
  .overrideGuard(JwtAuthGuard)
  .useValue({ canActivate: () => true })
  .compile();
```

### E2E Test with Supertest

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
      .send({ mid: 'MID001', name: 'Test Merchant' })
      .expect(201)
      .expect((res) => {
        expect(res.body).toHaveProperty('id');
        expect(res.body.mid).toBe('MID001');
      });
  });

  it('POST /api/v1/merchants should reject invalid body', () => {
    return request(app.getHttpServer())
      .post('/api/v1/merchants')
      .send({ mid: '' })
      .expect(400);
  });
});
```

---

## 6. Build & Deployment

### Build Commands

```bash
# Development with hot reload
npm run start:dev

# Production build
nest build

# Production start
node dist/main.js
```

### tsconfig.build.json

```json
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "./dist",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true
  },
  "exclude": ["node_modules", "dist", "test", "**/*.spec.ts"]
}
```

### Docker Multi-Stage Build

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
RUN npm prune --production

# Stage 2: Production
FROM node:20-slim
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

USER node
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

---

## Anti-Patterns (NestJS-Specific)

- Direct `new ServiceClass()` instantiation of injectable services (bypasses DI)
- Circular module dependencies without `forwardRef(() => ModuleClass)`
- Business logic in controllers (move to service layer)
- Raw SQL queries in controllers or services (use repository pattern)
- Mixing Prisma and TypeORM in the same project (pick one ORM)
- Using `any` type in DTOs (defeats validation and type safety)
- Missing `whitelist: true` in ValidationPipe (allows extra properties)
- Synchronous blocking operations in async handlers
- Global mutable state instead of REQUEST-scoped providers
