#!/usr/bin/env bash
#
# Test runner for updateLITE Arch Edition
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

print_header() {
    echo -e "\n${BOLD}═══════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}     updateLITE Arch Edition Test Suite${RESET}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}\n"
}

run_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .sh)

    echo -n "Testing $test_name... "

    if bash "$test_file" &>/dev/null; then
        echo -e "${GREEN}PASS${RESET}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${RESET}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_shellcheck() {
    echo -n "Running shellcheck... "

    local files=("$PROJECT_DIR/updatelite" "$PROJECT_DIR/lib/"*.sh)
    local failed=0

    for file in "${files[@]}"; do
        if ! shellcheck -e SC1091 "$file" &>/dev/null; then
            failed=$((failed + 1))
        fi
    done

    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}PASS${RESET}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}WARN${RESET} ($failed files with warnings)"
    fi
}

print_summary() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
    echo -e "Results: ${GREEN}$TESTS_PASSED passed${RESET}, ${RED}$TESTS_FAILED failed${RESET}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
}

main() {
    print_header

    # Source tests
    for test_file in "$SCRIPT_DIR"/test_*.sh; do
        if [[ -f "$test_file" ]]; then
            run_test "$test_file"
        fi
    done

    # Shellcheck
    if command -v shellcheck &>/dev/null; then
        run_shellcheck
    else
        echo -e "${YELLOW}shellcheck not installed, skipping${RESET}"
    fi

    print_summary

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
