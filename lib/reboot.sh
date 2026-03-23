#!/usr/bin/env bash
# reboot.sh - Reboot detection module (matches original visual style)
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

# Check if reboot is required by reading pacman hook output
check_reboot_required() {
    local needs_reboot=false
    local reboot_reasons=()

    # Primary: check if pacman hooks flagged a reboot during this session
    # This respects the distro's own reboot policy (e.g. CachyOS hooks)
    if [[ -n "$PACMAN_OUTPUT_LOG" && -f "$PACMAN_OUTPUT_LOG" ]]; then
        if grep -qi "reboot is recommended\|reboot.*required\|needs.*reboot" "$PACMAN_OUTPUT_LOG"; then
            needs_reboot=true
            reboot_reasons+=("core system packages (detected by pacman hooks)")
        fi
    fi

    # Secondary: check for kernel version mismatch (running vs installed)
    local running_kernel
    running_kernel=$(uname -r)

    local kernel_pkg=""
    for kernel in "linux-cachyos" "linux-cachyos-bore" "linux-cachyos-lts" "linux-zen" "linux-lts" "linux"; do
        kernel_pkg=$(pacman -Q "$kernel" 2>/dev/null | awk '{print $2}' || true)
        if [[ -n "$kernel_pkg" ]]; then
            break
        fi
    done

    if [[ -n "$kernel_pkg" ]]; then
        local running_ver="${running_kernel%%[-_]*}"
        local pkg_ver="${kernel_pkg%%-*}"

        if [[ "$running_ver" != "$pkg_ver" ]]; then
            needs_reboot=true
            reboot_reasons+=("kernel (running: $running_ver, installed: $pkg_ver)")
        fi
    fi

    # Cleanup temp file
    [[ -n "$PACMAN_OUTPUT_LOG" && -f "$PACMAN_OUTPUT_LOG" ]] && rm -f "$PACMAN_OUTPUT_LOG"

    # Show reboot notice or confirmation
    if [[ "$needs_reboot" == "true" ]]; then
        echo ""
        echo -e "${BOLD}${YELLOW}╔════════════════════════════════════════════════════════ ${RESET}"
        echo -e "${BOLD}${YELLOW}║            ⚠️  REBOOT RECOMMENDED ⚠️                    ${RESET}"
        echo -e "${BOLD}${YELLOW}╚════════════════════════════════════════════════════════ ${RESET}"
        echo ""

        if [[ ${#reboot_reasons[@]} -gt 0 ]]; then
            echo -e "${CYAN}  Critical packages updated:${RESET}"
            for reason in "${reboot_reasons[@]}"; do
                echo -e "    ${YELLOW}→${RESET} $reason"
            done
        fi

        echo ""
        echo -e "${DIM}  A system reboot is recommended to apply all changes.${RESET}"
    else
        echo ""
        echo -e "${GREEN}  ✓ No reboot required${RESET}"
    fi
}
