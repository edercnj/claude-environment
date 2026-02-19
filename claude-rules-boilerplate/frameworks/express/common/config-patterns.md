# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Express — Configuration Patterns
> Extends: `core/10-infrastructure-principles.md`

## dotenv Setup

```typescript
import 'dotenv/config'; // Load .env at the very top of entry point
```

## Typed Config Module with Zod

```typescript
import { z } from 'zod';

const configSchema = z.object({
  nodeEnv: z.enum(['development', 'test', 'production']).default('development'),
  port: z.coerce.number().default(3000),
  databaseUrl: z.string().url(),
  apiKey: z.string().min(16),
  logLevel: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  cors: z.object({
    origin: z.string().default('*'),
    credentials: z.boolean().default(false),
  }),
  rateLimit: z.object({
    windowMs: z.coerce.number().default(60000),
    max: z.coerce.number().default(100),
  }),
});

export type AppConfig = z.infer<typeof configSchema>;

export function loadConfig(): AppConfig {
  const result = configSchema.safeParse({
    nodeEnv: process.env.NODE_ENV,
    port: process.env.PORT,
    databaseUrl: process.env.DATABASE_URL,
    apiKey: process.env.API_KEY,
    logLevel: process.env.LOG_LEVEL,
    cors: {
      origin: process.env.CORS_ORIGIN,
      credentials: process.env.CORS_CREDENTIALS === 'true',
    },
    rateLimit: {
      windowMs: process.env.RATE_LIMIT_WINDOW_MS,
      max: process.env.RATE_LIMIT_MAX,
    },
  });

  if (!result.success) {
    console.error('Invalid configuration:', result.error.format());
    process.exit(1);
  }

  return result.data;
}
```

## Environment-Based Config

| Variable         | Development      | Test             | Production       |
| ---------------- | ---------------- | ---------------- | ---------------- |
| NODE_ENV         | development      | test             | production       |
| PORT             | 3000             | 0 (random)       | 3000             |
| DATABASE_URL     | localhost:5432   | sqlite::memory:  | from secret      |
| LOG_LEVEL        | debug            | warn             | info             |
| API_KEY          | dev-key-1234     | test-key-1234    | from secret      |

## Usage in Application

```typescript
const config = loadConfig();

const app = express();
app.listen(config.port, () => {
  console.log(`Server running on port ${config.port} [${config.nodeEnv}]`);
});
```

## Environment Files

| File              | Purpose                    | Git |
| ----------------- | -------------------------- | --- |
| `.env`            | Local development defaults | NO  |
| `.env.example`    | Template                   | YES |
| `.env.test`       | Test overrides             | YES |

## Anti-Patterns

- Do NOT scatter `process.env` calls throughout the codebase -- centralize in config module
- Do NOT skip validation -- crash fast on missing required config
- Do NOT commit `.env` with real secrets
- Do NOT use type assertions (`as string`) on env vars -- use Zod coercion
