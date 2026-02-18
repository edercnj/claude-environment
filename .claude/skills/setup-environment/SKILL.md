---
name: setup-environment
description: "Set up the local development environment: Minikube, Kustomize, PostgreSQL, Docker Compose, and Quarkus dev mode."
allowed-tools: Bash, Read, Write
argument-hint: "[--k8s | --compose | --quarkus]"
---

## Global Output Policy

- **Language**: English ONLY. (Ignore input language, always respond in English).
- **Tone**: Technical, Direct, and Concise.
- **Efficiency**: Remove all conversational fillers and greetings to save tokens.
- **Preservation**: All existing technical constraints below must be followed strictly.

# Skill: Dev Setup (Minikube + Kubernetes)

Manages the local development environment using Minikube and Kustomize.

## When to Use

- When the user asks to start/stop the local Kubernetes environment
- When they need to rebuild and redeploy on Minikube
- When they want to check environment status
- Triggers: "dev setup", "start minikube", "k8s local", "kubernetes dev", "deploy local"

## Arguments

| Argument   | Description                                                      |
| ---------- | ---------------------------------------------------------------- |
| `--start`  | Starts Minikube, builds image, deploys, and sets up port-forward |
| `--stop`   | Stops port-forwards, deletes namespace, and stops Minikube       |
| `--status` | Shows pods, services, and health checks                          |
| `--build`  | Rebuilds image and performs rolling restart                      |
| (none)     | Shows usage/help                                                 |

## Step 1 — Verify Prerequisites

Before running, verify that the required tools are installed:

- java 21+
- maven 3.9+
- docker
- minikube
- kubectl

Use the Bash tool to run: `which java mvn docker minikube kubectl`

## Step 2 — Execute Script

Run the script with the provided argument:

```bash
./scripts/dev-setup.sh {argument}
```

The script manages the entire lifecycle:

- `--start`: Starts Minikube -> enables addons -> builds image -> applies Kustomize -> waits for pods -> port-forward
- `--stop`: Stops port-forwards -> deletes namespace -> stops Minikube
- `--status`: Shows Minikube status -> pods -> services -> health checks
- `--build`: Rebuilds Maven + Docker -> rolling restart -> waits for rollout

## Step 3 — Report Status

After execution, report:

- If successful: access URLs (REST API, ISO 8583, Health, Swagger)
- If failed: error message and suggested fix

## Troubleshooting

| Problem              | Likely Cause                     | Solution                                         |
| -------------------- | -------------------------------- | ------------------------------------------------ |
| Minikube won't start | Docker is not running            | Run `docker ps` to check, start Docker Desktop   |
| Pod CrashLoopBackOff | Application error                | `kubectl -n bifrost-simulator logs <pod>`        |
| ImagePullBackOff     | Image does not exist in Minikube | `./scripts/dev-setup.sh --build`                 |
| Port-forward fails   | Pod is not ready                 | `kubectl -n bifrost-simulator get pods`          |
| Health check FAIL    | Application still starting       | Wait 30s, then try again                         |
| DB connection error  | PostgreSQL is not ready          | `kubectl -n bifrost-simulator logs postgresql-0` |

## Related Files

- `scripts/dev-setup.sh` — Main script
- `scripts/minikube-build.sh` — Build helper inside Minikube
- `k8s/overlays/dev/kustomization.yaml` — Development overlay
- `k8s/base/` — Base Kustomize manifests
- `.claude/rules/23-kubernetes.md` — Kubernetes rules
