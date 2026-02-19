---
name: dockerfile
description: "Dockerfile patterns per language covering multi-stage builds, security hardening, .dockerignore templates, layer optimization, health checks, and OCI labels. Internal reference for agents managing infrastructure."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Dockerfile Patterns

## Purpose

Provide production-grade, security-hardened Dockerfile templates for all major languages with multi-stage builds, minimal attack surface, and optimized layer caching.

---

## 1. Multi-Stage Build Templates

### Java (Maven + GraalVM Native)

```dockerfile
# ---- JVM Build ----
FROM eclipse-temurin:21-jdk-jammy AS build

WORKDIR /app

# Cache dependencies separately from source
COPY pom.xml mvnw ./
COPY .mvn .mvn
RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw dependency:go-offline -B

# Build application
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw package -DskipTests -B

# ---- GraalVM Native Build (optional) ----
FROM ghcr.io/graalvm/native-image-community:21 AS native-build

WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
RUN native-image \
    --no-fallback \
    --enable-http \
    --enable-https \
    -H:+ReportExceptionStackTraces \
    -jar app.jar \
    -o app

# ---- JVM Runtime ----
FROM eclipse-temurin:21-jre-jammy AS jvm-runtime

RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app
COPY --from=build --chown=appuser:appuser /app/target/*.jar app.jar

USER appuser:appuser
EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
    CMD ["java", "-cp", "app.jar", "HealthCheck"]

ENTRYPOINT ["java", \
    "-XX:MaxRAMPercentage=75.0", \
    "-XX:+UseG1GC", \
    "-XX:+ExitOnOutOfMemoryError", \
    "-jar", "app.jar"]

# ---- Native Runtime ----
FROM gcr.io/distroless/base-debian12:nonroot AS native-runtime

WORKDIR /app
COPY --from=native-build /app/app ./app

USER nonroot:nonroot
EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app/app", "--health-check"]

ENTRYPOINT ["/app/app"]
```

### TypeScript / Node.js

```dockerfile
# ---- Build ----
FROM node:22-alpine AS build

WORKDIR /app

# Cache dependencies
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --ignore-scripts

# Build TypeScript
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Prune dev dependencies
RUN npm ci --omit=dev --ignore-scripts

# ---- Runtime ----
FROM node:22-alpine AS runtime

# Security: remove unnecessary packages
RUN apk --no-cache add dumb-init && \
    rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm \
           /usr/local/bin/npx /usr/local/bin/corepack

RUN addgroup -g 10001 -S appuser && \
    adduser -u 10001 -S appuser -G appuser -h /app -s /sbin/nologin

WORKDIR /app

COPY --from=build --chown=appuser:appuser /app/node_modules ./node_modules
COPY --from=build --chown=appuser:appuser /app/dist ./dist
COPY --from=build --chown=appuser:appuser /app/package.json ./

USER appuser:appuser
EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD ["node", "-e", "fetch('http://localhost:8080/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"]

ENTRYPOINT ["dumb-init", "node", "--max-old-space-size=384", "dist/main.js"]
```

### Python

```dockerfile
# ---- Build ----
FROM python:3.12-slim AS build

WORKDIR /app

# Install build dependencies
RUN pip install --no-cache-dir uv

# Cache dependencies
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

# Copy application source
COPY src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# ---- Runtime ----
FROM python:3.12-slim AS runtime

# Security: do not install pip in runtime image
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copy the virtual environment from build
COPY --from=build --chown=appuser:appuser /app/.venv ./.venv
COPY --from=build --chown=appuser:appuser /app/src ./src

ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

USER appuser:appuser
EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')"]

ENTRYPOINT ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

### Go

```dockerfile
# ---- Build ----
FROM golang:1.23-alpine AS build

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Build static binary
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -trimpath -o /app/server ./cmd/server

# ---- Runtime ----
FROM gcr.io/distroless/static-debian12:nonroot AS runtime

COPY --from=build /app/server /server

USER nonroot:nonroot
EXPOSE 8080

