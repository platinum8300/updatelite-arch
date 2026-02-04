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
        while IFS= read -r line; do
            echo "    • $line"
            AUR_PACKAGES+=("$line")
        done <<< "$aur_pending"
        echo ""

        # Update with real-time output
        local paru_exit=0
        "$helper" -Syu --noconfirm --color always || paru_exit=$?

        # If failed, retry without tests
        if [[ $paru_exit -ne 0 ]]; then
            echo -e "${YELLOW}  ⚠️  Retrying without test verification...${RESET}"
            "$helper" -Syu --noconfirm --skipreview --color always || paru_exit=$?

            # If still failing, update individually
            if [[ $paru_exit -ne 0 ]]; then
                local aur_updates
                aur_updates=$("$helper" -Qua 2>/dev/null | cut -d' ' -f1 || true)

                if [[ -n "$aur_updates" ]]; then
                    local count
                    count=$(echo "$aur_updates" | wc -l)
                    echo -e "${CYAN}  Updating ${count} packages individually...${RESET}"
                    local success=0

                    while IFS= read -r pkg; do
                        if "$helper" -S --noconfirm --skipreview "$pkg" &>/dev/null; then
                            ((success++)) || true
                            echo -e "${GREEN}    ✓ ${pkg}${RESET}"
                        else
                            ((UPDATES_AUR_FAILED++)) || true
                            echo -e "${YELLOW}    ✗ ${pkg}${RESET}"
                        fi
                    done <<< "$aur_updates"

                    UPDATES_AUR=$success
                fi
            fi
        fi

        # Count successful AUR updates
        if [[ $paru_exit -eq 0 && ${#AUR_PACKAGES[@]} -gt 0 ]]; then
            UPDATES_AUR=${#AUR_PACKAGES[@]}
        fi
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
