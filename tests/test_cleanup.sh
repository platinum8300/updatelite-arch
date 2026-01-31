#!/usr/bin/env bash
# Test cleanup module

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source required modules
source "$PROJECT_DIR/lib/colors.sh"
source "$PROJECT_DIR/lib/config.sh"
source "$PROJECT_DIR/lib/utils.sh"
source "$PROJECT_DIR/lib/cleanup.sh"

# Test 1: Functions exist
test_functions_exist() {
    type system_cleanup &>/dev/null || exit 1
    type cleanup_orphans &>/dev/null || exit 1
    type cleanup_cache &>/dev/null || exit 1
    type cleanup_journal &>/dev/null || exit 1
}

# Test 2: Modules can be disabled
test_modules_disable() {
    CLEANUP_ORPHANS=false
    CLEANUP_CACHE=false
    CLEANUP_JOURNAL=false

    # These should return without error when disabled
    cleanup_orphans || exit 1
    cleanup_cache || exit 1
    cleanup_journal || exit 1
}

# Run tests
test_functions_exist
test_modules_disable

exit 0
