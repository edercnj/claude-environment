# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Dockerfile Patterns

## Multi-Stage Build Patterns by Language

### Java (Maven)

```dockerfile
# Stage 1: Build — compile and package with Maven
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn package -DskipTests -B

# Stage 2: Runtime — minimal JRE image
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -D appuser
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
USER 1001
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
```

| Stage | Purpose | Image |
|-------|---------|-------|
| build | Compile, resolve dependencies, package JAR | `eclipse-temurin:21-jdk` (full JDK + Maven) |
| runtime | Run the application | `eclipse-temurin:21-jre-alpine` (minimal JRE) |

### Java (GraalVM Native Image)

```dockerfile
# Stage 1: Build — compile native image
FROM ghcr.io/graalvm/native-image-community:21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn -Pnative native:compile -DskipTests -B

# Stage 2: Runtime — distroless (no OS, no shell)
FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=build /app/target/my-app .
EXPOSE 8080
USER 1001
ENTRYPOINT ["./my-app"]
```

| Stage | Purpose | Image |
|-------|---------|-------|
| build | Compile ahead-of-time native binary | `native-image-community:21` (GraalVM + native-image) |
| runtime | Run the native binary | `distroless/base-debian12` (no shell, no package manager) |

### TypeScript / Node.js

```dockerfile
# Stage 1: Dependencies — install node_modules
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

# Stage 2: Build — compile TypeScript
FROM node:22-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build
RUN npm prune --production

# Stage 3: Runtime — minimal Node.js
FROM node:22-alpine
WORKDIR /app
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -D appuser
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./
EXPOSE 3000
USER 1001
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1
ENTRYPOINT ["node", "dist/main.js"]
```

| Stage | Purpose | Image |
|-------|---------|-------|
| deps | Install all dependencies (cached layer) | `node:22-alpine` |
| build | Compile TypeScript, prune dev dependencies | `node:22-alpine` |
| runtime | Run compiled JavaScript | `node:22-alpine` |

### Python

```dockerfile
# Stage 1: Build — install dependencies into virtual env
FROM python:3.12-slim AS build
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime — copy virtual env
FROM python:3.12-slim
WORKDIR /app
RUN groupadd -g 1001 appgroup && useradd -u 1001 -g appgroup -m appuser
COPY --from=build /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY src ./src
EXPOSE 8000
USER 1001
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
ENTRYPOINT ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

| Stage | Purpose | Image |
|-------|---------|-------|
| build | Create venv, install pip packages | `python:3.12-slim` |
| runtime | Copy venv, run application | `python:3.12-slim` |

### Go

```dockerfile
# Stage 1: Build — compile static binary
FROM golang:1.23-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./cmd/server

# Stage 2: Runtime — scratch (zero OS)
FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /app/server /server
EXPOSE 8080
USER 1001
ENTRYPOINT ["/server"]
```

| Stage | Purpose | Image |
|-------|---------|-------|
| build | Compile statically linked Go binary | `golang:1.23-alpine` |
| runtime | Run binary with zero OS overhead | `scratch` (empty image) |

### Rust

```dockerfile
# Stage 1: Build — compile release binary
FROM rust:1.79-slim AS build
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release && rm -rf src
COPY src ./src
RUN cargo build --release

# Stage 2: Runtime — minimal Debian
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
RUN groupadd -g 1001 appgroup && useradd -u 1001 -g appgroup -m appuser
COPY --from=build /app/target/release/my-app /usr/local/bin/my-app
EXPOSE 8080
USER 1001
ENTRYPOINT ["my-app"]
```

| Stage | Purpose | Image |
|-------|---------|-------|
| build | Compile release binary (with dependency caching trick) | `rust:1.79-slim` |
| runtime | Run binary with minimal OS | `debian:bookworm-slim` |

## Security Hardening

### Non-Root USER (Mandatory)

```dockerfile
# Alpine-based
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -D appuser
USER 1001

# Debian/Ubuntu-based
RUN groupadd -g 1001 appgroup && useradd -u 1001 -g appgroup -m appuser
USER 1001

# Distroless — USER directive only (no adduser available)
USER 1001
```

**Rule:** NEVER run containers as root. ALWAYS create a dedicated user with a fixed UID/GID (1001 is conventional).

### Read-Only Filesystem

```dockerfile
# In Dockerfile: no writable directories needed
# In Kubernetes: readOnlyRootFilesystem: true

# If the app needs a writable temp directory:
# Mount an emptyDir volume at /tmp in Kubernetes
```

### No Package Managers in Final Image

```dockerfile
# GOOD — multi-stage, no build tools in final
FROM eclipse-temurin:21-jre-alpine
# No apk, apt, yum in final image

# BETTER — distroless (no shell, no package manager at all)
FROM gcr.io/distroless/java21-debian12

