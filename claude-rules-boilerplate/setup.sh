#!/usr/bin/env bash
set -euo pipefail

# Claude Code Boilerplate — Complete .claude/ Directory Generator
# Assembles .claude/ with rules, skills, agents, hooks, settings.json, and README.md.
#
# Usage:
#   ./setup.sh                          # Interactive mode
#   ./setup.sh --config setup-config.yaml  # Config file mode
#   ./setup.sh --config setup-config.yaml --output /path/to/project/.claude/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="${SCRIPT_DIR}/core"
PROFILES_DIR="${SCRIPT_DIR}/profiles"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
SKILLS_TEMPLATES_DIR="${SCRIPT_DIR}/skills-templates"
AGENTS_TEMPLATES_DIR="${SCRIPT_DIR}/agents-templates"
HOOKS_TEMPLATES_DIR="${SCRIPT_DIR}/hooks-templates"
SETTINGS_TEMPLATES_DIR="${SCRIPT_DIR}/settings-templates"
README_TEMPLATE="${SCRIPT_DIR}/readme-template.md"

# Defaults
CONFIG_FILE=""
OUTPUT_DIR=""
INTERACTIVE=true

# Resolved values (set by resolve_stack_commands)
COMPILE_COMMAND=""
BUILD_COMMAND=""
TEST_COMMAND=""
COVERAGE_COMMAND=""
FILE_EXTENSION=""
HOOK_TEMPLATE_KEY=""
SETTINGS_LANG_KEY=""
BUILD_TOOL=""
DEVELOPER_AGENT_KEY=""

# Protocols (parsed from config or interactive)
PROTOCOLS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Claude Code Boilerplate — Complete .claude/ Directory Generator"
            echo ""
            echo "Usage:"
            echo "  ./setup.sh                                    Interactive mode"
            echo "  ./setup.sh --config <file>                    Config file mode"
            echo "  ./setup.sh --config <file> --output <dir>     Config + custom output"
            echo ""
            echo "Options:"
            echo "  --config <file>    Path to setup-config.yaml"
            echo "  --output <dir>     Output directory (default: ./.claude/)"
            echo "  --help, -h         Show this help"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            exit 1
            ;;
    esac
done

# ─── Helper Functions ────────────────────────────────────────────────────────

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required tool not found: $1"
        exit 1
    fi
}

prompt_select() {
    local prompt="$1"
    shift
    local options=("$@")
    echo -e "${YELLOW}${prompt}${NC}"
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}"
    done
    while true; do
        read -rp "Select [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            echo "${options[$((choice-1))]}"
            return
        fi
        echo "Invalid selection. Try again."
    done
}

prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    if [[ -n "$default" ]]; then
        read -rp "$(echo -e "${YELLOW}${prompt}${NC} [${default}]: ")" value
        echo "${value:-$default}"
    else
        read -rp "$(echo -e "${YELLOW}${prompt}${NC}: ")" value
        echo "$value"
    fi
}

prompt_yesno() {
    local prompt="$1"
    local default="${2:-y}"
    read -rp "$(echo -e "${YELLOW}${prompt}${NC} [${default}]: ")" value
    value="${value:-$default}"
    [[ "$value" =~ ^[Yy] ]]
}

# Replace all {{PLACEHOLDER}} occurrences in a file
replace_placeholders() {
    local file="$1"
    sed -i.bak \
        -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
        -e "s|{{PROJECT_TYPE}}|${PROJECT_TYPE}|g" \
        -e "s|{{PROJECT_PURPOSE}}|${PROJECT_PURPOSE}|g" \
        -e "s|{{LANGUAGE}}|${LANGUAGE}|g" \
        -e "s|{{FRAMEWORK}}|${FRAMEWORK}|g" \
        -e "s|{{DB_TYPE}}|${DB_TYPE}|g" \
        -e "s|{{DB_MIGRATION}}|${DB_MIGRATION}|g" \
        -e "s|{{ARCHITECTURE}}|${ARCHITECTURE}|g" \
        -e "s|{{CONTAINER}}|${CONTAINER}|g" \
        -e "s|{{ORCHESTRATOR}}|${ORCHESTRATOR}|g" \
        -e "s|{{OBSERVABILITY}}|${OBSERVABILITY}|g" \
        -e "s|{{COMPILE_COMMAND}}|${COMPILE_COMMAND}|g" \
        -e "s|{{BUILD_COMMAND}}|${BUILD_COMMAND}|g" \
        -e "s|{{TEST_COMMAND}}|${TEST_COMMAND}|g" \
        -e "s|{{COVERAGE_COMMAND}}|${COVERAGE_COMMAND}|g" \
        -e "s|{{FILE_EXTENSION}}|${FILE_EXTENSION}|g" \
        -e "s|{{PROFILE}}|${PROFILE}|g" \
        -e "s|{{BUILD_TOOL}}|${BUILD_TOOL:-}|g" \
        "$file"
    rm -f "${file}.bak"
}

# Check if a value is in an array
array_contains() {
    local value="$1"
    shift
    for item in "$@"; do
        [[ "$item" == "$value" ]] && return 0
    done
    return 1
}

# ─── Config File Parsing ─────────────────────────────────────────────────────

parse_yaml_value() {
    local file="$1"
    local key="$2"
    local section="${3:-}"
    local raw_line
    if [[ -n "$section" ]]; then
        # Extract value under a specific section (e.g., database.type)
        raw_line=$(awk "BEGIN{found=0} /^${section}:/{found=1; next} found && /^[^ ]/{exit} found && /${key}:/{print; exit}" "$file")
    else
        raw_line=$(grep -E "^[[:space:]]*${key}:" "$file" | head -1)
    fi
    echo "$raw_line" \
        | sed 's/[^:]*:[[:space:]]*//' \
        | sed 's/[[:space:]]*#.*$//' \
        | sed 's/^"\(.*\)"$/\1/' \
        | sed "s/^'\(.*\)'$/\1/" \
        | xargs
}

