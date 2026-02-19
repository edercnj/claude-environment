# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Comprehensive Restructuring (v3 config):** Rewrite `setup-config.example.yaml` from flat v2 (`project.type`) to semantic v3 (`architecture.style`, `interfaces[]`, `data.message_broker`, `observability`, `testing`) with backward-compatible v2 migration.
- **Cloud-Native Principles (`core/12`):** 12-Factor compliance checklist, Kubernetes health probes, graceful shutdown, configuration hierarchy, container best practices, service mesh awareness. Cross-references rules 08/09/10 without duplication.
- **Patterns Directory (22 files):** Architectural (hexagonal-architecture, cqrs, event-sourcing, modular-monolith), Microservice (saga, outbox, api-gateway, service-discovery, bulkhead, strangler-fig, idempotency), Resilience (circuit-breaker, retry-with-backoff, timeout-patterns, dead-letter-queue), Data (repository-pattern, unit-of-work, cache-aside, event-store), Integration (anti-corruption-layer, backend-for-frontend, adapter-pattern).
- **Protocols Directory (8 files):** REST (rest-conventions, openapi-conventions), gRPC (grpc-conventions, grpc-versioning), GraphQL (graphql-conventions), WebSocket (websocket-conventions), Event-Driven (event-conventions, broker-patterns).
- **Setup.sh v3 support:** Pattern/protocol assembly based on architecture style and interface types, new interactive prompts (architecture style, DDD, event-driven, interfaces, message broker, testing), backward-compatible v2 config migration with warnings.
- **Cross-references:** core/05 links to hexagonal-architecture pattern, core/06 links to all 6 protocol directories, core/09 links to 5 resilience pattern files.
- **Security layer expansion (10 files):** Application security (OWASP Top 10), cryptography (encryption/hashing/key management), pentest readiness, and 6 compliance frameworks (PCI-DSS, PCI-SSF, LGPD, GDPR, HIPAA, SOX). Base security rules always included; compliance frameworks conditionally selected via `security.compliance[]`.
- **Cloud provider knowledge packs (4 files):** AWS, Azure, GCP, OCI service mapping references. Not rules — reference documents mapping boilerplate concepts to provider-specific services. Selected via `cloud.provider`.
- **Infrastructure patterns expansion (12 files):** Kubernetes deployment/kustomize/helm patterns, Dockerfile multi-stage builds per language, container registry patterns, Terraform and Crossplane IaC references, API gateway patterns (Kong, Istio, AWS APIGW, Traefik).
- **API Gateway pattern:** Generic API gateway pattern document plus 4 implementation-specific knowledge packs.
- **Domain knowledge templates (10 files):** Open Banking (PIX/BACEN), Healthcare FHIR, Telecom TMF, Insurance ACORD, IoT Telemetry — each with domain-rules.md and domain-template.md.
- **YAML configuration expansion:** New sections for `security` (compliance, encryption, pentest), `cloud` (provider), `infrastructure` (templating, IaC, registry, API gateway, service mesh), and `domain` (template selection). Backward compatible with existing format.
- **setup.sh updates:** New assembly phases for security rules, cloud knowledge packs, infrastructure knowledge packs. Domain template selection from templates/domains/. Two new conditional skills (security-compliance-review, review-gateway). Auto-enforcement: PCI-DSS/HIPAA compliance forces encryption at rest.
- **Database References (22 files):** SQL (PostgreSQL, Oracle, MySQL/MariaDB), NoSQL (MongoDB, Cassandra/ScyllaDB), Cache (Redis, Dragonfly, Memcached). Each with types-and-conventions, migration-patterns, query-optimization. Shared common principles per category.
- **Cache support in config:** New `stack.cache.type` field supporting `redis`, `dragonfly`, `memcached`, or `none`.
- **Oracle and Cassandra database types:** `stack.database.type` now supports `oracle` and `cassandra` in addition to existing options.
- **Mongock migration tool:** `stack.database.migration` now supports `mongock` for MongoDB projects.
- **Settings fragments:** `database-oracle.json`, `database-mongodb.json`, `database-cassandra.json`, `cache-redis.json`, `cache-dragonfly.json`, `cache-memcached.json`.
- **Layer templates:** MongoDB Document, MongoDB Repository, Cassandra Entity, and Cache Adapter templates added to the `layer-templates` knowledge pack.
- **Database Engineer agent:** Expanded from 20-point to 30-point checklist covering SQL, NoSQL, and Cache-specific validations. Now activates when `database != "none"` OR `cache != "none"`.
- **Database patterns knowledge pack:** Restructured as a hub referencing `references/` directory. References are auto-selected by `setup.sh` based on database and cache type.
- **Version matrix:** Consolidated cross-reference of all databases, caches, and framework integrations.

### Fixed
- **macOS awk compatibility:** `parse_yaml_nested()` rewritten from BSD-awk-incompatible syntax to pure bash `while read` loop. Fixes nested YAML parsing on macOS.

## [0.1.0] - 2026-02-18

### Added
- **Core Layer (11 files):** Universal engineering principles — clean code, SOLID, testing, git workflow, hexagonal architecture, API design, security, observability, resilience, infrastructure, database. All technology-agnostic with pseudocode examples.
- **Profile: java21-quarkus (9 files):** CDI, Panache, RESTEasy Reactive, MicroProfile Fault Tolerance, SmallRye Health, OpenTelemetry direct, `@ConfigMapping`, `@RegisterForReflection`, Quarkus native build.
- **Profile: java21-spring-boot (9 files):** Spring DI, Spring Data JPA, `@RestController`/`@ControllerAdvice`, Resilience4j, Spring Boot Actuator, Micrometer + OTel bridge, `@ConfigurationProperties`, `@RegisterReflectionForBinding`, Spring AOT native build.
- **Templates (2 files):** Project identity template and domain template with placeholder syntax.
- **Domain Examples (3):** ISO 8583 authorizer (5 files), e-commerce API (2 files), SaaS multi-tenant (2 files).
- **Generator (`setup.sh`):** Interactive and config-file modes, assembles core + profile + domain template.
- **Documentation (4 files):** README, CONTRIBUTING, ANATOMY-OF-A-RULE, FAQ.
