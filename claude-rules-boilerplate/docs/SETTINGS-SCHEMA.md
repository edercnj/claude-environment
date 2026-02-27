# Settings-Templates JSON Schema

## Overview

The `settings-templates/` directory contains JSON configuration files that define which command patterns are permitted for different tools, languages, and platforms within the Claude Code environment. These settings are used to control and restrict what commands can be executed through the Bash tool during code generation and development workflows.

## Purpose

Settings templates serve several critical functions:

1. **Security**: Restrict command execution to safe, whitelisted patterns
2. **Automation**: Enable CLI tools to be invoked safely without manual verification
3. **Language/Framework Support**: Define the appropriate tools and commands for each technology stack
4. **Portability**: Ensure generated code respects environment-specific constraints

## File Organization

Settings templates follow a naming convention that indicates their purpose:

```
{category}-{specific}.json    or    {category}.json
```

Common categories:
- `base.json` - Core permissions available in all environments
- `database-{engine}.json` - Database-specific tools (mysql, psql, mongodb, etc.)
- `cache-{engine}.json` - Cache layer tools (redis, memcached, dragonfly)
- `{language}-{build-tool}.json` - Language-specific build tools (java-maven, python-pip, rust-cargo)
- `docker.json`, `kubernetes.json` - Container orchestration
- `testing-{framework}.json` - Testing tools (newman for API testing)

## Schema Structure

Each settings file contains a JSON array of allowed command patterns:

```json
[
  "Bash(pattern1)",
  "Bash(pattern2)",
  "WebSearch",
  "WebFetch(domain:example.com)"
]
```

### Array Elements

#### Type: String with Tool and Pattern

**Format:** `ToolName(pattern)` or just `ToolName`

**Components:**
- **Tool Name**: The name of the capability being enabled (e.g., `Bash`, `WebSearch`, `WebFetch`)
- **Pattern**: Optional pattern using glob-like syntax with wildcards (`*`)
- **Domain Restriction**: For WebFetch, domain whitelist in parentheses

**Examples:**

1. **Bash command pattern:**
   ```json
   "Bash(docker build *)"
   ```
   - Permits: `docker build -t myimage .`, `docker build --no-cache .`
   - Denies: `docker push myimage`, `docker run`

2. **Multi-word command pattern:**
   ```json
   "Bash(kubectl apply *)"
   ```
   - Permits: `kubectl apply -f deployment.yaml`
   - Denies: `kubectl delete`, `kubectl port-forward`

3. **Wildcard patterns:**
   ```json
   "Bash(git *)"
   ```
   - Permits any git subcommand

4. **Web capabilities:**
   ```json
   "WebSearch"
   ```
   - Permits general web search

5. **Domain-restricted fetch:**
   ```json
   "WebFetch(domain:github.com)"
   ```
   - Permits fetching from github.com only

## Common Settings Files

### base.json

Core Git and Web capabilities available everywhere:

```json
[
  "Bash(git *)",
  "Bash(gh pr *)",
  "Bash(gh issue *)",
  "Bash(gh repo *)",
  "Bash(curl *)",
  "Bash(chmod *)",
  "Bash(ls *)",
  "Bash(wc *)",
  "Bash(test *)",
  "Bash(command -v *)",
  "WebSearch",
  "WebFetch(domain:github.com)"
]
```

**Enables:**
- Git version control operations
- GitHub CLI for pull requests and issues
- Network requests with curl
- File operations and testing
- Web search and GitHub-specific web access

### docker.json

Docker container and compose operations:

```json
[
  "Bash(docker build *)",
  "Bash(docker compose *)",
  "Bash(docker run *)",
  "Bash(docker ps *)",
  "Bash(docker logs *)",
  "Bash(docker exec *)",
  "Bash(docker stop *)",
  "Bash(docker info *)"
]
```

**Enables:**
- Building container images
- Managing multi-container deployments
- Running and inspecting containers
- Viewing container logs and information

### kubernetes.json

Kubernetes cluster operations:

```json
[
  "Bash(kubectl apply *)",
  "Bash(kubectl get *)",
  "Bash(kubectl describe *)",
  "Bash(kubectl logs *)",
  "Bash(kubectl port-forward *)",
  "Bash(kubectl delete *)",
  "Bash(kubectl kustomize *)",
  "Bash(minikube *)"
]
```

**Enables:**
- Deploying manifests to Kubernetes
- Querying cluster resources
- Debugging pod issues
- Local development with Minikube

### java-maven.json