HEALTHCHECK NONE
# Note: distroless does not support HEALTHCHECK; use Kubernetes probes instead

ENTRYPOINT ["/server"]
```

### Kotlin (Gradle)

```dockerfile
# ---- Build ----
FROM eclipse-temurin:21-jdk-jammy AS build

WORKDIR /app

# Cache Gradle wrapper and dependencies
COPY gradle gradle
COPY gradlew build.gradle.kts settings.gradle.kts ./
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew dependencies --no-daemon

# Build application
COPY src ./src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew bootJar --no-daemon -x test

# ---- Runtime ----
FROM eclipse-temurin:21-jre-jammy AS runtime

RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app
COPY --from=build --chown=appuser:appuser /app/build/libs/*.jar app.jar

USER appuser:appuser
EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
    CMD ["java", "-cp", "app.jar", "HealthCheck"]

ENTRYPOINT ["java", \
    "-XX:MaxRAMPercentage=75.0", \
    "-XX:+UseG1GC", \
    "-XX:+ExitOnOutOfMemoryError", \
    "-jar", "app.jar"]
```

### Rust

```dockerfile
# ---- Build ----
FROM rust:1.78-slim AS build

WORKDIR /app

# Cache dependencies using cargo-chef
RUN cargo install cargo-chef --locked

COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM rust:1.78-slim AS cook
RUN cargo install cargo-chef --locked
WORKDIR /app
COPY --from=build /app/recipe.json recipe.json
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target \
    cargo chef cook --release --recipe-path recipe.json

COPY --from=build /app .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target \
    cargo build --release && \
    cp target/release/my-service /app/server

# ---- Runtime ----
FROM gcr.io/distroless/cc-debian12:nonroot AS runtime

COPY --from=cook /app/server /server

USER nonroot:nonroot
EXPOSE 8080

ENTRYPOINT ["/server"]
```

### C# / .NET

```dockerfile
# ---- Build ----
FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS build

WORKDIR /app

# Cache NuGet packages
COPY *.csproj ./
RUN --mount=type=cache,target=/root/.nuget/packages \
    dotnet restore

# Build and publish
COPY . .
RUN --mount=type=cache,target=/root/.nuget/packages \
    dotnet publish -c Release -o /app/publish --no-restore

# ---- Native AOT Build (optional) ----
# FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS native-build
# WORKDIR /app
# COPY . .
# RUN dotnet publish -c Release -o /app/publish \
#     -p:PublishAot=true -p:StripSymbols=true

# ---- Runtime ----
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS runtime

RUN addgroup -g 10001 -S appuser && \
    adduser -u 10001 -S appuser -G appuser -h /app -s /sbin/nologin

WORKDIR /app
COPY --from=build --chown=appuser:appuser /app/publish .

USER appuser:appuser
EXPOSE 8080

ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_EnableDiagnostics=0

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD ["wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/healthz"]

ENTRYPOINT ["dotnet", "MyService.dll"]
```

---

## 2. Security Hardening

### Checklist

| Practice | Description |
|---|---|
| **Non-root user** | Always create and switch to a non-root user with `USER` |
| **Read-only filesystem** | Use `readOnlyRootFilesystem: true` in K8s; minimize writes in Dockerfile |
| **No package managers** | Do not install pip, npm, apt in the final stage |
| **Minimal base images** | Use `distroless`, `alpine`, or `-slim` variants |
| **No shell** | Prefer `distroless` (no shell) for Go and Rust |
| **Pin versions** | Pin base image tags to specific versions, not `latest` |
| **No secrets in image** | Never COPY secrets; use runtime injection via env or mounted volumes |
| **Scan for CVEs** | Integrate Trivy or Grype in CI pipeline |
| **Multi-stage builds** | Separate build tools from runtime image |
| **.dockerignore** | Exclude unnecessary files from build context |

### Non-Root User Pattern

```dockerfile
# Alpine-based
RUN addgroup -g 10001 -S appuser && \
    adduser -u 10001 -S appuser -G appuser -h /app -s /sbin/nologin

# Debian/Ubuntu-based
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

# Distroless (built-in nonroot user)
FROM gcr.io/distroless/static-debian12:nonroot
USER nonroot:nonroot
```

---

## 3. .dockerignore Template

```dockerignore
# Version control
.git
.gitignore

# IDE and editor files
.idea/
.vscode/
*.swp
*.swo
*~

# CI/CD
.github/
.gitlab-ci.yml
.circleci/
Jenkinsfile

# Documentation
*.md
LICENSE
docs/

# Docker files (avoid recursive build)
Dockerfile*
docker-compose*.yml
.dockerignore

# Environment and secrets
.env
.env.*
*.pem
*.key
*.crt

# Testing
**/test/
**/tests/
**/__tests__/
**/coverage/
.nyc_output/
*.test.*
*.spec.*

