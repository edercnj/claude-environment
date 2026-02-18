# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Quarkus — Infrastructure Patterns

> Extends: `core/10-infrastructure-principles.md`

## Dockerfile.jvm (Dev/Test)

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
USER 1001
ENTRYPOINT ["java", "-jar", "quarkus-run.jar"]
```

## Dockerfile.native (Staging/Production)

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

## Build Profiles

| Environment | Build | Base Image | Startup |
|----------|-------|-------------|---------|
| Dev | JVM (hot reload) | eclipse-temurin:21-jre-alpine | ~2s |
| Test/CI | JVM | eclipse-temurin:21-jre-alpine | ~2s |
| Staging | Native | quarkus-micro-image | < 100ms |
| **Production** | **Native** | **quarkus-micro-image** | **< 100ms** |

**Rule:** In production, ALWAYS use native build. JVM only for dev/test.

## Docker Compose (Local Dev)

```yaml
version: '3.8'
services:
  simulator:
    build:
      context: .
      dockerfile: src/main/docker/Dockerfile.jvm
    ports:
      - "8080:8080"
      - "8583:8583"
    environment:
      DB_URL: jdbc:postgresql://db:5432/simulator
      DB_USER: simulator
      DB_PASSWORD: simulator
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: simulator
      POSTGRES_USER: simulator
      POSTGRES_PASSWORD: simulator
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U simulator"]
      interval: 5s
      timeout: 5s
      retries: 5

  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    ports:
      - "4317:4317"
      - "4318:4318"
    profiles:
      - observability

volumes:
  pgdata:
```

## Kubernetes — Kustomize Structure

```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── app/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── hpa.yaml
│   │   ├── pdb.yaml
│   │   ├── networkpolicy.yaml
│   │   └── serviceaccount.yaml
│   ├── database/
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
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

## Quarkus-Specific Probes

### Native Application (staging/prod)

```yaml
startupProbe:
  httpGet:
    path: /q/health/started
    port: 8080
  initialDelaySeconds: 1
  periodSeconds: 2
  failureThreshold: 5

livenessProbe:
  httpGet:
    path: /q/health/live
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /q/health/ready
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 5
  failureThreshold: 3
```

### JVM Application (dev overlay)

```yaml
startupProbe:
  httpGet:
    path: /q/health/started
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 10

livenessProbe:
  httpGet:
    path: /q/health/live
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /q/health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

### PostgreSQL

```yaml
livenessProbe:
  exec:
    command: ["pg_isready", "-U", "simulator"]
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  exec:
    command: ["pg_isready", "-U", "simulator"]
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

## Resources per Environment

| Config | Dev (JVM) | Staging (Native) | Prod (Native) |
|--------|-----------|-------------------|----------------|
| Replicas | 1 | 2 | 3+ |
| Memory Request | 256Mi | 64Mi | 64Mi |
| Memory Limit | 512Mi | 128Mi | 128Mi |
| CPU Request | 250m | 100m | 200m |
| CPU Limit | 500m | 500m | 1000m |

## Externalized Configuration

```properties
quarkus.datasource.jdbc.url=${DB_URL:jdbc:postgresql://postgresql:5432/simulator}
quarkus.datasource.username=${DB_USER:simulator}
quarkus.datasource.password=${DB_PASSWORD:simulator}
simulator.socket.port=${SOCKET_PORT:8583}
simulator.socket.timeout=${SOCKET_TIMEOUT:30}
```

- **ConfigMap** for: application configuration, feature flags, business rules
- **Secret** for: database credentials, API keys
- **Rule:** Credentials ALWAYS in Secret, NEVER in ConfigMap

## Docker File Structure

```
src/main/docker/
├── Dockerfile.jvm              -> Dev/Test (JVM mode)
├── Dockerfile.native           -> Staging/Production (Native)
└── Dockerfile.native-micro     -> Optimized production (distroless)
```

## Container Rules

- Multi-stage build ALWAYS
- Non-root user (USER 1001)
- Standard OCI labels (org.opencontainers.image.*)
- HEALTHCHECK instruction
- Only necessary ports exposed (8080, 8583)
- No debug tools in production

## Tagging Strategy

```
authorizer-simulator:latest           -> latest build (dev)
authorizer-simulator:v0.1.0           -> semantic version
authorizer-simulator:v0.1.0-native    -> native build
authorizer-simulator:sha-abc123       -> commit SHA (CI)
```

**Rule:** NEVER use `latest` in production.
