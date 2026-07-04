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

# Test 2: detect_distro returns a usable lowercase id on any distro
test_detect_distro() {
    local distro
    distro=$(detect_distro)
    [[ -n "$distro" && "$distro" =~ ^[a-z0-9._-]+$ ]] || exit 1
}

# Test 2b: distro_display_name returns a non-empty human name
test_distro_display_name() {
    local name
    name=$(distro_display_name)
    [[ -n "$name" ]] || exit 1
}

# Test 3: detect_aur_helper works
test_detect_aur_helper() {
    local helper
    helper=$(detect_aur_helper)
    [[ "$helper" == "shelly" || "$helper" == "paru" || "$helper" == "yay" || "$helper" == "none" ]] || exit 1
}

# Run tests
test_defaults
test_detect_distro
test_distro_display_name
test_detect_aur_helper

exit 0
