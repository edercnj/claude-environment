# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
