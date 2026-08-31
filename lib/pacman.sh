#!/usr/bin/env bash
# pacman.sh - Pacman update module (matches original visual style)
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

# Detect installed packages whose pinned dependency version no longer matches
# the installed dependency, so the update would fail on them. Driven entirely
# by the DEP_MISMATCH_HOLDS config option ("package:dependency" pairs); empty
# by default, so nothing here is tied to a particular machine.
detect_broken_deps() {
    local broken_pkgs=() pair pkg dep needed current

    for pair in ${DEP_MISMATCH_HOLDS:-}; do
        pkg="${pair%%:*}"
        dep="${pair##*:}"
        [[ -n "$pkg" && -n "$dep" && "$pkg" != "$pair" ]] || continue
        pacman -Qi "$pkg" &>/dev/null || continue

        needed=$(pacman -Si "$pkg" 2>/dev/null | grep -oP "${dep}=\K[0-9.]+" | head -1 || true)
        current=$(pacman -Q "$dep" 2>/dev/null | awk '{print $2}' | cut -d'-' -f1 || true)

        if [[ -n "$needed" && -n "$current" && "$needed" != "$current" ]]; then
            broken_pkgs+=("$pkg")
        fi
    done
    echo "${broken_pkgs[*]:-}"
}

# Handle PGP errors
handle_pgp_error() {
    echo -e "${YELLOW}  ! PGP signature error detected. Fixing...${RESET}"

    # chaotic-keyring only exists when the Chaotic-AUR repo is configured
    local keyrings=(archlinux-keyring)
    pacman -Si chaotic-keyring &>/dev/null && keyrings+=(chaotic-keyring)

    # Keyring install and db sync must succeed for the recovery to count;
    # --refresh-keys often partially fails on flaky keyservers and is optional.
    local fix_ok=true
    if has_command gum; then
        gum spin --spinner dot --title "Updating keyring..." -- \
            sudo pacman -S --noconfirm "${keyrings[@]}" 2>/dev/null || fix_ok=false
        gum spin --spinner dot --title "Refreshing PGP keys..." -- \
            sudo pacman-key --refresh-keys 2>/dev/null || true
        gum spin --spinner dot --title "Syncing database..." -- \
            sudo pacman -Sy 2>/dev/null || fix_ok=false
    else
        sudo pacman -S --noconfirm "${keyrings[@]}" 2>/dev/null || fix_ok=false
        sudo pacman-key --refresh-keys 2>/dev/null || true
        sudo pacman -Sy 2>/dev/null || fix_ok=false
    fi

    if [[ "$fix_ok" == "true" ]]; then
        echo -e "${GREEN}  ✓ Keyring updated${RESET}"
    else
        echo -e "${YELLOW}  ! Keyring recovery incomplete (keyservers or mirrors unreachable?)${RESET}"
    fi
}

# Run the full system upgrade under script(1), which allocates a pseudo-TTY so
# pacman 7.x keeps its progress bars while the output is still captured to
# PACMAN_OUTPUT_LOG for the reboot check. Returns pacman's exit code.
run_pacman_syu() {
    local extra_args="${1:-}"
    local rc=0
    script -q -f -e -a -c "sudo pacman -Syyu --noconfirm --color always${extra_args:+ $extra_args}" "$PACMAN_OUTPUT_LOG" || rc=$?
    return $rc
}

# Check the tail of the captured pacman output for a PGP failure. Only the
# last lines are inspected so an incidental signature warning inside an
# unrelated failure does not trigger keyring recovery. The process
# substitution keeps a pipefail SIGPIPE from masking a match when grep -q
# exits before sed finishes writing.
pacman_log_has_pgp_error() {
    [[ -f "${PACMAN_OUTPUT_LOG:-}" ]] || return 1
    grep -qiE "PGP signature|unknown trust|firma PGP" \
        < <(tail -n 30 "$PACMAN_OUTPUT_LOG" | sed 's/\x1b\[[0-9;]*m//g')
}

