# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# NestJS — Dependency Injection Patterns

## Module System

Every feature MUST be encapsulated in a module:

```typescript
@Module({
  imports: [PrismaModule, ConfigModule],
  controllers: [MerchantController],
  providers: [MerchantService, MerchantRepository],
  exports: [MerchantService],
})
export class MerchantModule {}
```

| Element    | Purpose                                    |
| ---------- | ------------------------------------------ |
| imports    | Modules this module depends on             |
| controllers| Request handlers (REST endpoints)           |
| providers  | Injectable services, repositories, guards  |
| exports    | Providers available to importing modules   |

## Injectable Services

```typescript
// CORRECT -- constructor injection via @Injectable
@Injectable()
export class MerchantService {
  constructor(
    private readonly merchantRepo: MerchantRepository,
    private readonly configService: ConfigService,
  ) {}

  async findByMid(mid: string): Promise<Merchant | null> {
    return this.merchantRepo.findByMid(mid);
  }
}
```

## Custom Providers

### Value Provider
```typescript
{ provide: 'API_VERSION', useValue: 'v1' }
```

### Factory Provider
```typescript
{
  provide: 'CACHE_CLIENT',
  useFactory: (config: ConfigService) => {
    return new Redis(config.get('REDIS_URL'));
  },
  inject: [ConfigService],
}
```

### Class Provider
```typescript
{ provide: LoggerService, useClass: PinoLoggerService }
```

## Injection Scopes

| Scope       | Lifetime                     | Use Case                  |
| ----------- | ---------------------------- | ------------------------- |
| DEFAULT     | Singleton (shared instance)  | Stateless services        |
| REQUEST     | Per-request instance         | Request-scoped context    |
| TRANSIENT   | New instance per injection   | Stateful helpers          |

```typescript
@Injectable({ scope: Scope.REQUEST })
export class RequestContextService {
  private traceId: string;
}
```

## Anti-Patterns

- Do NOT use `@Inject()` on properties without constructor -- always prefer constructor injection
- Do NOT create circular dependencies between modules -- use `forwardRef()`
- Do NOT register providers globally unless truly needed (`@Global()`)
- Do NOT bypass DI by instantiating services with `new` in application code
