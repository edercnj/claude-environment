#!/usr/bin/env bash
set -euo pipefail

# Claude Code Boilerplate — Complete .claude/ Directory Generator (v3)
# Assembles .claude/ with rules, patterns, protocols, skills, agents, hooks,
# settings.json, and README.md.
#
# Usage:
#   ./setup.sh                          # Interactive mode
#   ./setup.sh --config setup-config.yaml  # Config file mode
#   ./setup.sh --config setup-config.yaml --output /path/to/project/.claude/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="${SCRIPT_DIR}/core"
LANGUAGES_DIR="${SCRIPT_DIR}/languages"
FRAMEWORKS_DIR="${SCRIPT_DIR}/frameworks"
DATABASES_DIR="${SCRIPT_DIR}/databases"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
PATTERNS_DIR="${SCRIPT_DIR}/patterns"
PROTOCOLS_DIR="${SCRIPT_DIR}/protocols"
SKILLS_TEMPLATES_DIR="${SCRIPT_DIR}/skills-templates"
AGENTS_TEMPLATES_DIR="${SCRIPT_DIR}/agents-templates"
HOOKS_TEMPLATES_DIR="${SCRIPT_DIR}/hooks-templates"
SETTINGS_TEMPLATES_DIR="${SCRIPT_DIR}/settings-templates"
README_TEMPLATE="${SCRIPT_DIR}/readme-template.md"
SECURITY_DIR="${SCRIPT_DIR}/security"
CLOUD_PROVIDERS_DIR="${SCRIPT_DIR}/cloud-providers"
INFRASTRUCTURE_DIR="${SCRIPT_DIR}/infrastructure"
PATTERNS_DIR="${SCRIPT_DIR}/patterns"

# Defaults
CONFIG_FILE=""
OUTPUT_DIR=""
INTERACTIVE=true
DRY_RUN=false
VALIDATE_ONLY=false

# Project identity (set by run_interactive or run_config)
PROJECT_NAME=""
PROJECT_PURPOSE=""
LANGUAGE_NAME=""       # "java", "typescript", "python", etc.
LANGUAGE_VERSION=""    # "21", "5", "3.12", etc.
FRAMEWORK_NAME=""      # "quarkus", "spring-boot", "nestjs", etc.
FRAMEWORK_VERSION=""   # "3.17", "3.4", "10", etc.

# Architecture (v3 config)
ARCH_STYLE=""          # microservice | modular-monolith | monolith | library | serverless
DOMAIN_DRIVEN=false
EVENT_DRIVEN=false
ARCHITECTURE=""        # hexagonal | clean | layered | modular (internal, for project identity)

# Interfaces (v3 — list of types parsed from config)
INTERFACE_TYPES=()     # ["rest", "grpc", "graphql", "websocket", "tcp-custom", "cli", "event-consumer", "event-producer", "scheduled"]

# Legacy compatibility
PROJECT_TYPE=""        # api | cli | library | worker | fullstack (v2 only)
PROTOCOLS=()           # Legacy protocols array (v2 compat)

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

# Data
DB_TYPE="none"
DB_MIGRATION="none"
CACHE_TYPE="none"
MESSAGE_BROKER_TYPE="none"

# Infrastructure
CONTAINER="none"
ORCHESTRATOR="none"

# Observability
OBSERVABILITY="opentelemetry"
OBSERVABILITY_BACKEND="grafana-stack"

# Testing
SMOKE_TESTS="true"
PERFORMANCE_TESTS="true"
CONTRACT_TESTS="false"
CHAOS_TESTS="false"

# Build
NATIVE_BUILD="false"

# Security config
SECURITY_COMPLIANCE=()
ENCRYPTION_AT_REST="true"
KEY_MANAGEMENT="none"
PENTEST_READINESS="true"

# Cloud config
CLOUD_PROVIDER="none"

# Infrastructure expanded config
TEMPLATING="kustomize"
IAC="none"
REGISTRY="none"
API_GATEWAY="none"
SERVICE_MESH="none"

# Domain template
DOMAIN_TEMPLATE="none"

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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --validate)
            VALIDATE_ONLY=true
            INTERACTIVE=false
            shift
            ;;
        --help|-h)
            echo "Claude Code Boilerplate — Complete .claude/ Directory Generator (v3)"
            echo ""
            echo "Usage:"
            echo "  ./setup.sh                                    Interactive mode"
            echo "  ./setup.sh --config <file>                    Config file mode"
            echo "  ./setup.sh --config <file> --output <dir>     Config + custom output"
            echo "  ./setup.sh --validate --config <file>         Validate config only"
            echo "  ./setup.sh --dry-run --config <file>          Show what would be generated"
            echo ""
            echo "Options:"
            echo "  --config <file>    Path to setup-config.yaml"
            echo "  --output <dir>     Output directory (default: ./.claude/)"
            echo "  --dry-run          Show what would be generated without creating files"
            echo "  --validate         Validate config file and exit"
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
        -e "s|{{LANGUAGE_NAME}}|${LANGUAGE_NAME}|g" \
        -e "s|{{LANGUAGE_VERSION}}|${LANGUAGE_VERSION}|g" \
        -e "s|{{FRAMEWORK_NAME}}|${FRAMEWORK_NAME}|g" \
        -e "s|{{FRAMEWORK_VERSION}}|${FRAMEWORK_VERSION}|g" \
        -e "s|{{LANGUAGE}}|${LANGUAGE_NAME}|g" \
        -e "s|{{FRAMEWORK}}|${FRAMEWORK_NAME}|g" \
        -e "s|{{DB_TYPE}}|${DB_TYPE}|g" \
        -e "s|{{DB_MIGRATION}}|${DB_MIGRATION}|g" \
        -e "s|{{ARCHITECTURE}}|${ARCHITECTURE}|g" \
        -e "s|{{ARCH_STYLE}}|${ARCH_STYLE}|g" \
        -e "s|{{CONTAINER}}|${CONTAINER}|g" \
        -e "s|{{ORCHESTRATOR}}|${ORCHESTRATOR}|g" \
        -e "s|{{OBSERVABILITY}}|${OBSERVABILITY}|g" \
        -e "s|{{COMPILE_COMMAND}}|${COMPILE_COMMAND}|g" \
        -e "s|{{BUILD_COMMAND}}|${BUILD_COMMAND}|g" \
        -e "s|{{TEST_COMMAND}}|${TEST_COMMAND}|g" \
        -e "s|{{COVERAGE_COMMAND}}|${COVERAGE_COMMAND}|g" \
        -e "s|{{FILE_EXTENSION}}|${FILE_EXTENSION}|g" \
        -e "s|{{BUILD_TOOL}}|${BUILD_TOOL:-}|g" \
        -e "s|{{CACHE_TYPE}}|${CACHE_TYPE:-none}|g" \
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
        raw_line=$(awk "BEGIN{found=0} /^${section}:/{found=1; next} found && /^[^ ]/{exit} found && /^[[:space:]]*#/{next} found && /^[[:space:]]*${key}:/{print; exit}" "$file")
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
    local in_sec=0 in_sub=0 raw_line=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^${section}: ]]; then
            in_sec=1; in_sub=0; continue
        fi
        if (( in_sec )) && [[ "$line" =~ ^[^\ ] ]]; then
            in_sec=0; in_sub=0; continue
        fi
        if (( in_sec )) && [[ "$line" =~ ^[[:space:]]{2}${subsection}: ]]; then
            in_sub=1; continue
        fi
        if (( in_sec && in_sub )) && [[ "$line" =~ ^[[:space:]]{2}[^\ ] ]] && [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
            in_sub=0; continue
        fi
        if (( in_sec && in_sub )) && [[ "$line" =~ ${key}: ]]; then
            raw_line="$line"; break
        fi
    done < "$file"
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

# Parse interfaces list (v3 format: list of objects with type, spec, broker)
# Returns interface types as newline-separated list
parse_interfaces() {
    local file="$1"
    local in_interfaces=0
    local in_item=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^interfaces: ]]; then
            in_interfaces=1; continue
        fi
        if (( in_interfaces )) && [[ "$line" =~ ^[^\ #] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            break
        fi
        if (( in_interfaces )) && [[ "$line" =~ ^[[:space:]]*-[[:space:]]*type: ]]; then
            local itype
            itype=$(echo "$line" | sed 's/.*type:[[:space:]]*//' | sed 's/[[:space:]]*#.*$//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/" | xargs)
            [[ -n "$itype" ]] && echo "$itype"
        fi
    done < "$file"
}

# ─── Old Format Detection & Migration ────────────────────────────────────────

detect_old_config_format() {
    local file="$1"
    # Check for old-style "type" field under project section
    local old_type
    old_type=$(parse_yaml_value "$file" "type" "project")
    if [[ -n "$old_type" ]] && [[ "$old_type" =~ ^(api|cli|library|worker|fullstack)$ ]]; then
        return 0  # Old format detected
    fi
    # Check for old-style "stack" section (v2)
    if grep -qE "^stack:" "$file" 2>/dev/null; then
        return 0  # Old format detected
    fi
    return 1  # New format
}

migrate_old_type() {
    local old_type="$1"
    case "$old_type" in
        api)
            ARCH_STYLE="microservice"
            INTERFACE_TYPES=("rest")
            ;;
        cli)
            ARCH_STYLE="library"
            INTERFACE_TYPES=("cli")
            ;;
        library)
            ARCH_STYLE="library"
            INTERFACE_TYPES=()
            ;;
        worker)
            ARCH_STYLE="microservice"
            INTERFACE_TYPES=("event-consumer")
            ;;
        fullstack)
            ARCH_STYLE="monolith"
            INTERFACE_TYPES=("rest")
            ;;
        *)
            ARCH_STYLE="microservice"
            INTERFACE_TYPES=("rest")
            ;;
    esac
    log_warn "Migrated old type '${old_type}' → architecture.style='${ARCH_STYLE}', interfaces=[${INTERFACE_TYPES[*]}]"
}

# ─── Stack Resolution ────────────────────────────────────────────────────────

