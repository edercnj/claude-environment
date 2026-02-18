---
name: quarkus-patterns
description: "Quarkus framework patterns: dev mode, hot reload, CDI, configuration profiles, native build constraints. Referenced internally by agents needing Quarkus context."
user-invocable: false
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Quarkus Development Guide

## Description

Guide for developing with Quarkus in the context of the ISO 8583 authorizer simulator.

## Essential Commands

### Dev Mode (Hot Reload)

```bash
mvn quarkus:dev
```

Starts the server in development mode with automatic hot reload. Press `w` to toggle between options:

- `w` — watch mode (recompiles when changes are detected)
- `d` — debug mode
- `q` — quit

### Build

```bash
# Build JAR
mvn clean package

# Build Native (GraalVM) — requires GraalVM installation
mvn package -Dnative

# Build Docker image
mvn quarkus:image-build
```

### Native Build (Production)

```bash
# Native build in container (does not require local GraalVM)
mvn package -Dnative -Dquarkus.native.container-build=true

# Native build with specific Mandrel
mvn package -Dnative \
    -Dquarkus.native.container-build=true \
    -Dquarkus.native.builder-image=quay.io/quarkus/ubi-quarkus-mandrel-builder-image:jdk-21

# Run native binary locally
./target/*-runner

# Docker native build
docker build -f src/main/docker/Dockerfile.native -t authorizer-simulator:native .

# Test native compatibility (without compiling)
mvn verify -Dnative -Dquarkus.native.enabled=false -Dquarkus.test.native-image-profile=test
```

### Tests

```bash
# Unit tests only
mvn test

# Unit tests + integration tests
mvn verify

# Run tests with a specific profile
mvn test -Dquarkus.test.profile=test

# Run a specific test
mvn test -Dtest=TransactionRepositoryTest

# Run with coverage
mvn clean verify jacoco:report
```

## Configuration (application.properties)

### File Locations

- Dev: `src/main/resources/application-dev.properties`
- Test: `src/main/resources/application-test.properties`
- Prod: `src/main/resources/application.properties`

### Application

```properties
quarkus.application.name=authorizer-simulator
quarkus.application.version=${project.version}
quarkus.http.port=8080
quarkus.http.ssl.certificate.path=${SSL_CERT_PATH:}
```

### TCP Socket ISO 8583

```properties
simulator.socket.port=8583
simulator.socket.timeout=30
simulator.socket.max-connections=100
simulator.socket.read-timeout=35000
simulator.socket.write-timeout=5000
```

### PostgreSQL

```properties
quarkus.datasource.db-kind=postgresql
quarkus.datasource.jdbc.url=jdbc:postgresql://localhost:5432/simulator
quarkus.datasource.username=simulator
quarkus.datasource.password=simulator
quarkus.datasource.jdbc.min-size=5
quarkus.datasource.jdbc.max-size=20
quarkus.datasource.jdbc.acquisition-timeout=5S
quarkus.datasource.jdbc.idle-removal-interval=15M
```

### Hibernate ORM

```properties
quarkus.hibernate-orm.database.generation=none
quarkus.hibernate-orm.log.sql=false
quarkus.hibernate-orm.log.bind-parameters=false
quarkus.hibernate-orm.second-level-caching-enabled=false
quarkus.hibernate-orm.packages=com.bifrost.simulator.adapter.outbound.persistence.entity
```

### Flyway

```properties
quarkus.flyway.migrate-at-start=true
quarkus.flyway.locations=db/migration
quarkus.flyway.baseline-on-migrate=false
quarkus.flyway.clean-disabled=true
quarkus.flyway.repair-at-start=false
```

### Health Checks

```properties
quarkus.smallrye-health.root-path=/q/health
quarkus.smallrye-health.liveness-path=/q/health/live
quarkus.smallrye-health.readiness-path=/q/health/ready
quarkus.smallrye-health.startup-path=/q/health/started
```

### OpenTelemetry

```properties
quarkus.otel.enabled=true
quarkus.otel.exporter.otlp.endpoint=http://localhost:4317
quarkus.otel.service.name=authorizer-simulator
quarkus.otel.traces.enabled=true
quarkus.otel.metrics.enabled=true
quarkus.otel.logs.enabled=true
```

