# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Java 21 + Spring Boot — Infrastructure Patterns

> Extends: `core/10-infrastructure-principles.md`

## Dockerfile.jvm (Standard — Dev/Test/Staging/Prod)

### Layered JAR Approach (Optimized)

```dockerfile
# Build stage
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn package -DskipTests

# Extract layers
FROM eclipse-temurin:21-jre-alpine AS extract
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
RUN java -Djarmode=tools -jar app.jar extract --layers --destination extracted

# Runtime stage (layered for optimal Docker caching)
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=extract /app/extracted/dependencies/ ./
COPY --from=extract /app/extracted/spring-boot-loader/ ./
COPY --from=extract /app/extracted/snapshot-dependencies/ ./
COPY --from=extract /app/extracted/application/ ./
EXPOSE 8080 8583
USER 1001
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
```

### Simple Fat JAR Approach

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
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080 8583
USER 1001
ENTRYPOINT ["java", "-jar", "app.jar"]
```

## Dockerfile.native (Optional — GraalVM Native Image)

```dockerfile
# Native Build stage
FROM ghcr.io/graalvm/native-image-community:21 AS native-build
WORKDIR /app
COPY pom.xml .
COPY src ./src
COPY mvnw .
COPY .mvn .mvn
RUN ./mvnw -Pnative native:compile -DskipTests

# Native Runtime stage
FROM alpine:3.19
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY --from=native-build /app/target/authorizer-simulator /app/application
RUN chmod 775 /app/application
EXPOSE 8080 8583
USER 1001
ENTRYPOINT ["./application"]
```

## Cloud Native Buildpacks Alternative

No Dockerfile needed — Spring Boot builds OCI images directly:

```bash
# Build image using Cloud Native Buildpacks
mvn spring-boot:build-image \
    -Dspring-boot.build-image.imageName=authorizer-simulator:latest

# With custom builder for native
mvn spring-boot:build-image \
    -Pnative \
    -Dspring-boot.build-image.imageName=authorizer-simulator:native
```

## Build Profiles

| Environment | Build | Base Image | Startup |
|----------|-------|-------------|---------|
| Dev | JVM (layered JAR) | eclipse-temurin:21-jre-alpine | ~3-5s |
| Test/CI | JVM | eclipse-temurin:21-jre-alpine | ~3-5s |
| Staging | JVM or Native | alpine (native) / temurin (JVM) | ~3s / < 200ms |
| **Production** | **JVM or Native** | **alpine (native) / temurin (JVM)** | **~3s / < 200ms** |

**Note:** Unlike Quarkus, Spring Boot applications commonly run in JVM mode in production. Native image support via Spring AOT is available but optional.

## Docker Compose (Local Dev)

```yaml
version: '3.8'
services:
  simulator:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
      - "8583:8583"
    environment:
      SPRING_PROFILES_ACTIVE: dev
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

## Spring Boot Probes

### JVM Application (default)

```yaml
startupProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 10

livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 20
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 5
  failureThreshold: 3
```

### Native Application (optional)

```yaml
startupProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 2
  periodSeconds: 2
  failureThreshold: 5

livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 3
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

| Config | Dev (JVM) | Staging (JVM) | Staging (Native) | Prod (JVM) | Prod (Native) |
|--------|-----------|---------------|-------------------|------------|----------------|
| Replicas | 1 | 2 | 2 | 3+ | 3+ |
| Memory Request | 384Mi | 384Mi | 64Mi | 512Mi | 64Mi |
| Memory Limit | 768Mi | 768Mi | 128Mi | 1Gi | 128Mi |
| CPU Request | 250m | 250m | 100m | 500m | 200m |
| CPU Limit | 500m | 1000m | 500m | 2000m | 1000m |

**Note:** Spring Boot JVM applications require more memory than Quarkus native. Plan 512Mi-1Gi for production JVM workloads.

## Externalized Configuration

Spring Boot maps environment variables using `UPPER_CASE_WITH_UNDERSCORES` convention:

```yaml
# application.yml — with env var placeholders
spring:
  datasource:
    url: ${DB_URL:jdbc:postgresql://localhost:5432/authorizer_simulator}
    username: ${DB_USER:simulator}
    password: ${DB_PASSWORD:simulator}

simulator:
  socket:
    port: ${SOCKET_PORT:8583}
    host: ${SOCKET_HOST:0.0.0.0}
    max-connections: ${SOCKET_MAX_CONNECTIONS:100}
    idle-timeout: ${SOCKET_IDLE_TIMEOUT:300}
```

Spring Boot automatically maps:
- `SPRING_DATASOURCE_URL` -> `spring.datasource.url`
- `SIMULATOR_SOCKET_PORT` -> `simulator.socket.port`
- `MANAGEMENT_TRACING_ENABLED` -> `management.tracing.enabled`

**Rules:**
- **ConfigMap** for: application configuration, feature flags, business rules
- **Secret** for: database credentials, API keys
- **Rule:** Credentials ALWAYS in Secret, NEVER in ConfigMap

## Graceful Shutdown

```yaml
# application.yml
server:
  shutdown: graceful

spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```

Kubernetes preStop hook (allows Service endpoint removal before SIGTERM):

```yaml
spec:
  terminationGracePeriodSeconds: 45
  containers:
  - name: app
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 5"]
```

## Docker File Structure

```
src/main/docker/
├── Dockerfile.jvm              -> Standard (JVM layered JAR)
└── Dockerfile.native           -> Optional (GraalVM native image)
```

Or single `Dockerfile` at project root using the layered approach.

## Container Rules

- Multi-stage build ALWAYS
- Non-root user (USER 1001)
- Standard OCI labels (org.opencontainers.image.*)
- HEALTHCHECK instruction
- Only necessary ports exposed (8080, 8583)
- No debug tools in production
- Layered JAR extraction for optimal Docker layer caching

## Tagging Strategy

```
authorizer-simulator:latest           -> latest build (dev)
authorizer-simulator:v0.1.0           -> semantic version
authorizer-simulator:v0.1.0-native    -> native build (if applicable)
authorizer-simulator:sha-abc123       -> commit SHA (CI)
```

**Rule:** NEVER use `latest` in production.

## Spring Boot Profiles vs Quarkus Profiles

| Spring Boot | Quarkus Equivalent | Activation |
|------------|-------------------|------------|
| `application.yml` | `application.properties` | Always loaded |
| `application-dev.yml` | `application-dev.properties` | `SPRING_PROFILES_ACTIVE=dev` |
| `application-test.yml` | `application-test.properties` | `@ActiveProfiles("test")` |
| `application-prod.yml` | `application-prod.properties` | `SPRING_PROFILES_ACTIVE=prod` |

Activate profile via environment variable:
```yaml
# K8S ConfigMap or Deployment env
- name: SPRING_PROFILES_ACTIVE
  value: "prod"
```
