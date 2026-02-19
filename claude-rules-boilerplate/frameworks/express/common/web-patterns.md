# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Express — Web Patterns (Routing, Validation, Responses)
> Extends: `core/06-api-design-principles.md`

## Router Pattern

Separate routes into domain-specific routers:

```typescript
// routes/merchant.router.ts
const router = Router();

router.get('/', merchantController.list);
router.post('/', validate(createMerchantSchema), merchantController.create);
router.get('/:id', merchantController.findById);
router.put('/:id', validate(updateMerchantSchema), merchantController.update);
router.delete('/:id', merchantController.remove);

export { router as merchantRouter };
```

## Controller Pattern

```typescript
export class MerchantController {
  constructor(private readonly service: MerchantService) {}

  list = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const page = parseInt(req.query.page as string) || 0;
      const limit = parseInt(req.query.limit as string) || 20;
      const result = await this.service.list(page, limit);
      res.json(result);
    } catch (err) {
      next(err);
    }
  };

  create = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const merchant = await this.service.create(req.body);
      res.status(201).json(merchant);
    } catch (err) {
      next(err);
    }
  };

  findById = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const merchant = await this.service.findById(parseInt(req.params.id));
      res.json(merchant);
    } catch (err) {
      next(err);
    }
  };
}
```

## Validation with Zod

```typescript
import { z } from 'zod';

export const createMerchantSchema = z.object({
  body: z.object({
    mid: z.string().min(1).max(15),
    name: z.string().min(1).max(100),
    document: z.string().regex(/^\d{11,14}$/),
    mcc: z.string().length(4).regex(/^\d{4}$/),
  }),
});

export function validate(schema: z.ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse({ body: req.body, query: req.query, params: req.params });
    if (!result.success) {
      const violations = result.error.issues.reduce((acc, issue) => {
        const field = issue.path.slice(1).join('.');
        acc[field] = acc[field] ?? [];
        acc[field].push(issue.message);
        return acc;
      }, {} as Record<string, string[]>);
      res.status(400).json({
        type: '/errors/validation-error',
        title: 'Validation Error',
        status: 400,
        detail: 'Request validation failed',
        extensions: { violations },
      });
      return;
    }
    next();
  };
}
```

## Paginated Response

```typescript
interface PaginatedResponse<T> {
  data: T[];
  pagination: { page: number; limit: number; total: number; totalPages: number };
}

function paginate<T>(data: T[], page: number, limit: number, total: number): PaginatedResponse<T> {
  return { data, pagination: { page, limit, total, totalPages: Math.ceil(total / limit) } };
}
```

## Project Structure

```
src/
├── routes/          # Express routers
├── controllers/     # Request handlers
├── services/        # Business logic
├── repositories/    # Data access
├── middleware/       # Express middleware
├── schemas/         # Zod validation schemas
├── errors/          # Custom error classes
└── config/          # Configuration
```

## Anti-Patterns

- Do NOT use `req.body` without validation -- always validate with Zod or Joi
- Do NOT put business logic in route handlers -- delegate to services
- Do NOT forget `try/catch` or `next(err)` in async handlers
- Do NOT return raw database entities -- map to response DTOs
