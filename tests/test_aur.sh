#!/usr/bin/env bash
# Test AUR module

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source required modules
source "$PROJECT_DIR/lib/colors.sh"
source "$PROJECT_DIR/lib/config.sh"
source "$PROJECT_DIR/lib/utils.sh"
source "$PROJECT_DIR/lib/aurbuild.sh"
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

    # Shelly 3.x: verb-first; the rebuild verb keeps its name but moves position
    stub="$stub_dir/shelly3"
    printf '#!/usr/bin/env bash\necho 3.1.1\n' > "$stub"
    chmod +x "$stub"
    SHELLY_DIALECT=""
    shelly_detect_dialect "$stub"
    [[ "$SHELLY_DIALECT" == "verb-first" ]] || exit 1
    [[ "$(shelly_subcommand "$stub" list-updates)" == "list-updates aur" ]] || exit 1
    [[ "$(shelly_subcommand "$stub" upgrade)" == "upgrade aur" ]] || exit 1
    [[ "$(shelly_subcommand "$stub" rebuild)" == "update aur" ]] || exit 1

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

# Test 7: single-package rebuilds confirm Shelly's PKGBUILD review
#
# Shelly asks "Proceed with update to <pkg>? (y/N)" for a changed PKGBUILD and
# --no-confirm does not cover it, so an unattended run blocks on the prompt and
# a closed stdin declines it. The rebuild must answer it and pass extra flags
# before the package name.
test_shelly_rebuild_one() {
    local stub_dir stub rc
    stub_dir=$(mktemp -d)
    trap 'rm -rf "$stub_dir"' RETURN

    stub="$stub_dir/shelly"
    cat > "$stub" <<'STUB'
#!/usr/bin/env bash
[[ "$1" == "--version" ]] && { echo "3.1.1"; exit 0; }
echo "$*" > "$(dirname "$0")/argv"
printf 'Proceed with update to %s? (y/N) ' "${@: -1}"
# -t so a regression that stops answering fails the test instead of hanging it,
# which is how this looked in practice: an unattended run frozen on the prompt.
read -r -t 5 answer || answer=""
[[ "$answer" == "y" ]] || exit 1
exit 0
STUB
    chmod +x "$stub"

    SHELLY_DIALECT=""
    rc=0
    shelly_rebuild_one "$stub" foo --no-check >/dev/null || rc=$?
    [[ $rc -eq 0 ]] || exit 1
    [[ "$(cat "$stub_dir/argv")" == "update aur --no-confirm --no-check foo" ]] || exit 1

    SHELLY_DIALECT=""
}

# Test 8: after a failed bulk upgrade, only still-pending packages are retried
#
# Shelly keeps going after a build failure and aborts at the commit, so the
# original pending list still names packages it already installed. Rebuilding
# those costs minutes each and misreports them as fresh work.
#
# The escalation's makepkg path is stubbed out: it clones from the AUR and
# installs what it builds, which a test must never do. Package names are
# prefixed so a leak could not name a real package either.
test_shelly_retry_scope() {
    local stub_dir stub
    stub_dir=$(mktemp -d)
    trap 'rm -rf "$stub_dir"' RETURN

    stub="$stub_dir/shelly"
    cat > "$stub" <<'STUB'
#!/usr/bin/env bash
state="$(dirname "$0")"
[[ "$1" == "--version" ]] && { echo "3.1.1"; exit 0; }
if [[ "$1 $2" == "list-updates aur" ]]; then
    if [[ -f "$state/bulk_done" ]]; then
        echo '[{"Name":"ul-test-c","Version":"1-1","NewVersion":"2-1"}]'
    else
        echo '[{"Name":"ul-test-a","Version":"1-1","NewVersion":"2-1"},{"Name":"ul-test-b","Version":"1-1","NewVersion":"2-1"},{"Name":"ul-test-c","Version":"1-1","NewVersion":"2-1"}]'
    fi
    exit 0
fi
if [[ "$1 $2" == "upgrade aur" ]]; then
    touch "$state/bulk_done"
    exit 1
fi
if [[ "$1 $2" == "update aur" ]]; then
    echo "${@: -1}" >> "$state/rebuilt"
    exit 0
fi
exit 99
STUB
    chmod +x "$stub"

    # Nothing here may touch the network, the real package database, or the
    # caches a real run keeps.
    aur_makepkg_build() { echo "makepkg must not run in tests" >&2; return 1; }
    export XDG_CACHE_HOME="$stub_dir/cache"
    export LOG_DIR="$stub_dir/logs"

    AUR_PACKAGES=()
    UPDATES_AUR=0
    UPDATES_AUR_FAILED=0
    AUR_SKIP_PACKAGES=""
    SHELLY_DIALECT=""

    update_aur_shelly "$stub" >/dev/null 2>&1 || true

    # Only the package the bulk pass never reached may be rebuilt
    [[ "$(cat "$stub_dir/rebuilt" 2>/dev/null)" == "ul-test-c" ]] || exit 1

    SHELLY_DIALECT=""
}

# Test 9: a package that already failed at this version is not attempted again
#
# The point of the record is to stop paying for a build that cannot succeed on
# every single run; it must also expire on its own when a new version appears.
test_aur_failure_memory() {
    local stub_dir reason
    stub_dir=$(mktemp -d)
    trap 'rm -rf "$stub_dir"' RETURN

    export XDG_CACHE_HOME="$stub_dir/cache"

    aur_failure_reason ul-test-pkg 2.0-1 >/dev/null && exit 1

    aur_record_failure ul-test-pkg 2.0-1 "compiler error"
    reason=$(aur_failure_reason ul-test-pkg 2.0-1) || exit 1
    [[ "$reason" == *"compiler error"* ]] || exit 1

    # A newer version is a different situation and must be tried again
    aur_failure_reason ul-test-pkg 2.1-1 >/dev/null && exit 1

    aur_clear_failure ul-test-pkg
    aur_failure_reason ul-test-pkg 2.0-1 >/dev/null && exit 1

    return 0
}

# Test 10: helper classification uses the basename
#
# AUR_HELPER may hold a path, and classifying "/usr/bin/shelly" as pacman-style
# sends every call through flags Shelly rejects.
test_helper_kind_path() {
    [[ "$(aur_helper_kind /usr/bin/shelly)" == "shelly" ]] || exit 1
    [[ "$(aur_helper_kind /usr/bin/paru)" == "pacman" ]] || exit 1
}

# Run tests
test_function_exists
test_module_disable
test_helper_detection
test_helper_kind
test_shelly_dialect
test_shelly_list_pending
test_shelly_rebuild_one
test_shelly_retry_scope
test_aur_failure_memory
test_helper_kind_path

exit 0
