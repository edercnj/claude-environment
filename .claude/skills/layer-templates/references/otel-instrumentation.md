# Template: OpenTelemetry Instrumentation

## Pattern — Custom Spans

```java
package com.bifrost.simulator.adapter.inbound.socket;

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Scope;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class TransactionTracer {

    private final Tracer tracer;

    @Inject
    public TransactionTracer(Tracer tracer) {
        this.tracer = tracer;
    }

    public <T> T traceTransaction(String mti, String stan, String merchantId, java.util.function.Supplier<T> operation) {
        Span span = tracer.spanBuilder("transaction.process")
            .setAttribute("iso.mti", mti)
            .setAttribute("iso.stan", stan)
            .setAttribute("merchant.id", merchantId)
            .startSpan();
        try (Scope scope = span.makeCurrent()) {
            T result = operation.get();
            span.setStatus(StatusCode.OK);
            return result;
        } catch (Exception e) {
            span.setStatus(StatusCode.ERROR, e.getMessage());
            span.recordException(e);
            throw e;
        } finally {
            span.end();
        }
    }
}
```

## Pattern — Custom Metrics

```java
package com.bifrost.simulator.config;

import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.DoubleHistogram;
import io.opentelemetry.api.metrics.LongUpDownCounter;
import io.opentelemetry.api.metrics.Meter;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class TransactionMetrics {

    private final LongCounter transactionCounter;
    private final DoubleHistogram transactionDuration;
    private final LongUpDownCounter activeConnections;

    @Inject
    public TransactionMetrics(Meter meter) {
        this.transactionCounter = meter.counterBuilder("simulator.transactions")
            .setDescription("Total transactions processed")
            .build();
        this.transactionDuration = meter.histogramBuilder("simulator.transaction.duration")
            .setDescription("Transaction processing duration")
            .setUnit("s")
            .build();
        this.activeConnections = meter.upDownCounterBuilder("simulator.connections.active")
            .setDescription("Active TCP connections")
            .build();
    }

    public void recordTransaction(String mti, String responseCode, String isoVersion) {
        transactionCounter.add(1, Attributes.builder()
            .put("mti", mti)
            .put("response_code", responseCode)
            .put("iso_version", isoVersion)
            .build());
    }

    public void recordDuration(String mti, String responseCode, double durationSeconds) {
        transactionDuration.record(durationSeconds, Attributes.builder()
            .put("mti", mti)
            .put("response_code", responseCode)
            .build());
    }

    public void connectionOpened() {
        activeConnections.add(1, Attributes.builder().put("protocol", "tcp").build());
    }

    public void connectionClosed() {
        activeConnections.add(-1, Attributes.builder().put("protocol", "tcp").build());
    }
}
```

## CHANGE THESE

- **Span names**: `{domain}.{operation}` (e.g., `transaction.process`, `message.parse`)
- **Span attributes**: Add domain-specific attributes from Rule 18
- **Metric names**: `simulator.{metric}` with appropriate type (Counter, Histogram, UpDownCounter)
- **Tags/attributes**: Match the mandatory metrics table in Rule 18

## Critical Rules (memorize)

1. Use OpenTelemetry API directly — NEVER Micrometer directly
2. NEVER include PAN, PIN, CVV, track data in spans or metrics
3. Metric prefix: `simulator.*`
4. Span names: lowercase with dots (`transaction.process`)
5. Always set span status (OK or ERROR) and call `span.end()`

## PROHIBITED Span Attributes

- `pan` (Primary Account Number)
- `pin_block`
- `cvv` / `cvc`
- `track_data`
- `card_expiry`

## Checklist

- [ ] OpenTelemetry API (not Micrometer)
- [ ] Span status set (OK or ERROR)
- [ ] `span.end()` in finally block
- [ ] No sensitive data in attributes
- [ ] Metric names prefixed with `simulator.*`
- [ ] Mandatory metrics present (Rule 18)
