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
    type update_aur_pacman &>/dev/null || exit 1
    type update_aur_shelly &>/dev/null || exit 1
    type shelly_detect_dialect &>/dev/null || exit 1
    type shelly_subcommand &>/dev/null || exit 1
    type shelly_list_pending &>/dev/null || exit 1
    type aur_helper_kind &>/dev/null || exit 1
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
    # Should return paru, yay, shelly, or none
    [[ "$helper" =~ ^(paru|yay|shelly|none)$ ]] || exit 1
}

# Test 4: Helper dialect classification
test_helper_kind() {
    [[ "$(aur_helper_kind shelly)" == "shelly" ]] || exit 1
    [[ "$(aur_helper_kind paru)" == "pacman" ]] || exit 1
    [[ "$(aur_helper_kind yay)" == "pacman" ]] || exit 1
}

# Test 5: Shelly CLI dialect detection and subcommand mapping
#
# Shelly 3.0 moved from "shelly aur <verb>" to "shelly <verb> aur"; both are
# driven from stubs here so neither dialect can regress unnoticed.
test_shelly_dialect() {
    local stub_dir stub
    stub_dir=$(mktemp -d)
    trap 'rm -rf "$stub_dir"' RETURN

    # Shelly 2.x: "aur" command group, "aur update" for single packages
    stub="$stub_dir/shelly2"
    printf '#!/usr/bin/env bash\necho 2.4.1\n' > "$stub"
    chmod +x "$stub"
    SHELLY_DIALECT=""
    shelly_detect_dialect "$stub"
    [[ "$SHELLY_DIALECT" == "aur-first" ]] || exit 1
    [[ "$(shelly_subcommand "$stub" list-updates)" == "aur list-updates" ]] || exit 1
    [[ "$(shelly_subcommand "$stub" upgrade)" == "aur upgrade" ]] || exit 1
    [[ "$(shelly_subcommand "$stub" rebuild)" == "aur update" ]] || exit 1

    # Shelly 3.x: verb-first, and "install aur" replaces the dropped "aur update"
    stub="$stub_dir/shelly3"
    printf '#!/usr/bin/env bash\necho 3.1.1\n' > "$stub"
    chmod +x "$stub"
    SHELLY_DIALECT=""
    shelly_detect_dialect "$stub"
    [[ "$SHELLY_DIALECT" == "verb-first" ]] || exit 1
    [[ "$(shelly_subcommand "$stub" list-updates)" == "list-updates aur" ]] || exit 1
    [[ "$(shelly_subcommand "$stub" upgrade)" == "upgrade aur" ]] || exit 1
    [[ "$(shelly_subcommand "$stub" rebuild)" == "install aur" ]] || exit 1

    SHELLY_DIALECT=""
}

# Test 6: pending parsing reports both versions, and failures are not silent
test_shelly_list_pending() {
    local stub_dir stub out rc
    stub_dir=$(mktemp -d)
    trap 'rm -rf "$stub_dir"' RETURN

    stub="$stub_dir/shelly"
    cat > "$stub" <<'STUB'
#!/usr/bin/env bash
[[ "$1" == "--version" ]] && { echo "3.1.1"; exit 0; }
[[ "$1 $2" == "list-updates aur" ]] && {
    echo '[{"Name":"foo","Version":"1.0-1","NewVersion":"2.0-1"}]'
    exit 0
}
exit 1
STUB
    chmod +x "$stub"
    SHELLY_DIALECT=""
    [[ "$(shelly_list_pending "$stub")" == "foo 1.0-1 -> 2.0-1" ]] || exit 1

    # A helper that fails must propagate, not read as "nothing pending"
    printf '#!/usr/bin/env bash\nexit 7\n' > "$stub"
    SHELLY_DIALECT=""
    rc=0
    out=$(shelly_list_pending "$stub") || rc=$?
    [[ $rc -ne 0 ]] || exit 1
    [[ -z "$out" ]] || exit 1

    SHELLY_DIALECT=""
}

# Run tests
test_function_exists
test_module_disable
test_helper_detection
test_helper_kind
test_shelly_dialect
test_shelly_list_pending

exit 0
