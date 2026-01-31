#!/usr/bin/env bash
# Test colors module

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source colors module
ENABLE_COLORS=true
source "$PROJECT_DIR/lib/colors.sh"

# Test 1: Color variables are declared (may be empty in non-TTY)
test_colors_defined() {
    # Variables should exist (even if empty when not in TTY)
    [[ -v RED ]] || exit 1
    [[ -v GREEN ]] || exit 1
    [[ -v RESET ]] || exit 1
}

# Test 2: Print functions exist
test_print_functions() {
    type print_success &>/dev/null || exit 1
    type print_error &>/dev/null || exit 1
    type print_warning &>/dev/null || exit 1
    type print_info &>/dev/null || exit 1
}

# Test 3: Print functions work
test_print_output() {
    local output
    output=$(print_success "test" 2>&1)
    [[ -n "$output" ]] || exit 1
}

# Run tests
test_colors_defined
test_print_functions
test_print_output

exit 0