resolve_stack_commands() {
    case "${LANGUAGE_NAME}" in
        java)
            FILE_EXTENSION=".java"
            DEVELOPER_AGENT_KEY="java"
            # Build tool depends on framework config or default to maven
            case "${BUILD_TOOL:-maven}" in
                maven|Maven)
                    COMPILE_COMMAND="./mvnw compile -q"
                    BUILD_COMMAND="./mvnw package -DskipTests"
                    TEST_COMMAND="./mvnw verify"
                    COVERAGE_COMMAND="./mvnw verify jacoco:report"
                    BUILD_TOOL="Maven"
                    HOOK_TEMPLATE_KEY="java-maven"
                    SETTINGS_LANG_KEY="java-maven"
                    ;;
                gradle|Gradle)
                    COMPILE_COMMAND="./gradlew compileJava -q"
                    BUILD_COMMAND="./gradlew build -x test"
                    TEST_COMMAND="./gradlew test"
                    COVERAGE_COMMAND="./gradlew test jacocoTestReport"
                    BUILD_TOOL="Gradle"
                    HOOK_TEMPLATE_KEY="java-maven"
                    SETTINGS_LANG_KEY="java-gradle"
                    ;;
            esac
            ;;
        kotlin)
            FILE_EXTENSION=".kt"
            DEVELOPER_AGENT_KEY="kotlin"
            COMPILE_COMMAND="./gradlew compileKotlin -q"
            BUILD_COMMAND="./gradlew build -x test"
            TEST_COMMAND="./gradlew test"
            COVERAGE_COMMAND="./gradlew test jacocoTestReport"
            BUILD_TOOL="Gradle"
            HOOK_TEMPLATE_KEY="kotlin"
            SETTINGS_LANG_KEY="java-gradle"
            ;;
        typescript)
            FILE_EXTENSION=".ts"
            DEVELOPER_AGENT_KEY="typescript"
            COMPILE_COMMAND="npx --no-install tsc --noEmit"
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
            COMPILE_COMMAND="dotnet build --no-restore --verbosity quiet"
            BUILD_COMMAND="dotnet build"
            TEST_COMMAND="dotnet test"
            COVERAGE_COMMAND="dotnet test --collect:\"XPlat Code Coverage\""
            BUILD_TOOL="dotnet"
            HOOK_TEMPLATE_KEY="csharp"
            SETTINGS_LANG_KEY="csharp-dotnet"
            ;;
    esac
}

# ─── Stack Validation ────────────────────────────────────────────────────────

validate_stack_compatibility() {
    local lang="$LANGUAGE_NAME"
    local lang_ver="$LANGUAGE_VERSION"
    local fw="$FRAMEWORK_NAME"

    # Language ↔ Framework compatibility
    case "$fw" in
        quarkus|spring-boot)
            if [[ "$lang" != "java" && "$lang" != "kotlin" ]]; then
                log_error "Framework '${fw}' requires language 'java' or 'kotlin', got '${lang}'"
                exit 1
            fi
            ;;
        nestjs|express|fastify)
            if [[ "$lang" != "typescript" ]]; then
                log_error "Framework '${fw}' requires language 'typescript', got '${lang}'"
                exit 1
            fi
            ;;
        fastapi|django|flask)
            if [[ "$lang" != "python" ]]; then
                log_error "Framework '${fw}' requires language 'python', got '${lang}'"
                exit 1
            fi
            ;;
        stdlib|gin|fiber)
            if [[ "$lang" != "go" ]]; then
                log_error "Framework '${fw}' requires language 'go', got '${lang}'"
                exit 1
            fi
            ;;
        ktor)
            if [[ "$lang" != "kotlin" ]]; then
                log_error "Framework '${fw}' requires language 'kotlin', got '${lang}'"
                exit 1
            fi
            ;;
        axum|actix)
            if [[ "$lang" != "rust" ]]; then
                log_error "Framework '${fw}' requires language 'rust', got '${lang}'"
                exit 1
            fi
            ;;
        dotnet)
            if [[ "$lang" != "csharp" ]]; then
                log_error "Framework '${fw}' requires language 'csharp', got '${lang}'"
                exit 1
            fi
            ;;
    esac

    # Quarkus 3.x requires Java 17+
    if [[ "$fw" == "quarkus" && "$lang" == "java" ]]; then
        if [[ "$lang_ver" == "11" ]]; then
            log_error "Quarkus 3.x requires Java 17+, got Java ${lang_ver}"
            exit 1
        fi
    fi

    # Spring Boot 3.x requires Java 17+
    if [[ "$fw" == "spring-boot" && "$lang" == "java" && -n "$FRAMEWORK_VERSION" ]]; then
        local fw_major="${FRAMEWORK_VERSION%%.*}"
        if [[ "$fw_major" -ge 3 ]] 2>/dev/null && [[ "$lang_ver" == "11" ]]; then
            log_error "Spring Boot 3.x requires Java 17+, got Java ${lang_ver}"
            exit 1
        fi
    fi

    # Django 5.x requires Python 3.10+
    if [[ "$fw" == "django" && -n "$FRAMEWORK_VERSION" ]]; then
        local fw_major="${FRAMEWORK_VERSION%%.*}"
        if [[ "$fw_major" -ge 5 ]] 2>/dev/null; then
            local py_minor="${lang_ver#*.}"
            if [[ "$py_minor" -lt 10 ]] 2>/dev/null; then
                log_error "Django 5.x requires Python 3.10+, got Python ${lang_ver}"
                exit 1
            fi
        fi
    fi

    # native_build warnings
    if [[ "$NATIVE_BUILD" == "true" ]]; then
        if [[ "$fw" == "spring-boot" && -n "$FRAMEWORK_VERSION" ]]; then
            local fw_major="${FRAMEWORK_VERSION%%.*}"
            if [[ "$fw_major" -le 2 ]] 2>/dev/null; then
                log_warn "Native build with Spring Boot 2.x is experimental. Consider upgrading to 3.x."
            fi
        fi
        if [[ "$lang" == "go" || "$lang" == "rust" ]]; then
            log_info "${lang} compiles natively. The native_build flag has no effect."
        fi
    fi

    # Validate interface types
    local valid_iface_types=("rest" "grpc" "graphql" "websocket" "tcp-custom" "cli" "event-consumer" "event-producer" "scheduled")
    for itype in "${INTERFACE_TYPES[@]}"; do
        if ! array_contains "$itype" "${valid_iface_types[@]}"; then
            log_error "Invalid interface type: '${itype}'. Valid values: ${valid_iface_types[*]}"
            exit 1
        fi
    done

    # Validate architecture style
    local valid_styles=("microservice" "modular-monolith" "monolith" "library" "serverless")
    if [[ -n "$ARCH_STYLE" ]] && ! array_contains "$ARCH_STYLE" "${valid_styles[@]}"; then
        log_error "Invalid architecture.style: '${ARCH_STYLE}'. Valid values: ${valid_styles[*]}"
        exit 1
    fi

    # Validate language directory exists
    if [[ ! -d "${LANGUAGES_DIR}/${lang}" ]]; then
        log_warn "Language directory not found: languages/${lang}"
    fi

    # Validate framework directory exists
    if [[ ! -d "${FRAMEWORKS_DIR}/${fw}" ]]; then
        log_warn "Framework directory not found: frameworks/${fw}"
    fi

    log_success "Stack validation passed: ${lang} ${lang_ver} + ${fw} (${ARCH_STYLE})"
}

infer_native_build() {
    if [[ "$NATIVE_BUILD" != "auto" && -n "$NATIVE_BUILD" && "$NATIVE_BUILD" != "" ]]; then
        return  # Explicitly set, don't override
    fi
    case "$LANGUAGE_NAME" in
        java|kotlin)
            case "$FRAMEWORK_NAME" in
                quarkus) NATIVE_BUILD="true" ;;
                spring-boot)
                    local fw_major="${FRAMEWORK_VERSION%%.*}"
                    if [[ -n "$fw_major" && "$fw_major" -ge 3 ]] 2>/dev/null; then
                        NATIVE_BUILD="true"
                    else
                        NATIVE_BUILD="false"
                    fi
                    ;;
                *) NATIVE_BUILD="false" ;;
            esac
            ;;
        *) NATIVE_BUILD="false" ;;
    esac
    log_info "Native build inferred: ${NATIVE_BUILD}"
}

find_version_dir() {
    local base_dir="$1" name="$2" version="$3"
    # Try exact match first
    [[ -d "${base_dir}/${name}-${version}" ]] && echo "${base_dir}/${name}-${version}" && return
    # Try major version with .x suffix
    local major="${version%%.*}"
    [[ -d "${base_dir}/${name}-${major}.x" ]] && echo "${base_dir}/${name}-${major}.x" && return
    echo ""
}

# Derive PROTOCOLS array from INTERFACE_TYPES for backward compatibility
derive_protocols_from_interfaces() {
    PROTOCOLS=()
    for itype in "${INTERFACE_TYPES[@]}"; do
        case "$itype" in
            rest|grpc|graphql|websocket|tcp-custom)
                PROTOCOLS+=("$itype")
                ;;
            # event-consumer, event-producer, cli, scheduled don't map to old protocols
        esac
    done
    # Default to rest if no protocols derived and not a library/cli-only project
    if [[ ${#PROTOCOLS[@]} -eq 0 ]] && [[ "$ARCH_STYLE" != "library" ]]; then
        PROTOCOLS=("rest")
    fi
}

# Derive PROJECT_TYPE from ARCH_STYLE for backward compat in templates
derive_project_type() {
    if [[ -n "$PROJECT_TYPE" ]]; then
        return  # Already set (old format)
    fi
    case "$ARCH_STYLE" in
        microservice)
            if array_contains "event-consumer" "${INTERFACE_TYPES[@]}" && ! array_contains "rest" "${INTERFACE_TYPES[@]}"; then
                PROJECT_TYPE="worker"
            else
                PROJECT_TYPE="api"
            fi
            ;;
        modular-monolith|monolith)
            PROJECT_TYPE="api"
            ;;
        library)
            if array_contains "cli" "${INTERFACE_TYPES[@]}"; then
                PROJECT_TYPE="cli"
            else
                PROJECT_TYPE="library"
            fi
            ;;
        serverless)
            PROJECT_TYPE="api"
            ;;
        *)
            PROJECT_TYPE="api"
            ;;
    esac
}

