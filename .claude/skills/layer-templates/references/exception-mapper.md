# Template: Exception Mapper

## Pattern — SimulatorExceptionMapper

```java
package com.bifrost.simulator.adapter.inbound.rest;

import com.bifrost.simulator.adapter.inbound.rest.dto.ProblemDetail;
import com.bifrost.simulator.domain.exception.MerchantAlreadyExistsException;
import com.bifrost.simulator.domain.exception.MerchantNotFoundException;
import com.bifrost.simulator.domain.exception.TerminalAlreadyExistsException;
import com.bifrost.simulator.domain.exception.TerminalNotFoundException;
import com.bifrost.simulator.domain.exception.InvalidDocumentException;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;
import org.jboss.logging.Logger;

@Provider
public class SimulatorExceptionMapper implements ExceptionMapper<RuntimeException> {

    private static final Logger LOG = Logger.getLogger(SimulatorExceptionMapper.class);

    @Context
    UriInfo uriInfo;

    @Override
    public Response toResponse(RuntimeException exception) {
        var problemDetail = switch (exception) {
            case MerchantNotFoundException e -> ProblemDetail.notFound(
                "Merchant not found: " + e.getIdentifier(), uriInfo.getPath());
            case MerchantAlreadyExistsException e -> ProblemDetail.conflict(
                "Merchant with MID '%s' already exists".formatted(e.getMid()),
                uriInfo.getPath(), java.util.Map.of("existingMid", e.getMid()));
            case TerminalNotFoundException e -> ProblemDetail.notFound(
                "Terminal not found: " + e.getIdentifier(), uriInfo.getPath());
            case TerminalAlreadyExistsException e -> ProblemDetail.conflict(
                "Terminal with TID '%s' already exists".formatted(e.getTid()),
                uriInfo.getPath(), java.util.Map.of("existingTid", e.getTid()));
            case InvalidDocumentException e -> ProblemDetail.badRequest(
                e.getMessage(), uriInfo.getPath());
            default -> {
                LOG.errorf("Unexpected error on %s: %s", uriInfo.getPath(), exception.getMessage());
                yield ProblemDetail.internalError("Internal processing error", uriInfo.getPath());
            }
        };
        return Response.status(problemDetail.status()).entity(problemDetail).build();
    }
}
```

## CHANGE THESE

- **case branches**: Add one `case` per new domain exception
- **ProblemDetail factory**: Use `notFound()`, `conflict()`, `badRequest()`, `internalError()`
- **Error messages**: Include the identifier/context from the exception

## Critical Rules (memorize)

1. Pattern matching switch (Java 21) — MANDATORY
2. Each domain exception gets its own `case` branch
3. `default` MUST log at ERROR and return 500 generic (never expose stack trace)
4. Use `ProblemDetail` factory methods — NEVER construct with `new`
5. `@Provider` annotation — auto-registered by JAX-RS

## Checklist

- [ ] `@Provider` annotation
- [ ] Pattern matching switch (not if/else)
- [ ] Every domain exception has a `case`
- [ ] `default` logs at ERROR level
- [ ] `default` returns generic 500 (no stack trace)
- [ ] Uses `ProblemDetail` factory methods
