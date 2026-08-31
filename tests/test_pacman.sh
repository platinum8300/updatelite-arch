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

# Test 4: failure hints follow the actual pacman error
test_failure_hint() {
    local tmp
    tmp=$(mktemp)
    PACMAN_OUTPUT_LOG="$tmp"

    # Package conflict, in the localized wording pacman actually prints
    printf '%s\n' \
        ':: a-1.0-1 y b-2.0-1 están en conflicto. ¿Quitar b? [s/N]' \
        'error: se han detectado paquetes con conflictos sin resolver' > "$tmp"
    pacman_failure_hint | grep -q "Package conflict: 'b'" || { rm -f "$tmp"; exit 1; }

    # Mirror failure gets its own hint, not the conflict one
    printf '%s\n' "error: failed retrieving file 'core.db' from mirror" > "$tmp"
    pacman_failure_hint | grep -qi "mirror or network" || { rm -f "$tmp"; exit 1; }

    # Unrecognised failure must not invent a hint
    printf '%s\n' 'error: something else entirely' > "$tmp"
    pacman_failure_hint && { rm -f "$tmp"; exit 1; }

    rm -f "$tmp"
}

# Test 5: only verified package renames are auto-resolved
test_supersede_plan() {
    local tmp
    tmp=$(mktemp)
    PACMAN_OUTPUT_LOG="$tmp"

    # Both sides unknown to the repos: no Replaces/Provides to verify
    printf '%s\n' ':: nope-1.0-1 and alsonope-2.0-1 are in conflict. Remove alsonope?' > "$tmp"
    pacman_supersede_plan && { rm -f "$tmp"; exit 1; }

    # A critical package is never removed, whatever the metadata says
    CRITICAL_PACKAGES="sacred"
    printf '%s\n' ':: newpkg-1.0-1 and sacred-2.0-1 are in conflict. Remove sacred?' > "$tmp"
    pacman_supersede_plan && { rm -f "$tmp"; exit 1; }

    # Output without a conflict question yields no plan
    printf '%s\n' 'error: failed to commit transaction (conflicting files)' > "$tmp"
    pacman_supersede_plan && { rm -f "$tmp"; exit 1; }

    rm -f "$tmp"
}

# Test 6: pacman -Si fields are parsed into individual names
test_si_field_parsing() {
    printf '%s\n' 'foo>=1.2  bar' | pacman_field_lists foo || exit 1
    printf '%s\n' 'foo  bar' | pacman_field_lists baz && exit 1
    printf '%s\n' 'None' | pacman_field_lists foo && exit 1
    return 0
}

# Run tests
test_function_exists
test_pacman_lock
test_module_disable
test_failure_hint
test_supersede_plan
test_si_field_parsing

exit 0