verify_cross_references() {
    local output_dir="$1"
    local warnings=0

    log_info "Verifying cross-references..."

    # 1. Check agent references in skills
    if [[ -d "${output_dir}/skills" ]]; then
        for skill_file in "${output_dir}/skills"/*/SKILL.md; do
            if [[ -f "$skill_file" ]]; then
                local skill_name
                skill_name=$(basename "$(dirname "$skill_file")")
                local agents_referenced
                agents_referenced=$(grep -oE 'agents/[a-z0-9_-]+' "$skill_file" 2>/dev/null | sed 's|agents/||' | sort -u || true)
                for agent in $agents_referenced; do
                    if [[ ! -f "${output_dir}/agents/${agent}.md" ]]; then
                        log_warn "Skill '${skill_name}' references agent '${agent}' but agents/${agent}.md does not exist"
                        warnings=$((warnings + 1))
                    fi
                done
            fi
        done
    fi

    # 2. Check rule references in agents
    if [[ -d "${output_dir}/agents" ]]; then
        for agent_file in "${output_dir}/agents"/*.md; do
            if [[ -f "$agent_file" ]]; then
                local agent_name
                agent_name=$(basename "$agent_file")
                local rules_referenced
                rules_referenced=$(grep -oE 'rules/[0-9]+-[a-z0-9_-]+\.md' "$agent_file" 2>/dev/null | sed 's|rules/||' | sort -u || true)
                for rule in $rules_referenced; do
                    if [[ ! -f "${output_dir}/rules/${rule}" ]]; then
                        log_warn "Agent '${agent_name}' references rule '${rule}' but rules/${rule} does not exist"
                        warnings=$((warnings + 1))
                    fi
                done
            fi
        done
    fi

    # 3. Check for unreplaced placeholders
    local unreplaced
    unreplaced=$(grep -rE '\{\{[A-Z_]+\}\}' "${output_dir}" 2>/dev/null | grep -v 'settings.local.json' || true)
    if [[ -n "$unreplaced" ]]; then
        log_warn "Unreplaced placeholders found:"
        echo "$unreplaced" | head -10
        warnings=$((warnings + $(echo "$unreplaced" | wc -l | xargs)))
    fi

    if [[ "$warnings" -eq 0 ]]; then
        log_success "Cross-reference verification passed (0 warnings)"
    else
        log_warn "Cross-reference verification completed with ${warnings} warning(s)"
    fi
}

# ─── Interactive Mode ─────────────────────────────────────────────────────────

run_interactive() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Claude Code Boilerplate — Project Setup     ║${NC}"
    echo -e "${GREEN}║  Comprehensive Architecture (v3)             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""

    PROJECT_NAME=$(prompt_input "Project name" "my-service")
    PROJECT_PURPOSE=$(prompt_input "Brief project purpose")

    # Architecture style
    ARCH_STYLE=$(prompt_select "Architecture style:" "microservice" "modular-monolith" "monolith" "library" "serverless")

    # DDD and event-driven flags
    DOMAIN_DRIVEN=false
    prompt_yesno "Enable Domain-Driven Design patterns?" "n" && DOMAIN_DRIVEN=true
    EVENT_DRIVEN=false
    prompt_yesno "Enable event-driven patterns?" "n" && EVENT_DRIVEN=true

    # Interfaces
    INTERFACE_TYPES=()
    echo -e "${YELLOW}Select interfaces (communication protocols):${NC}"
    prompt_yesno "  REST API?" "y" && INTERFACE_TYPES+=("rest")
    prompt_yesno "  gRPC?" "n" && INTERFACE_TYPES+=("grpc")
    prompt_yesno "  GraphQL?" "n" && INTERFACE_TYPES+=("graphql")
    prompt_yesno "  WebSocket?" "n" && INTERFACE_TYPES+=("websocket")
    prompt_yesno "  TCP custom?" "n" && INTERFACE_TYPES+=("tcp-custom")
    prompt_yesno "  CLI?" "n" && INTERFACE_TYPES+=("cli")
    if [[ "$EVENT_DRIVEN" == "true" ]]; then
        prompt_yesno "  Event consumer?" "y" && INTERFACE_TYPES+=("event-consumer")
        prompt_yesno "  Event producer?" "y" && INTERFACE_TYPES+=("event-producer")
    fi
    prompt_yesno "  Scheduled jobs?" "n" && INTERFACE_TYPES+=("scheduled")

    # Derive PROTOCOLS for backward compatibility
    derive_protocols_from_interfaces
    derive_project_type

    # Step 1: Language name
    LANGUAGE_NAME=$(prompt_select "Language:" "java" "typescript" "python" "go" "kotlin" "rust" "csharp")

    # Step 2: Language version
    case "$LANGUAGE_NAME" in
        java)       LANGUAGE_VERSION=$(prompt_select "Java version:" "21" "17" "11") ;;
        typescript) LANGUAGE_VERSION=$(prompt_select "TypeScript version:" "5") ;;
        python)     LANGUAGE_VERSION=$(prompt_select "Python version:" "3.12") ;;
        go)         LANGUAGE_VERSION=$(prompt_select "Go version:" "1.22") ;;
        kotlin)     LANGUAGE_VERSION=$(prompt_select "Kotlin version:" "2.0") ;;
        rust)       LANGUAGE_VERSION=$(prompt_select "Rust edition:" "2024") ;;
        csharp)     LANGUAGE_VERSION=$(prompt_select "C# version:" "12") ;;
    esac

    # Step 3: Framework
    case "$LANGUAGE_NAME" in
        java)       FRAMEWORK_NAME=$(prompt_select "Framework:" "quarkus" "spring-boot") ;;
        typescript) FRAMEWORK_NAME=$(prompt_select "Framework:" "nestjs" "express" "fastify") ;;
        python)     FRAMEWORK_NAME=$(prompt_select "Framework:" "fastapi" "django" "flask") ;;
        go)         FRAMEWORK_NAME=$(prompt_select "Framework:" "stdlib" "gin" "fiber") ;;
        kotlin)     FRAMEWORK_NAME=$(prompt_select "Framework:" "ktor" "spring-boot") ;;
        rust)       FRAMEWORK_NAME=$(prompt_select "Framework:" "axum" "actix") ;;
        csharp)     FRAMEWORK_NAME="dotnet" ;;
    esac

    # Step 4: Framework version (optional)
    FRAMEWORK_VERSION=$(prompt_input "Framework version (optional)" "")

    DB_TYPE=$(prompt_select "Database:" "postgresql" "oracle" "mysql" "mongodb" "cassandra" "sqlite" "none")

    if [[ "$DB_TYPE" != "none" ]]; then
        case "$LANGUAGE_NAME" in
            java|kotlin)
                case "$DB_TYPE" in
                    postgresql|oracle|mysql) DB_MIGRATION=$(prompt_select "Migration tool:" "flyway" "liquibase" "none") ;;
                    mongodb) DB_MIGRATION=$(prompt_select "Migration tool:" "mongock" "none") ;;
                    cassandra) DB_MIGRATION="none" ;;
                    *) DB_MIGRATION="none" ;;
                esac
                ;;
            typescript) DB_MIGRATION=$(prompt_select "Migration tool:" "prisma" "none") ;;
            python) DB_MIGRATION=$(prompt_select "Migration tool:" "alembic" "none") ;;
            *) DB_MIGRATION="none" ;;
        esac
    else
        DB_MIGRATION="none"
    fi

    CACHE_TYPE=$(prompt_select "Cache:" "none" "redis" "dragonfly" "memcached")

    # Message broker
    MESSAGE_BROKER_TYPE="none"
    if [[ "$EVENT_DRIVEN" == "true" ]]; then
        MESSAGE_BROKER_TYPE=$(prompt_select "Message broker:" "kafka" "rabbitmq" "sqs" "pulsar" "nats" "none")
    fi

    ARCHITECTURE=$(prompt_select "Architecture pattern:" "hexagonal" "clean" "layered" "modular")

    CONTAINER=$(prompt_select "Container runtime:" "docker" "podman" "none")
    ORCHESTRATOR=$(prompt_select "Orchestrator:" "kubernetes" "docker-compose" "none")

    # Observability backend (always enabled, choose backend)
    OBSERVABILITY=$(prompt_select "Observability standard:" "opentelemetry" "datadog" "prometheus-only")
    OBSERVABILITY_BACKEND=$(prompt_select "Observability backend:" "grafana-stack" "elastic-stack" "datadog" "newrelic" "custom")

    NATIVE_BUILD=false
    if [[ "$LANGUAGE_NAME" == "java" || "$LANGUAGE_NAME" == "kotlin" ]]; then
        prompt_yesno "Enable native build (GraalVM/Mandrel)?" "y" && NATIVE_BUILD=true
    fi

    # Testing
    SMOKE_TESTS=false
    prompt_yesno "Enable smoke tests?" "y" && SMOKE_TESTS=true
    PERFORMANCE_TESTS=false
    prompt_yesno "Enable performance tests?" "y" && PERFORMANCE_TESTS=true
    CONTRACT_TESTS=false
    prompt_yesno "Enable contract tests?" "n" && CONTRACT_TESTS=true
    CHAOS_TESTS=false
    prompt_yesno "Enable chaos tests?" "n" && CHAOS_TESTS=true

    # Build tool for Java
    if [[ "$LANGUAGE_NAME" == "java" ]]; then
        BUILD_TOOL=$(prompt_select "Build tool:" "maven" "gradle")
    fi
}

# ─── Config File Mode ─────────────────────────────────────────────────────────

run_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi

    # Detect old vs new config format
    if detect_old_config_format "$CONFIG_FILE"; then
        log_warn "Detected old config format (v2). Auto-migrating..."
        run_config_v2_compat
    else
        run_config_v3
    fi

    log_info "Loaded config from: $CONFIG_FILE"
}

# Parse v3 config format
run_config_v3() {
    # Project identity
    PROJECT_NAME=$(parse_yaml_value "$CONFIG_FILE" "name" "project")
    PROJECT_PURPOSE=$(parse_yaml_value "$CONFIG_FILE" "purpose" "project")

    # Architecture
    ARCH_STYLE=$(parse_yaml_value "$CONFIG_FILE" "style" "architecture")
    [[ -z "$ARCH_STYLE" ]] && ARCH_STYLE="microservice"
    DOMAIN_DRIVEN=$(parse_yaml_value "$CONFIG_FILE" "domain_driven" "architecture")
    [[ -z "$DOMAIN_DRIVEN" ]] && DOMAIN_DRIVEN="false"
    EVENT_DRIVEN=$(parse_yaml_value "$CONFIG_FILE" "event_driven" "architecture")
    [[ -z "$EVENT_DRIVEN" ]] && EVENT_DRIVEN="false"

    # Interfaces (v3 format)
    local iface_list
    iface_list=$(parse_interfaces "$CONFIG_FILE")
    if [[ -n "$iface_list" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && INTERFACE_TYPES+=("$line")
        done <<< "$iface_list"
    fi

    # Derive PROTOCOLS and PROJECT_TYPE for backward compat
    derive_protocols_from_interfaces
    derive_project_type

    # Language
    LANGUAGE_NAME=$(parse_yaml_value "$CONFIG_FILE" "name" "language")
    LANGUAGE_VERSION=$(parse_yaml_value "$CONFIG_FILE" "version" "language")

    # Framework
    FRAMEWORK_NAME=$(parse_yaml_value "$CONFIG_FILE" "name" "framework")
    FRAMEWORK_VERSION=$(parse_yaml_value "$CONFIG_FILE" "version" "framework")
    BUILD_TOOL=$(parse_yaml_value "$CONFIG_FILE" "build_tool" "framework")
    [[ -z "$BUILD_TOOL" ]] && BUILD_TOOL="maven"
    NATIVE_BUILD=$(parse_yaml_value "$CONFIG_FILE" "native_build" "framework")
    [[ -z "$NATIVE_BUILD" ]] && NATIVE_BUILD="false"
    if [[ ! "$LANGUAGE_NAME" =~ ^(java|kotlin)$ ]]; then
        NATIVE_BUILD="false"
    fi

    # Data: database
    DB_TYPE=$(parse_yaml_nested "$CONFIG_FILE" "data" "database" "type")
    [[ -z "$DB_TYPE" ]] && DB_TYPE="none"
    DB_MIGRATION=$(parse_yaml_nested "$CONFIG_FILE" "data" "database" "migration")
    [[ -z "$DB_MIGRATION" ]] && DB_MIGRATION="none"

    # Data: cache
    CACHE_TYPE=$(parse_yaml_nested "$CONFIG_FILE" "data" "cache" "type")
    [[ -z "$CACHE_TYPE" ]] && CACHE_TYPE="none"

    # Data: message broker
    MESSAGE_BROKER_TYPE=$(parse_yaml_nested "$CONFIG_FILE" "data" "message_broker" "type")
    [[ -z "$MESSAGE_BROKER_TYPE" ]] && MESSAGE_BROKER_TYPE="none"

    # Infrastructure
    CONTAINER=$(parse_yaml_value "$CONFIG_FILE" "container" "infrastructure")
    [[ -z "$CONTAINER" ]] && CONTAINER="none"
    ORCHESTRATOR=$(parse_yaml_value "$CONFIG_FILE" "orchestrator" "infrastructure")
    [[ -z "$ORCHESTRATOR" ]] && ORCHESTRATOR="none"

    # Observability (top-level section)
    OBSERVABILITY=$(parse_yaml_value "$CONFIG_FILE" "standard" "observability")
    [[ -z "$OBSERVABILITY" ]] && OBSERVABILITY="opentelemetry"
    OBSERVABILITY_BACKEND=$(parse_yaml_value "$CONFIG_FILE" "backend" "observability")
    [[ -z "$OBSERVABILITY_BACKEND" ]] && OBSERVABILITY_BACKEND="grafana-stack"

    # Testing
    SMOKE_TESTS=$(parse_yaml_value "$CONFIG_FILE" "smoke_tests" "testing")
    [[ -z "$SMOKE_TESTS" ]] && SMOKE_TESTS="true"
    PERFORMANCE_TESTS=$(parse_yaml_value "$CONFIG_FILE" "performance_tests" "testing")
    [[ -z "$PERFORMANCE_TESTS" ]] && PERFORMANCE_TESTS="true"
    CONTRACT_TESTS=$(parse_yaml_value "$CONFIG_FILE" "contract_tests" "testing")
    [[ -z "$CONTRACT_TESTS" ]] && CONTRACT_TESTS="false"
    CHAOS_TESTS=$(parse_yaml_value "$CONFIG_FILE" "chaos_tests" "testing")
    [[ -z "$CHAOS_TESTS" ]] && CHAOS_TESTS="false"

    # Architecture pattern (for project identity — default to hexagonal)
    ARCHITECTURE="hexagonal"
}

# Parse old v2 config format with backward compatibility
run_config_v2_compat() {
    log_warn "Using backward-compatible v2 config parsing. Consider migrating to v3 format."

    # Project identity
    PROJECT_NAME=$(parse_yaml_value "$CONFIG_FILE" "name" "project")
    PROJECT_TYPE=$(parse_yaml_value "$CONFIG_FILE" "type" "project")
    PROJECT_PURPOSE=$(parse_yaml_value "$CONFIG_FILE" "purpose" "project")
    ARCHITECTURE=$(parse_yaml_value "$CONFIG_FILE" "architecture" "project")
    [[ -z "$ARCHITECTURE" ]] && ARCHITECTURE="hexagonal"

    # Migrate old type to new architecture style + interfaces
    if [[ -n "$PROJECT_TYPE" ]]; then
        migrate_old_type "$PROJECT_TYPE"
    else
        ARCH_STYLE="microservice"
        INTERFACE_TYPES=("rest")
    fi

    # Language
    LANGUAGE_NAME=$(parse_yaml_value "$CONFIG_FILE" "name" "language")
    LANGUAGE_VERSION=$(parse_yaml_value "$CONFIG_FILE" "version" "language")

    # Framework
    FRAMEWORK_NAME=$(parse_yaml_value "$CONFIG_FILE" "name" "framework")
    FRAMEWORK_VERSION=$(parse_yaml_value "$CONFIG_FILE" "version" "framework")
    BUILD_TOOL=$(parse_yaml_value "$CONFIG_FILE" "build_tool" "framework")
    [[ -z "$BUILD_TOOL" ]] && BUILD_TOOL="maven"
    NATIVE_BUILD=$(parse_yaml_value "$CONFIG_FILE" "native_build" "framework")
    [[ -z "$NATIVE_BUILD" ]] && NATIVE_BUILD="false"
    if [[ ! "$LANGUAGE_NAME" =~ ^(java|kotlin)$ ]]; then
        NATIVE_BUILD="false"
    fi

    # Stack: database (old v2 nesting under "stack")
    DB_TYPE=$(parse_yaml_nested "$CONFIG_FILE" "stack" "database" "type")
    [[ -z "$DB_TYPE" ]] && DB_TYPE="none"
    DB_MIGRATION=$(parse_yaml_nested "$CONFIG_FILE" "stack" "database" "migration")
    [[ -z "$DB_MIGRATION" ]] && DB_MIGRATION="none"

    # Stack: infrastructure
    CONTAINER=$(parse_yaml_nested "$CONFIG_FILE" "stack" "infrastructure" "container")
    [[ -z "$CONTAINER" ]] && CONTAINER="none"
    ORCHESTRATOR=$(parse_yaml_nested "$CONFIG_FILE" "stack" "infrastructure" "orchestrator")
    [[ -z "$ORCHESTRATOR" ]] && ORCHESTRATOR="none"
    OBSERVABILITY=$(parse_yaml_nested "$CONFIG_FILE" "stack" "infrastructure" "observability")
    [[ -z "$OBSERVABILITY" ]] && OBSERVABILITY="opentelemetry"
    OBSERVABILITY_BACKEND="grafana-stack"

    # Stack: cache
    CACHE_TYPE=$(parse_yaml_nested "$CONFIG_FILE" "stack" "cache" "type")
    [[ -z "$CACHE_TYPE" ]] && CACHE_TYPE="none"

    # Message broker (not in v2)
    MESSAGE_BROKER_TYPE="none"

    # Smoke tests
    SMOKE_TESTS=$(parse_yaml_value "$CONFIG_FILE" "smoke_tests" "stack")
    [[ -z "$SMOKE_TESTS" ]] && SMOKE_TESTS="true"
    PERFORMANCE_TESTS="true"
    CONTRACT_TESTS="false"
    CHAOS_TESTS="false"

    # Parse old protocols list and merge with migrated interfaces
    local proto_list
    proto_list=$(parse_yaml_list "$CONFIG_FILE" "protocols")
    if [[ -n "$proto_list" ]]; then
        while IFS= read -r line; do
            if [[ -n "$line" ]] && ! array_contains "$line" "${INTERFACE_TYPES[@]}"; then
                INTERFACE_TYPES+=("$line")
            fi
        done <<< "$proto_list"
    fi

    # Security
    local compliance_list
    compliance_list=$(parse_yaml_list "$CONFIG_FILE" "compliance")
    if [[ -n "$compliance_list" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && SECURITY_COMPLIANCE+=("$line")
        done <<< "$compliance_list"
    fi
    ENCRYPTION_AT_REST=$(parse_yaml_nested "$CONFIG_FILE" "security" "encryption" "at_rest")
    [[ -z "$ENCRYPTION_AT_REST" ]] && ENCRYPTION_AT_REST="true"
    KEY_MANAGEMENT=$(parse_yaml_nested "$CONFIG_FILE" "security" "encryption" "key_management")
    [[ -z "$KEY_MANAGEMENT" ]] && KEY_MANAGEMENT="none"
    PENTEST_READINESS=$(parse_yaml_value "$CONFIG_FILE" "pentest_readiness" "security")
    [[ -z "$PENTEST_READINESS" ]] && PENTEST_READINESS="true"

    # Cloud
    CLOUD_PROVIDER=$(parse_yaml_value "$CONFIG_FILE" "provider" "cloud")
    [[ -z "$CLOUD_PROVIDER" ]] && CLOUD_PROVIDER="none"

    # Infrastructure expanded (new section takes precedence over stack.infrastructure)
    local new_container new_orchestrator
    new_container=$(parse_yaml_value "$CONFIG_FILE" "container" "infrastructure")
    new_orchestrator=$(parse_yaml_value "$CONFIG_FILE" "orchestrator" "infrastructure")
    [[ -n "$new_container" ]] && CONTAINER="$new_container"
    [[ -n "$new_orchestrator" ]] && ORCHESTRATOR="$new_orchestrator"

    TEMPLATING=$(parse_yaml_value "$CONFIG_FILE" "templating" "infrastructure")
    [[ -z "$TEMPLATING" ]] && TEMPLATING="kustomize"
    IAC=$(parse_yaml_value "$CONFIG_FILE" "iac" "infrastructure")
    [[ -z "$IAC" ]] && IAC="none"
    REGISTRY=$(parse_yaml_value "$CONFIG_FILE" "registry" "infrastructure")
    [[ -z "$REGISTRY" ]] && REGISTRY="none"
    API_GATEWAY=$(parse_yaml_value "$CONFIG_FILE" "api_gateway" "infrastructure")
    [[ -z "$API_GATEWAY" ]] && API_GATEWAY="none"
    SERVICE_MESH=$(parse_yaml_value "$CONFIG_FILE" "service_mesh" "infrastructure")
    [[ -z "$SERVICE_MESH" ]] && SERVICE_MESH="none"

    # Domain template
    DOMAIN_TEMPLATE=$(parse_yaml_value "$CONFIG_FILE" "template" "domain")
    [[ -z "$DOMAIN_TEMPLATE" ]] && DOMAIN_TEMPLATE="none"

    # Auto-enforcement: compliance implies encryption
    if array_contains "pci-dss" "${SECURITY_COMPLIANCE[@]}" || array_contains "hipaa" "${SECURITY_COMPLIANCE[@]}"; then
        ENCRYPTION_AT_REST="true"
    fi

    # Re-derive protocols from merged interfaces
    derive_protocols_from_interfaces

    DOMAIN_DRIVEN="false"
    EVENT_DRIVEN="false"

    log_info "Loaded config from: $CONFIG_FILE"
}

# ─── Phase 1: Assemble Rules ─────────────────────────────────────────────────

assemble_rules() {
    local rules_dir="${OUTPUT_DIR}/rules"
    mkdir -p "$rules_dir"

    local lang="$LANGUAGE_NAME"
    local lang_ver="$LANGUAGE_VERSION"
    local fw="$FRAMEWORK_NAME"
    local fw_ver="$FRAMEWORK_VERSION"

    # ── Layer 1: Core (01-12) ──
    log_info "Layer 1: Copying core rules..."
    for core_file in "$CORE_DIR"/*.md; do
        if [[ -f "$core_file" ]]; then
            local basename
            basename=$(basename "$core_file")

            # Skip cloud-native principles for library projects (most don't apply)
            if [[ "$basename" == "12-cloud-native-principles.md" && "$ARCH_STYLE" == "library" ]]; then
                log_info "  Skipping ${basename} (library project)"
                continue
            fi

            cp "$core_file" "${rules_dir}/${basename}"
            log_success "  ${basename}"
        fi
    done

    # ── Layer 2: Language (20-25) ──
    log_info "Layer 2: Copying language rules (${lang} ${lang_ver})..."
    local lang_num=20

    # Language common files (20-22)
    local lang_common_dir="${LANGUAGES_DIR}/${lang}/common"
    if [[ -d "$lang_common_dir" ]]; then
        for lang_file in "$lang_common_dir"/*.md; do
            if [[ -f "$lang_file" ]]; then
                local basename
                basename=$(basename "$lang_file")
                local target_name
                target_name=$(printf "%02d-%s" "$lang_num" "$basename")
                cp "$lang_file" "${rules_dir}/${target_name}"
                log_success "  ${target_name}"
                lang_num=$((lang_num + 1))
            fi
        done
    else
        log_warn "  Language common directory not found: languages/${lang}/common/"
    fi

    # Language version-specific files (24-25)
    local lang_version_dir="${LANGUAGES_DIR}/${lang}/${lang}-${lang_ver}"
    lang_num=24
    if [[ -d "$lang_version_dir" ]]; then
        for ver_file in "$lang_version_dir"/*.md; do
            if [[ -f "$ver_file" ]]; then
                local basename
                basename=$(basename "$ver_file")
                local target_name
                target_name=$(printf "%02d-%s" "$lang_num" "$basename")
                cp "$ver_file" "${rules_dir}/${target_name}"
                log_success "  ${target_name}"
                lang_num=$((lang_num + 1))
            fi
        done
    else
        log_warn "  Language version directory not found: languages/${lang}/${lang}-${lang_ver}/"
    fi

    # ── Layer 3: Framework (30-42) ──
    log_info "Layer 3: Copying framework rules (${fw})..."
    local fw_num=30

    # Framework common files (30-39)
    local fw_common_dir="${FRAMEWORKS_DIR}/${fw}/common"
    if [[ -d "$fw_common_dir" ]]; then
        for fw_file in "$fw_common_dir"/*.md; do
            if [[ -f "$fw_file" ]]; then
                local basename
                basename=$(basename "$fw_file")
                local target_name
                target_name=$(printf "%02d-%s" "$fw_num" "$basename")
                cp "$fw_file" "${rules_dir}/${target_name}"
                log_success "  ${target_name}"
                fw_num=$((fw_num + 1))
            fi
        done
    else
        log_warn "  Framework common directory not found: frameworks/${fw}/common/"
    fi

    # Framework version-specific files (40-42)
    if [[ -n "$fw_ver" ]]; then
        local fw_version_dir
        fw_version_dir=$(find_version_dir "${FRAMEWORKS_DIR}/${fw}" "$fw" "$fw_ver")
        fw_num=40
        if [[ -n "$fw_version_dir" && -d "$fw_version_dir" ]]; then
            for fwv_file in "$fw_version_dir"/*.md; do
                if [[ -f "$fwv_file" ]]; then
                    local basename
                    basename=$(basename "$fwv_file")
                    local target_name
                    target_name=$(printf "%02d-%s" "$fw_num" "$basename")
                    cp "$fwv_file" "${rules_dir}/${target_name}"
                    log_success "  ${target_name}"
                    fw_num=$((fw_num + 1))
                fi
            done
        fi
    fi

    # ── Layer 4: Domain (50-51) ──
    log_info "Layer 4: Generating project identity and domain..."

    # Generate Project Identity (50)
    generate_project_identity "${rules_dir}"
    log_success "  50-project-identity.md"

    # Copy Domain Template (51)
    if [[ "$DOMAIN_TEMPLATE" != "none" && "$DOMAIN_TEMPLATE" != "custom" ]]; then
        local domain_dir="${TEMPLATES_DIR}/domains/${DOMAIN_TEMPLATE}"
        if [[ -d "$domain_dir" && -f "${domain_dir}/domain-rules.md" ]]; then
            cp "${domain_dir}/domain-rules.md" "${rules_dir}/51-domain.md"
            log_success "  51-domain.md (${DOMAIN_TEMPLATE} domain)"
        elif [[ -d "${TEMPLATES_DIR}/examples/${DOMAIN_TEMPLATE}" ]]; then
            # Fallback: check examples directory for legacy templates
            local legacy_domain
            legacy_domain=$(find "${TEMPLATES_DIR}/examples/${DOMAIN_TEMPLATE}" -name "*domain.md" | head -1)
            if [[ -n "$legacy_domain" ]]; then
                cp "$legacy_domain" "${rules_dir}/51-domain.md"
                log_success "  51-domain.md (${DOMAIN_TEMPLATE} domain — from examples)"
            fi
        else
            log_warn "  Domain template not found: ${DOMAIN_TEMPLATE}. Using generic template."
            cp "${TEMPLATES_DIR}/domain-template.md" "${rules_dir}/51-domain.md"
        fi
    else
        cp "${TEMPLATES_DIR}/domain-template.md" "${rules_dir}/51-domain.md"
        log_success "  51-domain.md (template — customize for your domain)"
    fi
}

generate_project_identity() {
    local rules_dir="$1"
    local interfaces_list="${INTERFACE_TYPES[*]:-none}"
    cat > "${rules_dir}/50-project-identity.md" <<HEREDOC
# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Project Identity — ${PROJECT_NAME}

## Identity
- **Name:** ${PROJECT_NAME}
- **Purpose:** ${PROJECT_PURPOSE}
- **Architecture Style:** ${ARCH_STYLE}
- **Domain-Driven Design:** ${DOMAIN_DRIVEN}
- **Event-Driven:** ${EVENT_DRIVEN}
- **Interfaces:** ${interfaces_list}
- **Language:** ${LANGUAGE_NAME} ${LANGUAGE_VERSION}
- **Framework:** ${FRAMEWORK_NAME}${FRAMEWORK_VERSION:+ ${FRAMEWORK_VERSION}}

## Technology Stack
| Layer | Technology |
|-------|-----------|
| Architecture | ${ARCH_STYLE} |
| Language | ${LANGUAGE_NAME} ${LANGUAGE_VERSION} |
| Framework | ${FRAMEWORK_NAME}${FRAMEWORK_VERSION:+ ${FRAMEWORK_VERSION}} |
| Build Tool | ${BUILD_TOOL:-N/A} |
| Database | ${DB_TYPE} |
| Migration | ${DB_MIGRATION} |
| Cache | ${CACHE_TYPE:-none} |
| Message Broker | ${MESSAGE_BROKER_TYPE:-none} |
| Container | ${CONTAINER} |
| Orchestrator | ${ORCHESTRATOR} |
| Observability | ${OBSERVABILITY} (${OBSERVABILITY_BACKEND}) |
| Resilience | Mandatory (always enabled) |
| Native Build | ${NATIVE_BUILD} |
| Smoke Tests | ${SMOKE_TESTS} |
| Contract Tests | ${CONTRACT_TESTS} |

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

# ─── Database & Cache Reference Helpers ──────────────────────────────────────

copy_database_references() {
    local db_type="$1"
    local target_dir="$2/skills/database-patterns/references"
    mkdir -p "$target_dir"

    # Always copy version matrix
    if [[ -f "${DATABASES_DIR}/version-matrix.md" ]]; then
        cp "${DATABASES_DIR}/version-matrix.md" "$target_dir/"
    fi

    case "$db_type" in
        postgresql|oracle|mysql)
            if [[ -d "${DATABASES_DIR}/sql/common" ]]; then
                cp "${DATABASES_DIR}/sql/common/"*.md "$target_dir/" 2>/dev/null || true
            fi
            if [[ -d "${DATABASES_DIR}/sql/${db_type}" ]]; then
                cp "${DATABASES_DIR}/sql/${db_type}/"*.md "$target_dir/" 2>/dev/null || true
            fi
            ;;
        mongodb|cassandra)
            if [[ -d "${DATABASES_DIR}/nosql/common" ]]; then
                cp "${DATABASES_DIR}/nosql/common/"*.md "$target_dir/" 2>/dev/null || true
            fi
            if [[ -d "${DATABASES_DIR}/nosql/${db_type}" ]]; then
                cp "${DATABASES_DIR}/nosql/${db_type}/"*.md "$target_dir/" 2>/dev/null || true
            fi
            ;;
    esac
    log_success "  database references for ${db_type}"
}

copy_cache_references() {
    local cache_type="$1"
    local target_dir="$2/skills/database-patterns/references"
    mkdir -p "$target_dir"

    if [[ "$cache_type" != "none" ]]; then
        if [[ -d "${DATABASES_DIR}/cache/common" ]]; then
            cp "${DATABASES_DIR}/cache/common/"*.md "$target_dir/" 2>/dev/null || true
        fi
        if [[ -d "${DATABASES_DIR}/cache/${cache_type}" ]]; then
            cp "${DATABASES_DIR}/cache/${cache_type}/"*.md "$target_dir/" 2>/dev/null || true
        fi
        log_success "  cache references for ${cache_type}"
    fi
}

# ─── Phase 1b: Assemble Security Rules ────────────────────────────────────────

assemble_security_rules() {
    local rules_dir="${OUTPUT_DIR}/rules"

    log_info "Copying security rules..."

    # Always include base security rules
    if [[ -f "${SECURITY_DIR}/application-security.md" ]]; then
        cp "${SECURITY_DIR}/application-security.md" "${rules_dir}/15-application-security.md"
        log_success "  15-application-security.md"
    fi

    if [[ -f "${SECURITY_DIR}/cryptography.md" ]]; then
        cp "${SECURITY_DIR}/cryptography.md" "${rules_dir}/16-cryptography.md"
        log_success "  16-cryptography.md"
    fi

    # Pentest readiness (conditional)
    if [[ "$PENTEST_READINESS" == "true" ]]; then
        if [[ -f "${SECURITY_DIR}/pentest-readiness.md" ]]; then
            cp "${SECURITY_DIR}/pentest-readiness.md" "${rules_dir}/17-pentest-readiness.md"
            log_success "  17-pentest-readiness.md"
        fi
    fi

    # Compliance frameworks (conditional — from security.compliance[])
    for compliance in "${SECURITY_COMPLIANCE[@]}"; do
        if [[ -f "${SECURITY_DIR}/compliance/${compliance}.md" ]]; then
            cp "${SECURITY_DIR}/compliance/${compliance}.md" "${rules_dir}/18-compliance-${compliance}.md"
            log_success "  18-compliance-${compliance}.md"
        else
            log_warn "  Compliance file not found: security/compliance/${compliance}.md"
        fi
    done
}

# ─── Phase 2b: Assemble Cloud Knowledge ──────────────────────────────────────

assemble_cloud_knowledge() {
    if [[ "$CLOUD_PROVIDER" == "none" ]]; then
        log_info "No cloud provider selected, skipping cloud knowledge pack."
        return
    fi

    local kp_dir="${OUTPUT_DIR}/skills/knowledge-packs"
    mkdir -p "$kp_dir"

    if [[ -f "${CLOUD_PROVIDERS_DIR}/${CLOUD_PROVIDER}.md" ]]; then
        cp "${CLOUD_PROVIDERS_DIR}/${CLOUD_PROVIDER}.md" "${kp_dir}/cloud-${CLOUD_PROVIDER}.md"
        log_success "  cloud-${CLOUD_PROVIDER}.md (knowledge pack)"
    else
        log_warn "  Cloud provider file not found: cloud-providers/${CLOUD_PROVIDER}.md"
    fi
}

# ─── Phase 2c: Assemble Infrastructure Knowledge ─────────────────────────────

assemble_infrastructure_knowledge() {
    local kp_dir="${OUTPUT_DIR}/skills/knowledge-packs"
    mkdir -p "$kp_dir"

    log_info "Copying infrastructure knowledge packs..."

    # Kubernetes deployment patterns (if orchestrator == kubernetes)
    if [[ "$ORCHESTRATOR" == "kubernetes" ]]; then
        if [[ -f "${INFRASTRUCTURE_DIR}/kubernetes/deployment-patterns.md" ]]; then
            cp "${INFRASTRUCTURE_DIR}/kubernetes/deployment-patterns.md" "${kp_dir}/k8s-deployment.md"
            log_success "  k8s-deployment.md"
        fi
    fi

    # Templating: kustomize or helm
    if [[ "$TEMPLATING" == "kustomize" ]]; then
        if [[ -f "${INFRASTRUCTURE_DIR}/kubernetes/kustomize-patterns.md" ]]; then
            cp "${INFRASTRUCTURE_DIR}/kubernetes/kustomize-patterns.md" "${kp_dir}/k8s-kustomize.md"
            log_success "  k8s-kustomize.md"
        fi
    elif [[ "$TEMPLATING" == "helm" ]]; then
        if [[ -f "${INFRASTRUCTURE_DIR}/kubernetes/helm-patterns.md" ]]; then
            cp "${INFRASTRUCTURE_DIR}/kubernetes/helm-patterns.md" "${kp_dir}/k8s-helm.md"
            log_success "  k8s-helm.md"
        fi
    fi

    # Container patterns (if container != none)
    if [[ "$CONTAINER" != "none" ]]; then
        if [[ -f "${INFRASTRUCTURE_DIR}/containers/dockerfile-patterns.md" ]]; then
            cp "${INFRASTRUCTURE_DIR}/containers/dockerfile-patterns.md" "${kp_dir}/dockerfile.md"
            log_success "  dockerfile.md"
        fi
        if [[ -f "${INFRASTRUCTURE_DIR}/containers/registry-patterns.md" ]]; then
            cp "${INFRASTRUCTURE_DIR}/containers/registry-patterns.md" "${kp_dir}/registry.md"
            log_success "  registry.md"
        fi
    fi

    # IaC patterns (if iac != none)
    if [[ "$IAC" != "none" ]]; then
        if [[ -f "${INFRASTRUCTURE_DIR}/iac/${IAC}-patterns.md" ]]; then
            cp "${INFRASTRUCTURE_DIR}/iac/${IAC}-patterns.md" "${kp_dir}/iac-${IAC}.md"
            log_success "  iac-${IAC}.md"
        fi
    fi

    # API Gateway patterns (if api_gateway != none)
    if [[ "$API_GATEWAY" != "none" ]]; then
        # Copy the generic API gateway pattern
        if [[ -f "${PATTERNS_DIR}/microservice/api-gateway.md" ]]; then
            cp "${PATTERNS_DIR}/microservice/api-gateway.md" "${kp_dir}/api-gateway-pattern.md"
            log_success "  api-gateway-pattern.md"
        fi
        # Copy the specific gateway implementation
        if [[ -f "${INFRASTRUCTURE_DIR}/api-gateway/${API_GATEWAY}-patterns.md" ]]; then
            cp "${INFRASTRUCTURE_DIR}/api-gateway/${API_GATEWAY}-patterns.md" "${kp_dir}/api-gateway.md"
            log_success "  api-gateway.md (${API_GATEWAY})"
        fi
    fi
}

# ─── Phase 1.5: Assemble Patterns ────────────────────────────────────────────

# Pattern tracking arrays (populated by select_pattern / select_pattern_dir)
SELECTED_ARCHITECTURAL=()
SELECTED_MICROSERVICE=()
SELECTED_RESILIENCE=()
SELECTED_DATA=()
SELECTED_INTEGRATION=()
_CONCATENATED_PROTOCOLS=()

select_pattern() {
    local rel_path="$1"
    local src="${PATTERNS_DIR}/${rel_path}"
    if [[ ! -f "$src" ]]; then
        return
    fi
    # Determine category from first path component
    local category="${rel_path%%/*}"
    # Avoid duplicates
    case "$category" in
        architectural)
            for p in "${SELECTED_ARCHITECTURAL[@]}"; do [[ "$p" == "$rel_path" ]] && return; done
            SELECTED_ARCHITECTURAL+=("$rel_path")
            ;;
        microservice)
            for p in "${SELECTED_MICROSERVICE[@]}"; do [[ "$p" == "$rel_path" ]] && return; done
            SELECTED_MICROSERVICE+=("$rel_path")
            ;;
        resilience)
            for p in "${SELECTED_RESILIENCE[@]}"; do [[ "$p" == "$rel_path" ]] && return; done
            SELECTED_RESILIENCE+=("$rel_path")
            ;;
        data)
            for p in "${SELECTED_DATA[@]}"; do [[ "$p" == "$rel_path" ]] && return; done
            SELECTED_DATA+=("$rel_path")
            ;;
        integration)
            for p in "${SELECTED_INTEGRATION[@]}"; do [[ "$p" == "$rel_path" ]] && return; done
            SELECTED_INTEGRATION+=("$rel_path")
            ;;
    esac
    log_success "  + ${rel_path}"
}

select_pattern_dir() {
    local dir_name="$1"
    local src_dir="${PATTERNS_DIR}/${dir_name}"
    if [[ -d "$src_dir" ]]; then
        for f in "$src_dir"/*.md; do
            if [[ -f "$f" ]]; then
                local basename
                basename=$(basename "$f")
                select_pattern "${dir_name}/${basename}"
            fi
        done
    fi
}

flush_patterns() {
    local rules_dir="$1"
    local flushed=0

    # Helper: concatenate array of rel_paths into a single numbered file
    _flush_category() {
        local category="$1"
        shift
        local paths=("$@")
        if [[ ${#paths[@]} -eq 0 ]]; then
            return
        fi
        local outfile="${rules_dir}/14-${category}-patterns.md"
        {
            local cap_category
            cap_category="$(printf '%s' "$category" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$category" | cut -c2-)"
            echo "# ${cap_category} Patterns"
            echo ""
            echo "<!-- Auto-generated: concatenated from patterns/${category}/ -->"
            echo ""
            for rel_path in "${paths[@]}"; do
                local src="${PATTERNS_DIR}/${rel_path}"
                if [[ -f "$src" ]]; then
                    echo "---"
                    echo ""
                    cat "$src"
                    echo ""
                fi
            done
        } > "$outfile"
        log_success "  14-${category}-patterns.md (${#paths[@]} patterns)"
        flushed=$((flushed + 1))
    }

    _flush_category "architectural" "${SELECTED_ARCHITECTURAL[@]}"
    _flush_category "microservice"  "${SELECTED_MICROSERVICE[@]}"
    _flush_category "resilience"    "${SELECTED_RESILIENCE[@]}"
    _flush_category "data"          "${SELECTED_DATA[@]}"
    _flush_category "integration"   "${SELECTED_INTEGRATION[@]}"

    if [[ "$flushed" -eq 0 ]]; then
        log_warn "No patterns selected."
    fi
}

assemble_patterns() {
    if [[ ! -d "$PATTERNS_DIR" ]]; then
        log_warn "Patterns directory not found, skipping patterns."
        return
    fi

    local rules_dir="${OUTPUT_DIR}/rules"

    # Reset tracking arrays
    SELECTED_ARCHITECTURAL=()
    SELECTED_MICROSERVICE=()
    SELECTED_RESILIENCE=()
    SELECTED_DATA=()
    SELECTED_INTEGRATION=()

    log_info "Selecting patterns based on architecture: ${ARCH_STYLE}..."

    # Always include hexagonal architecture
    select_pattern "architectural/hexagonal-architecture.md"

    case "$ARCH_STYLE" in
        microservice)
            select_pattern_dir "microservice"
            select_pattern_dir "resilience"
            select_pattern "integration/anti-corruption-layer.md"
            select_pattern "integration/backend-for-frontend.md"
            select_pattern "integration/adapter-pattern.md"
            select_pattern_dir "data"
            ;;
        modular-monolith)
            select_pattern "architectural/modular-monolith.md"
            select_pattern "resilience/circuit-breaker.md"
            select_pattern "resilience/retry-with-backoff.md"
            select_pattern_dir "data"
            ;;
        monolith)
            select_pattern_dir "data"
            select_pattern "resilience/circuit-breaker.md"
            ;;
        library)
            if [[ "$DB_TYPE" != "none" ]]; then
                select_pattern "data/repository-pattern.md"
            fi
            select_pattern "integration/adapter-pattern.md"
            ;;
        serverless)
            select_pattern_dir "resilience"
            select_pattern_dir "integration"
            ;;
    esac

    # Event-driven patterns (cross-cutting)
    if [[ "$EVENT_DRIVEN" == "true" ]]; then
        select_pattern "data/event-store.md"
        select_pattern "microservice/saga-pattern.md"
        select_pattern "microservice/outbox-pattern.md"
        select_pattern "microservice/idempotency.md"
        select_pattern "resilience/dead-letter-queue.md"
        select_pattern "architectural/event-sourcing.md"
    fi

    # DDD patterns (cross-cutting)
    if [[ "$DOMAIN_DRIVEN" == "true" ]]; then
        select_pattern "integration/anti-corruption-layer.md"
    fi

    # CQRS is useful for both microservice and modular-monolith
    if [[ "$ARCH_STYLE" == "microservice" || "$ARCH_STYLE" == "modular-monolith" ]]; then
        select_pattern "architectural/cqrs.md"
    fi

    # Flush all selected patterns into flat 14-*-patterns.md files
    flush_patterns "$rules_dir"
}

# ─── Phase 1.6: Assemble Protocols ───────────────────────────────────────────

concat_protocol_dir() {
    local dir_name="$1"
    local rules_dir="$2"
    local src_dir="${PROTOCOLS_DIR}/${dir_name}"
    local outfile="${rules_dir}/13-${dir_name}-conventions.md"

    if [[ ! -d "$src_dir" ]]; then
        log_warn "  Protocol directory '${dir_name}' not found, skipping."
        return
    fi

    # Skip if already concatenated in this run (e.g., event-driven from both consumer and producer)
    local marker
    for marker in "${_CONCATENATED_PROTOCOLS[@]}"; do
        if [[ "$marker" == "$dir_name" ]]; then
            return
        fi
    done
    _CONCATENATED_PROTOCOLS+=("$dir_name")

    local count=0
    {
        local cap_dir_name
        cap_dir_name="$(printf '%s' "$dir_name" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$dir_name" | cut -c2-)"
        echo "# ${cap_dir_name} Conventions"
        echo ""
        echo "<!-- Auto-generated: concatenated from protocols/${dir_name}/ -->"
        echo ""
        for f in "$src_dir"/*.md; do
            if [[ -f "$f" ]]; then
                echo "---"
                echo ""
                cat "$f"
                echo ""
                count=$((count + 1))
            fi
        done
    } > "$outfile"

    log_success "  13-${dir_name}-conventions.md (${count} files)"
}

assemble_protocols() {
    if [[ ! -d "$PROTOCOLS_DIR" ]]; then
        log_warn "Protocols directory not found, skipping protocols."
        return
    fi

    local rules_dir="${OUTPUT_DIR}/rules"
    _CONCATENATED_PROTOCOLS=()

    log_info "Selecting protocols based on interfaces: ${INTERFACE_TYPES[*]:-none}..."

    for itype in "${INTERFACE_TYPES[@]}"; do
        case "$itype" in
            rest)
                concat_protocol_dir "rest" "$rules_dir"
                ;;
            grpc)
                concat_protocol_dir "grpc" "$rules_dir"
                ;;
            graphql)
                concat_protocol_dir "graphql" "$rules_dir"
                ;;
            websocket)
                concat_protocol_dir "websocket" "$rules_dir"
                ;;
            event-consumer|event-producer)
                concat_protocol_dir "event-driven" "$rules_dir"
                ;;
        esac
    done
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

        # review-api: requires "rest" in interfaces
        if array_contains "rest" "${INTERFACE_TYPES[@]}"; then
            copy_conditional_skill "review-api"
        fi

        # review-grpc: requires "grpc" in interfaces
        if array_contains "grpc" "${INTERFACE_TYPES[@]}"; then
            copy_conditional_skill "review-grpc"
        fi

        # review-graphql: requires "graphql" in interfaces
        if array_contains "graphql" "${INTERFACE_TYPES[@]}"; then
            copy_conditional_skill "review-graphql"
        fi

        # review-events: requires event-consumer or event-producer
        if array_contains "event-consumer" "${INTERFACE_TYPES[@]}" || array_contains "event-producer" "${INTERFACE_TYPES[@]}"; then
            copy_conditional_skill "review-events"
        fi

        # instrument-otel: requires observability != "none"
        if [[ "$OBSERVABILITY" != "none" ]]; then
            copy_conditional_skill "instrument-otel"
        fi

        # setup-environment: requires orchestrator != "none"
        if [[ "$ORCHESTRATOR" != "none" ]]; then
            copy_conditional_skill "setup-environment"
        fi

        # run-smoke-api: requires smoke_tests = true + rest
        if [[ "$SMOKE_TESTS" == "true" ]] && array_contains "rest" "${INTERFACE_TYPES[@]}"; then
            copy_conditional_skill "run-smoke-api"
        fi

        # run-smoke-socket: requires smoke_tests + tcp-custom
        if [[ "$SMOKE_TESTS" == "true" ]] && array_contains "tcp-custom" "${INTERFACE_TYPES[@]}"; then
            copy_conditional_skill "run-smoke-socket"
        fi

        # run-e2e: always available
        copy_conditional_skill "run-e2e"

        # run-perf-test: when performance tests enabled
        if [[ "$PERFORMANCE_TESTS" == "true" ]]; then
            copy_conditional_skill "run-perf-test"
        fi

        # run-contract-tests: when contract tests enabled
        if [[ "$CONTRACT_TESTS" == "true" ]]; then
            copy_conditional_skill "run-contract-tests"
        fi

        # security-compliance-review: requires any compliance framework
        if [[ ${#SECURITY_COMPLIANCE[@]} -gt 0 ]]; then
            copy_conditional_skill "security-compliance-review"
        fi

        # review-gateway: requires api_gateway != none
        if [[ "$API_GATEWAY" != "none" ]]; then
            copy_conditional_skill "review-gateway"
        fi
    fi

    # Copy knowledge packs
    if [[ -d "${SKILLS_TEMPLATES_DIR}/knowledge-packs" ]]; then
        log_info "Copying knowledge packs..."

        # layer-templates: always included
        copy_knowledge_pack "layer-templates"

        # database-patterns: requires database != "none"
        if [[ "$DB_TYPE" != "none" ]]; then
            copy_knowledge_pack "database-patterns"
            copy_database_references "$DB_TYPE" "$OUTPUT_DIR"
            copy_cache_references "${CACHE_TYPE:-none}" "$OUTPUT_DIR"
        elif [[ "${CACHE_TYPE:-none}" != "none" ]]; then
            # Cache without database: still copy database-patterns as container for cache refs
            copy_knowledge_pack "database-patterns"
            copy_cache_references "$CACHE_TYPE" "$OUTPUT_DIR"
        fi

        # stack-patterns: one per profile
        local stack_pack=""
        case "$FRAMEWORK_NAME" in
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

        # api-engineer: requires "rest" in interfaces (also handles grpc/graphql checklists)
        if array_contains "rest" "${INTERFACE_TYPES[@]}" || \
           array_contains "grpc" "${INTERFACE_TYPES[@]}" || \
           array_contains "graphql" "${INTERFACE_TYPES[@]}"; then
            copy_conditional_agent "api-engineer.md"
        fi

        # event-engineer: requires event-driven architecture
        if [[ "$EVENT_DRIVEN" == "true" ]] || \
           array_contains "event-consumer" "${INTERFACE_TYPES[@]}" || \
           array_contains "event-producer" "${INTERFACE_TYPES[@]}"; then
            copy_conditional_agent "event-engineer.md"
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
        log_info "No compile hook for ${LANGUAGE_NAME} (interpreted language), skipping hooks."
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
    local db_settings_key=""
    case "$DB_TYPE" in
        postgresql) db_settings_key="database-psql" ;;
        mysql) db_settings_key="database-mysql" ;;
        oracle) db_settings_key="database-oracle" ;;
        mongodb) db_settings_key="database-mongodb" ;;
        cassandra) db_settings_key="database-cassandra" ;;
    esac
    if [[ -n "$db_settings_key" ]] && [[ -f "${SETTINGS_TEMPLATES_DIR}/${db_settings_key}.json" ]]; then
        local db_perms
        db_perms=$(cat "${SETTINGS_TEMPLATES_DIR}/${db_settings_key}.json")
        all_permissions=$(merge_json_arrays "$all_permissions" "$db_perms")
    fi

    # Cache client permissions
    if [[ "${CACHE_TYPE:-none}" != "none" ]]; then
        local cache_settings_key="cache-${CACHE_TYPE}"
        if [[ -f "${SETTINGS_TEMPLATES_DIR}/${cache_settings_key}.json" ]]; then
            local cache_perms
            cache_perms=$(cat "${SETTINGS_TEMPLATES_DIR}/${cache_settings_key}.json")
            all_permissions=$(merge_json_arrays "$all_permissions" "$cache_perms")
        fi
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
│   ├── patterns/           ← Design patterns (architecture-driven)
│   └── protocols/          ← Protocol conventions (interface-driven)
├── skills/                 ← Skills invocable via /command
├── agents/                 ← AI personas (used by skills)
└── hooks/                  ← Automation (post-compile, etc.)
\`\`\`

## Tips

- **Rules are always active** — loaded automatically in every conversation
- **Patterns are selected** — based on architecture style (${ARCH_STYLE})
- **Protocols are selected** — based on interfaces (${INTERFACE_TYPES[*]:-none})
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

    # Validate stack compatibility
    validate_stack_compatibility

    # Infer native_build if set to "auto" or empty
    infer_native_build

    # --validate: stop after validation
    if [[ "$VALIDATE_ONLY" == true ]]; then
        echo ""
        log_success "Configuration validated successfully."
        echo "  Architecture:   ${ARCH_STYLE}"
        echo "  Language:       ${LANGUAGE_NAME} ${LANGUAGE_VERSION}"
        echo "  Framework:      ${FRAMEWORK_NAME}${FRAMEWORK_VERSION:+ ${FRAMEWORK_VERSION}}"
        echo "  Native Build:   ${NATIVE_BUILD}"
        echo "  Interfaces:     ${INTERFACE_TYPES[*]:-none}"
        echo "  Domain-Driven:  ${DOMAIN_DRIVEN}"
        echo "  Event-Driven:   ${EVENT_DRIVEN}"
        exit 0
    fi

    # Resolve stack-specific commands
    resolve_stack_commands

    # Set output directory
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="./.claude"
    fi

    echo ""
    log_info "Configuration:"
    echo "  Project:        ${PROJECT_NAME}"
    echo "  Architecture:   ${ARCH_STYLE} (DDD: ${DOMAIN_DRIVEN}, Events: ${EVENT_DRIVEN})"
    echo "  Interfaces:     ${INTERFACE_TYPES[*]:-none}"
    echo "  Language:       ${LANGUAGE_NAME} ${LANGUAGE_VERSION}"
    echo "  Framework:      ${FRAMEWORK_NAME}${FRAMEWORK_VERSION:+ ${FRAMEWORK_VERSION}}"
    echo "  Database:       ${DB_TYPE} (migration: ${DB_MIGRATION})"
    echo "  Cache:          ${CACHE_TYPE:-none}"
    echo "  Msg Broker:     ${MESSAGE_BROKER_TYPE:-none}"
    echo "  Infrastructure: ${CONTAINER} + ${ORCHESTRATOR}"
    echo "  Observability:  ${OBSERVABILITY} / ${OBSERVABILITY_BACKEND} (always enabled)"
    echo "  Native Build:   ${NATIVE_BUILD}"
    echo "  Resilience:     mandatory"
    echo "  Testing:        smoke=${SMOKE_TESTS} perf=${PERFORMANCE_TESTS} contract=${CONTRACT_TESTS} chaos=${CHAOS_TESTS}"
    echo "  Security:       compliance=[${SECURITY_COMPLIANCE[*]:-none}] encryption=${ENCRYPTION_AT_REST} kms=${KEY_MANAGEMENT}"
    echo "  Cloud:          ${CLOUD_PROVIDER}"
    echo "  Templating:     ${TEMPLATING}"
    echo "  IaC:            ${IAC}"
    echo "  Registry:       ${REGISTRY}"
    echo "  API Gateway:    ${API_GATEWAY}"
    echo "  Service Mesh:   ${SERVICE_MESH}"
    echo "  Domain:         ${DOMAIN_TEMPLATE}"
    echo ""

    # --dry-run: show what would be generated and exit
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Dry run — the following would be generated in ${OUTPUT_DIR}/:"
        echo ""
        echo "  rules/"
        echo "    Layer 1 (Core):      $(ls "${CORE_DIR}"/*.md 2>/dev/null | wc -l | xargs) files"
        echo "    Layer 2 (Language):  ${LANGUAGE_NAME} ${LANGUAGE_VERSION}"
        local lang_common="${LANGUAGES_DIR}/${LANGUAGE_NAME}/common"
        [[ -d "$lang_common" ]] && echo "      common:           $(ls "${lang_common}"/*.md 2>/dev/null | wc -l | xargs) files"
        local lang_ver_dir="${LANGUAGES_DIR}/${LANGUAGE_NAME}/${LANGUAGE_NAME}-${LANGUAGE_VERSION}"
        [[ -d "$lang_ver_dir" ]] && echo "      version-specific: $(ls "${lang_ver_dir}"/*.md 2>/dev/null | wc -l | xargs) files"
        echo "    Layer 3 (Framework): ${FRAMEWORK_NAME}"
        local fw_common="${FRAMEWORKS_DIR}/${FRAMEWORK_NAME}/common"
        [[ -d "$fw_common" ]] && echo "      common:           $(ls "${fw_common}"/*.md 2>/dev/null | wc -l | xargs) files"
        if [[ -n "$FRAMEWORK_VERSION" ]]; then
            local fw_ver_dir
            fw_ver_dir=$(find_version_dir "${FRAMEWORKS_DIR}/${FRAMEWORK_NAME}" "$FRAMEWORK_NAME" "$FRAMEWORK_VERSION")
            if [[ -n "$fw_ver_dir" ]]; then
                echo "      version-specific: $(ls "${fw_ver_dir}"/*.md 2>/dev/null | wc -l | xargs) files (${fw_ver_dir##*/})"
            else
                echo "      version-specific: 0 files (no match for ${FRAMEWORK_VERSION})"
            fi
        fi
        echo "    Layer 4 (Domain):   2 files (identity + domain template)"
        echo "    14-*-patterns.md    selected by architecture.style=${ARCH_STYLE}"
        echo "    13-*-conventions.md selected by interfaces=[${INTERFACE_TYPES[*]:-}]"
        echo ""
        echo "  skills/                core + conditional (feature-gated)"
        echo "  agents/                core + conditional + ${DEVELOPER_AGENT_KEY}-developer"
        [[ -n "$HOOK_TEMPLATE_KEY" ]] && echo "  hooks/                 post-compile-check.sh (${HOOK_TEMPLATE_KEY})"
        echo "  settings.json          composed from permission fragments"
        echo "  README.md              generated from template"
        echo ""
        log_info "No files were created (dry run)."
        exit 0
    fi

    if [[ "$INTERACTIVE" == true ]]; then
        prompt_yesno "Proceed with setup?" "y" || { log_warn "Aborted."; exit 0; }
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    log_info "Output directory: ${OUTPUT_DIR}/"

    # Clean stale generated files from previous runs
    local rules_dir="${OUTPUT_DIR}/rules"
    if [[ -d "$rules_dir" ]]; then
        rm -f "$rules_dir"/13-*-conventions.md "$rules_dir"/14-*-patterns.md
        # Remove legacy subdirectories from older versions
        rm -rf "$rules_dir"/patterns "$rules_dir"/protocols
    fi
    echo ""

    # Phase 1: Rules
    log_info "━━━ Phase 1: Rules ━━━"
    assemble_rules
    echo ""

    # Phase 1b: Security Rules
    log_info "━━━ Phase 1b: Security Rules ━━━"
    assemble_security_rules
    echo ""

    # Phase 1.5: Patterns
    log_info "━━━ Phase 1.5: Patterns ━━━"
    assemble_patterns
    echo ""

    # Phase 1.6: Protocols
    log_info "━━━ Phase 1.6: Protocols ━━━"
    assemble_protocols
    echo ""


    # Phase 2: Skills
    log_info "━━━ Phase 2: Skills ━━━"
    assemble_skills
    echo ""

    # Phase 2b: Cloud Knowledge
    log_info "━━━ Phase 2b: Cloud Knowledge Packs ━━━"
    assemble_cloud_knowledge
    echo ""

    # Phase 2c: Infrastructure Knowledge
    log_info "━━━ Phase 2c: Infrastructure Knowledge Packs ━━━"
    assemble_infrastructure_knowledge
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

    # Phase 7: Cross-reference verification
    log_info "━━━ Phase 7: Verification ━━━"
    verify_cross_references "$OUTPUT_DIR"
    echo ""

    # ─── Summary ──────────────────────────────────────────────────────────
    echo ""
    log_success "Setup complete!"
    echo ""

    local rules_count=0 skills_count=0 agents_count=0 patterns_count=0 protocols_count=0
    [[ -d "${OUTPUT_DIR}/rules" ]] && rules_count=$(find "${OUTPUT_DIR}/rules" -maxdepth 1 -name "*.md" -not -name "13-*" -not -name "14-*" | wc -l | xargs)
    [[ -d "${OUTPUT_DIR}/rules" ]] && patterns_count=$(find "${OUTPUT_DIR}/rules" -maxdepth 1 -name "14-*-patterns.md" | wc -l | xargs)
    [[ -d "${OUTPUT_DIR}/rules" ]] && protocols_count=$(find "${OUTPUT_DIR}/rules" -maxdepth 1 -name "13-*-conventions.md" | wc -l | xargs)
    [[ -d "${OUTPUT_DIR}/skills" ]] && skills_count=$(find "${OUTPUT_DIR}/skills" -name "SKILL.md" | wc -l | xargs)
    [[ -d "${OUTPUT_DIR}/agents" ]] && agents_count=$(find "${OUTPUT_DIR}/agents" -name "*.md" | wc -l | xargs)

    log_info "Generated:"
    echo "  Rules:      ${rules_count}"
    echo "  Patterns:   ${patterns_count} (14-*-patterns.md)"
    echo "  Protocols:  ${protocols_count} (13-*-conventions.md)"
    echo "  Skills:     ${skills_count}"
    echo "  Agents:     ${agents_count}"
    echo "  Hooks:      $(ls "${OUTPUT_DIR}/hooks" 2>/dev/null | wc -l | xargs)"
    echo "  Settings:   settings.json + settings.local.json"
    echo "  README:     README.md"
    log_info "Output: ${OUTPUT_DIR}/"
    echo ""
    log_info "Next steps:"
    echo "  1. Review and customize rules/50-project-identity.md"
    echo "  2. Fill in rules/51-domain.md with your domain rules"
    echo "  3. Add domain-specific scopes to rules/04-git-workflow.md"
    echo "  4. Review settings.json permissions"
    echo "  5. Add local overrides to settings.local.json"
    echo ""
}

main