# Parse a value nested 2 levels deep: section.subsection.key
# Example: parse_yaml_nested config.yaml "stack" "database" "type"
parse_yaml_nested() {
    local file="$1"
    local section="$2"
    local subsection="$3"
    local key="$4"
    local raw_line
    raw_line=$(awk -v sec="$section" -v sub="$subsection" -v k="$key" '
        BEGIN { in_sec=0; in_sub=0 }
        $0 ~ "^"sec":" { in_sec=1; next }
        in_sec && /^[^ ]/ { in_sec=0; in_sub=0 }
        in_sec && $0 ~ "^  "sub":" { in_sub=1; next }
        in_sec && in_sub && /^  [^ ]/ && !/^    / { in_sub=0 }
        in_sec && in_sub && $0 ~ k":" { print; exit }
    ' "$file")
    echo "$raw_line" \
        | sed 's/[^:]*:[[:space:]]*//' \
        | sed 's/[[:space:]]*#.*$//' \
        | sed 's/^"\(.*\)"$/\1/' \
        | sed "s/^'\(.*\)'$/\1/" \
        | xargs
}

parse_yaml_list() {
    local file="$1"
    local key="$2"
    awk "BEGIN{found=0} /^[[:space:]]*${key}:/{found=1; next} found && /^[[:space:]]*-/{print; next} found{exit}" "$file" \
        | sed 's/[[:space:]]*#.*$//' \
        | sed 's/^[[:space:]]*-[[:space:]]*//' \
        | sed 's/^"\(.*\)"$/\1/' \
        | sed "s/^'\(.*\)'$/\1/" \
        | xargs -L1
}

# ─── Stack Resolution ────────────────────────────────────────────────────────

resolve_stack_commands() {
    case "${LANGUAGE}" in
        java21)
            FILE_EXTENSION=".java"
            DEVELOPER_AGENT_KEY="java"
            case "${FRAMEWORK}" in
                quarkus|spring-boot)
                    COMPILE_COMMAND="mvn compile -q"
                    BUILD_COMMAND="mvn package -DskipTests"
                    TEST_COMMAND="mvn verify"
                    COVERAGE_COMMAND="mvn verify jacoco:report"
                    BUILD_TOOL="Maven"
                    HOOK_TEMPLATE_KEY="java-maven"
                    SETTINGS_LANG_KEY="java-maven"
                    ;;
            esac
            ;;
        kotlin)
            FILE_EXTENSION=".kt"
            DEVELOPER_AGENT_KEY="kotlin"
            COMPILE_COMMAND="gradle compileKotlin -q"
            BUILD_COMMAND="gradle build -x test"
            TEST_COMMAND="gradle test"
            COVERAGE_COMMAND="gradle test jacocoTestReport"
            BUILD_TOOL="Gradle"
            HOOK_TEMPLATE_KEY="kotlin"
            SETTINGS_LANG_KEY="java-gradle"
            ;;
        typescript)
            FILE_EXTENSION=".ts"
            DEVELOPER_AGENT_KEY="typescript"
            COMPILE_COMMAND="npx tsc --noEmit"
            BUILD_COMMAND="npm run build"
            TEST_COMMAND="npm test"
            COVERAGE_COMMAND="npm test -- --coverage"
            BUILD_TOOL="npm"
            HOOK_TEMPLATE_KEY="typescript"
            SETTINGS_LANG_KEY="typescript-npm"
            ;;
        python)
            FILE_EXTENSION=".py"
            DEVELOPER_AGENT_KEY="python"
            COMPILE_COMMAND="python3 -m py_compile"
            BUILD_COMMAND="pip install -e ."
            TEST_COMMAND="pytest"
            COVERAGE_COMMAND="pytest --cov"
            BUILD_TOOL="pip"
            HOOK_TEMPLATE_KEY=""  # No compile hook for Python
            SETTINGS_LANG_KEY="python-pip"
            ;;
        go)
            FILE_EXTENSION=".go"
            DEVELOPER_AGENT_KEY="go"
            COMPILE_COMMAND="go build ./..."
            BUILD_COMMAND="go build ./..."
            TEST_COMMAND="go test ./..."
            COVERAGE_COMMAND="go test -coverprofile=coverage.out ./..."
            BUILD_TOOL="go"
            HOOK_TEMPLATE_KEY="go"
            SETTINGS_LANG_KEY="go"
            ;;
        rust)
            FILE_EXTENSION=".rs"
            DEVELOPER_AGENT_KEY="rust"
            COMPILE_COMMAND="cargo check"
            BUILD_COMMAND="cargo build"
            TEST_COMMAND="cargo test"
            COVERAGE_COMMAND="cargo tarpaulin"
            BUILD_TOOL="Cargo"
            HOOK_TEMPLATE_KEY="rust"
            SETTINGS_LANG_KEY="rust-cargo"
            ;;
        csharp)
            FILE_EXTENSION=".cs"
            DEVELOPER_AGENT_KEY="csharp"
            COMPILE_COMMAND="dotnet build --no-restore -q"
            BUILD_COMMAND="dotnet build"
            TEST_COMMAND="dotnet test"
            COVERAGE_COMMAND="dotnet test --collect:\"XPlat Code Coverage\""
            BUILD_TOOL="dotnet"
            HOOK_TEMPLATE_KEY="csharp"
            SETTINGS_LANG_KEY="csharp-dotnet"
            ;;
    esac
}

# ─── Interactive Mode ─────────────────────────────────────────────────────────

