#!/usr/bin/env bash
# aur.sh - AUR helper module (matches original visual style)
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

# Check whether a package is listed in AUR_SKIP_PACKAGES (space-separated)
aur_should_skip() {
    local pkg="$1" skip
    for skip in ${AUR_SKIP_PACKAGES:-}; do
        [[ "$pkg" == "$skip" ]] && return 0
    done
    return 1
}

# Update AUR packages
#
# Orchestrator: resolves the configured helper, prints the shared section
# chrome, and dispatches to the backend that matches the helper's CLI dialect.
# Backends are responsible only for the per-helper update flow and for
# populating the shared tracking globals (AUR_PACKAGES, UPDATES_AUR,
# UPDATES_AUR_FAILED) so the summary renders identically regardless of helper.
update_aur() {
    if [[ "$ENABLE_AUR" != "true" ]]; then
        return 0
    fi

    local helper
    helper=$(detect_aur_helper)

    if [[ "$helper" == "none" ]]; then
        echo -e "${YELLOW}  ! No AUR helper installed. Skipping AUR...${RESET}"
        return 0
    fi

    show_section "AUR - Arch User Repository ($helper)" "${MAGENTA}" "📦"

    echo -e "${MAGENTA}  → Checking and updating AUR packages...${RESET}"
    echo ""

    local backend_rc=0
    case "$(aur_helper_kind "$helper")" in
        shelly)
            update_aur_shelly "$helper" || backend_rc=$?
            ;;
        *)
            update_aur_pacman "$helper" || backend_rc=$?
            ;;
    esac

    echo ""
    if [[ $backend_rc -ne 0 ]]; then
        echo -e "${YELLOW}  ! AUR process completed with errors${RESET}"
    else
        echo -e "${GREEN}  ✓ AUR process completed${RESET}"
    fi

    end_section
}

