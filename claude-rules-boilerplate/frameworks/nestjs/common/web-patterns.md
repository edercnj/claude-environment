# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# NestJS — Web Patterns (Controllers, DTOs, Pipes, Guards)

## Controller Pattern

```typescript
@Controller('api/v1/merchants')
export class MerchantController {
  constructor(private readonly merchantService: MerchantService) {}

  @Get()
  async list(
    @Query('page', new DefaultValuePipe(0), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ): Promise<PaginatedResponse<MerchantResponse>> {
    return this.merchantService.list(page, limit);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body(ValidationPipe) dto: CreateMerchantDto): Promise<MerchantResponse> {
    return this.merchantService.create(dto);
  }

  @Get(':id')
  async findById(@Param('id', ParseIntPipe) id: number): Promise<MerchantResponse> {
    return this.merchantService.findById(id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Param('id', ParseIntPipe) id: number): Promise<void> {
    await this.merchantService.deactivate(id);
  }
}
```

## DTOs with class-validator

```typescript
export class CreateMerchantDto {
  @IsNotEmpty()
  @MaxLength(15)
  mid: string;

  @IsNotEmpty()
  @MaxLength(100)
  name: string;

  @IsNotEmpty()
  @Matches(/^\d{11,14}$/)
  document: string;

  @IsNotEmpty()
  @Length(4, 4)
  mcc: string;
}
```

## Exception Filters

```typescript
@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const status = exception.getStatus();

    response.status(status).json({
      type: `/errors/${this.slugify(exception.message)}`,
      title: exception.message,
      status,
      detail: exception.getResponse()?.['message'] ?? exception.message,
      instance: ctx.getRequest<Request>().url,
    });
  }
}
```

## Guards

```typescript
@Injectable()
export class ApiKeyGuard implements CanActivate {
  constructor(private readonly configService: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const apiKey = request.headers['x-api-key'];
    return apiKey === this.configService.get('API_KEY');
  }
}
```

## Interceptors

```typescript
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger(LoggingInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const now = Date.now();
    const req = context.switchToHttp().getRequest<Request>();
    return next.handle().pipe(
      tap(() => this.logger.log(`${req.method} ${req.url} ${Date.now() - now}ms`)),
    );
  }
}
```

## Pipes

| Pipe             | Purpose                                   |
| ---------------- | ----------------------------------------- |
| ValidationPipe   | Validate DTOs via class-validator          |
| ParseIntPipe     | Transform string param to integer          |
| ParseUUIDPipe    | Validate UUID format                       |
| DefaultValuePipe | Provide default for optional params        |

## Anti-Patterns

- Do NOT throw plain `Error` -- use `HttpException` or custom NestJS exceptions
- Do NOT put business logic in controllers -- delegate to services
- Do NOT skip validation on incoming DTOs -- always use `ValidationPipe`
- Do NOT return JPA/Prisma entities directly -- map to response DTOs
