#!/usr/bin/env bash
# aurbuild.sh - resilient AUR build paths, and memory of what cannot be built
#
# Copyright (C) 2026 platinum8300
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# An AUR helper is a convenience wrapper, not the definition of how an AUR
# package is built: makepkg is. When a helper's own source handling gets in the
# way, an updater that only knows how to call the helper reports a failure and
# leaves the package behind on every run from then on. This module gives
# updateLITE a way around that, and a memory so a build that cannot succeed
# today is not attempted again until something relevant has changed.

# Status marks matching the rest of updateLITE's output, built from their UTF-8
# bytes so this file stays free of literal glyphs.
AUR_MARK_OK=$(printf '\xe2\x9c\x93')
AUR_MARK_FAIL=$(printf '\xe2\x9c\x97')

# Answers for any prompt a build path may raise. Unattended means unattended;
# the helper backends make the same choice.
aur_auto_answers() {
    yes
}

aur_state_dir() {
    local dir="${XDG_CACHE_HOME:-$HOME/.cache}/updatelite"
    mkdir -p "$dir"
    printf '%s\n' "$dir"
}

aur_build_root() {
    local dir
    dir="$(aur_state_dir)/aur-build"
    mkdir -p "$dir"
    printf '%s\n' "$dir"
}

aur_log_root() {
    local dir="${LOG_DIR:-$HOME/logs/updatelite}/build"
    mkdir -p "$dir"
    printf '%s\n' "$dir"
}

# ---------------------------------------------------------------------------
# Memory of deterministic failures
#
# A package that cannot be built stays unbuildable until something changes, and
# retrying it costs a full compile on every run: python310 is a complete CPython
# build. Records are keyed on what would make a retry worthwhile, so a new
# package version or a new toolchain clears the record by itself and the package
# is tried again with no user action.
# ---------------------------------------------------------------------------

aur_failure_file() {
    printf '%s\n' "$(aur_state_dir)/aur-failures"
}

# The toolchain a recorded failure was observed against.
aur_toolchain_id() {
    local gcc_version=""
    gcc_version=$(gcc --version 2>/dev/null | head -1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -1 || true)
    printf 'gcc-%s\n' "${gcc_version:-unknown}"
}

# Print the recorded reason when this exact package version already failed on
# this toolchain; return non-zero when it is worth trying again.
aur_failure_reason() {
    local pkg="$1" version="$2" file toolchain
    file="$(aur_failure_file)"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    toolchain="$(aur_toolchain_id)"
    awk -F'\t' -v p="$pkg" -v v="$version" -v t="$toolchain" \
        '$1 == p && $2 == v && $3 == t { print $4 " on " $5; found = 1 }
         END { exit !found }' "$file"
}

aur_record_failure() {
    local pkg="$1" version="$2" reason="$3" file tmp
    file="$(aur_failure_file)"
    tmp="${file}.tmp"

    touch "$file"
    awk -F'\t' -v p="$pkg" '$1 != p' "$file" > "$tmp" || true
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$pkg" "$version" "$(aur_toolchain_id)" "$reason" "$(date +%Y-%m-%d)" >> "$tmp"
    mv -f "$tmp" "$file"
}

aur_clear_failure() {
    local pkg="$1" file tmp
    file="$(aur_failure_file)"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    tmp="${file}.tmp"
    awk -F'\t' -v p="$pkg" '$1 != p' "$file" > "$tmp" || true
    mv -f "$tmp" "$file"
}

# ---------------------------------------------------------------------------
# Running a build step
# ---------------------------------------------------------------------------

# Run one build attempt with its output appended to a log file, printing a
# single status line. The full output stays on disk: printing all of it buries
# the run in configure chatter, and discarding it makes a long build look like a
# freeze. On failure the tail of the log is shown, which is where the real error
# is.
aur_run_step() {
    local label="$1" log="$2"
    shift 2
    local rc=0

    printf '%b' "${DIM}       ${label}...${RESET} "
    {
        echo ""
        echo "### ${label} :: $(date '+%Y-%m-%d %H:%M:%S')"
    } >> "$log"

    "$@" >> "$log" 2>&1 < <(aur_auto_answers) || rc=$?

    if [[ $rc -eq 0 ]]; then
        echo -e "${GREEN}ok${RESET}"
    else
        echo -e "${DIM}no${RESET}"
    fi

    return $rc
}

# Print the interesting tail of a failed build, skipping the configure noise.
aur_show_error_tail() {
    local log="$1" lines="${2:-10}" line

    grep -vE '^(checking |configure:|  -> |[[:space:]]*$)' "$log" 2>/dev/null \
        | tail -n "$lines" \
        | while IFS= read -r line; do
            echo -e "${DIM}       | ${line:0:150}${RESET}"
        done
    echo -e "${DIM}       | log: ${log}${RESET}"
}

# ---------------------------------------------------------------------------
# makepkg: the reference way to build an AUR package
# ---------------------------------------------------------------------------

