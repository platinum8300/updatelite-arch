#!/usr/bin/env bash
# Test configuration loading

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source config module
source "$PROJECT_DIR/lib/config.sh"

# Test 1: Default values are set
test_defaults() {
    [[ "$ENABLE_PACMAN" == "true" ]] || exit 1
    [[ "$ENABLE_AUR" == "true" ]] || exit 1
    [[ "$ENABLE_DOCKER" == "false" ]] || exit 1
    [[ "$AUR_HELPER" == "auto" ]] || exit 1
}

# Test 2: detect_distro works
test_detect_distro() {
    local distro
    distro=$(detect_distro)
    [[ "$distro" == "arch" || "$distro" == "cachyos" || "$distro" == "unknown" ]] || exit 1
}

# Test 3: detect_aur_helper works
test_detect_aur_helper() {
    local helper
    helper=$(detect_aur_helper)
    [[ "$helper" == "paru" || "$helper" == "yay" || "$helper" == "none" ]] || exit 1
}

# Run tests
test_defaults
test_detect_distro
test_detect_aur_helper

exit 0