# Build artifacts
**/node_modules/
**/target/
**/build/
**/dist/
**/bin/
**/obj/
**/__pycache__/
**/*.pyc
*.class
*.jar

# OS files
.DS_Store
Thumbs.db

# Terraform / IaC
**/*.tfstate*
**/.terraform/

# Kubernetes manifests (not needed in image)
k8s/
charts/
helmfile.yaml
```

---

## 4. Layer Optimization

### Instruction Ordering Strategy

```
1. Base image (changes rarely)
2. System packages (changes rarely)
3. Create user (changes rarely)
4. Copy dependency manifests (changes on dep update)
5. Install dependencies (cached if manifests unchanged)
6. Copy source code (changes frequently)
7. Build application
8. Final stage: copy artifacts only
```

### BuildKit Cache Mounts

```dockerfile
# Maven
RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw package -DskipTests -B

# Gradle
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew bootJar --no-daemon

# Go
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /app/server ./cmd/server

# npm
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# pip / uv
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen

# NuGet
RUN --mount=type=cache,target=/root/.nuget/packages \
    dotnet restore

# Cargo
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target \
    cargo build --release
```

### Multi-Platform Build

```dockerfile
# Enable BuildKit and build for multiple architectures
# docker buildx build --platform linux/amd64,linux/arm64 -t my-image:tag .
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /server ./cmd/server
```

---

## 5. Health Check

### Per-Language HEALTHCHECK Examples

```dockerfile
# Java (JVM)
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
    CMD ["java", "-cp", "app.jar", "HealthCheck"]

# Node.js
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD ["node", "-e", "fetch('http://localhost:8080/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]

# Python
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')"]

# Go / Rust (distroless - no HEALTHCHECK, use K8s probes)
# HEALTHCHECK not supported in distroless; rely on Kubernetes probes

# C# / .NET
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD ["wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/healthz"]
```

### Timing Guide

| Runtime | start-period | interval | timeout | retries |
|---|---|---|---|---|
| Java JVM | 30s | 10s | 3s | 3 |
| Java Native | 5s | 10s | 3s | 3 |
| Go | 5s | 10s | 3s | 3 |
| Node.js | 10s | 10s | 3s | 3 |
| Python | 10s | 10s | 3s | 3 |
| Rust | 5s | 10s | 3s | 3 |
| .NET | 10s | 10s | 3s | 3 |

---

## 6. Labels

### OCI Image Spec Labels

```dockerfile
# Apply OCI-standard labels via build args
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.opencontainers.image.title="my-service" \
      org.opencontainers.image.description="My service description" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/example/my-service" \
      org.opencontainers.image.url="https://github.com/example/my-service" \
      org.opencontainers.image.documentation="https://github.com/example/my-service/blob/main/README.md" \
      org.opencontainers.image.vendor="Example Corp" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.base.name="eclipse-temurin:21-jre-jammy"
```

### Build Command with Labels

```bash
docker build \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
  --build-arg VERSION="1.0.0" \
  -t registry.example.com/my-service:1.0.0-$(git rev-parse --short HEAD) \
  .
```
