# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# NestJS — Configuration Patterns
> Extends: `core/10-infrastructure-principles.md`

## @nestjs/config Setup

```typescript
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: [`.env.${process.env.NODE_ENV}`, '.env'],
      validationSchema: Joi.object({
        NODE_ENV: Joi.string().valid('development', 'test', 'production').default('development'),
        PORT: Joi.number().default(3000),
        DATABASE_URL: Joi.string().required(),
        API_KEY: Joi.string().required(),
      }),
      validationOptions: { abortEarly: true },
    }),
  ],
})
export class AppModule {}
```

## Typed Configuration with Zod

```typescript
import { z } from 'zod';

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url().optional(),
  API_KEY: z.string().min(16),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
});

export type EnvConfig = z.infer<typeof envSchema>;
```

## ConfigService Usage

```typescript
@Injectable()
export class AppService {
  constructor(private readonly config: ConfigService<EnvConfig, true>) {}

  getDatabaseUrl(): string {
    return this.config.get('DATABASE_URL', { infer: true });
  }

  getPort(): number {
    return this.config.get('PORT', { infer: true });
  }
}
```

## Namespaced Configuration

```typescript
export default registerAs('database', () => ({
  url: process.env.DATABASE_URL,
  poolSize: parseInt(process.env.DB_POOL_SIZE ?? '10', 10),
  ssl: process.env.DB_SSL === 'true',
}));

// Usage
@Injectable()
export class DatabaseService {
  constructor(@Inject('database') private dbConfig: { url: string; poolSize: number; ssl: boolean }) {}
}
```

## Environment Files

| File              | Purpose                    | Committed to Git |
| ----------------- | -------------------------- | ---------------- |
| `.env`            | Default / local dev        | NO               |
| `.env.example`    | Template with dummy values | YES              |
| `.env.test`       | Test overrides             | YES (no secrets) |
| `.env.production` | Prod overrides             | NO               |

## Anti-Patterns

- Do NOT access `process.env` directly in services -- always use `ConfigService`
- Do NOT commit `.env` files with real secrets -- use `.env.example` as template
- Do NOT skip validation -- invalid config should crash at startup, not at runtime
- Do NOT use string literals for config keys -- define a typed schema or constants