run_interactive() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Claude Code Boilerplate — Project Setup     ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""

    PROJECT_NAME=$(prompt_input "Project name" "my-project")
    PROJECT_TYPE=$(prompt_select "Project type:" "api" "cli" "library" "worker" "fullstack")
    PROJECT_PURPOSE=$(prompt_input "Brief project purpose")

    LANGUAGE=$(prompt_select "Language:" "java21" "typescript" "python" "go" "kotlin" "rust" "csharp")

    case "$LANGUAGE" in
        java21)   FRAMEWORK=$(prompt_select "Framework:" "quarkus" "spring-boot") ;;
        typescript) FRAMEWORK=$(prompt_select "Framework:" "nestjs" "express" "fastify") ;;
        python)   FRAMEWORK=$(prompt_select "Framework:" "fastapi" "django" "flask") ;;
        go)       FRAMEWORK=$(prompt_select "Framework:" "stdlib" "gin" "fiber") ;;
        kotlin)   FRAMEWORK=$(prompt_select "Framework:" "ktor" "spring-boot") ;;
        rust)     FRAMEWORK=$(prompt_select "Framework:" "axum" "actix") ;;
        csharp)   FRAMEWORK="dotnet" ;;
    esac

    DB_TYPE=$(prompt_select "Database:" "postgresql" "mysql" "mongodb" "sqlite" "none")

    if [[ "$DB_TYPE" != "none" ]]; then
        case "$LANGUAGE" in
            java21|kotlin) DB_MIGRATION=$(prompt_select "Migration tool:" "flyway" "liquibase" "none") ;;
            typescript) DB_MIGRATION=$(prompt_select "Migration tool:" "prisma" "none") ;;
            python) DB_MIGRATION=$(prompt_select "Migration tool:" "alembic" "none") ;;
            *) DB_MIGRATION="none" ;;
        esac
    else
        DB_MIGRATION="none"
    fi

    ARCHITECTURE=$(prompt_select "Architecture:" "hexagonal" "clean" "layered" "modular")

    # Protocols
    PROTOCOLS=("rest")
    echo -e "${YELLOW}Additional protocols (rest is always included):${NC}"
    prompt_yesno "  Add gRPC?" "n" && PROTOCOLS+=("grpc")
    prompt_yesno "  Add GraphQL?" "n" && PROTOCOLS+=("graphql")
    prompt_yesno "  Add WebSocket?" "n" && PROTOCOLS+=("websocket")
    prompt_yesno "  Add TCP custom?" "n" && PROTOCOLS+=("tcp-custom")

    CONTAINER=$(prompt_select "Container runtime:" "docker" "podman" "none")
    ORCHESTRATOR=$(prompt_select "Orchestrator:" "kubernetes" "docker-compose" "none")
    OBSERVABILITY=$(prompt_select "Observability:" "opentelemetry" "datadog" "prometheus-only" "none")

    NATIVE_BUILD=false
    if [[ "$LANGUAGE" == "java21" && "$FRAMEWORK" == "quarkus" ]] || [[ "$LANGUAGE" == "go" ]] || [[ "$LANGUAGE" == "rust" ]]; then
        prompt_yesno "Enable native build?" "y" && NATIVE_BUILD=true
    fi

    RESILIENCE=false
    prompt_yesno "Enable resilience patterns?" "y" && RESILIENCE=true

    SMOKE_TESTS=false
    prompt_yesno "Enable smoke tests?" "y" && SMOKE_TESTS=true

    PROFILE="${LANGUAGE}-${FRAMEWORK}"
}

# ─── Config File Mode ─────────────────────────────────────────────────────────

