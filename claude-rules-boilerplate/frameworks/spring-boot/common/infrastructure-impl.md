# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Spring Boot — Infrastructure Patterns

> Extends: `core/10-infrastructure-principles.md`
> All cloud-agnostic, Kustomize, and container security principles apply.

## Docker — JVM Build (Layered JARs)

Spring Boot produces layered JARs by default, enabling efficient Docker layer caching:

```dockerfile
# Stage 1: Build
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN chmod +x mvnw && ./mvnw dependency:go-offline
COPY src ./src
RUN ./mvnw package -DskipTests

# Stage 2: Extract layers
FROM eclipse-temurin:21-jdk-alpine AS extract
WORKDIR /app
COPY --from=build /app/target/*.jar application.jar
RUN java -Djarmode=layertools -jar application.jar extract

# Stage 3: Runtime
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Add non-root user
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -D appuser

# Copy layers in order of change frequency (least to most)
COPY --from=extract /app/dependencies/ ./
COPY --from=extract /app/spring-boot-loader/ ./
COPY --from=extract /app/snapshot-dependencies/ ./
COPY --from=extract /app/application/ ./

EXPOSE 8080 8583

USER 1001

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health/liveness || exit 1

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
```

## Docker — Native Build (GraalVM)

```dockerfile
# Stage 1: Build native image
FROM ghcr.io/graalvm/native-image-community:21 AS native-build
WORKDIR /app
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN chmod +x mvnw && ./mvnw dependency:go-offline
COPY src ./src
RUN ./mvnw -Pnative native:compile -DskipTests

# Stage 2: Runtime (minimal)
FROM alpine:3.19
WORKDIR /app

RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -D appuser && \
    apk add --no-cache libstdc++

COPY --from=native-build /app/target/authorizer-simulator /app/application
RUN chmod 755 /app/application

EXPOSE 8080 8583

USER 1001

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health/liveness || exit 1

ENTRYPOINT ["./application"]
```

## Cloud Native Buildpacks (Alternative)

No Dockerfile needed. Uses Paketo buildpacks:

```bash
# JVM image
mvn spring-boot:build-image \
    -Dspring-boot.build-image.imageName=authorizer-simulator:jvm

# Native image
mvn -Pnative spring-boot:build-image \
    -Dspring-boot.build-image.imageName=authorizer-simulator:native
```

### Build Rules

| Environment | Build | Base Image | Startup |
|-------------|-------|------------|---------|
| Dev | JVM (DevTools) | eclipse-temurin:21-jre-alpine | ~2s |
| Test/CI | JVM | eclipse-temurin:21-jre-alpine | ~2s |
| Staging | Native | alpine:3.19 (minimal) | < 200ms |
| **Production** | **Native** | **alpine:3.19 (minimal)** | **< 200ms** |

## Docker Compose (Local Dev)

```yaml
services:
  simulator:
    build:
      context: .
      dockerfile: Dockerfile.jvm
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

## Kubernetes Kustomize Structure

```
k8s/
+-- base/
|   +-- kustomization.yaml
|   +-- namespace.yaml
|   +-- app/
|   |   +-- deployment.yaml
|   |   +-- service.yaml
|   |   +-- configmap.yaml
|   |   +-- secret.yaml
|   |   +-- hpa.yaml
|   |   +-- pdb.yaml
|   |   +-- serviceaccount.yaml
|   +-- database/
|   |   +-- statefulset.yaml
|   |   +-- service.yaml
|   |   +-- configmap.yaml
|   |   +-- secret.yaml
|   +-- observability/
|       +-- otel-collector-deployment.yaml
|       +-- otel-collector-service.yaml
|       +-- otel-collector-configmap.yaml
+-- overlays/
    +-- dev/
    |   +-- kustomization.yaml
    +-- staging/
    |   +-- kustomization.yaml
    +-- prod/
        +-- kustomization.yaml
```

## Kubernetes Probes for Spring Boot

Spring Boot applications have longer startup than Quarkus native. Probe timings MUST account for this:

### JVM Mode (Dev Overlay)

```yaml
startupProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 12

livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 20
  periodSeconds: 5
  failureThreshold: 3
```

### Native Mode (Staging/Prod)

```yaml
startupProbe:
  httpGet:
    path: /actuator/health/liveness
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

### Probe Comparison: Spring Boot vs Quarkus

| Probe | Spring Boot JVM | Spring Boot Native | Quarkus Native |
|-------|----------------|-------------------|---------------|
| Startup initialDelay | 10s | 2s | 1s |
| Liveness initialDelay | 30s | 5s | 5s |
| Readiness initialDelay | 20s | 3s | 3s |
| Liveness path | `/actuator/health/liveness` | `/actuator/health/liveness` | `/q/health/live` |
| Readiness path | `/actuator/health/readiness` | `/actuator/health/readiness` | `/q/health/ready` |

## Resources per Environment

| Config | Dev (JVM) | Staging (Native) | Prod (Native) |
|--------|-----------|-------------------|----------------|
| Replicas | 1 | 2 | 3+ |
| Memory Request | 256Mi | 64Mi | 128Mi |
| Memory Limit | 512Mi | 256Mi | 256Mi |
| CPU Request | 250m | 100m | 200m |
| CPU Limit | 500m | 500m | 1000m |

```yaml
# base/app/deployment.yaml
spec:
  template:
    spec:
      containers:
      - name: authorizer-simulator
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8583
          name: iso8583
```

## Externalized Configuration

```yaml
# base/app/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: simulator-config
data:
  SPRING_PROFILES_ACTIVE: "prod"
  SIMULATOR_SOCKET_PORT: "8583"
  SIMULATOR_ISO_DEFAULT_VERSION: "1993"
  MANAGEMENT_OTLP_TRACING_ENDPOINT: "http://otel-collector:4318/v1/traces"
  MANAGEMENT_TRACING_ENABLED: "true"

---
# base/app/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: simulator-secrets
type: Opaque
stringData:
  DB_URL: "jdbc:postgresql://postgresql:5432/simulator"
  DB_USER: "simulator"
  DB_PASSWORD: "simulator"
```

## Security Context

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    runAsGroup: 1001
    fsGroup: 1001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: authorizer-simulator
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir:
      sizeLimit: 64Mi
```

## Graceful Shutdown

Spring Boot supports graceful shutdown natively:

```yaml
# application.yml
server:
  shutdown: graceful

spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```

Kubernetes manifest:

```yaml
spec:
  terminationGracePeriodSeconds: 30
  containers:
  - name: authorizer-simulator
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 5"]
```

The `sleep 5` allows the Service to remove the pod from endpoints before SIGTERM is sent.

## Container Rules

| Rule | Detail |
|------|--------|
| Multi-stage build | ALWAYS |
| Non-root user | USER 1001 |
| Read-only filesystem | When possible (emptyDir for /tmp) |
| OCI labels | `org.opencontainers.image.*` |
| HEALTHCHECK | Via `/actuator/health/liveness` |
| Exposed ports | 8080 (HTTP), 8583 (ISO 8583) |
| No debug tools | Production images are minimal |
| No credentials | Environment variables only |

## Anti-Patterns (FORBIDDEN)

```java
// FORBIDDEN — Container running as root
USER root  // Must be USER 1001

// FORBIDDEN — Credentials in Docker image
ENV DB_PASSWORD=mysecret  // Use Kubernetes Secret

// FORBIDDEN — latest tag in production
image: authorizer-simulator:latest  // Use semantic version or SHA

// FORBIDDEN — No probes
// Every deployment MUST have liveness, readiness, and startup probes

// FORBIDDEN — Helm charts
// Use Kustomize only

// FORBIDDEN — Cloud provider-specific resources
apiVersion: elbv2.k8s.aws/v1beta1  // Cloud-agnostic!

// FORBIDDEN — Deployment for database
kind: Deployment  // PostgreSQL MUST use StatefulSet

// FORBIDDEN — No graceful shutdown
server.shutdown: immediate  // Use graceful

// FORBIDDEN — JVM mode in production
// Native build is mandatory for staging and production
```
