#!/usr/bin/env bash
# Test AUR module

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source required modules
source "$PROJECT_DIR/lib/colors.sh"
source "$PROJECT_DIR/lib/config.sh"
source "$PROJECT_DIR/lib/utils.sh"
source "$PROJECT_DIR/lib/aur.sh"

# Test 1: Function exists
test_function_exists() {
    type update_aur &>/dev/null || exit 1
    type list_aur_packages &>/dev/null || exit 1
}

# Test 2: Module can be disabled
test_module_disable() {
    ENABLE_AUR=false
    update_aur || exit 1
}

# Test 3: Helper detection
test_helper_detection() {
    local helper
    helper=$(detect_aur_helper)
    # Should return paru, yay, or none
    [[ "$helper" =~ ^(paru|yay|none)$ ]] || exit 1
}

# Run tests
test_function_exists
test_module_disable
test_helper_detection

exit 0