### Logging

```properties
quarkus.log.level=INFO
quarkus.log.console.format=%d{HH:mm:ss} %-5p [%c{2.}] %m%n
quarkus.log.file.enable=true
quarkus.log.file.path=logs/authorizer-simulator.log
quarkus.log.file.format=%d{yyyy-MM-dd HH:mm:ss} %-5p [%c{2.}] %m%n
```

### Validation

```properties
quarkus.hibernate-validator.expression-language-feature-level=intermediate
```

## Profiles

### Dev Profile

```properties
# src/main/resources/application-dev.properties
quarkus.log.level=DEBUG
quarkus.datasource.devservices.enabled=true
quarkus.hibernate-orm.log.sql=true
quarkus.hibernate-orm.log.bind-parameters=true
simulator.socket.port=8583
```

### Test Profile

```properties
# src/main/resources/application-test.properties
quarkus.log.level=WARN
quarkus.datasource.devservices.enabled=false
quarkus.datasource.db-kind=h2
quarkus.datasource.jdbc.url=jdbc:h2:mem:test
quarkus.datasource.username=sa
quarkus.datasource.password=
quarkus.hibernate-orm.database.generation=drop-and-create
quarkus.flyway.migrate-at-start=true
simulator.socket.port=18583
simulator.socket.timeout=5
```

### Prod Profile

```properties
# src/main/resources/application.properties
quarkus.log.level=INFO
quarkus.log.json.enabled=true
quarkus.log.json.pretty-print=false
quarkus.datasource.jdbc.url=${DB_URL:jdbc:postgresql://postgresql:5432/simulator}
quarkus.datasource.username=${DB_USER:simulator}
quarkus.datasource.password=${DB_PASSWORD:simulator}
simulator.socket.port=${SOCKET_PORT:8583}
simulator.socket.timeout=${SOCKET_TIMEOUT:30}
```

## Required Quarkus Extensions

Added to `pom.xml`:

```xml
<!-- REST API -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-rest-jackson</artifactId>
</dependency>

<!-- Database -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-hibernate-orm-panache</artifactId>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-jdbc-postgresql</artifactId>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-flyway</artifactId>
</dependency>

<!-- Networking -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-vertx</artifactId>
</dependency>

<!-- Observability (OpenTelemetry) -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-opentelemetry</artifactId>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-health</artifactId>
</dependency>

<!-- Validation -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-hibernate-validator</artifactId>
</dependency>

<!-- Testing -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>rest-assured</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>testcontainers</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>postgresql</artifactId>
    <scope>test</scope>
</dependency>
```

## Hot Reload Workflow

1. Start dev mode: `mvn quarkus:dev`
2. Modify a Java file (class, resource, etc.)
3. Save the file
4. Quarkus detects the change and recompiles automatically
5. Server restarts with the new code
6. Access `http://localhost:8080/api/v1/health` to verify

## Debugging

In dev mode, press `d` to enter debug mode. The server will wait for a debugger connection.

With IDE (IntelliJ, VS Code):

1. Configure "Debug" for localhost:5005 (remote debugger)
2. Press `d` in the Quarkus console
3. Click "Debug" in the IDE

## Environment Variables

Configurations can be overridden with environment variables:

```bash
export DB_URL=jdbc:postgresql://my-postgres:5432/simulator
export DB_USER=admin
export DB_PASSWORD=secret
export SOCKET_PORT=9583
export SOCKET_TIMEOUT=60

mvn quarkus:dev
```

## Troubleshooting

### Port already in use

```bash
# Change port temporarily
mvn quarkus:dev -Dquarkus.http.port=8081
```

### PostgreSQL not connecting

```bash
# Check if PostgreSQL is running
psql -h localhost -U simulator -d simulator

# If not, start with Docker
docker run --name postgres -e POSTGRES_PASSWORD=simulator -e POSTGRES_DB=simulator -p 5432:5432 postgres:16
```

### Flyway migration fails

```bash
# Clean schema and recreate
mvn flyway:clean flyway:migrate

# (Dev/test only, never in production!)
```

### Hot reload not working

```bash
# Restart dev mode
# Press Ctrl+C to stop
# mvn quarkus:dev again
```
