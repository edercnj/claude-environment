# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Express — Middleware Patterns

## Middleware Execution Order

```
Request → cors → helmet → rateLimiter → logger → auth → routeHandler → errorHandler → Response
```

## Error Handling Middleware

Error middleware MUST be the last `app.use()` and MUST have 4 parameters:

```typescript
export function errorHandler(err: AppError, req: Request, res: Response, next: NextFunction): void {
  const status = err.statusCode ?? 500;
  const detail = status === 500 ? 'Internal server error' : err.message;

  if (status === 500) {
    logger.error({ err, path: req.path, method: req.method }, 'Unhandled error');
  }

  res.status(status).json({
    type: `/errors/${err.code ?? 'internal-error'}`,
    title: err.title ?? 'Error',
    status,
    detail,
    instance: req.originalUrl,
  });
}
```

## Authentication Middleware

```typescript
export function authMiddleware(config: AppConfig) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const apiKey = req.headers['x-api-key'];
    if (!apiKey || apiKey !== config.apiKey) {
      res.status(401).json({ type: '/errors/unauthorized', title: 'Unauthorized', status: 401 });
      return;
    }
    next();
  };
}
```

## Request Logging Middleware

```typescript
export function requestLogger(logger: Logger) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const start = Date.now();
    res.on('finish', () => {
      logger.info({
        method: req.method,
        path: req.path,
        status: res.statusCode,
        durationMs: Date.now() - start,
      });
    });
    next();
  };
}
```

## Rate Limiting Middleware

```typescript
import rateLimit from 'express-rate-limit';

export const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    res.status(429).json({
      type: '/errors/too-many-requests',
      title: 'Too Many Requests',
      status: 429,
      detail: 'Rate limit exceeded',
      instance: req.originalUrl,
    });
  },
});
```

## Middleware Registration

```typescript
const app = express();

app.use(cors());
app.use(helmet());
app.use(express.json({ limit: '1mb' }));
app.use(apiLimiter);
app.use(requestLogger(logger));
app.use('/api', authMiddleware(config));
app.use('/api/v1/merchants', merchantRouter);
app.use(errorHandler); // MUST be last
```

## Custom AppError Class

```typescript
export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string,
    public readonly code: string = 'unknown-error',
    public readonly title: string = 'Error',
  ) {
    super(message);
    this.name = 'AppError';
  }

  static notFound(resource: string, id: string): AppError {
    return new AppError(404, `${resource} '${id}' not found`, 'not-found', 'Not Found');
  }

  static conflict(message: string): AppError {
    return new AppError(409, message, 'conflict', 'Conflict');
  }
}
```

## Anti-Patterns

- Do NOT forget the `next()` call in non-terminal middleware
- Do NOT put error handling middleware before route handlers
- Do NOT use `app.use(express.json())` without a body size limit
- Do NOT log sensitive data (passwords, tokens) in request logger
- Do NOT throw unhandled exceptions in async middleware -- wrap with try/catch or use express-async-errors
