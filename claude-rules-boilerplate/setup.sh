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
LANGUAGES_DIR="${SCRIPT_DIR}/languages"
FRAMEWORKS_DIR="${SCRIPT_DIR}/frameworks"
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
DRY_RUN=false
VALIDATE_ONLY=false

# Project identity (set by run_interactive or run_config)
LANGUAGE_NAME=""       # "java", "typescript", "python", etc.
LANGUAGE_VERSION=""    # "21", "5", "3.12", etc.
FRAMEWORK_NAME=""      # "quarkus", "spring-boot", "nestjs", etc.
FRAMEWORK_VERSION=""   # "3.17", "3.4", "10", etc.

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
            echo "Claude Code Boilerplate — Complete .claude/ Directory Generator"
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
        -e "s|{{CONTAINER}}|${CONTAINER}|g" \
        -e "s|{{ORCHESTRATOR}}|${ORCHESTRATOR}|g" \
        -e "s|{{OBSERVABILITY}}|${OBSERVABILITY}|g" \
        -e "s|{{COMPILE_COMMAND}}|${COMPILE_COMMAND}|g" \
        -e "s|{{BUILD_COMMAND}}|${BUILD_COMMAND}|g" \
        -e "s|{{TEST_COMMAND}}|${TEST_COMMAND}|g" \
        -e "s|{{COVERAGE_COMMAND}}|${COVERAGE_COMMAND}|g" \
        -e "s|{{FILE_EXTENSION}}|${FILE_EXTENSION}|g" \
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
    case "${LANGUAGE_NAME}" in
        java)
            FILE_EXTENSION=".java"
            DEVELOPER_AGENT_KEY="java"
            # Build tool depends on framework config or default to maven
            case "${BUILD_TOOL:-maven}" in
                maven|Maven)
                    COMPILE_COMMAND="mvn compile -q"
                    BUILD_COMMAND="mvn package -DskipTests"
                    TEST_COMMAND="mvn verify"
                    COVERAGE_COMMAND="mvn verify jacoco:report"
                    BUILD_TOOL="Maven"
                    HOOK_TEMPLATE_KEY="java-maven"
                    SETTINGS_LANG_KEY="java-maven"
                    ;;
                gradle|Gradle)
                    COMPILE_COMMAND="gradle compileJava -q"
                    BUILD_COMMAND="gradle build -x test"
                    TEST_COMMAND="gradle test"
                    COVERAGE_COMMAND="gradle test jacocoTestReport"
                    BUILD_TOOL="Gradle"
                    HOOK_TEMPLATE_KEY="java-maven"
                    SETTINGS_LANG_KEY="java-gradle"
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

    # Validate protocol values
    local valid_protocols=("rest" "grpc" "graphql" "websocket" "tcp-custom")
    for proto in "${PROTOCOLS[@]}"; do
        if ! array_contains "$proto" "${valid_protocols[@]}"; then
            log_error "Invalid protocol: '${proto}'. Valid values: ${valid_protocols[*]}"
            exit 1
        fi
    done

    # Validate language directory exists
    if [[ ! -d "${LANGUAGES_DIR}/${lang}" ]]; then
        log_warn "Language directory not found: languages/${lang}"
    fi

    # Validate framework directory exists
    if [[ ! -d "${FRAMEWORKS_DIR}/${fw}" ]]; then
        log_warn "Framework directory not found: frameworks/${fw}"
    fi

    log_success "Stack validation passed: ${lang} ${lang_ver} + ${fw}"
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
    echo -e "${GREEN}║  4-Layer Architecture (v2)                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""

    PROJECT_NAME=$(prompt_input "Project name" "my-project")
    PROJECT_TYPE=$(prompt_select "Project type:" "api" "cli" "library" "worker" "fullstack")
    PROJECT_PURPOSE=$(prompt_input "Brief project purpose")

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

    DB_TYPE=$(prompt_select "Database:" "postgresql" "mysql" "mongodb" "sqlite" "none")

    if [[ "$DB_TYPE" != "none" ]]; then
        case "$LANGUAGE_NAME" in
            java|kotlin) DB_MIGRATION=$(prompt_select "Migration tool:" "flyway" "liquibase" "none") ;;
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

    # Observability backend (always enabled, choose backend)
    OBSERVABILITY=$(prompt_select "Observability backend:" "opentelemetry" "datadog" "prometheus-only")

    NATIVE_BUILD=false
    if [[ "$LANGUAGE_NAME" == "java" || "$LANGUAGE_NAME" == "kotlin" ]]; then
        prompt_yesno "Enable native build (GraalVM/Mandrel)?" "y" && NATIVE_BUILD=true
    fi

    # Resilience is always mandatory — no prompt

    SMOKE_TESTS=false
    prompt_yesno "Enable smoke tests?" "y" && SMOKE_TESTS=true

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

    # Project identity
    PROJECT_NAME=$(parse_yaml_value "$CONFIG_FILE" "name" "project")
    PROJECT_TYPE=$(parse_yaml_value "$CONFIG_FILE" "type" "project")
    PROJECT_PURPOSE=$(parse_yaml_value "$CONFIG_FILE" "purpose" "project")
    ARCHITECTURE=$(parse_yaml_value "$CONFIG_FILE" "architecture" "project")

    # Language (new 4-layer format: language.name + language.version)
    LANGUAGE_NAME=$(parse_yaml_value "$CONFIG_FILE" "name" "language")
    LANGUAGE_VERSION=$(parse_yaml_value "$CONFIG_FILE" "version" "language")

    # Framework (new 4-layer format: framework.name + framework.version)
    FRAMEWORK_NAME=$(parse_yaml_value "$CONFIG_FILE" "name" "framework")
    FRAMEWORK_VERSION=$(parse_yaml_value "$CONFIG_FILE" "version" "framework")

    # Build tool (from framework section or auto-detect)
    BUILD_TOOL=$(parse_yaml_value "$CONFIG_FILE" "build_tool" "framework")
    [[ -z "$BUILD_TOOL" ]] && BUILD_TOOL="maven"

    # Native build (from framework section)
    NATIVE_BUILD=$(parse_yaml_value "$CONFIG_FILE" "native_build" "framework")
    [[ -z "$NATIVE_BUILD" ]] && NATIVE_BUILD="false"
    # native_build only applies to JVM languages (GraalVM/Mandrel)
    if [[ ! "$LANGUAGE_NAME" =~ ^(java|kotlin)$ ]]; then
        NATIVE_BUILD="false"
    fi

    # Stack: database
    DB_TYPE=$(parse_yaml_nested "$CONFIG_FILE" "stack" "database" "type")
    [[ -z "$DB_TYPE" ]] && DB_TYPE="none"
    DB_MIGRATION=$(parse_yaml_nested "$CONFIG_FILE" "stack" "database" "migration")
    [[ -z "$DB_MIGRATION" ]] && DB_MIGRATION="none"

    # Stack: infrastructure
    CONTAINER=$(parse_yaml_nested "$CONFIG_FILE" "stack" "infrastructure" "container")
    [[ -z "$CONTAINER" ]] && CONTAINER="none"
    ORCHESTRATOR=$(parse_yaml_nested "$CONFIG_FILE" "stack" "infrastructure" "orchestrator")
    [[ -z "$ORCHESTRATOR" ]] && ORCHESTRATOR="none"

    # Observability (always enabled — backend selection only)
    OBSERVABILITY=$(parse_yaml_nested "$CONFIG_FILE" "stack" "infrastructure" "observability")
    [[ -z "$OBSERVABILITY" ]] && OBSERVABILITY="opentelemetry"

    # Resilience is always mandatory — no config option
    # Smoke tests
    SMOKE_TESTS=$(parse_yaml_value "$CONFIG_FILE" "smoke_tests" "stack")
    [[ -z "$SMOKE_TESTS" ]] && SMOKE_TESTS="true"

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

    # ── Layer 1: Core (01-11) ──
    log_info "Layer 1: Copying core rules..."
    for core_file in "$CORE_DIR"/*.md; do
        if [[ -f "$core_file" ]]; then
            local basename
            basename=$(basename "$core_file")
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
    cp "${TEMPLATES_DIR}/domain-template.md" "${rules_dir}/51-domain.md"
    log_success "  51-domain.md (template — customize for your domain)"
}

generate_project_identity() {
    local rules_dir="$1"
    cat > "${rules_dir}/50-project-identity.md" <<HEREDOC
# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Project Identity — ${PROJECT_NAME}

## Identity
- **Name:** ${PROJECT_NAME}
- **Type:** ${PROJECT_TYPE}
- **Purpose:** ${PROJECT_PURPOSE}
- **Language:** ${LANGUAGE_NAME} ${LANGUAGE_VERSION}
- **Framework:** ${FRAMEWORK_NAME}${FRAMEWORK_VERSION:+ ${FRAMEWORK_VERSION}}
- **Database:** ${DB_TYPE}
- **Architecture:** ${ARCHITECTURE}

## Technology Stack
| Layer | Technology |
|-------|-----------|
| Language | ${LANGUAGE_NAME} ${LANGUAGE_VERSION} |
| Framework | ${FRAMEWORK_NAME}${FRAMEWORK_VERSION:+ ${FRAMEWORK_VERSION}} |
| Build Tool | ${BUILD_TOOL:-N/A} |
| Database | ${DB_TYPE} |
| Migration | ${DB_MIGRATION} |
| Container | ${CONTAINER} |
| Orchestrator | ${ORCHESTRATOR} |
| Observability | ${OBSERVABILITY} |
| Resilience | Mandatory (always enabled) |
| Native Build | ${NATIVE_BUILD} |
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

        # run-smoke-api: requires smoke_tests = true + rest
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

    # Validate stack compatibility
    validate_stack_compatibility

    # Infer native_build if set to "auto" or empty
    infer_native_build

    # --validate: stop after validation
    if [[ "$VALIDATE_ONLY" == true ]]; then
        echo ""
        log_success "Configuration validated successfully."
        echo "  Language:       ${LANGUAGE_NAME} ${LANGUAGE_VERSION}"
        echo "  Framework:      ${FRAMEWORK_NAME}${FRAMEWORK_VERSION:+ ${FRAMEWORK_VERSION}}"
        echo "  Native Build:   ${NATIVE_BUILD}"
        echo "  Protocols:      ${PROTOCOLS[*]}"
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
    echo "  Project:        ${PROJECT_NAME} (${PROJECT_TYPE})"
    echo "  Language:       ${LANGUAGE_NAME} ${LANGUAGE_VERSION}"
    echo "  Framework:      ${FRAMEWORK_NAME}${FRAMEWORK_VERSION:+ ${FRAMEWORK_VERSION}}"
    echo "  Database:       ${DB_TYPE} (migration: ${DB_MIGRATION})"
    echo "  Architecture:   ${ARCHITECTURE}"
    echo "  Protocols:      ${PROTOCOLS[*]}"
    echo "  Infrastructure: ${CONTAINER} + ${ORCHESTRATOR}"
    echo "  Observability:  ${OBSERVABILITY} (always enabled)"
    echo "  Native Build:   ${NATIVE_BUILD}"
    echo "  Resilience:     mandatory"
    echo "  Smoke Tests:    ${SMOKE_TESTS}"
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

    # Phase 7: Cross-reference verification
    log_info "━━━ Phase 7: Verification ━━━"
    verify_cross_references "$OUTPUT_DIR"
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
    echo "  1. Review and customize rules/50-project-identity.md"
    echo "  2. Fill in rules/51-domain.md with your domain rules"
    echo "  3. Add domain-specific scopes to rules/04-git-workflow.md"
    echo "  4. Review settings.json permissions"
    echo "  5. Add local overrides to settings.local.json"
    echo ""
}

main
