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

# Clean problematic AUR package cache
clean_problematic_packages() {
    local problematic=(
        python-vega_datasets
        python-pytest-flakefinder
        python-safehttpx
        python-groovy
        python-mcp
        python-httpx-sse
        python-gradio-client
        python-gradio
    )

    for pkg in "${problematic[@]}"; do
        if [[ -d ~/.cache/paru/clone/$pkg ]]; then
            rm -rf ~/.cache/paru/clone/$pkg 2>/dev/null
        fi
    done
}

# Update AUR packages
update_aur() {
    if [[ "$ENABLE_AUR" != "true" ]]; then
        return 0
    fi

    local helper
    helper=$(detect_aur_helper)

    if [[ "$helper" == "none" ]]; then
        echo -e "${YELLOW}  ⚠️  No AUR helper installed. Skipping AUR...${RESET}"
        return 0
    fi

    show_section "AUR - Arch User Repository ($helper)" "${MAGENTA}" "📦"

    # Clean problematic cache
    clean_problematic_packages

    echo -e "${MAGENTA}  → Checking and updating AUR packages...${RESET}"
    echo ""

    # Check for pending AUR packages (|| true to prevent exit on no updates)
    local aur_pending
    aur_pending=$("$helper" -Qua 2>/dev/null || true)

    if [[ -n "$aur_pending" ]]; then
        echo -e "${CYAN}  Packages available for update:${RESET}"
        local pending_list=()
        while IFS= read -r line; do
            echo "    • $line"
            pending_list+=("$line")
        done <<< "$aur_pending"
        echo ""

        # Attempt 1: bulk update
        local paru_exit=0
        "$helper" -Syu --noconfirm --color always || paru_exit=$?

        # Attempt 2: retry without tests if failed
        if [[ $paru_exit -ne 0 ]]; then
            echo -e "${YELLOW}  ⚠️  Retrying without test verification...${RESET}"
            paru_exit=0
            "$helper" -Syu --noconfirm --skipreview --color always || paru_exit=$?

            # Attempt 3: update individually if still failing
            if [[ $paru_exit -ne 0 ]]; then
                local remaining_pkgs
                remaining_pkgs=$("$helper" -Qua 2>/dev/null | cut -d' ' -f1 || true)

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
    else
        echo -e "${GREEN}  ✓ All AUR packages are up to date${RESET}"
    fi

    echo ""
    echo -e "${GREEN}  ✓ AUR process completed${RESET}"

    end_section
}

# List foreign (AUR) packages
list_aur_packages() {
    pacman -Qm
}
