#!/usr/bin/env bash
# Test pacman module

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source required modules
source "$PROJECT_DIR/lib/colors.sh"
source "$PROJECT_DIR/lib/config.sh"
source "$PROJECT_DIR/lib/utils.sh"
source "$PROJECT_DIR/lib/pacman.sh"

# Test 1: Function exists
test_function_exists() {
    type update_pacman &>/dev/null || exit 1
    type check_pacman_lock &>/dev/null || exit 1
}

# Test 2: check_pacman_lock works
test_pacman_lock() {
    # Should return 0 if no lock (normal state)
    if [[ ! -f /var/lib/pacman/db.lck ]]; then
        check_pacman_lock || exit 1
    fi
}

# Test 3: Module can be disabled
test_module_disable() {
    ENABLE_PACMAN=false
    # Should return early without error
    update_pacman || exit 1
}

# Run tests
test_function_exists
test_pacman_lock
test_module_disable

exit 0