run_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi

    PROJECT_NAME=$(parse_yaml_value "$CONFIG_FILE" "name" "project")
    PROJECT_TYPE=$(parse_yaml_value "$CONFIG_FILE" "type" "project")
    PROJECT_PURPOSE=$(parse_yaml_value "$CONFIG_FILE" "purpose" "project")
    LANGUAGE=$(parse_yaml_value "$CONFIG_FILE" "language" "project")
    FRAMEWORK=$(parse_yaml_value "$CONFIG_FILE" "framework" "project")

    # Support both new (hierarchical under stack:) and old (flat) YAML formats
    DB_TYPE=$(parse_yaml_nested "$CONFIG_FILE" "stack" "database" "type")
    [[ -z "$DB_TYPE" ]] && DB_TYPE=$(parse_yaml_value "$CONFIG_FILE" "type" "database")
    DB_MIGRATION=$(parse_yaml_nested "$CONFIG_FILE" "stack" "database" "migration")
    [[ -z "$DB_MIGRATION" ]] && DB_MIGRATION=$(parse_yaml_value "$CONFIG_FILE" "migration" "database")

    # Architecture: new format under project:, old format as top-level
    ARCHITECTURE=$(parse_yaml_value "$CONFIG_FILE" "architecture" "project")
    [[ -z "$ARCHITECTURE" ]] && ARCHITECTURE=$(parse_yaml_value "$CONFIG_FILE" "architecture")

    CONTAINER=$(parse_yaml_nested "$CONFIG_FILE" "stack" "infrastructure" "container")
    [[ -z "$CONTAINER" ]] && CONTAINER=$(parse_yaml_value "$CONFIG_FILE" "container" "infrastructure")
    ORCHESTRATOR=$(parse_yaml_nested "$CONFIG_FILE" "stack" "infrastructure" "orchestrator")
    [[ -z "$ORCHESTRATOR" ]] && ORCHESTRATOR=$(parse_yaml_value "$CONFIG_FILE" "orchestrator" "infrastructure")
    OBSERVABILITY=$(parse_yaml_nested "$CONFIG_FILE" "stack" "infrastructure" "observability")
    [[ -z "$OBSERVABILITY" ]] && OBSERVABILITY=$(parse_yaml_value "$CONFIG_FILE" "observability" "infrastructure")

    # native_build: new format under stack.java:, old format under options:
    NATIVE_BUILD=$(parse_yaml_nested "$CONFIG_FILE" "stack" "java" "native_build")
    [[ -z "$NATIVE_BUILD" ]] && NATIVE_BUILD=$(parse_yaml_value "$CONFIG_FILE" "native_build" "options")
    # native_build only applies to JVM languages
    if [[ ! "$LANGUAGE" =~ ^(java21|kotlin)$ ]]; then
        NATIVE_BUILD="false"
    fi

    RESILIENCE=$(parse_yaml_value "$CONFIG_FILE" "resilience" "stack")
    [[ -z "$RESILIENCE" ]] && RESILIENCE=$(parse_yaml_value "$CONFIG_FILE" "resilience" "options")
    SMOKE_TESTS=$(parse_yaml_value "$CONFIG_FILE" "smoke_tests" "stack")
    [[ -z "$SMOKE_TESTS" ]] && SMOKE_TESTS=$(parse_yaml_value "$CONFIG_FILE" "smoke_tests" "options")

    # Parse protocols list
    local proto_list
    proto_list=$(parse_yaml_list "$CONFIG_FILE" "protocols")
    if [[ -n "$proto_list" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && PROTOCOLS+=("$line")
        done <<< "$proto_list"
    fi
    # Default to rest if empty
    if [[ ${#PROTOCOLS[@]} -eq 0 ]]; then
        PROTOCOLS=("rest")
    fi

    PROFILE="${LANGUAGE}-${FRAMEWORK}"

    log_info "Loaded config from: $CONFIG_FILE"
}

# ─── Phase 1: Assemble Rules ─────────────────────────────────────────────────

assemble_rules() {
    local rules_dir="${OUTPUT_DIR}/rules"
    local profile_dir="${PROFILES_DIR}/${PROFILE}"

    mkdir -p "$rules_dir"

    # Validate profile exists
    if [[ ! -d "$profile_dir" ]]; then
        log_warn "Profile not found: ${PROFILE}"
        log_info "Available profiles:"
        ls -1 "$PROFILES_DIR" 2>/dev/null || echo "  (none)"
        log_info "Core rules will still be copied."
        profile_dir=""
    fi

    # Copy Core (01-11)
    log_info "Copying core rules..."
    for core_file in "$CORE_DIR"/*.md; do
        if [[ -f "$core_file" ]]; then
            local basename
            basename=$(basename "$core_file")
            cp "$core_file" "${rules_dir}/${basename}"
            log_success "  ${basename}"
        fi
    done

    # Copy Profile (20-29)
    if [[ -n "$profile_dir" ]]; then
        log_info "Copying profile: ${PROFILE}..."
        local profile_num=20
        for profile_file in "$profile_dir"/*.md; do
            if [[ -f "$profile_file" ]]; then
                local basename
                basename=$(basename "$profile_file")
                local target_name
                target_name=$(printf "%02d-%s" "$profile_num" "$basename")
                cp "$profile_file" "${rules_dir}/${target_name}"
                log_success "  ${target_name}"
                profile_num=$((profile_num + 1))
            fi
        done
    fi

    # Generate Project Identity (30)
    log_info "Generating project identity..."
    generate_project_identity "${rules_dir}"
    log_success "  30-project-identity.md"

    # Copy Domain Template (31)
    log_info "Copying domain template..."
    cp "${TEMPLATES_DIR}/domain-template.md" "${rules_dir}/31-domain.md"
    log_success "  31-domain.md (template — customize for your domain)"
}

generate_project_identity() {
    local rules_dir="$1"
    cat > "${rules_dir}/30-project-identity.md" <<HEREDOC
# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Project Identity — ${PROJECT_NAME}

## Identity
- **Name:** ${PROJECT_NAME}
- **Type:** ${PROJECT_TYPE}
- **Purpose:** ${PROJECT_PURPOSE}
- **Language:** ${LANGUAGE}
- **Framework:** ${FRAMEWORK}
- **Database:** ${DB_TYPE}
- **Architecture:** ${ARCHITECTURE}

## Technology Stack
| Layer | Technology |
|-------|-----------|
| Language | ${LANGUAGE} |
| Framework | ${FRAMEWORK} |
| Database | ${DB_TYPE} |
| Migration | ${DB_MIGRATION} |
| Container | ${CONTAINER} |
| Orchestrator | ${ORCHESTRATOR} |
| Observability | ${OBSERVABILITY} |

## Options
| Option | Enabled |
|--------|:-------:|
| Native Build | ${NATIVE_BUILD} |
| Resilience | ${RESILIENCE} |
| Smoke Tests | ${SMOKE_TESTS} |

## Source of Truth (Hierarchy)
1. Epics / PRDs (vision and global rules)
2. ADRs (architectural decisions)
3. Stories / tickets (detailed requirements)
4. Rules (.claude/rules/)
5. Source code

## Language
- Code: English (classes, methods, variables)
- Commits: English (Conventional Commits)
- Documentation: English (customize as needed)
- Application logs: English

## Constraints
<!-- Customize constraints for your project -->
- Cloud-Agnostic: ZERO dependencies on cloud-specific services
- Horizontal scalability: Application must be stateless
- Externalized configuration: All configuration via environment variables or ConfigMaps
HEREDOC
}

# ─── Phase 2: Assemble Skills ────────────────────────────────────────────────

assemble_skills() {
    local skills_dir="${OUTPUT_DIR}/skills"
    mkdir -p "$skills_dir"

    if [[ ! -d "$SKILLS_TEMPLATES_DIR" ]]; then
        log_warn "Skills templates directory not found, skipping skills."
        return
    fi

    # Copy core skills (always included)
    if [[ -d "${SKILLS_TEMPLATES_DIR}/core" ]]; then
        log_info "Copying core skills..."
        for skill_dir in "${SKILLS_TEMPLATES_DIR}/core"/*/; do
            if [[ -d "$skill_dir" ]]; then
                local skill_name
                skill_name=$(basename "$skill_dir")
                mkdir -p "${skills_dir}/${skill_name}"
                cp -r "${skill_dir}"* "${skills_dir}/${skill_name}/"
                replace_placeholders "${skills_dir}/${skill_name}/SKILL.md"
                log_success "  ${skill_name}"
            fi
        done
    fi

    # Copy conditional skills (feature-gated)
    if [[ -d "${SKILLS_TEMPLATES_DIR}/conditional" ]]; then
        log_info "Copying conditional skills..."

        # review-api: requires "rest" in protocols
        if array_contains "rest" "${PROTOCOLS[@]}"; then
            copy_conditional_skill "review-api"
        fi

        # instrument-otel: requires observability != "none"
        if [[ "$OBSERVABILITY" != "none" ]]; then
            copy_conditional_skill "instrument-otel"
        fi

        # setup-environment: requires orchestrator != "none"
        if [[ "$ORCHESTRATOR" != "none" ]]; then
            copy_conditional_skill "setup-environment"
        fi

        # run-smoke-api: requires smoke_tests + rest
        if [[ "$SMOKE_TESTS" == "true" ]] && array_contains "rest" "${PROTOCOLS[@]}"; then
            copy_conditional_skill "run-smoke-api"
        fi

        # run-smoke-socket: requires smoke_tests + tcp-custom
        if [[ "$SMOKE_TESTS" == "true" ]] && array_contains "tcp-custom" "${PROTOCOLS[@]}"; then
            copy_conditional_skill "run-smoke-socket"
        fi

        # run-e2e: always available
        copy_conditional_skill "run-e2e"

        # run-perf-test: always available
        copy_conditional_skill "run-perf-test"
    fi

    # Copy knowledge packs
    if [[ -d "${SKILLS_TEMPLATES_DIR}/knowledge-packs" ]]; then
        log_info "Copying knowledge packs..."

        # layer-templates: always included
        copy_knowledge_pack "layer-templates"

        # database-patterns: requires database != "none"
        if [[ "$DB_TYPE" != "none" ]]; then
            copy_knowledge_pack "database-patterns"
        fi

        # stack-patterns: one per profile
        local stack_pack=""
        case "$FRAMEWORK" in
            quarkus) stack_pack="quarkus-patterns" ;;
            spring-boot) stack_pack="spring-patterns" ;;
        esac
        if [[ -n "$stack_pack" ]] && [[ -d "${SKILLS_TEMPLATES_DIR}/knowledge-packs/stack-patterns/${stack_pack}" ]]; then
            mkdir -p "${skills_dir}/${stack_pack}"
            cp -r "${SKILLS_TEMPLATES_DIR}/knowledge-packs/stack-patterns/${stack_pack}"/* "${skills_dir}/${stack_pack}/"
            if [[ -f "${skills_dir}/${stack_pack}/SKILL.md" ]]; then
                replace_placeholders "${skills_dir}/${stack_pack}/SKILL.md"
            fi
            log_success "  ${stack_pack} (knowledge pack)"
        fi
    fi
}

copy_conditional_skill() {
    local skill_name="$1"
    local src="${SKILLS_TEMPLATES_DIR}/conditional/${skill_name}"
    local dest="${OUTPUT_DIR}/skills/${skill_name}"
    if [[ -d "$src" ]]; then
        mkdir -p "$dest"
        cp -r "${src}"/* "$dest/"
        if [[ -f "${dest}/SKILL.md" ]]; then
            replace_placeholders "${dest}/SKILL.md"
        fi
        log_success "  ${skill_name}"
    fi
}

copy_knowledge_pack() {
    local pack_name="$1"
    local src="${SKILLS_TEMPLATES_DIR}/knowledge-packs/${pack_name}"
    local dest="${OUTPUT_DIR}/skills/${pack_name}"
    if [[ -d "$src" ]]; then
        mkdir -p "$dest"
        cp -r "${src}"/* "$dest/"
        if [[ -f "${dest}/SKILL.md" ]]; then
            replace_placeholders "${dest}/SKILL.md"
        fi
        log_success "  ${pack_name} (knowledge pack)"
    fi
}

# ─── Phase 3: Assemble Agents ────────────────────────────────────────────────

assemble_agents() {
    local agents_dir="${OUTPUT_DIR}/agents"
    mkdir -p "$agents_dir"

    if [[ ! -d "$AGENTS_TEMPLATES_DIR" ]]; then
        log_warn "Agents templates directory not found, skipping agents."
        return
    fi

    # Copy core agents (always included)
    if [[ -d "${AGENTS_TEMPLATES_DIR}/core" ]]; then
        log_info "Copying core agents..."
        for agent_file in "${AGENTS_TEMPLATES_DIR}/core"/*.md; do
            if [[ -f "$agent_file" ]]; then
                local basename
                basename=$(basename "$agent_file")
                cp "$agent_file" "${agents_dir}/${basename}"
                replace_placeholders "${agents_dir}/${basename}"
                log_success "  ${basename}"
            fi
        done
    fi

    # Copy conditional agents (feature-gated)
    if [[ -d "${AGENTS_TEMPLATES_DIR}/conditional" ]]; then
        log_info "Copying conditional agents..."

        # database-engineer: requires database != "none" (planning + review)
        if [[ "$DB_TYPE" != "none" ]]; then
            copy_conditional_agent "database-engineer.md"
        fi

        # observability-engineer: requires observability != "none"
        if [[ "$OBSERVABILITY" != "none" ]]; then
            copy_conditional_agent "observability-engineer.md"
        fi

        # devops-engineer: requires container or orchestrator != "none"
        if [[ "$CONTAINER" != "none" ]] || [[ "$ORCHESTRATOR" != "none" ]]; then
            copy_conditional_agent "devops-engineer.md"
        fi

        # api-engineer: requires "rest" in protocols
        if array_contains "rest" "${PROTOCOLS[@]}"; then
            copy_conditional_agent "api-engineer.md"
        fi
    fi

    # Copy developer agent (one per language)
    if [[ -d "${AGENTS_TEMPLATES_DIR}/developers" ]]; then
        log_info "Copying developer agent..."
        local dev_file="${AGENTS_TEMPLATES_DIR}/developers/${DEVELOPER_AGENT_KEY}-developer.md"
        if [[ -f "$dev_file" ]]; then
            cp "$dev_file" "${agents_dir}/${DEVELOPER_AGENT_KEY}-developer.md"
            replace_placeholders "${agents_dir}/${DEVELOPER_AGENT_KEY}-developer.md"
            log_success "  ${DEVELOPER_AGENT_KEY}-developer.md"
        else
            log_warn "Developer agent not found: ${DEVELOPER_AGENT_KEY}-developer.md"
        fi
    fi
}

copy_conditional_agent() {
    local agent_file="$1"
    local src="${AGENTS_TEMPLATES_DIR}/conditional/${agent_file}"
    local dest="${OUTPUT_DIR}/agents/${agent_file}"
    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        replace_placeholders "$dest"
        log_success "  ${agent_file}"
    fi
}

# ─── Phase 4: Assemble Hooks ─────────────────────────────────────────────────

assemble_hooks() {
    # Only for compiled languages with a hook template
    if [[ -z "$HOOK_TEMPLATE_KEY" ]]; then
        log_info "No compile hook for ${LANGUAGE} (interpreted language), skipping hooks."
        return
    fi

    local hook_src="${HOOKS_TEMPLATES_DIR}/${HOOK_TEMPLATE_KEY}/post-compile-check.sh"
    if [[ ! -f "$hook_src" ]]; then
        log_warn "Hook template not found: ${hook_src}, skipping hooks."
        return
    fi

    local hooks_dir="${OUTPUT_DIR}/hooks"
    mkdir -p "$hooks_dir"

    log_info "Copying compile hook..."
    cp "$hook_src" "${hooks_dir}/post-compile-check.sh"
    chmod +x "${hooks_dir}/post-compile-check.sh"
    log_success "  post-compile-check.sh (${HOOK_TEMPLATE_KEY})"
}

# ─── Phase 5: Generate Settings ──────────────────────────────────────────────

generate_settings() {
    log_info "Generating settings.json..."

    # Collect permission fragments
    local all_permissions="[]"

    # Base permissions (always)
    if [[ -f "${SETTINGS_TEMPLATES_DIR}/base.json" ]]; then
        local base_perms
        base_perms=$(cat "${SETTINGS_TEMPLATES_DIR}/base.json")
        all_permissions=$(merge_json_arrays "$all_permissions" "$base_perms")
    fi

    # Language-specific permissions
    if [[ -n "$SETTINGS_LANG_KEY" ]] && [[ -f "${SETTINGS_TEMPLATES_DIR}/${SETTINGS_LANG_KEY}.json" ]]; then
        local lang_perms
        lang_perms=$(cat "${SETTINGS_TEMPLATES_DIR}/${SETTINGS_LANG_KEY}.json")
        all_permissions=$(merge_json_arrays "$all_permissions" "$lang_perms")
    fi

    # Docker permissions
    if [[ "$CONTAINER" == "docker" ]] || [[ "$CONTAINER" == "podman" ]]; then
        if [[ -f "${SETTINGS_TEMPLATES_DIR}/docker.json" ]]; then
            local docker_perms
            docker_perms=$(cat "${SETTINGS_TEMPLATES_DIR}/docker.json")
            all_permissions=$(merge_json_arrays "$all_permissions" "$docker_perms")
        fi
    fi

    # Kubernetes permissions
    if [[ "$ORCHESTRATOR" == "kubernetes" ]]; then
        if [[ -f "${SETTINGS_TEMPLATES_DIR}/kubernetes.json" ]]; then
            local k8s_perms
            k8s_perms=$(cat "${SETTINGS_TEMPLATES_DIR}/kubernetes.json")
            all_permissions=$(merge_json_arrays "$all_permissions" "$k8s_perms")
        fi
    fi

    # Docker Compose permissions
    if [[ "$ORCHESTRATOR" == "docker-compose" ]]; then
        if [[ -f "${SETTINGS_TEMPLATES_DIR}/docker-compose.json" ]]; then
            local dc_perms
            dc_perms=$(cat "${SETTINGS_TEMPLATES_DIR}/docker-compose.json")
            all_permissions=$(merge_json_arrays "$all_permissions" "$dc_perms")
        fi
    fi

    # Database client permissions
    if [[ "$DB_TYPE" == "postgresql" ]] && [[ -f "${SETTINGS_TEMPLATES_DIR}/database-psql.json" ]]; then
        local db_perms
        db_perms=$(cat "${SETTINGS_TEMPLATES_DIR}/database-psql.json")
        all_permissions=$(merge_json_arrays "$all_permissions" "$db_perms")
    elif [[ "$DB_TYPE" == "mysql" ]] && [[ -f "${SETTINGS_TEMPLATES_DIR}/database-mysql.json" ]]; then
        local db_perms
        db_perms=$(cat "${SETTINGS_TEMPLATES_DIR}/database-mysql.json")
        all_permissions=$(merge_json_arrays "$all_permissions" "$db_perms")
    fi

    # Smoke test permissions (Newman)
    if [[ "$SMOKE_TESTS" == "true" ]] && [[ -f "${SETTINGS_TEMPLATES_DIR}/testing-newman.json" ]]; then
        local newman_perms
        newman_perms=$(cat "${SETTINGS_TEMPLATES_DIR}/testing-newman.json")
        all_permissions=$(merge_json_arrays "$all_permissions" "$newman_perms")
    fi

    # Build the settings.json
    local hooks_json=""
    if [[ -n "$HOOK_TEMPLATE_KEY" ]]; then
        hooks_json=$(cat <<'HOOKEOF'
,
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-compile-check.sh",
            "timeout": 60,
            "statusMessage": "Checking compilation..."
          }
        ]
      }
    ]
  }
HOOKEOF
)
    fi

    # Format permissions as indented JSON array
    local formatted_perms
    formatted_perms=$(echo "$all_permissions" | python3 -c "
import sys, json
perms = json.load(sys.stdin)
# Deduplicate while preserving order
seen = set()
unique = []
for p in perms:
    if p not in seen:
        seen.add(p)
        unique.append(p)
lines = []
for p in unique:
    lines.append('      ' + json.dumps(p))
print(',\n'.join(lines))
" 2>/dev/null || echo "$all_permissions")

    cat > "${OUTPUT_DIR}/settings.json" <<SETTINGSEOF
{
  "permissions": {
    "allow": [
${formatted_perms}
    ]
  }${hooks_json}
}
SETTINGSEOF

    log_success "  settings.json"

    # Generate settings.local.json template
    cat > "${OUTPUT_DIR}/settings.local.json" <<'LOCALEOF'
{
  "permissions": {
    "allow": []
  }
}
LOCALEOF
    log_success "  settings.local.json (template — add local overrides)"
}

merge_json_arrays() {
    local arr1="$1"
    local arr2="$2"
    python3 -c "
import json, sys
a = json.loads(sys.argv[1])
b = json.loads(sys.argv[2])
print(json.dumps(a + b))
" "$arr1" "$arr2" 2>/dev/null || echo "$arr1"
}

# ─── Phase 6: Generate README ────────────────────────────────────────────────

generate_readme() {
    log_info "Generating README.md..."

    if [[ ! -f "$README_TEMPLATE" ]]; then
        log_warn "README template not found, generating minimal README."
        generate_minimal_readme
        return
    fi

    cp "$README_TEMPLATE" "${OUTPUT_DIR}/README.md"

    # Count items
    local rules_count=0
    local skills_count=0
    local agents_count=0
    local knowledge_packs_count=0

    if [[ -d "${OUTPUT_DIR}/rules" ]]; then
        rules_count=$(find "${OUTPUT_DIR}/rules" -name "*.md" | wc -l | xargs)
    fi

    if [[ -d "${OUTPUT_DIR}/skills" ]]; then
        skills_count=$(find "${OUTPUT_DIR}/skills" -name "SKILL.md" | wc -l | xargs)
    fi

    if [[ -d "${OUTPUT_DIR}/agents" ]]; then
        agents_count=$(find "${OUTPUT_DIR}/agents" -name "*.md" | wc -l | xargs)
    fi

    # Generate rules table
    local rules_table=""
    if [[ -d "${OUTPUT_DIR}/rules" ]]; then
        rules_table="| # | File | Scope |\n|---|------|-------|\n"
        for rule_file in "${OUTPUT_DIR}/rules"/*.md; do
            if [[ -f "$rule_file" ]]; then
                local fname
                fname=$(basename "$rule_file")
                local num
                num=$(echo "$fname" | grep -oE '^[0-9]+' || echo "")
                local scope
                scope=$(echo "$fname" | sed 's/^[0-9]*-//' | sed 's/\.md$//' | sed 's/-/ /g')
                rules_table+="| ${num} | \`${fname}\` | ${scope} |\n"
            fi
        done
    fi

    # Generate skills table
    local skills_table=""
    if [[ -d "${OUTPUT_DIR}/skills" ]]; then
        for skill_dir in "${OUTPUT_DIR}/skills"/*/; do
            if [[ -f "${skill_dir}SKILL.md" ]]; then
                local sname
                sname=$(basename "$skill_dir")
                local sdesc
                sdesc=$(grep -E "^description:" "${skill_dir}SKILL.md" | head -1 | sed 's/description:\s*"\{0,1\}\([^"]*\)"\{0,1\}/\1/' || echo "")
                skills_table+="| **${sname}** | \`/${sname}\` | ${sdesc} |\n"
            fi
        done
    fi

    # Generate agents table
    local agents_table=""
    if [[ -d "${OUTPUT_DIR}/agents" ]]; then
        for agent_file in "${OUTPUT_DIR}/agents"/*.md; do
            if [[ -f "$agent_file" ]]; then
                local aname
                aname=$(basename "$agent_file" .md)
                agents_table+="| **${aname}** | \`${aname}.md\` |\n"
            fi
        done
    fi

    # Hooks section
    local hooks_section="No hooks configured."
    if [[ -n "$HOOK_TEMPLATE_KEY" ]]; then
        hooks_section="### Post-Compile Check\n\n- **Event:** \`PostToolUse\` (after \`Write\` or \`Edit\`)\n- **Script:** \`.claude/hooks/post-compile-check.sh\`\n- **Behavior:** When a \`${FILE_EXTENSION}\` file is modified, runs \`${COMPILE_COMMAND}\` automatically\n- **Purpose:** Catch compilation errors immediately after file changes"
    fi

    # Replace placeholders in README
    sed -i.bak \
        -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
        -e "s|{{RULES_COUNT}}|${rules_count}|g" \
        -e "s|{{SKILLS_COUNT}}|${skills_count}|g" \
        -e "s|{{AGENTS_COUNT}}|${agents_count}|g" \
        "${OUTPUT_DIR}/README.md"

    # Generate knowledge packs table
    local knowledge_packs_table="No knowledge packs configured."
    local kp_found=false
    if [[ -d "${OUTPUT_DIR}/skills" ]]; then
        local kp_list=""
        for skill_dir in "${OUTPUT_DIR}/skills"/*/; do
            if [[ -f "${skill_dir}SKILL.md" ]]; then
                # Knowledge packs have user-invocable: false or no argument-hint
                if grep -q "user-invocable:[[:space:]]*false" "${skill_dir}SKILL.md" 2>/dev/null || \
                   grep -q "^# Knowledge Pack" "${skill_dir}SKILL.md" 2>/dev/null; then
                    local kp_name
                    kp_name=$(basename "$skill_dir")
                    kp_list+="| \`${kp_name}\` | Referenced internally by agents |\n"
                    kp_found=true
                fi
            fi
        done
        if [[ "$kp_found" == true ]]; then
            knowledge_packs_table="| Pack | Usage |\n|------|-------|\n${kp_list}"
        fi
    fi

    # Generate settings section
    local settings_section="### settings.json\n\nPermissions are configured in \`settings.json\` under \`permissions.allow\`.\nThis controls which Bash commands Claude Code can run without asking.\n\n### settings.local.json\n\nLocal overrides (gitignored). Use for personal preferences or team-specific tools.\n\nSee the files directly for current configuration."

    # Replace multi-line placeholders using python3 for safety
    python3 -c "
import sys
with open(sys.argv[1], 'r') as f:
    content = f.read()
content = content.replace('{{RULES_TABLE}}', sys.argv[2])
content = content.replace('{{SKILLS_TABLE}}', sys.argv[3])
content = content.replace('{{AGENTS_TABLE}}', sys.argv[4])
content = content.replace('{{HOOKS_SECTION}}', sys.argv[5])
content = content.replace('{{KNOWLEDGE_PACKS_TABLE}}', sys.argv[6])
content = content.replace('{{SETTINGS_SECTION}}', sys.argv[7])
with open(sys.argv[1], 'w') as f:
    f.write(content)
" "${OUTPUT_DIR}/README.md" \
    "$(echo -e "$rules_table")" \
    "$(echo -e "$skills_table")" \
    "$(echo -e "$agents_table")" \
    "$(echo -e "$hooks_section")" \
    "$(echo -e "$knowledge_packs_table")" \
    "$(echo -e "$settings_section")" 2>/dev/null || true

    rm -f "${OUTPUT_DIR}/README.md.bak"
    log_success "  README.md"
}

generate_minimal_readme() {
    cat > "${OUTPUT_DIR}/README.md" <<READMEEOF
# .claude/ — ${PROJECT_NAME}

This directory contains the Claude Code configuration for **${PROJECT_NAME}**.

## Structure

\`\`\`
.claude/
├── README.md               ← You are here
├── settings.json           ← Shared config (committed to git)
├── settings.local.json     ← Local overrides (gitignored)
├── rules/                  ← Coding rules (loaded in system prompt)
├── skills/                 ← Skills invocable via /command
├── agents/                 ← AI personas (used by skills)
└── hooks/                  ← Automation (post-compile, etc.)
\`\`\`

## Tips

- **Rules are always active** — loaded automatically in every conversation
- **Skills are lazy** — only load when you type \`/name\`
- **Agents are not invoked directly** — used by skills internally
- **Hooks run automatically** — compile check after editing source files
READMEEOF
    log_success "  README.md (minimal)"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    echo ""

    if [[ "$INTERACTIVE" == true ]]; then
        run_interactive
    else
        run_config
    fi

    # Resolve stack-specific commands
    resolve_stack_commands

    # Set output directory
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="./.claude"
    fi

    echo ""
    log_info "Configuration:"
    echo "  Project:        ${PROJECT_NAME} (${PROJECT_TYPE})"
    echo "  Stack:          ${LANGUAGE} + ${FRAMEWORK}"
    echo "  Database:       ${DB_TYPE} (migration: ${DB_MIGRATION})"
    echo "  Architecture:   ${ARCHITECTURE}"
    echo "  Protocols:      ${PROTOCOLS[*]}"
    echo "  Infrastructure: ${CONTAINER} + ${ORCHESTRATOR}"
    echo "  Observability:  ${OBSERVABILITY}"
    echo "  Native Build:   ${NATIVE_BUILD}"
    echo "  Resilience:     ${RESILIENCE}"
    echo "  Smoke Tests:    ${SMOKE_TESTS}"
    echo ""

    if [[ "$INTERACTIVE" == true ]]; then
        prompt_yesno "Proceed with setup?" "y" || { log_warn "Aborted."; exit 0; }
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    log_info "Output directory: ${OUTPUT_DIR}/"
    echo ""

    # Phase 1: Rules
    log_info "━━━ Phase 1: Rules ━━━"
    assemble_rules
    echo ""

    # Phase 2: Skills
    log_info "━━━ Phase 2: Skills ━━━"
    assemble_skills
    echo ""

    # Phase 3: Agents
    log_info "━━━ Phase 3: Agents ━━━"
    assemble_agents
    echo ""

    # Phase 4: Hooks
    log_info "━━━ Phase 4: Hooks ━━━"
    assemble_hooks
    echo ""

    # Phase 5: Settings
    log_info "━━━ Phase 5: Settings ━━━"
    generate_settings
    echo ""

    # Phase 6: README
    log_info "━━━ Phase 6: README ━━━"
    generate_readme
    echo ""

    # ─── Summary ──────────────────────────────────────────────────────────
    echo ""
    log_success "Setup complete!"
    echo ""

    local rules_count=0 skills_count=0 agents_count=0
    [[ -d "${OUTPUT_DIR}/rules" ]] && rules_count=$(find "${OUTPUT_DIR}/rules" -name "*.md" | wc -l | xargs)
    [[ -d "${OUTPUT_DIR}/skills" ]] && skills_count=$(find "${OUTPUT_DIR}/skills" -name "SKILL.md" | wc -l | xargs)
    [[ -d "${OUTPUT_DIR}/agents" ]] && agents_count=$(find "${OUTPUT_DIR}/agents" -name "*.md" | wc -l | xargs)

    log_info "Generated:"
    echo "  Rules:    ${rules_count}"
    echo "  Skills:   ${skills_count}"
    echo "  Agents:   ${agents_count}"
    echo "  Hooks:    $(ls "${OUTPUT_DIR}/hooks" 2>/dev/null | wc -l | xargs)"
    echo "  Settings: settings.json + settings.local.json"
    echo "  README:   README.md"
    log_info "Output: ${OUTPUT_DIR}/"
    echo ""
    log_info "Next steps:"
    echo "  1. Review and customize rules/30-project-identity.md"
    echo "  2. Fill in rules/31-domain.md with your domain rules"
    echo "  3. Add domain-specific scopes to rules/04-git-workflow.md"
    echo "  4. Review settings.json permissions"
    echo "  5. Add local overrides to settings.local.json"
    echo ""
}

main