# AUR backend for pacman-style helpers (paru, yay)
update_aur_pacman() {
    local helper="$1"

    # Check for pending AUR packages (|| true to prevent exit on no updates)
    local aur_pending
    aur_pending=$("$helper" -Qua 2>/dev/null || true)

    if [[ -z "$aur_pending" ]]; then
        echo -e "${GREEN}  ✓ All AUR packages are up to date${RESET}"
        return 0
    fi

    echo -e "${CYAN}  Packages available for update:${RESET}"
    local pending_list=() skipped=() pkg
    while IFS= read -r line; do
        pkg="${line%% *}"
        if aur_should_skip "$pkg"; then
            echo -e "    ${DIM}· $line (skipped)${RESET}"
            skipped+=("$pkg")
        else
            echo "    • $line"
            pending_list+=("$line")
        fi
    done <<< "$aur_pending"
    echo ""

    if [[ ${#pending_list[@]} -eq 0 ]]; then
        echo -e "${DIM}  · All pending packages are listed in AUR_SKIP_PACKAGES${RESET}"
        return 0
    fi

    local ignore_flag=""
    if [[ ${#skipped[@]} -gt 0 ]]; then
        ignore_flag="--ignore=$(IFS=,; echo "${skipped[*]}")"
    fi

    # Remove partial downloads from paru clone cache before attempting update
    find ~/.cache/paru/clone/ -name "*.part" -type f -delete 2>/dev/null || true

    # Attempt 1: bulk update
    local paru_exit=0
    "$helper" -Syu --noconfirm --color always $ignore_flag || paru_exit=$?

    # Attempt 2: retry without tests if failed
    if [[ $paru_exit -ne 0 ]]; then
        echo -e "${YELLOW}  ! Retrying without test verification...${RESET}"
        paru_exit=0
        "$helper" -Syu --noconfirm --skipreview --color always $ignore_flag || paru_exit=$?

        # Attempt 3: update individually if still failing
        if [[ $paru_exit -ne 0 ]]; then
            local remaining_pkgs
            remaining_pkgs=$("$helper" -Qua 2>/dev/null | cut -d' ' -f1 || true)
            if [[ -n "$remaining_pkgs" && ${#skipped[@]} -gt 0 ]]; then
                remaining_pkgs=$(grep -vxF -f <(printf '%s\n' "${skipped[@]}") <<< "$remaining_pkgs" || true)
            fi

            if [[ -n "$remaining_pkgs" ]]; then
                local count
                count=$(echo "$remaining_pkgs" | wc -l)
                echo -e "${CYAN}  Updating ${count} packages individually...${RESET}"

                while IFS= read -r pkg; do
                    if "$helper" -S --noconfirm --skipreview "$pkg" &>/dev/null; then
                        echo -e "${GREEN}    ✓ ${pkg}${RESET}"
                    else
                        echo -e "${YELLOW}    ✗ ${pkg}${RESET}"
                    fi
                done <<< "$remaining_pkgs"
            fi
        fi
    fi

    # Determine results by comparing before/after state
    local still_pending_pkgs
    still_pending_pkgs=$("$helper" -Qua 2>/dev/null | awk '{print $1}' || true)

    for entry in "${pending_list[@]}"; do
        local pkg="${entry%% *}"
        if [[ -z "$still_pending_pkgs" ]] || ! grep -qx "$pkg" <<< "$still_pending_pkgs"; then
            AUR_PACKAGES+=("$entry")
            ((UPDATES_AUR++)) || true
        else
            ((UPDATES_AUR_FAILED++)) || true
        fi
    done
}

# Shelly 3.0 reorganised its CLI from "shelly aur <verb>" to "shelly <verb> aur",
# and dropped the "aur update" verb: single-package rebuilds now go through
# "install aur". Both dialects are still in the wild, so detect which one is
# installed instead of hardcoding either.
SHELLY_DIALECT=""
shelly_detect_dialect() {
    local helper="$1" version major

    if [[ -n "$SHELLY_DIALECT" ]]; then
        return 0
    fi

    version=$("$helper" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*' | head -1 || true)
    major="${version%%.*}"

    if [[ "$major" =~ ^[0-9]+$ ]]; then
        if [[ "$major" -ge 3 ]]; then
            SHELLY_DIALECT="verb-first"
        else
            SHELLY_DIALECT="aur-first"
        fi
    elif "$helper" --help 2>/dev/null | grep -qE '^[[:space:]]+aur[[:space:]]'; then
        # Unreadable version: fall back to looking for the 2.x "aur" command group
        SHELLY_DIALECT="aur-first"
    else
        SHELLY_DIALECT="verb-first"
    fi
}

# Emit the subcommand words for an AUR action in the installed dialect, so
# callers can splice them into a Shelly invocation.
#   list-updates  pending updates as JSON
#   upgrade       rebuild + reinstall every out-of-date package
#   rebuild       rebuild + reinstall a single package
shelly_subcommand() {
    local helper="$1" action="$2"

    shelly_detect_dialect "$helper"

    if [[ "$SHELLY_DIALECT" == "verb-first" ]]; then
        case "$action" in
            list-updates) echo "list-updates aur" ;;
            upgrade)      echo "upgrade aur" ;;
            rebuild)      echo "install aur" ;;
        esac
    else
        case "$action" in
            list-updates) echo "aur list-updates" ;;
            upgrade)      echo "aur upgrade" ;;
            rebuild)      echo "aur update" ;;
        esac
    fi
}

# List pending Shelly AUR updates as "name old -> new" lines, one per package,
# matching the format paru reports so the summary renders identically.
# Names and versions are emitted in matching order in the JSON, so index pairing
# is reliable; 2.x omits NewVersion, in which case only the version is shown.
# Returns non-zero when Shelly itself fails, so callers can tell "nothing
# pending" apart from "could not ask" instead of reporting a clean run.
# Shared by the update backend and the dry-run preview so both parse Shelly
# identically.
shelly_list_pending() {
    local helper="$1" pending_json subcommand

    subcommand=$(shelly_subcommand "$helper" list-updates)
    pending_json=$("$helper" $subcommand -j 2>/dev/null) || return $?

    local names=() versions=() new_versions=() i entry
    mapfile -t names        < <(grep -oP '"Name":"\K[^"]+'       <<< "$pending_json")
    mapfile -t versions     < <(grep -oP '"Version":"\K[^"]+'    <<< "$pending_json")
    mapfile -t new_versions < <(grep -oP '"NewVersion":"\K[^"]+' <<< "$pending_json")
    for i in "${!names[@]}"; do
        entry="${names[$i]}"
        if [[ -n "${versions[$i]:-}" && -n "${new_versions[$i]:-}" ]]; then
            entry+=" ${versions[$i]} -> ${new_versions[$i]}"
        elif [[ -n "${new_versions[$i]:-}" ]]; then
            entry+=" ${new_versions[$i]}"
        elif [[ -n "${versions[$i]:-}" ]]; then
            entry+=" ${versions[$i]}"
        fi
        echo "$entry"
    done
}

# AUR backend for Shelly
#
# Shelly is not a pacman wrapper: it exposes verb-based subcommands and talks to
# libalpm directly. We mirror the pacman backend's strategy (list pending -> bulk
# upgrade -> per-package fallback -> diff to score results) using Shelly's own
# verbs, and reuse the JSON output for reliable, locale-independent parsing.
#
# The exact subcommand spelling depends on the installed Shelly major version;
# see shelly_subcommand() for the dialects.
update_aur_shelly() {
    local helper="$1"

    # Warm the dialect cache in this shell so the probe runs once, not once per
    # command substitution below.
    shelly_detect_dialect "$helper"

    local pending list_rc=0
    pending=$(shelly_list_pending "$helper") || list_rc=$?

    if [[ $list_rc -ne 0 ]]; then
        echo -e "${YELLOW}  ! Could not read pending AUR updates from ${helper}${RESET}"
        echo -e "${DIM}    Run '${helper} $(shelly_subcommand "$helper" list-updates)' to see why${RESET}"
        return 1
    fi

    if [[ -z "$pending" ]]; then
        echo -e "${GREEN}  ✓ All AUR packages are up to date${RESET}"
        return 0
    fi

    echo -e "${CYAN}  Packages available for update:${RESET}"
    local pending_list=() skipped=() entry pkg
    while IFS= read -r entry; do
        pkg="${entry%% *}"
        if aur_should_skip "$pkg"; then
            echo -e "    ${DIM}· $entry (skipped)${RESET}"
            skipped+=("$pkg")
        else
            echo "    • $entry"
            pending_list+=("$entry")
        fi
    done <<< "$pending"
    echo ""

    if [[ ${#pending_list[@]} -eq 0 ]]; then
        echo -e "${DIM}  · All pending packages are listed in AUR_SKIP_PACKAGES${RESET}"
        return 0
    fi

    # Attempt 1: bulk upgrade. --singlepane renders a pacman-style linear stream
    # (cleaner for non-interactive runs and logging than the default panes).
    # Shelly has no --ignore equivalent, so when AUR_SKIP_PACKAGES matched
    # something, update the remaining packages one by one instead.
    local shelly_exit=0
    if [[ ${#skipped[@]} -gt 0 ]]; then
        # Already per-package: report each result here and let the final
        # before/after diff score failures. Triggering the bulk-failure retry
        # below would re-run packages that just succeeded.
        for entry in "${pending_list[@]}"; do
            pkg="${entry%% *}"
            if "$helper" $(shelly_subcommand "$helper" rebuild) --no-confirm --singlepane "$pkg"; then
                echo -e "${GREEN}    ✓ ${pkg}${RESET}"
            else
                echo -e "${YELLOW}    ✗ ${pkg}${RESET}"
            fi
        done
    else
        "$helper" $(shelly_subcommand "$helper" upgrade) --no-confirm --singlepane || shelly_exit=$?
    fi

    # Attempt 2: rebuild the still-pending packages individually
    if [[ $shelly_exit -ne 0 ]]; then
        echo -e "${YELLOW}  ! Retrying failed packages individually...${RESET}"
        for entry in "${pending_list[@]}"; do
            pkg="${entry%% *}"
            if "$helper" $(shelly_subcommand "$helper" rebuild) --no-confirm "$pkg" &>/dev/null; then
                echo -e "${GREEN}    ✓ ${pkg}${RESET}"
            else
                echo -e "${YELLOW}    ✗ ${pkg}${RESET}"
            fi
        done
    fi

    # Determine results by comparing before/after state. If Shelly cannot be
    # queried now, none of the upgrades can be confirmed, so count them failed
    # rather than silently crediting them as successful.
    local still_pending
    list_rc=0
    still_pending=$(shelly_list_pending "$helper") || list_rc=$?

    if [[ $list_rc -ne 0 ]]; then
        echo -e "${YELLOW}  ! Could not verify which packages were upgraded${RESET}"
        UPDATES_AUR_FAILED=$(( UPDATES_AUR_FAILED + ${#pending_list[@]} ))
        return 1
    fi

    still_pending=$(awk '{print $1}' <<< "$still_pending")

    for entry in "${pending_list[@]}"; do
        pkg="${entry%% *}"
        if [[ -z "$still_pending" ]] || ! grep -qxF "$pkg" <<< "$still_pending"; then
            AUR_PACKAGES+=("$entry")
            ((UPDATES_AUR++)) || true
        else
            ((UPDATES_AUR_FAILED++)) || true
        fi
    done
}

# List foreign (AUR) packages
list_aur_packages() {
    pacman -Qm
}