# BAD — build tools in final image
FROM eclipse-temurin:21-jdk
RUN mvn package   # Build tools remain in final image
```

### Pin Versions (Mandatory)

```dockerfile
# GOOD — pinned versions
FROM node:22.11.0-alpine3.20
RUN apk add --no-cache curl=8.9.1-r2
RUN pip install requests==2.32.3

# BAD — floating versions
FROM node:latest
RUN apk add curl
RUN pip install requests
```

**Rule:** Pin ALL base images and package versions. Use SHA digests for maximum reproducibility in production.

```dockerfile
# Maximum reproducibility
FROM node:22.11.0-alpine3.20@sha256:abc123...
```

### Scan Images (Mandatory in CI)

| Tool | Type | Integration |
|------|------|-------------|
| Trivy | Vulnerability scanner | CLI, CI/CD, registry webhook |
| Grype | Vulnerability scanner | CLI, CI/CD |
| Snyk Container | Vulnerability + license | CLI, CI/CD, IDE |
| Docker Scout | Vulnerability + SBOM | Docker Desktop, CI/CD |

**Rule:** EVERY image MUST be scanned before deployment. Block builds with CRITICAL or HIGH vulnerabilities.

### .dockerignore (Mandatory)

```
.git
.github
.vscode
.idea
node_modules
target
dist
*.md
*.log
docker-compose*.yml
Dockerfile*
.env*
.dockerignore
coverage
.nyc_output
__pycache__
*.pyc
.pytest_cache
```

**Rule:** EVERY project with a Dockerfile MUST have a `.dockerignore`. Reduces build context size and prevents leaking secrets or unnecessary files.

## Optimization

### Layer Ordering

```dockerfile
# GOOD — least-changing layers first (maximize cache hits)
FROM node:22-alpine
WORKDIR /app

# 1. System dependencies (rarely change)
RUN apk add --no-cache curl

# 2. Dependency manifest (changes when deps change)
COPY package.json package-lock.json ./
RUN npm ci

# 3. Source code (changes frequently)
COPY src ./src
RUN npm run build

# BAD — source code before dependencies (busts cache every change)
COPY . .
RUN npm ci && npm run build
```

**Rule:** Order layers from least-frequently-changed to most-frequently-changed. Dependency installation BEFORE source code copy.

### Combine RUN Commands

```dockerfile
# GOOD — single layer, no intermediate artifacts
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# BAD — multiple layers, apt cache persisted
RUN apt-get update
RUN apt-get install -y curl ca-certificates
```

**Rule:** Combine related `RUN` commands with `&&` to reduce layers and clean up in the same layer. ALWAYS remove package manager caches.

### COPY --from (Multi-Stage Artifact Transfer)

```dockerfile
# Copy specific artifacts from build stage
COPY --from=build /app/target/app.jar ./app.jar
COPY --from=build /app/config/defaults.yaml ./config/

# Copy from external image
COPY --from=ghcr.io/grpc-ecosystem/grpc-health-probe:v0.4.25 \
  /ko-app/grpc-health-probe /usr/local/bin/grpc-health-probe
```

### HEALTHCHECK

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1
```

| Parameter | Default | Recommendation |
|-----------|---------|----------------|
| `--interval` | 30s | 30s for most workloads |
| `--timeout` | 30s | 5s (fail fast) |
| `--start-period` | 0s | Match app startup time (30-120s for JVM) |
| `--retries` | 3 | 3 (standard) |

**Rule:** EVERY Dockerfile MUST include a HEALTHCHECK. Use `wget` or `curl` (not both) for HTTP checks. For distroless images without shell tools, implement health check at the application level and use Kubernetes probes instead.

### OCI Labels

```dockerfile
LABEL org.opencontainers.image.title="my-app" \
      org.opencontainers.image.description="My Application Service" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.vendor="MyOrg" \
      org.opencontainers.image.source="https://github.com/myorg/my-app" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="MIT"
```

**Rule:** EVERY production image MUST include standard OCI labels for traceability. Use build arguments (`ARG`) for dynamic values like version, SHA, and build date.

## Dockerfile Rules Summary

| Rule | Standard |
|------|----------|
| Build | Multi-stage ALWAYS |
| User | Non-root (USER 1001), fixed UID/GID |
| Base image | Minimal (alpine, slim, distroless, scratch) |
| Versions | Pin ALL base images and package versions |
| Labels | Standard OCI labels (`org.opencontainers.image.*`) |
| Health check | HEALTHCHECK instruction in every Dockerfile |
| Secrets | NEVER baked into image; use build secrets (`--mount=type=secret`) |
| .dockerignore | MANDATORY for every project |
| Layer order | Least-changing first, dependencies before source |
| Package managers | NOT in final production images |
| Scanning | MANDATORY in CI (Trivy, Grype, or equivalent) |
| Debug tools | NOT in production images |
