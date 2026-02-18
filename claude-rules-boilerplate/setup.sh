#!/usr/bin/env bash
set -euo pipefail

# Claude Rules Boilerplate — Project Generator
# Assembles .claude/rules/ from core + profile + domain template.
#
# Usage:
#   ./setup.sh                          # Interactive mode
#   ./setup.sh --config setup-config.yaml  # Config file mode
#   ./setup.sh --config setup-config.yaml --output /path/to/project/.claude/rules/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="${SCRIPT_DIR}/core"
PROFILES_DIR="${SCRIPT_DIR}/profiles"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# Defaults
CONFIG_FILE=""
OUTPUT_DIR=""
INTERACTIVE=true

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
            echo "Claude Rules Boilerplate — Project Generator"
            echo ""
            echo "Usage:"
            echo "  ./setup.sh                                    Interactive mode"
            echo "  ./setup.sh --config <file>                    Config file mode"
            echo "  ./setup.sh --config <file> --output <dir>     Config + custom output"
            echo ""
            echo "Options:"
            echo "  --config <file>    Path to setup-config.yaml"
            echo "  --output <dir>     Output directory (default: ./.claude/rules/)"
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

# ─── Config File Parsing ─────────────────────────────────────────────────────

parse_yaml_value() {
    local file="$1"
    local key="$2"
    grep -E "^\s*${key}:" "$file" | head -1 | sed 's/.*:\s*"\{0,1\}\([^"]*\)"\{0,1\}\s*$/\1/' | xargs
}

parse_yaml_list() {
    local file="$1"
    local key="$2"
    awk "/^\s*${key}:/{found=1; next} found && /^\s*-/{print; next} found{exit}" "$file" | sed 's/.*-\s*"\{0,1\}\([^"]*\)"\{0,1\}\s*$/\1/'
}

# ─── Interactive Mode ─────────────────────────────────────────────────────────

run_interactive() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Claude Rules Boilerplate — Project Setup    ║${NC}"
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

    PROJECT_NAME=$(parse_yaml_value "$CONFIG_FILE" "name")
    PROJECT_TYPE=$(parse_yaml_value "$CONFIG_FILE" "type")
    PROJECT_PURPOSE=$(parse_yaml_value "$CONFIG_FILE" "purpose")
    LANGUAGE=$(parse_yaml_value "$CONFIG_FILE" "language")
    FRAMEWORK=$(parse_yaml_value "$CONFIG_FILE" "framework")
    DB_TYPE=$(parse_yaml_value "$CONFIG_FILE" "type" | tail -1)  # database type
    DB_MIGRATION=$(parse_yaml_value "$CONFIG_FILE" "migration")
    ARCHITECTURE=$(parse_yaml_value "$CONFIG_FILE" "architecture")
    CONTAINER=$(parse_yaml_value "$CONFIG_FILE" "container")
    ORCHESTRATOR=$(parse_yaml_value "$CONFIG_FILE" "orchestrator")
    OBSERVABILITY=$(parse_yaml_value "$CONFIG_FILE" "observability")
    NATIVE_BUILD=$(parse_yaml_value "$CONFIG_FILE" "native_build")
    RESILIENCE=$(parse_yaml_value "$CONFIG_FILE" "resilience")
    SMOKE_TESTS=$(parse_yaml_value "$CONFIG_FILE" "smoke_tests")

    PROFILE="${LANGUAGE}-${FRAMEWORK}"

    log_info "Loaded config from: $CONFIG_FILE"
}

# ─── Assembly ─────────────────────────────────────────────────────────────────

assemble() {
    local profile_dir="${PROFILES_DIR}/${PROFILE}"

    # Validate profile exists
    if [[ ! -d "$profile_dir" ]]; then
        log_error "Profile not found: ${PROFILE}"
        log_info "Available profiles:"
        ls -1 "$PROFILES_DIR" 2>/dev/null || echo "  (none)"
        log_info ""
        log_info "The core rules will still be copied. Create the profile manually"
        log_info "or contribute it to the boilerplate."
        profile_dir=""
    fi

    # Set output directory
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="./.claude/rules"
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    log_info "Output directory: $OUTPUT_DIR"

    # Counter for file numbering
    local num=1

    # ─── Copy Core (01-11) ────────────────────────────────────────────────
    log_info "Copying core rules..."
    for core_file in "$CORE_DIR"/*.md; do
        if [[ -f "$core_file" ]]; then
            local basename
            basename=$(basename "$core_file")
            cp "$core_file" "${OUTPUT_DIR}/${basename}"
            log_success "  ${basename}"
            num=$((num + 1))
        fi
    done

    # ─── Copy Profile (20-29) ─────────────────────────────────────────────
    if [[ -n "$profile_dir" ]]; then
        log_info "Copying profile: ${PROFILE}..."
        local profile_num=20
        for profile_file in "$profile_dir"/*.md; do
            if [[ -f "$profile_file" ]]; then
                local basename
                basename=$(basename "$profile_file")
                local target_name
                target_name=$(printf "%02d-%s" "$profile_num" "$basename")
                cp "$profile_file" "${OUTPUT_DIR}/${target_name}"
                log_success "  ${target_name}"
                profile_num=$((profile_num + 1))
            fi
        done
    fi

    # ─── Generate Project Identity (30) ───────────────────────────────────
    log_info "Generating project identity..."
    generate_project_identity
    log_success "  30-project-identity.md"

    # ─── Copy Domain Template (31) ────────────────────────────────────────
    log_info "Copying domain template..."
    cp "${TEMPLATES_DIR}/domain-template.md" "${OUTPUT_DIR}/31-domain.md"
    log_success "  31-domain.md (template — customize for your domain)"

    # ─── Summary ──────────────────────────────────────────────────────────
    echo ""
    log_success "Setup complete!"
    echo ""
    local file_count
    file_count=$(find "$OUTPUT_DIR" -name "*.md" | wc -l | xargs)
    log_info "Files generated: ${file_count}"
    log_info "Output: ${OUTPUT_DIR}/"
    echo ""
    log_info "Next steps:"
    echo "  1. Review and customize 30-project-identity.md"
    echo "  2. Fill in 31-domain.md with your domain rules"
    echo "  3. Add domain-specific scopes to 04-git-workflow.md"
    if [[ -z "$profile_dir" ]]; then
        echo "  4. Create a technology profile for ${PROFILE} (see docs/CONTRIBUTING.md)"
    fi
    echo ""
}

generate_project_identity() {
    cat > "${OUTPUT_DIR}/30-project-identity.md" <<HEREDOC
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

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    echo ""

    if [[ "$INTERACTIVE" == true ]]; then
        run_interactive
    else
        run_config
    fi

    echo ""
    log_info "Configuration:"
    echo "  Project:        ${PROJECT_NAME} (${PROJECT_TYPE})"
    echo "  Stack:          ${LANGUAGE} + ${FRAMEWORK}"
    echo "  Database:       ${DB_TYPE} (migration: ${DB_MIGRATION})"
    echo "  Architecture:   ${ARCHITECTURE}"
    echo "  Infrastructure: ${CONTAINER} + ${ORCHESTRATOR}"
    echo "  Observability:  ${OBSERVABILITY}"
    echo "  Native Build:   ${NATIVE_BUILD}"
    echo "  Resilience:     ${RESILIENCE}"
    echo "  Smoke Tests:    ${SMOKE_TESTS}"
    echo ""

    if [[ "$INTERACTIVE" == true ]]; then
        prompt_yesno "Proceed with setup?" "y" || { log_warn "Aborted."; exit 0; }
    fi

    assemble
}

main
