---
name: infrastructure
description: "Infrastructure patterns: Docker multi-stage builds, Kubernetes manifests (cloud-agnostic), security context, 12-Factor App principles, graceful shutdown, resource management, and cloud-native design."
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Knowledge Pack: Infrastructure

## Purpose

Provides infrastructure and deployment patterns for {{LANGUAGE}} {{FRAMEWORK}}, enabling cloud-agnostic, cloud-native service deployment. Covers container best practices (multi-stage Docker), Kubernetes manifests (Kustomize-based), security hardening, 12-Factor compliance, health probes, graceful shutdown, resource management, and observability integration.

## Quick Reference (always in context)

See `references/infrastructure-principles.md` for the essential infrastructure summary (cloud-agnostic, IaC, health probes, graceful shutdown, security context).

## Detailed References

Read these files for comprehensive infrastructure guidance:

| Reference | Content |
|-----------|---------|
| `patterns/infrastructure/docker-multi-stage.md` | Multi-stage Dockerfile structure, build stage (dependencies, compilation), runtime stage (minimal image), optimization strategies, layer caching, base image selection |
| `patterns/infrastructure/container-security.md` | Non-root user (UID >= 1000), read-only filesystem, capability dropping, minimal base images, secret management (never bake secrets), image scanning and signing |
| `patterns/infrastructure/kubernetes-manifests.md` | YAML structure, Deployment vs StatefulSet, Service types, ConfigMap vs Secret, resource requests/limits, probes (liveness/readiness/startup), security context, labels, annotations |
| `patterns/infrastructure/kustomize-organization.md` | Directory structure (base vs overlays), patch strategies, environment-specific configuration, ConfigMap and Secret generation, image tagging, resource composition |
| `patterns/infrastructure/health-probes.md` | Liveness probe (process alive), readiness probe (dependencies OK), startup probe (initialization complete), probe timing per runtime, endpoint implementation, degradation reflection |
| `patterns/infrastructure/graceful-shutdown.md` | SIGTERM handling, drain in-flight requests, timeout budgets, preStop hooks, connection cleanup, database/broker disconnection, zero-downtime deployments |
| `patterns/infrastructure/resource-management.md` | CPU/memory requests and limits, QoS classes (Guaranteed, Burstable, BestEffort), vertical pod autoscaling, horizontal pod autoscaling (HPA) configuration |
| `patterns/infrastructure/cloud-native-principles.md` | 12-Factor App compliance checklist, statelessness verification, configuration externalization, backing services as resources, dev/prod parity, logs to stdout/stderr |
