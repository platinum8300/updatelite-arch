#!/usr/bin/env bash
# summary.sh - Summary display module (matches original visual style)
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

# Show header (clean, minimalist style)
show_header() {
    local phrase
    phrase=$(get_random_phrase)
    local distro
    distro=$(detect_distro)

    clear

    echo ""
    echo -e "${DIM}───────────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -e "    ${BOLD}${GREEN}update${RESET}${BOLD}${MAGENTA}LITE${RESET}  ${DIM}·${RESET}  ${CYAN}${distro^} Edition${RESET}"
    echo ""
    echo -e "    ${DIM}📅${RESET} $(date '+%d/%m/%Y %H:%M')"
    echo -e "    ${DIM}📝${RESET} ${phrase}"
    echo ""
    echo -e "${DIM}───────────────────────────────────────────────────────────${RESET}"
    echo ""
}

# Show detailed summary (matches original style with box drawing)
show_summary() {
    local elapsed
    elapsed=$(get_elapsed_time)

    # Get system info
    local mem_info mem_percent disk_info disk_percent kernel
    mem_info=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
    mem_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    disk_info=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
    disk_percent=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')
    kernel=$(uname -r)

    # Count pacman upgraded vs installed
    local pacman_upgraded=0
    local pacman_installed=0
    for pkg in "${PACMAN_PACKAGES[@]}"; do
        local action="${pkg##*|}"
        if [[ "$action" == "upgraded" ]]; then
            pacman_upgraded=$((pacman_upgraded + 1))
        elif [[ "$action" == "installed" ]]; then
            pacman_installed=$((pacman_installed + 1))
        fi
    done

    echo ""
    echo -e "${DIM}───────────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -e "  ${BOLD}SUMMARY${RESET}"
    echo ""

    # Statistics in compact format
    echo -e "  ${BOLD}${BLUE}PACMAN${RESET}    ${GREEN}▲${RESET} ${pacman_upgraded} upgraded  ${BLUE}○${RESET} ${pacman_installed} new"
    echo -e "  ${BOLD}${MAGENTA}AUR${RESET}       ${GREEN}▲${RESET} ${UPDATES_AUR} upgraded  ${RED}✗${RESET} ${UPDATES_AUR_FAILED} failed"
    if [[ "$ENABLE_DOCKER" == "true" ]]; then
        echo -e "  ${BOLD}${CYAN}FLATPAK${RESET}   ${GREEN}▲${RESET} ${UPDATES_FLATPAK} upgraded  ${BLUE}🐋${RESET} Docker: ${UPDATES_DOCKER}"
    else
        echo -e "  ${BOLD}${CYAN}FLATPAK${RESET}   ${GREEN}▲${RESET} ${UPDATES_FLATPAK} upgraded"
    fi
    echo ""
    echo -e "  ${BOLD}${YELLOW}CLEANUP${RESET}   Cache: ${CACHE_FREED:-0 MB}  Journal: ${JOURNAL_FREED:-0 MB}  Orphans: ${ORPHANS_REMOVED}"
    echo ""

    # ═══════════════════════════════════════════════════════════════
    # SECTION: UPDATED PACKAGES - Organized by categories
    # ═══════════════════════════════════════════════════════════════
    echo -e "${DIM}───────────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -e "  ${BOLD}UPDATED PACKAGES${RESET}"
    echo ""

    local has_updates=false

    # ─────────────────────────────────────────────────────────────
    # PACMAN - System packages
    # ─────────────────────────────────────────────────────────────
    if [[ ${#PACMAN_PACKAGES[@]} -gt 0 ]]; then
        has_updates=true
        echo -e "  ${BOLD}${BLUE}📦 PACMAN${RESET} ${DIM}(${pacman_upgraded} upgraded, ${pacman_installed} new)${RESET}"
        echo -e "  ${DIM}┌─────────────────────────────────────────────────────${RESET}"
        for pkg in "${PACMAN_PACKAGES[@]}"; do
            local pkg_name="${pkg%%|*}"
            local rest="${pkg#*|}"
            local versions="${rest%|*}"
            local action="${rest##*|}"
            if [[ "$action" == "upgraded" ]]; then
                echo -e "  ${DIM}│${RESET}  ${GREEN}▲${RESET} ${WHITE}${pkg_name}${RESET}"
                echo -e "  ${DIM}│${RESET}    ${DIM}${versions}${RESET}"
            elif [[ "$action" == "installed" ]]; then
                echo -e "  ${DIM}│${RESET}  ${BLUE}○${RESET} ${WHITE}${pkg_name}${RESET} ${DIM}(new)${RESET}"
                echo -e "  ${DIM}│${RESET}    ${DIM}${versions}${RESET}"
            fi
        done
        echo -e "  ${DIM}└─────────────────────────────────────────────────────${RESET}"
        echo ""
    fi

    # ─────────────────────────────────────────────────────────────
    # AUR - Arch User Repository
    # ─────────────────────────────────────────────────────────────
    if [[ ${#AUR_PACKAGES[@]} -gt 0 ]]; then
        has_updates=true
        echo -e "  ${BOLD}${MAGENTA}📦 AUR${RESET} ${DIM}(${UPDATES_AUR} upgraded)${RESET}"
        echo -e "  ${DIM}┌─────────────────────────────────────────────────────${RESET}"
        for pkg in "${AUR_PACKAGES[@]}"; do
            local pkg_name
            pkg_name=$(echo "$pkg" | awk '{print $1}')
            local versions
            versions=$(echo "$pkg" | awk '{$1=""; print $0}' | xargs)
            echo -e "  ${DIM}│${RESET}  ${MAGENTA}▲${RESET} ${WHITE}${pkg_name}${RESET}"
            echo -e "  ${DIM}│${RESET}    ${DIM}${versions}${RESET}"
        done
        echo -e "  ${DIM}└─────────────────────────────────────────────────────${RESET}"
        echo ""
    fi

    # ─────────────────────────────────────────────────────────────
    # FLATPAK - Sandboxed Applications
    # ─────────────────────────────────────────────────────────────
    if [[ ${#FLATPAK_PACKAGES[@]} -gt 0 ]]; then
        has_updates=true
        echo -e "  ${BOLD}${CYAN}📦 FLATPAK${RESET} ${DIM}(${UPDATES_FLATPAK} upgraded)${RESET}"
        echo -e "  ${DIM}┌─────────────────────────────────────────────────────${RESET}"
        for app in "${FLATPAK_PACKAGES[@]}"; do
            local app_name
            app_name=$(echo "$app" | awk '{print $1}')
            local app_id
            app_id=$(echo "$app" | awk '{print $2}')
            local app_version
            app_version=$(echo "$app" | awk '{print $3}')
            echo -e "  ${DIM}│${RESET}  ${CYAN}▲${RESET} ${WHITE}${app_name}${RESET}"
            echo -e "  ${DIM}│${RESET}    ${DIM}${app_id}${RESET}"
            if [[ -n "$app_version" ]]; then
                echo -e "  ${DIM}│${RESET}    ${DIM}→ ${app_version}${RESET}"
            fi
        done
        echo -e "  ${DIM}└─────────────────────────────────────────────────────${RESET}"
        echo ""
    fi

    # If no updates
    if [[ "$has_updates" == "false" ]]; then
        echo -e "  ${DIM}┌─────────────────────────────────────────────────────${RESET}"
        echo -e "  ${DIM}│${RESET}  ${GREEN}✓${RESET} ${DIM}System already up to date - No changes${RESET}"
        echo -e "  ${DIM}└─────────────────────────────────────────────────────${RESET}"
        echo ""
    fi

    # ═══════════════════════════════════════════════════════════════
    # SECTION: SYSTEM
    # ═══════════════════════════════════════════════════════════════
    echo -e "${DIM}───────────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -e "  ${BOLD}SYSTEM${RESET}"
    echo ""

    # Progress bars
    local ram_bar disk_bar
    ram_bar=$(progress_bar "$mem_percent" 100)
    disk_bar=$(progress_bar "$disk_percent" 100)

    echo -e "  💾 RAM:    ${ram_bar}  ${mem_info}"
    echo -e "  💿 DISK:   ${disk_bar}  ${disk_info}"
    echo ""
    echo -e "  🔄 Kernel: ${kernel}"
    echo -e "  ⏱️  Time:   ${elapsed}"
    echo ""
}

# Show footer (matches original style)
show_footer() {
    local phrase
    phrase=$(get_random_phrase)

    echo -e "${DIM}───────────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -e "  ${BOLD}${GREEN}✓ COMPLETED${RESET}  ${phrase}"
    echo ""
    echo -e "${DIM}───────────────────────────────────────────────────────────${RESET}"
    echo ""
}
