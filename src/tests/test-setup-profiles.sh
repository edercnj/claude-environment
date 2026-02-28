#!/usr/bin/env bash
set -uo pipefail

# Test script for setup.sh configuration profiles
# Validates that each config-template generates correct .claude/ structure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_PROFILES=0

# Helper functions
log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS_COUNT++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL_COUNT++))
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
}

# Validate .claude/ directory structure
validate_claude_dir() {
    local claude_dir="$1"
    local profile="$2"
    local errors=0

    # Check for mandatory directories
    local required_dirs=(
        "rules"
        "skills"
        "agents"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${claude_dir}/${dir}" ]]; then
            log_fail "Missing directory: ${dir}/ in profile ${profile}"
            ((errors++))
        else
            log_info "Found ${dir}/ directory"
        fi
    done

    # Check for mandatory files in rules directory
    if [[ -d "${claude_dir}/rules" ]]; then
        local rule_files=$(find "${claude_dir}/rules" -name "*.md" -type f | wc -l)
        if [[ $rule_files -gt 0 ]]; then
            log_pass "Found ${rule_files} rule files in ${profile}"
        else
            log_fail "No rule files found in ${profile}"
            ((errors++))
        fi
    fi

    # Check for skills directory content
    if [[ -d "${claude_dir}/skills" ]]; then
        log_pass "Skills directory exists in ${profile}"
    else
        log_fail "Skills directory missing in ${profile}"
        ((errors++))
    fi

    # Check for agents directory content
    if [[ -d "${claude_dir}/agents" ]]; then
        log_pass "Agents directory exists in ${profile}"
    else
        log_fail "Agents directory missing in ${profile}"
        ((errors++))
    fi

    # Check for mandatory files at root
    if [[ ! -f "${claude_dir}/settings.json" ]]; then
        log_fail "Missing settings.json in ${profile}"
        ((errors++))
    else
        log_pass "Found settings.json in ${profile}"
    fi

    if [[ ! -f "${claude_dir}/README.md" ]]; then
        log_fail "Missing README.md in ${profile}"
        ((errors++))
    else
        log_pass "Found README.md in ${profile}"
    fi

    # Validate settings.json is valid JSON
    if [[ -f "${claude_dir}/settings.json" ]]; then
        if command -v jq &> /dev/null; then
            if jq empty "${claude_dir}/settings.json" 2>/dev/null; then
                log_pass "settings.json is valid JSON in ${profile}"
            else
                log_fail "settings.json is invalid JSON in ${profile}"
                ((errors++))
            fi
        else
            log_info "jq not available, skipping JSON validation for ${profile}"
        fi
    fi

    return $errors
}

# Main test logic
main() {
    log_header "Setup Profile Validation Tests"
    log_info "Project root: ${PROJECT_ROOT}"
    log_info "Config templates directory: ${PROJECT_ROOT}/config-templates"

    # Find all config templates
    local config_files=$(find "${PROJECT_ROOT}/config-templates" -name "setup-config.*.yaml" -type f | sort)

    if [[ -z "$config_files" ]]; then
        log_fail "No config template files found"
        return 1
    fi

    # Process each config template
    while IFS= read -r config_file; do
        local profile=$(basename "$config_file" | sed 's/setup-config\.\(.*\)\.yaml/\1/')
        ((TOTAL_PROFILES++))

        log_header "Testing profile: ${profile}"
        log_info "Config file: ${config_file}"

        # Create temporary output directory
        local test_output="/tmp/test-output-${profile}-$$"
        rm -rf "$test_output"
        mkdir -p "$test_output"

        # Run setup.sh with this config
        log_info "Running setup.sh with config..."
        if cd "${PROJECT_ROOT}" && ./setup.sh --config "${config_file}" --output "${test_output}/.claude/" > /dev/null 2>&1; then
            log_pass "setup.sh completed successfully for ${profile}"

            # Validate the generated structure
            validate_claude_dir "${test_output}/.claude" "${profile}"
            local validation_result=$?

            if [[ $validation_result -eq 0 ]]; then
                log_pass "Profile ${profile} validation successful"
            else
                log_fail "Profile ${profile} validation failed with $validation_result errors"
            fi
        else
            log_fail "setup.sh failed for profile ${profile}"
            # Try to show error output
            if cd "${PROJECT_ROOT}" && ./setup.sh --config "${config_file}" --output "${test_output}/.claude/" 2>&1 | head -20; then
                true
            fi
        fi

        # Cleanup
        rm -rf "$test_output"

    done <<< "$config_files"

    log_header "Test Summary"
    echo -e "Total profiles tested: ${TOTAL_PROFILES}"
    echo -e "${GREEN}Passed:${NC} ${PASS_COUNT}"
    echo -e "${RED}Failed:${NC} ${FAIL_COUNT}"

    if [[ $FAIL_COUNT -eq 0 && $TOTAL_PROFILES -gt 0 ]]; then
        echo -e "${GREEN}All setup profile tests passed!${NC}"
        return 0
    else
        echo -e "${RED}${FAIL_COUNT} tests failed!${NC}"
        return 1
    fi
}

main "$@"
