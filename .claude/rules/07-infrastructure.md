# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Rule 07 — Infrastructure (K8S, Docker, PostgreSQL)

## Docker

### Multi-Stage Build
```dockerfile
# Build stage
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn package -DskipTests

# Runtime stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /app/target/quarkus-app/ ./
EXPOSE 8080 8583
ENTRYPOINT ["java", "-jar", "quarkus-run.jar"]
```

### Quarkus Native Build (Production)
```dockerfile
# Native Build stage (using Mandrel)
FROM quay.io/quarkus/ubi-quarkus-mandrel-builder-image:jdk-21 AS native-build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN ./mvnw package -Dnative -DskipTests \
    -Dquarkus.native.additional-build-args="--initialize-at-build-time"

# Native Runtime stage (minimal image)
FROM quay.io/quarkus/quarkus-micro-image:2.0
WORKDIR /app
COPY --from=native-build /app/target/*-runner /app/application
RUN chmod 775 /app/application
EXPOSE 8080 8583
USER 1001
ENTRYPOINT ["./application", "-Dquarkus.http.host=0.0.0.0"]
```

### Build Rules
| Environment | Build | Base Image | Startup |
|----------|-------|-------------|---------|
| Dev | JVM (hot reload) | eclipse-temurin:21-jre-alpine | ~2s |
| Test/CI | JVM | eclipse-temurin:21-jre-alpine | ~2s |
| Staging | Native | quarkus-micro-image | < 100ms |
| **Production** | **Native** | **quarkus-micro-image** | **< 100ms** |

> **RULE:** In production, ALWAYS use native build. JVM only for dev/test.

### Docker Rules
- ALWAYS use multi-stage build
- Runtime base image: `eclipse-temurin:21-jre-alpine` (minimal footprint)
- Expose port 8080 (REST API) and 8583 (TCP ISO 8583)
- Health check via `/q/health` (Quarkus SmallRye Health)
- Do not run as root (use USER 1001)
- Standard OCI labels

## Kubernetes

### Cloud-Agnostic Principles
- **NO** cloud provider-specific resources (LoadBalancer type can be changed by overlay)
- **NO** proprietary operators (e.g., AWS RDS Operator)
- Use only native K8S resources: Deployment, Service, ConfigMap, Secret, StatefulSet, PVC
- PersistentVolumeClaim with configurable `storageClassName` (not hardcoded)

### Manifests Structure
```
k8s/
├── base/
│   ├── namespace.yaml
│   ├── app/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── hpa.yaml
│   ├── database/
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   └── pvc.yaml
│   └── observability/
│       ├── otel-collector-deployment.yaml
│       ├── otel-collector-service.yaml
│       └── otel-collector-configmap.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

### Application (Deployment)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: authorizer-simulator
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
  template:
    spec:
      containers:
      - name: authorizer-simulator
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /q/health/live
            port: 8080
          initialDelaySeconds: 10
        readinessProbe:
          httpGet:
            path: /q/health/ready
            port: 8080
          initialDelaySeconds: 5
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8583
          name: iso8583
```

