---
name: review-api
description: "Skill: REST API Design Review — Validates REST API endpoints for RFC 7807 error responses, pagination, URL versioning, OpenAPI documentation, status codes, and DTO patterns."
allowed-tools: Read, Grep, Glob, Bash
argument-hint: "[endpoint-path or feature-name]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: REST API Design Review

## Description

Reviews REST API design for compliance with best practices: RFC 7807 error responses, pagination wrappers, URL versioning, OpenAPI annotations, proper HTTP status codes, and DTO separation from domain models.

**Condition**: This skill applies when the project uses REST protocol.

## Prerequisites

- REST API endpoints exist in the codebase
- {{FRAMEWORK}} is configured with REST/HTTP support
- OpenAPI/Swagger dependency is available

## Knowledge Pack References

Before reviewing, read the relevant conventions:
- `skills/api-design/references/api-design-principles.md` — URL structure, status codes, error format, pagination
- `skills/protocols/references/rest-conventions.md` — REST resource naming, HTTP methods, versioning, RFC 7807

## Execution Flow

1. **Discover endpoints** — Search for REST controller/resource classes:
   - Scan for route annotations or decorators (e.g., `@Path`, `@RestController`, `@Get`, `@app.route`)
   - List all endpoints with their HTTP methods and paths

2. **Validate URL structure** — Check each endpoint:
   - URLs use nouns, not verbs (`/api/v1/resources`, not `/api/v1/createResource`)
   - Versioning in path (`/api/v1/`)
   - Sub-resources follow hierarchy (`/api/v1/parents/{id}/children`)
   - Collection endpoints use plural nouns

3. **Validate status codes** — For each endpoint:
   - GET list returns 200
   - GET item returns 200 (or 404)
   - POST returns 201 with Location header
   - PUT returns 200 (or 404)
   - DELETE returns 204 (or 404)
   - Validation errors return 400
   - Duplicates return 409

4. **Validate error responses (RFC 7807)** — Check for:
   - ProblemDetail record/class with fields: type, title, status, detail, instance
   - Factory methods for each error type (notFound, conflict, badRequest, validationError, internalError)
   - ExceptionMapper/handler that converts domain exceptions to ProblemDetail
   - No stack traces exposed in production responses

5. **Validate pagination** — Check list endpoints:
   - Paginated wrapper with data + pagination metadata (page, limit, total, totalPages)
   - Query parameters for page, limit, sort
   - Default values for pagination parameters

6. **Validate DTOs** — Check request/response separation:
   - Request DTOs have input validation annotations
   - Response DTOs are immutable (records or final classes)
   - No domain entities exposed directly in REST responses
   - Sensitive data masked in responses (PAN, documents, etc.)

7. **Validate OpenAPI documentation** — Check for:
   - Schema annotations on DTOs with descriptions and examples
   - OpenAPI spec auto-generated and accessible
   - Swagger UI available in dev profile

8. **Generate report** — Summarize findings as checklist:
   - List compliant items
   - List violations with file paths and line numbers
   - Suggest fixes for each violation

## Usage Examples

```
/review-api merchants
/review-api /api/v1/transactions
/review-api
```

## Review Checklist

- [ ] URLs follow RESTful pattern (nouns, no verbs)
- [ ] Proper versioning in URL path (/api/v1/)
- [ ] Correct HTTP status codes per operation
- [ ] Request DTOs have validation annotations
- [ ] Response DTOs are immutable, no domain entities exposed
- [ ] Error responses follow RFC 7807 (ProblemDetail)
- [ ] Pagination implemented for list endpoints
- [ ] Sensitive data masked in responses
- [ ] OpenAPI/Swagger documentation generated
- [ ] ExceptionMapper covers all domain exceptions
- [ ] No stack traces in production error responses
- [ ] Rate limit responses return 429 + Retry-After header
