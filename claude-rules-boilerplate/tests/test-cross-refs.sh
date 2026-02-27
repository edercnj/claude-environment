#!/usr/bin/env bash
set -euo pipefail

# Test script for cross-reference validation
# Finds all .md files and validates internal references

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
TOTAL_COUNT=0

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

# Extract references from markdown
# Backtick paths like `rules/02-domain.md`, `skills/...`, etc.
extract_references() {
    local file="$1"
    grep -oE '`[a-zA-Z0-9_/.-]+`' "$file" | sed 's/`//g' || true
}

# Check if a reference exists as a file or directory
is_valid_reference() {
    local ref="$1"
    local ref_type="unknown"

    # Check if it's a file
    if [[ -f "${PROJECT_ROOT}/${ref}" ]]; then
        ref_type="file"
        return 0
    fi

    # Check if it's a directory
    if [[ -d "${PROJECT_ROOT}/${ref}" ]]; then
        ref_type="directory"
        return 0
    fi

    # Check if it exists relative to PROJECT_ROOT
    if [[ -e "${PROJECT_ROOT}/${ref}" ]]; then
        ref_type="exists"
        return 0
    fi

    return 1
}

# Main test logic
main() {
    log_header "Cross-Reference Validation Test"
    log_info "Project root: ${PROJECT_ROOT}"
    log_info "Scanning for .md files..."

    local broken_refs=0

    # Find all markdown files
    while IFS= read -r md_file; do
        log_info "Checking: ${md_file#${PROJECT_ROOT}/}"
        ((TOTAL_COUNT++))

        # Extract all backtick references
        while IFS= read -r ref; do
            [[ -z "$ref" ]] && continue

            if is_valid_reference "$ref"; then
                log_pass "Reference found: ${ref}"
            else
                log_fail "Broken reference in ${md_file#${PROJECT_ROOT}/}: ${ref}"
                ((broken_refs++))
            fi
        done < <(extract_references "$md_file")
    done < <(find "${PROJECT_ROOT}" -name "*.md" -type f | grep -v node_modules | grep -v ".git" | sort)

    log_header "Test Summary"
    echo -e "Total files checked: ${TOTAL_COUNT}"
    echo -e "${GREEN}Passed:${NC} ${PASS_COUNT}"
    echo -e "${RED}Failed:${NC} ${FAIL_COUNT}"

    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${GREEN}All cross-references valid!${NC}"
        return 0
    else
        echo -e "${RED}Found ${FAIL_COUNT} broken references!${NC}"
        return 1
    fi
}

main "$@"
