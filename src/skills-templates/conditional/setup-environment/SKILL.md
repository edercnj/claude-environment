---
name: setup-environment
description: "Skill: Dev Environment Setup — Sets up the local development environment including container orchestrator, database, and build tools."
allowed-tools: Bash, Read, Write
argument-hint: "[--start | --stop | --status | --build]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Dev Environment Setup

## Description

Manages the local development environment lifecycle. Handles starting/stopping the container orchestrator ({{ORCHESTRATOR}}), provisioning the database ({{DB_TYPE}}), building the application, and verifying health checks.

**Condition**: This skill applies when orchestrator is not "none".

## Prerequisites

- {{ORCHESTRATOR}} installed and accessible in PATH
- {{DB_TYPE}} client tools available (optional, for manual queries)
- {{BUILD_TOOL}} installed (for application builds)
- Container runtime (Docker or Podman) running

## Arguments

| Argument   | Description                                                        |
| ---------- | ------------------------------------------------------------------ |
| `--start`  | Starts orchestrator, builds image, deploys, and sets up networking |
| `--stop`   | Stops services, tears down containers, and cleans up               |
| `--status` | Shows running services, pods/containers, and health check results  |
| `--build`  | Rebuilds application image and restarts services                   |
| (none)     | Shows usage/help                                                   |

## Execution Flow

1. **Verify prerequisites** — Check that required tools are installed:
   - Run `which` or `command -v` for each required tool
   - Verify container runtime is running (`docker info` or `podman info`)
   - Report missing tools with installation instructions

2. **Execute requested operation**:

   **--start**:
   - Start {{ORCHESTRATOR}} (e.g., `minikube start`, `docker-compose up -d`)
   - Wait for orchestrator to be ready
   - Build application: `{{BUILD_COMMAND}}`
   - Build container image
   - Deploy application and dependencies ({{DB_TYPE}}, etc.)
   - Wait for all services to be healthy
   - Set up port-forwarding or networking as needed

   **--stop**:
   - Stop port-forwarding / networking
   - Tear down application and dependencies
   - Stop {{ORCHESTRATOR}} if applicable

   **--status**:
   - Show orchestrator status
   - List running services/pods/containers
   - Check health endpoints
   - Report database connectivity

   **--build**:
   - Rebuild application: `{{BUILD_COMMAND}}`
   - Rebuild container image
   - Rolling restart / redeploy
   - Wait for health checks to pass

3. **Report status** — After execution:
   - If successful: show access URLs (API, health, docs)
   - If failed: show error message and suggested fix

## Usage Examples

```
/setup-environment --start
/setup-environment --status
/setup-environment --build
/setup-environment --stop
```

## Troubleshooting

| Problem                  | Likely Cause                  | Solution                                    |
| ------------------------ | ----------------------------- | ------------------------------------------- |
| Orchestrator won't start | Container runtime not running | Start Docker/Podman first                   |
| Service CrashLoop        | Application error             | Check application logs                      |
| Image not found          | Image not built               | Run with `--build` flag                     |
| Port conflict            | Port already in use           | Stop conflicting service or change port     |
| Health check timeout     | Application still starting    | Wait 30s, then check logs                   |
| DB connection error      | Database not ready            | Check database container logs               |

## Helm Mode (when infrastructure.templating == helm)

**--start:**
1. Verify prerequisites: helm, kubectl
2. Build application: `{{BUILD_COMMAND}}`
3. Build container image: `docker build -t {{PROJECT_NAME}}:dev .`
4. Install/upgrade chart: `helm upgrade --install {{PROJECT_NAME}} ./chart -f chart/values-dev.yaml --wait --timeout 120s`
5. Wait for pods ready: `kubectl wait --for=condition=ready pod -l app={{PROJECT_NAME}} --timeout=120s`
6. Port-forward: `kubectl port-forward svc/{{PROJECT_NAME}} {{PORT}}:{{PORT}}`

**--stop:**
1. Stop port-forward
2. Uninstall chart: `helm uninstall {{PROJECT_NAME}}`

**--build:**
1. Build application
2. Rebuild image
3. Upgrade chart: `helm upgrade {{PROJECT_NAME}} ./chart -f chart/values-dev.yaml --wait`

**--status:**
1. `helm list` (show installed charts)
2. `helm status {{PROJECT_NAME}}`
3. `kubectl get pods -l app={{PROJECT_NAME}}`
4. Health check: `curl -s http://localhost:{{PORT}}/health`

## Related Files

- `scripts/dev-setup.sh` — Main setup script (if exists)
- Container orchestration manifests (k8s/, docker-compose.yml)
- Helm chart directory (chart/)
- Application configuration files
