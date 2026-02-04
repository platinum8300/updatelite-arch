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

# Detect packages with problematic dependencies
detect_broken_deps() {
    local broken_pkgs=""

    if pacman -Qi linux-cachyos-bore-nvidia-open &>/dev/null; then
        local needed_nvidia
        needed_nvidia=$(pacman -Si linux-cachyos-bore-nvidia-open 2>/dev/null | grep -oP "nvidia-utils=\K[0-9.]+" | head -1)
        local current_nvidia
        current_nvidia=$(pacman -Q nvidia-utils 2>/dev/null | awk '{print $2}' | cut -d'-' -f1)

        if [[ -n "$needed_nvidia" && "$needed_nvidia" != "$current_nvidia" ]]; then
            broken_pkgs="linux-cachyos-bore-nvidia-open"
        fi
    fi
    echo "$broken_pkgs"
}

# Handle PGP errors
handle_pgp_error() {
    echo -e "${YELLOW}  ⚠️  PGP signature error detected. Fixing...${RESET}"

    if has_command gum; then
        gum spin --spinner dot --title "Updating keyring..." -- \
            sudo pacman -S --noconfirm archlinux-keyring chaotic-keyring 2>/dev/null
        gum spin --spinner dot --title "Refreshing PGP keys..." -- \
            sudo pacman-key --refresh-keys 2>/dev/null
        gum spin --spinner dot --title "Syncing database..." -- \
            sudo pacman -Sy 2>/dev/null
    else
        sudo pacman -S --noconfirm archlinux-keyring chaotic-keyring 2>/dev/null
        sudo pacman-key --refresh-keys 2>/dev/null
        sudo pacman -Sy 2>/dev/null
    fi

    echo -e "${GREEN}  ✓ Keyring updated${RESET}"
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
        echo -e "${YELLOW}  ⚠️  Temporarily skipping: ${ignore_packages}${RESET}"
        ignore_flag="--ignore=${ignore_packages//,/,}"
    fi

    echo -e "${BLUE}  → Syncing and updating...${RESET}"
    echo ""

    # Execute pacman with real-time output
    local pacman_exit
    if [[ -n "$ignore_flag" ]]; then
        sudo pacman -Syyu --noconfirm --color always $ignore_flag
    else
        sudo pacman -Syyu --noconfirm --color always
    fi
    pacman_exit=$?

    # If failed, check for PGP error
    if [[ $pacman_exit -ne 0 ]]; then
        local last_error
        last_error=$(sudo pacman -Syyu --noconfirm 2>&1 | tail -5)
        if echo "$last_error" | grep -qE "PGP signature|unknown trust|firma PGP"; then
            handle_pgp_error

            echo -e "${BLUE}  → Retrying update...${RESET}"
            if [[ -n "$ignore_flag" ]]; then
                sudo pacman -Syyu --noconfirm --color always $ignore_flag
            else
                sudo pacman -Syyu --noconfirm --color always
            fi
            pacman_exit=$?
        fi
    fi

    echo ""
    if [[ $pacman_exit -eq 0 ]]; then
        echo -e "${GREEN}  ✓ Pacman update completed${RESET}"
    else
        echo -e "${RED}  ✗ Pacman error. Continuing...${RESET}"
        echo -e "${YELLOW}    Suggestion: sudo pacman -S archlinux-keyring chaotic-keyring${RESET}"
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