# Build and install one package straight from its AUR git repository.
#
# This is the way around a helper's own defects. Shelly 3.1.1, for instance,
# does not extract .pkg.zst sources and ignores arch-specific source_x86_64
# arrays, so darkly-bin and electron41-bin cannot be built through it at all
# while makepkg builds and installs both without complaint. The clone is kept
# between runs so already downloaded sources are not fetched again.
aur_makepkg_build() {
    local pkg="$1" log="$2"
    local dir
    dir="$(aur_build_root)/$pkg"

    if [[ -d "$dir/.git" ]]; then
        git -C "$dir" fetch --depth 1 origin >> "$log" 2>&1 || return 1
        git -C "$dir" reset --hard FETCH_HEAD >> "$log" 2>&1 || return 1
    else
        rm -rf "$dir"
        git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$dir" >> "$log" 2>&1 || return 1
    fi

    ( cd "$dir" && makepkg --syncdeps --install --clean --force --noconfirm )
}

# ---------------------------------------------------------------------------
# Compiler failures
# ---------------------------------------------------------------------------

# An internal compiler error is never the package's fault. It is either a
# compiler bug, in which case a different compiler builds the same sources, or
# faulty hardware, in which case the same compile fails intermittently and
# nothing in a PKGBUILD will fix it. Either way it is worth one retry on another
# installed compiler before the package is written off.
aur_log_has_ice() {
    grep -qE 'internal compiler error|fancy_abort|SIGSEGV' "$1" 2>/dev/null
}

# Name an older GCC that is installed. Empty when there is none.
aur_alternate_compiler() {
    local current major candidate
    current=$(gcc --version 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1 || true)

    if [[ ! "$current" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    for (( major = current - 1; major >= current - 4; major-- )); do
        candidate="gcc-${major}"
        if command -v "$candidate" &>/dev/null; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
}

# makepkg runs build() in a shell that inherits the environment, and autotools,
# cargo and meson all honour CC/CXX.
aur_makepkg_build_with_compiler() {
    local pkg="$1" log="$2" cc="$3"
    local cxx="${cc/gcc/g++}"

    CC="$cc" CXX="$cxx" aur_makepkg_build "$pkg" "$log"
}

# ---------------------------------------------------------------------------
# Files that block an install
# ---------------------------------------------------------------------------

# Extract conflicting paths from either wording: pacman reports
# "<pkg>: /path exists in filesystem", Shelly reports "<pkg> in file /path".
aur_conflicting_paths() {
    local log="$1"

    {
        grep -oE 'in file /[^[:space:]]+' "$log" 2>/dev/null | sed 's|^in file ||'
        grep -oE '/[^[:space:]]+ exists in filesystem' "$log" 2>/dev/null \
            | sed 's| exists in filesystem$||'
    } | sort -u
}

aur_log_has_file_conflict() {
    grep -qE 'conflicting files|exists in filesystem' "$1" 2>/dev/null
}

# Report the paths that are blocking an install, and say which of them no
# package owns.
#
# An unowned path is one an earlier install left behind after its package
# stopped shipping it, and it is the documented case for overwriting. This
# function only reports: removing files from the system is left to the user, who
# can see here exactly which paths are involved and that nothing owns them.
aur_report_file_conflicts() {
    local log="$1" path reported=1

    while IFS= read -r path; do
        if [[ -z "$path" ]]; then
            continue
        fi

        reported=0
        if pacman -Qo "$path" &>/dev/null; then
            echo -e "${YELLOW}       blocked by ${path} (owned by $(pacman -Qoq "$path" 2>/dev/null))${RESET}"
        else
            echo -e "${YELLOW}       blocked by ${path} (owned by no package)${RESET}"
        fi
    done < <(aur_conflicting_paths "$log")

    return $reported
}

# ---------------------------------------------------------------------------
# The escalation
# ---------------------------------------------------------------------------

# Update one AUR package, escalating until something works:
#
#   1. the configured helper, which is fastest and handles the common case
#   2. makepkg, which builds correctly where the helper's source handling fails
#   3. makepkg on an older installed compiler, when the build hit an ICE
#
# Sets AUR_LAST_REASON to a short description when every path failed, so the
# caller can record it.
AUR_LAST_REASON=""
aur_upgrade_one() {
    local helper="$1" pkg="$2"
    local log stamp compiler
    stamp="$(date +%Y%m%d-%H%M%S)"
    log="$(aur_log_root)/${pkg}-${stamp}.log"
    AUR_LAST_REASON=""

    : > "$log"

    if aur_run_step "helper" "$log" aur_helper_rebuild "$helper" "$pkg"; then
        aur_clear_failure "$pkg"
        return 0
    fi

    if aur_run_step "makepkg" "$log" aur_makepkg_build "$pkg" "$log"; then
        aur_clear_failure "$pkg"
        return 0
    fi

    if aur_log_has_ice "$log"; then
        compiler="$(aur_alternate_compiler)"
        if [[ -n "$compiler" ]]; then
            if aur_run_step "makepkg on ${compiler}" "$log" \
                aur_makepkg_build_with_compiler "$pkg" "$log" "$compiler"; then
                aur_clear_failure "$pkg"
                return 0
            fi
        fi
        AUR_LAST_REASON="compiler error"
    fi

    if aur_log_has_file_conflict "$log"; then
        aur_report_file_conflicts "$log" || true
        AUR_LAST_REASON="file conflict"
    fi

    if [[ -z "$AUR_LAST_REASON" ]]; then
        AUR_LAST_REASON="build failed"
        aur_show_error_tail "$log"
    fi

    return 1
}
