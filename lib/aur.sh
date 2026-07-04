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

    case "$(aur_helper_kind "$helper")" in
        shelly)
            update_aur_shelly "$helper"
            ;;
        *)
            update_aur_pacman "$helper"
            ;;
    esac

    echo ""
    echo -e "${GREEN}  ✓ AUR process completed${RESET}"

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

# List pending Shelly AUR updates as "name version" lines, one per package.
# Names and versions are emitted in matching order in the JSON; every package
# object carries both fields, so index pairing is reliable. Shared by the
# update backend and the dry-run preview so both parse Shelly identically.
shelly_list_pending() {
    local helper="$1" pending_json
    pending_json=$("$helper" aur list-updates -j 2>/dev/null || echo "[]")

    local names=() versions=() i entry
    mapfile -t names    < <(grep -oP '"Name":"\K[^"]+'    <<< "$pending_json")
    mapfile -t versions < <(grep -oP '"Version":"\K[^"]+' <<< "$pending_json")
    for i in "${!names[@]}"; do
        entry="${names[$i]} ${versions[$i]:-}"
        echo "${entry% }"
    done
}

# AUR backend for Shelly
#
# Shelly is not a pacman wrapper: it exposes verb-based subcommands and talks to
# libalpm directly. We mirror the pacman backend's strategy (list pending -> bulk
# upgrade -> per-package fallback -> diff to score results) using Shelly's own
# verbs, and reuse the JSON output for reliable, locale-independent parsing.
#
#   shelly aur list-updates -j   pending updates as JSON (Name/Version per entry)
#   shelly aur upgrade           rebuild + reinstall every out-of-date package
#   shelly aur update <pkg>      rebuild + reinstall a single package
update_aur_shelly() {
    local helper="$1"

    local pending
    pending=$(shelly_list_pending "$helper")

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
            if "$helper" aur update --no-confirm --singlepane "$pkg"; then
                echo -e "${GREEN}    ✓ ${pkg}${RESET}"
            else
                echo -e "${YELLOW}    ✗ ${pkg}${RESET}"
            fi
        done
    else
        "$helper" aur upgrade --no-confirm --singlepane || shelly_exit=$?
    fi

    # Attempt 2: rebuild the still-pending packages individually
    if [[ $shelly_exit -ne 0 ]]; then
        echo -e "${YELLOW}  ! Retrying failed packages individually...${RESET}"
        for entry in "${pending_list[@]}"; do
            pkg="${entry%% *}"
            if "$helper" aur update --no-confirm "$pkg" &>/dev/null; then
                echo -e "${GREEN}    ✓ ${pkg}${RESET}"
            else
                echo -e "${YELLOW}    ✗ ${pkg}${RESET}"
            fi
        done
    fi

    # Determine results by comparing before/after state
    local still_pending
    still_pending=$(shelly_list_pending "$helper" | awk '{print $1}')

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