# Print the values of one "pacman -Si" field, joining the continuation lines
# pacman uses when a list does not fit on a single line. The query is pinned to
# LC_ALL=C so the field names stay parseable whatever locale the user reads the
# visible upgrade output in.
pacman_si_field() {
    local pkg="$1" field="$2"

    LC_ALL=C pacman -Si "$pkg" 2>/dev/null | awk -v field="$field" '
        $0 ~ "^" field "[[:space:]]*:" { sub(/^[^:]*:[[:space:]]*/, ""); print; seen = 1; next }
        seen && /^[[:space:]]/ { sub(/^[[:space:]]+/, ""); print; next }
        seen { exit }
    '
}

# Read a "pacman -Si" field from stdin and report whether it lists $1. Version
# constraints are stripped, so "foo<=1.2" still matches "foo".
pacman_field_lists() {
    local want="$1" line word found=1

    while read -r line; do
        # Deliberate word splitting: pacman prints these fields space separated.
        for word in $line; do
            word="${word%%[<>=]*}"
            if [[ "$word" == "$want" ]]; then
                found=0
            fi
        done
    done
    return $found
}

# Print one "incoming superseded" pair per conflict question in the tail of the
# captured pacman output. pacman phrases them as
#   :: <new>-<ver>-<rel> and <old>-<ver>-<rel> are in conflict. Remove <old>?
# so the removal target comes from the question itself and the incoming package
# from the head of the same line, with its pkgver-pkgrel tail stripped off.
pacman_conflict_pairs() {
    [[ -f "${PACMAN_OUTPUT_LOG:-}" ]] || return 1

    tail -n 80 "$PACMAN_OUTPUT_LOG" \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -E "::.*(Remove|Quitar) [^?]+\?" \
        | while IFS= read -r line; do
            local incoming victim
            incoming=$(grep -oP '::\s+\K\S+' <<< "$line" || true)
            incoming="${incoming%-*-*}"
            victim=$(grep -oP '(?:Remove|Quitar) \K[^?]+(?=\?)' <<< "$line" || true)
            if [[ -n "$incoming" && -n "$victim" ]]; then
                echo "$incoming $victim"
            fi
        done | sort -u
}

