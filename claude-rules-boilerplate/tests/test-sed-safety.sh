#!/usr/bin/env bash
set -euo pipefail

# Test script for sed safety functions
# Tests escape_sed_replacement and placeholder replacement with dangerous inputs

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
    ((TOTAL_COUNT++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL_COUNT++))
    ((TOTAL_COUNT++))
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

# Import the escape_sed_replacement function (would be from setup.sh in real usage)
# This is a copy of the function for testing purposes
escape_sed_replacement() {
    local string="$1"
    # Escape special sed characters in replacement strings: &, \, /
    string="${string//\\/\\\\}"  # backslash
    string="${string//&/\\&}"     # ampersand
    string="${string//\//\\/}"    # forward slash
    echo "$string"
}

# Test function - compare expected vs actual
test_equals() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$expected" == "$actual" ]]; then
        log_pass "$test_name"
    else
        log_fail "$test_name: expected '${expected}', got '${actual}'"
    fi
}

# Main test logic
main() {
    log_header "SED Safety Function Tests"
    log_info "Testing escape_sed_replacement with dangerous inputs..."

    # Test 1: String with pipe character
    local input1="value|with|pipes"
    local escaped1=$(escape_sed_replacement "$input1")
    test_equals "Escape pipe characters" "value|with|pipes" "$escaped1"

    # Test 2: String with ampersand (special in sed replacement)
    local input2="value&replacement"
    local escaped2=$(escape_sed_replacement "$input2")
    test_equals "Escape ampersand" "value\\&replacement" "$escaped2"

    # Test 3: String with backslash
    local input3="value\\with\\backslash"
    local escaped3=$(escape_sed_replacement "$input3")
    test_equals "Escape backslash" "value\\\\with\\\\backslash" "$escaped3"

    # Test 4: String with forward slash
    local input4="path/to/file"
    local escaped4=$(escape_sed_replacement "$input4")
    test_equals "Escape forward slash" "path\\/to\\/file" "$escaped4"

    # Test 5: String with newline (should not break sed)
    local input5="line1
line2"
    local escaped5=$(escape_sed_replacement "$input5")
    test_equals "Handle newlines" "line1
line2" "$escaped5"

    # Test 6: String with backticks
    local input6='`command`'
    local escaped6=$(escape_sed_replacement "$input6")
    test_equals "Preserve backticks" '`command`' "$escaped6"

    # Test 7: Combined dangerous characters
    local input7="a&b/c\\d|e"
    local escaped7=$(escape_sed_replacement "$input7")
    test_equals "Combined dangerous chars" "a\\&b\\/c\\\\d|e" "$escaped7"

    # Test 8: Empty string
    local input8=""
    local escaped8=$(escape_sed_replacement "$input8")
    test_equals "Empty string" "" "$escaped8"

    log_header "PROJECT_NAME Replacement Tests"
    log_info "Testing that PROJECT_NAME with special chars doesn't break sed..."

    # Test 9: PROJECT_NAME with special characters
    local project_name="my-project&name/with\\chars"
    local escaped_project=$(escape_sed_replacement "$project_name")
    local template="Service name: {PROJECT_NAME}"
    local result=$(echo "$template" | sed "s/{PROJECT_NAME}/${escaped_project}/g")
    if [[ "$result" == "Service name: my-project&name/with\\chars" ]]; then
        log_pass "PROJECT_NAME with special chars substitutes correctly"
    else
        log_fail "PROJECT_NAME replacement failed: got '$result'"
    fi

    # Test 10: PROJECT_NAME in multiple locations
    local template2="Project: {PROJECT_NAME}, Path: /path/{PROJECT_NAME}"
    local result2=$(echo "$template2" | sed "s/{PROJECT_NAME}/${escaped_project}/g")
    local expected2="Project: my-project&name/with\\chars, Path: /path/my-project&name/with\\chars"
    test_equals "Multiple PROJECT_NAME replacements" "$expected2" "$result2"

    # Test 11: Actual sed replacement doesn't error
    if echo "placeholder {PROJECT_NAME}" | sed "s/{PROJECT_NAME}/${escaped_project}/g" > /dev/null 2>&1; then
        log_pass "SED command executes without error"
    else
        log_fail "SED command failed with escaped PROJECT_NAME"
    fi

    log_header "Test Summary"
    echo -e "Total tests: ${TOTAL_COUNT}"
    echo -e "${GREEN}Passed:${NC} ${PASS_COUNT}"
    echo -e "${RED}Failed:${NC} ${FAIL_COUNT}"

    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${GREEN}All SED safety tests passed!${NC}"
        return 0
    else
        echo -e "${RED}${FAIL_COUNT} tests failed!${NC}"
        return 1
    fi
}

main "$@"
