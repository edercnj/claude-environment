# Template: TCP Handler (Vert.x)

## Pattern

```java
package com.bifrost.simulator.adapter.inbound.socket;

import com.bifrost.simulator.application.AuthorizeTransactionUseCase;
import com.bifrost.simulator.domain.model.TransactionResult;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import org.jboss.logging.Logger;

@ApplicationScoped
public class DebitMessageHandler {

    private static final Logger LOG = Logger.getLogger(DebitMessageHandler.class);
    private static final String MTI_DEBIT_REQUEST = "1200";
    private static final String MTI_DEBIT_RESPONSE = "1210";
    private static final String RESPONSE_CODE_SYSTEM_ERROR = "96";
    private static final String RESPONSE_CODE_INVALID_TRANSACTION = "12";

    private final AuthorizeTransactionUseCase authorizeUseCase;

    @Inject
    public DebitMessageHandler(AuthorizeTransactionUseCase authorizeUseCase) {
        this.authorizeUseCase = authorizeUseCase;
    }

    public byte[] handle(byte[] rawMessage, ConnectionContext context) {
        try {
            var isoMessage = parseMessage(rawMessage);
            var result = authorizeUseCase.authorize(isoMessage);
            return buildResponse(isoMessage, result, context);
        } catch (Exception e) {
            LOG.errorf("Error processing debit message from connection %s: %s",
                context.connectionId(), e.getMessage());
            return buildErrorResponse(RESPONSE_CODE_SYSTEM_ERROR);
        }
    }

    private Object parseMessage(byte[] rawMessage) {
        // Parse ISO 8583 message using b8583 library
        // Extract: PAN (DE-2), Processing Code (DE-3), Amount (DE-4), etc.
        throw new UnsupportedOperationException("Implement with b8583 library");
    }

    private byte[] buildResponse(Object request, TransactionResult result, ConnectionContext context) {
        // Build ISO 8583 response:
        // - Change MTI from 1200 to 1210
        // - Set DE-39 (Response Code) from result
        // - Copy echo fields (DE-11 STAN, DE-37 RRN, DE-41 TID, DE-42 MID)
        // - Pack and return
        throw new UnsupportedOperationException("Implement response packing");
    }

    private byte[] buildErrorResponse(String responseCode) {
        // Build minimal error response with RC 96
        throw new UnsupportedOperationException("Implement error response");
    }
}
```

## CHANGE THESE

- **Class name**: `{TransactionType}MessageHandler`
- **MTI constants**: Request and response MTI for this transaction type
- **Use case**: Inject the appropriate authorization use case
- **Parse/build methods**: Implement with b8583 library

## Critical Rules (memorize)

1. `@ApplicationScoped` — stateless, thread-safe
2. NEVER close the TCP connection after processing — connections are PERSISTENT
3. On error: return RC 96, keep connection OPEN
4. NEVER log full PAN — mask first
5. Constructor injection with `@Inject`

## Checklist

- [ ] `@ApplicationScoped`
- [ ] Constructor injection
- [ ] Named constants for MTI and response codes
- [ ] Error handling returns RC 96 (fail secure)
- [ ] Connection stays open on error
- [ ] PAN masked before logging
- [ ] Methods <= 25 lines
- [ ] Stateless (no mutable fields)