Java/Maven build environment:

```json
[
  "Bash(mvn *)",
  "Bash(java *)",
  "Bash(jar *)",
  "Bash(javap *)"
]
```

**Enables:**
- Building and testing Java projects
- Running Java applications
- Inspecting JAR contents

### database-psql.json

PostgreSQL database operations:

```json
[
  "Bash(psql *)"
]
```

**Similar files exist for:**
- `database-mysql.json` - MySQL operations
- `database-mongodb.json` - MongoDB operations
- `database-cassandra.json` - Cassandra operations
- `database-oracle.json` - Oracle operations

### cache-redis.json

Redis cache operations:

```json
[
  "Bash(redis-cli *)"
]
```

**Similar files exist for:**
- `cache-memcached.json` - Memcached operations
- `cache-dragonfly.json` - Dragonfly cache operations

## Composition

Settings files are composed together during setup to create a combined permission set based on the project configuration. For example, a project with:
- Language: Java with Maven
- Database: PostgreSQL
- Cache: Redis
- Container: Docker
- Orchestrator: Kubernetes

Would activate:
- `base.json`
- `java-maven.json`
- `database-psql.json`
- `cache-redis.json`
- `docker.json`
- `kubernetes.json`

The final permission set is the union of all activated files.

## Pattern Matching Rules

### Wildcard Semantics

The `*` wildcard matches any sequence of characters within a single command:

| Pattern | Matches | Denies |
|---------|---------|--------|
| `git *` | `git clone`, `git push`, `git log --oneline` | (nothing starting with `git ` matches) |
| `docker build *` | `docker build -t image .` | `docker run`, `docker push` |
| `kubectl apply *` | `kubectl apply -f file.yaml` | `kubectl delete`, `kubectl patch` |
| `Bash(ls *)` | `ls`, `ls -la`, `ls /home` | `cd`, `cat` |

### Exact Matching

Patterns without wildcards must match exactly:

| Pattern | Matches | Denies |
|---------|---------|--------|
| `WebSearch` | Web search requests | (nothing) |
| `WebFetch(domain:github.com)` | Fetches from github.com | Fetches from other domains |

### Multi-Flag Commands

Flags and options are included in the wildcard match:

```json
"Bash(docker run *)"
```

This permits:
- `docker run -it ubuntu bash`
- `docker run --rm -v /host:/container image`
- `docker run --env VAR=value image command`

## Design Principles

### 1. Principle of Least Privilege

Only enable command patterns that are necessary for the specific technology stack. Do not activate settings that are unused.

### 2. Command Scope

Each pattern should enable a functional capability, not a single command variant:
- Good: `Bash(git *)` enables all Git operations
- Overly specific: `Bash(git commit -m)` restricts to only this exact flag pattern

### 3. Domain Whitelisting

For external access (WebFetch), prefer domain whitelisting over allowing all domains:
- Good: `WebFetch(domain:github.com)` restricts to GitHub
- Risky: `WebFetch(domain:*)`

### 4. No Negative Patterns

Settings templates use only allow-lists, never deny-lists. This prevents accidental command injection through unexpected patterns.

## Adding New Settings

To add a new settings template for a tool or platform:

1. **Create the file** in `settings-templates/` with appropriate naming
2. **Define allowed patterns** as a JSON array of strings
3. **Document in this schema** the purpose and use cases
4. **Test with projects** that use the new tool
5. **Update setup.sh** if the new setting should be automatically included based on project configuration

Example structure for a new tool:

```json
[
  "Bash(new-tool subcommand1 *)",
  "Bash(new-tool subcommand2 *)",
  "WebFetch(domain:api.example.com)"
]
```

## Validation

All settings files must:
- Be valid JSON (parseable, no syntax errors)
- Contain an array of strings
- Use consistent pattern formatting
- Include only tool-pattern pairs that have been tested

Invalid settings files will prevent project setup from completing.

## Security Considerations

Settings templates control what can be executed in generated code. When configuring settings:

1. **Only enable necessary tools** for the project's technology stack
2. **Use specific domains** for WebFetch (never wildcard domains)
3. **Review patterns** before activating them - understand what commands they permit
4. **Keep settings minimal** - each pattern expands the attack surface
5. **Document custom patterns** if adding non-standard settings files

## Related Files

- `setup.sh` - Main setup script that activates settings based on project configuration
- `.claude/config.yaml` - Project configuration that determines which settings are activated
- Rules documents - Define architecture and coding standards that guide what commands are needed