### PostgreSQL (StatefulSet)
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
spec:
  serviceName: postgresql
  replicas: 1
  template:
    spec:
      containers:
      - name: postgresql
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: pgdata
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: pgdata
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
```

### Externalized Configuration
- **ConfigMap** for: application configuration, feature flags, business rules
- **Secret** for: database credentials, API keys
- **Environment Variables** mapped via Quarkus config:
  ```properties
  quarkus.datasource.jdbc.url=${DB_URL:jdbc:postgresql://postgresql:5432/simulator}
  quarkus.datasource.username=${DB_USER:simulator}
  quarkus.datasource.password=${DB_PASSWORD:simulator}
  simulator.socket.port=${SOCKET_PORT:8583}
  simulator.socket.timeout=${SOCKET_TIMEOUT:30}
  ```

## PostgreSQL

### Flyway Migrations
- Location: `src/main/resources/db/migration/`
- Naming: `V{version}__{description}.sql`
  - Example: `V1__create_transaction_table.sql`
  - Example: `V2__create_merchant_terminal_tables.sql`
- NEVER modify a migration already applied — create a new migration
- ALWAYS use explicit transactions in migrations

### Default Schema
```sql
-- All tables in 'simulator' schema
CREATE SCHEMA IF NOT EXISTS simulator;

-- Default timestamp columns
created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
```

### Connection Pool
```properties
quarkus.datasource.jdbc.min-size=5
quarkus.datasource.jdbc.max-size=20
quarkus.datasource.jdbc.acquisition-timeout=5S
```

## Observability (OpenTelemetry)

### Observability Stack
| Pillar | Technology | Backend (suggestion) |
|-------|-----------|-------------------|
| Traces | OpenTelemetry SDK + OTLP Exporter | Jaeger / Tempo |
| Metrics | OpenTelemetry SDK + OTLP Exporter | Prometheus / Mimir |
| Logs | OpenTelemetry SDK + SLF4J Bridge | Loki / Elasticsearch |
| Health | SmallRye Health (Quarkus) | Kubernetes Probes |

> **RULE:** Use OpenTelemetry as the ONLY standard for instrumentation. NEVER use proprietary observability APIs (direct Micrometer, Jaeger SDK, etc.)

### Quarkus Configuration
```properties
# OpenTelemetry
quarkus.otel.enabled=true
quarkus.otel.exporter.otlp.endpoint=http://otel-collector:4317
quarkus.otel.exporter.otlp.protocol=grpc
quarkus.otel.service.name=authorizer-simulator
quarkus.otel.resource.attributes=service.version=0.1.0,deployment.environment=${ENV:dev}

# Traces
quarkus.otel.traces.enabled=true
quarkus.otel.traces.sampler=parentbased_always_on

# Metrics
quarkus.otel.metrics.enabled=true

# Logs (via SLF4J bridge)
quarkus.otel.logs.enabled=true
quarkus.log.handler.open-telemetry.enabled=true
```

### Health Checks
- **Liveness:** `/q/health/live` — application is running
- **Readiness:** `/q/health/ready` — DB connected + socket listening
- **Startup:** `/q/health/started` — application finished startup

### Custom Metrics (via OpenTelemetry API)
```java
// ✅ CORRECT — Use OpenTelemetry API directly
@ApplicationScoped
public class TransactionMetrics {
    private final Meter meter;
    private final LongCounter transactionCounter;
    private final DoubleHistogram transactionDuration;
    private final LongUpDownCounter activeConnections;

    @Inject
    public TransactionMetrics(Meter meter) {
        this.meter = meter;
        this.transactionCounter = meter.counterBuilder("simulator.transactions")
            .setDescription("Total transactions processed")
            .build();
        this.transactionDuration = meter.histogramBuilder("simulator.transaction.duration")
            .setDescription("Transaction processing duration in seconds")
            .setUnit("s")
            .build();
        this.activeConnections = meter.upDownCounterBuilder("simulator.connections.active")
            .setDescription("Active TCP connections")
            .build();
    }
}
```

### Mandatory Metrics
| Name | Type | Tags | Description |
|------|------|------|-----------|
| `simulator.transactions` | Counter | mti, response_code, iso_version | Total transactions |
| `simulator.transaction.duration` | Histogram | mti, response_code | Processing duration |
| `simulator.connections.active` | UpDownCounter | protocol | Active TCP connections |
| `simulator.timeout.simulations` | Counter | tid, mid | Simulated timeouts |
| `simulator.db.query.duration` | Histogram | query_type | SQL query duration |

> **Resilience metrics** (circuit breaker, rate limiting, bulkhead, degradation) are defined in **Rule 24 — Application Resilience** and exposed automatically by SmallRye Fault Tolerance via OpenTelemetry.

### Distributed Tracing
- Each ISO 8583 transaction creates a **root span**
- Sub-spans for: parsing, validation, decision, persistence, packing
- Mandatory span attributes: `mti`, `stan`, `response_code`, `merchant_id`
- **NEVER** include PAN, PIN, or sensitive data in spans

### Structured Logging
- JSON format in production (integrated with OpenTelemetry Logs)
- Mandatory fields: timestamp, level, logger, message, trace_id, span_id, mdc (transaction_id, mti, mid)
- Automatic correlation: `trace_id` and `span_id` in each log line
- PAN and sensitive data NEVER in logs (use masking)

### Kubernetes — OpenTelemetry Collector
```yaml
# k8s/base/observability/otel-collector.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:latest
        ports:
        - containerPort: 4317  # gRPC OTLP
          name: otlp-grpc
        - containerPort: 4318  # HTTP OTLP
          name: otlp-http
        - containerPort: 8889  # Prometheus metrics
          name: prometheus
```