# Decide whether the failed transaction is nothing but package renames. A
# conflict qualifies only when the incoming package declares BOTH Replaces and
# Provides for the installed one, which is upstream saying "this package is now
# part of that one". pacman applies such a rename silently once the old name is
# gone from every repo, and only asks while the old name still exists in
# another one - a CachyOS rebuild shadowing an Arch package, say - where the
# unattended --noconfirm answers no and drops the whole upgrade.
#
# Prints the packages to remove, and returns 0 only when every pending conflict
# checks out: one unexplained conflict disqualifies the batch, so a genuine
# conflict is never resolved behind the user's back.
pacman_supersede_plan() {
    local pairs incoming victim victims=()

    pairs=$(pacman_conflict_pairs) || return 1
    [[ -n "$pairs" ]] || return 1

    while read -r incoming victim; do
        [[ -n "$incoming" && -n "$victim" ]] || return 1

        # Anything the user calls critical stays untouched, whatever the
        # metadata claims.
        [[ " ${CRITICAL_PACKAGES:-} " == *" $victim "* ]] && return 1

        pacman -Qq "$victim" &>/dev/null || return 1
        pacman_si_field "$incoming" Replaces | pacman_field_lists "$victim" || return 1
        pacman_si_field "$incoming" Provides | pacman_field_lists "$victim" || return 1

        victims+=("$victim")
    done <<< "$pairs"

    [[ ${#victims[@]} -gt 0 ]] || return 1
    echo "${victims[*]}"
}

# Drop the superseded packages and rerun the upgrade so the incoming ones take
# their place. It takes two transactions because pacman cannot remove and
# upgrade in one; if the upgrade still fails the removal is rolled back, which
# is always possible here because the superseded package still existing in a
# repo is the very reason pacman asked in the first place.
resolve_superseded_conflicts() {
    local victims="$1" extra_args="${2:-}" rc=0

    echo -e "${YELLOW}  ! Superseded by the incoming update: ${victims}${RESET}"
    echo -e "${BLUE}  → Removing and retrying...${RESET}"
    echo ""

    # -Rdd: the reverse dependencies keep resolving because the incoming
    # package provides the same name, and it lands in the upgrade below.
    if ! sudo pacman -Rdd --noconfirm $victims; then
        echo -e "${RED}  ✗ Could not remove ${victims}${RESET}"
        return 1
    fi

    run_pacman_syu "$extra_args" || rc=$?

    if [[ $rc -ne 0 ]]; then
        echo -e "${YELLOW}  ! Upgrade still failing, restoring ${victims}${RESET}"
        sudo pacman -S --noconfirm $victims \
            || echo -e "${RED}    Restore failed, reinstall manually: ${victims}${RESET}"
    fi

    return $rc
}

# Inspect the tail of the captured pacman output and print a suggestion that
# matches the actual failure instead of a fixed one. pacman's messages are
# localized, so every pattern covers the English and Spanish wording. Prints
# one line per hint, the last one always an actionable "Suggestion:"; returns
# 1 without printing when the failure is not recognised.
pacman_failure_hint() {
    [[ -f "${PACMAN_OUTPUT_LOG:-}" ]] || return 1

    local log
    log=$(tail -n 80 "$PACMAN_OUTPUT_LOG" | sed 's/\x1b\[[0-9;]*m//g')

    # Package conflicts: pacman asks whether to drop the superseded package,
    # and --noconfirm answers "no", so the whole transaction is aborted. Usual
    # fallout of an upstream package being merged into another one.
    if grep -qiE "unresolvable package conflicts|conflictos sin resolver|conflicting dependencies|dependencias en conflicto" <<< "$log"; then
        local victim
        victim=$(grep -oP '(?:Remove|Quitar) \K[^?]+(?=\?)' <<< "$log" | tail -1)
        if [[ -n "$victim" ]]; then
            echo "Package conflict: '${victim}' has to be removed, --noconfirm declines it"
        else
            echo "Unresolved package conflict: --noconfirm cannot answer the prompt"
        fi
        echo "Suggestion: run 'sudo pacman -Syu' manually and accept the removal"
        return 0
    fi

    # Files owned by no package, or by a different one, sit where the new
    # package wants to write. Never suggest a blind --overwrite here.
    if grep -qiE "conflicting files|archivos en conflicto|exists in filesystem|existe en el sistema de archivos" <<< "$log"; then
        echo "File conflict: some files on disk block the new packages"
        echo "Suggestion: check the owner with 'pacman -Qo <file>' before overwriting"
        return 0
    fi

    if grep -qiE "PGP signature|unknown trust|firma PGP|confianza desconocida" <<< "$log"; then
        echo "Signature check failed and the keyring recovery did not fix it"
        echo "Suggestion: sudo pacman -S archlinux-keyring && sudo pacman-key --refresh-keys"
        return 0
    fi

    if grep -qiE "invalid or corrupted package|paquete no válido o dañado" <<< "$log"; then
        echo "A cached package is corrupted or truncated"
        echo "Suggestion: sudo pacman -Sc && sudo pacman -Syu"
        return 0
    fi

    if grep -qiE "not enough free disk space|no hay suficiente espacio" <<< "$log"; then
        echo "Not enough free space to stage the upgrade"
        echo "Suggestion: sudo pacman -Scc, then retry the update"
        return 0
    fi

    if grep -qiE "failed retrieving file|error al recuperar el archivo|could not resolve host|no se pudo resolver el host" <<< "$log"; then
        echo "Downloads failed: mirror or network problem"
        echo "Suggestion: refresh your mirrorlist, or just retry in a few minutes"
        return 0
    fi

    # Kept last: the conflict branch above matches the same wording in
    # Spanish, so only genuine dependency gaps reach this point.
    if grep -qiE "unable to satisfy dependency|no se pudo satisfacer la dependencia|could not satisfy dependencies" <<< "$log"; then
        echo "A dependency is missing from the repos (partial or in-flight update)"
        echo "Suggestion: wait for the mirrors to catch up, never force a partial upgrade"
        return 0
    fi

    return 1
}

# Check for pacman database lock
check_pacman_lock() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo -e "${RED}  ✗ Pacman database is locked${RESET}"
        echo -e "${YELLOW}    Another package manager might be running${RESET}"
        echo -e "${DIM}    If not, remove: sudo rm /var/lib/pacman/db.lck${RESET}"
        return 1
    fi
    return 0
}

# Update system packages via pacman
update_pacman() {
    if [[ "$ENABLE_PACMAN" != "true" ]]; then
        return 0
    fi

    show_section "PACMAN - System Packages" "${BLUE}" "📦"

    # Detect problematic packages
    local ignore_packages
    ignore_packages=$(detect_broken_deps)
    local ignore_flag=""

    if [[ -n "$ignore_packages" ]]; then
        echo -e "${YELLOW}  ! Temporarily skipping: ${ignore_packages}${RESET}"
        ignore_flag="--ignore=${ignore_packages// /,}"
    fi

    echo -e "${BLUE}  → Syncing and updating...${RESET}"
    echo ""

    # Capture the exit code with || so errexit cannot abort the run here:
    # a pacman failure must fall through to the PGP recovery path below.
    local pacman_exit=0
    run_pacman_syu "$ignore_flag" || pacman_exit=$?

    # If failed, check the captured output for a PGP error and retry once.
    if [[ $pacman_exit -ne 0 ]] && pacman_log_has_pgp_error; then
        handle_pgp_error

        echo -e "${BLUE}  → Retrying update...${RESET}"
        pacman_exit=0
        run_pacman_syu "$ignore_flag" || pacman_exit=$?
    fi

    # A conflict question that --noconfirm declined leaves the whole
    # transaction unapplied. Retry only when the conflict is a verified
    # package rename; a real conflict is reported instead.
    if [[ $pacman_exit -ne 0 && "${PACMAN_AUTO_RESOLVE_CONFLICTS:-true}" == "true" ]]; then
        local superseded
        if superseded=$(pacman_supersede_plan); then
            pacman_exit=0
            resolve_superseded_conflicts "$superseded" "$ignore_flag" || pacman_exit=$?
        fi
    fi

    echo ""
    if [[ $pacman_exit -eq 0 ]]; then
        echo -e "${GREEN}  ✓ Pacman update completed${RESET}"
    else
        echo -e "${RED}  ✗ Pacman error. Continuing...${RESET}"
        local hint_line
        while IFS= read -r hint_line; do
            if [[ -n "$hint_line" ]]; then
                echo -e "${YELLOW}    ${hint_line}${RESET}"
            fi
        done < <(pacman_failure_hint || \
            echo "Suggestion: run 'sudo pacman -Syu' manually to see the full error")
    fi

    # Capture updated/installed packages from log
    if [[ -f /var/log/pacman.log ]]; then
        local total_lines
        total_lines=$(wc -l < /var/log/pacman.log)
        local new_lines=$((total_lines - LOG_LINE_START))
        if [[ $new_lines -gt 0 ]]; then
            while IFS= read -r line; do
                PACMAN_PACKAGES+=("$line")
            done < <(tail -n "$new_lines" /var/log/pacman.log | grep -E '\[ALPM\] (upgraded|installed)' | awk '{
                action = $3
                pkg = $4
                match($0, /\(([^)]+)\)/, arr)
                versions = arr[1]
                print pkg "|" versions "|" action
            }')
            UPDATES_PACMAN=${#PACMAN_PACKAGES[@]}
        fi
    fi

    end_section
}
