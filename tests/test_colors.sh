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
    [[ -v YELLOW ]] || exit 1
    [[ -v BLUE ]] || exit 1
    [[ -v MAGENTA ]] || exit 1
    [[ -v CYAN ]] || exit 1
    [[ -v BOLD ]] || exit 1
    [[ -v DIM ]] || exit 1
    [[ -v RESET ]] || exit 1
}

# Test 2: Colors are disabled when ENABLE_COLORS=false
test_colors_disabled() {
    local output
    output=$(
        ENABLE_COLORS=false bash -c "source '$PROJECT_DIR/lib/colors.sh'; printf '%s' \"\$RED\$GREEN\$RESET\""
    )
    [[ -z "$output" ]] || exit 1
}

# Run tests
test_colors_defined
test_colors_disabled

exit 0
