#!/usr/bin/env bash
# dryrun.sh - Dry-run preview module (read-only, applies no changes)
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

# Entry point for --dry-run: show what a real run would update or clean,
# without touching the system. Only read-only commands are used, so no
# sudo authentication is required.
run_dry_run() {
    echo -e "  ${BOLD}${YELLOW}DRY RUN${RESET}  ${DIM}Preview only - nothing will be modified${RESET}"

    dry_run_pacman
    dry_run_aur
    dry_run_flatpak
    dry_run_docker
    dry_run_firmware
    if [[ "${NO_CLEANUP:-false}" != "true" ]]; then
        dry_run_cleanup
    fi

    echo -e "${DIM}───────────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -e "  ${BOLD}${YELLOW}✓ DRY RUN COMPLETED${RESET}  ${DIM}No changes were made${RESET}"
    echo ""
    echo -e "${DIM}───────────────────────────────────────────────────────────${RESET}"
    echo ""
}

# Preview pending repo updates
dry_run_pacman() {
    if [[ "$ENABLE_PACMAN" != "true" ]]; then
        return 0
    fi

    show_section "PACMAN - System Packages" "${BLUE}" "📦"

    local updates=""
    if has_command checkupdates; then
        # checkupdates (pacman-contrib) syncs into a temp copy of the
        # database: the preview is fresh and the real db is untouched
        updates=$(checkupdates 2>/dev/null || true)
    else
        echo -e "${DIM}  · checkupdates not found (pacman-contrib); using last synced database${RESET}"
        updates=$(pacman -Qu 2>/dev/null || true)
    fi

    if [[ -n "$updates" ]]; then
        local count line pkg ignore_packages
        # Same held-back detection the real run applies via --ignore
        ignore_packages=$(detect_broken_deps)
        count=$(wc -l <<< "$updates")
        echo -e "${CYAN}  ${count} package(s) would be updated:${RESET}"
        while IFS= read -r line; do
            pkg="${line%% *}"
            if [[ -n "$ignore_packages" && " $ignore_packages " == *" $pkg "* ]]; then
                echo -e "    ${DIM}· $line (skipped: dependency mismatch)${RESET}"
            else
                echo "    • $line"
            fi
        done <<< "$updates"
    else
        echo -e "${GREEN}  ✓ System packages are up to date${RESET}"
    fi

    end_section
}

# Preview pending AUR updates
dry_run_aur() {
    if [[ "$ENABLE_AUR" != "true" ]]; then
        return 0
    fi

    local helper
    helper=$(detect_aur_helper)
    if [[ "$helper" == "none" ]]; then
        return 0
    fi

    show_section "AUR - Arch User Repository ($helper)" "${MAGENTA}" "📦"

    local pending=""
    if [[ "$(aur_helper_kind "$helper")" == "shelly" ]]; then
        pending=$(shelly_list_pending "$helper")
    else
        pending=$("$helper" -Qua 2>/dev/null || true)
    fi

    if [[ -n "$pending" ]]; then
        local count line pkg
        count=$(wc -l <<< "$pending")
        echo -e "${CYAN}  ${count} AUR package(s) would be updated:${RESET}"
        while IFS= read -r line; do
            pkg="${line%% *}"
            if aur_should_skip "$pkg"; then
                echo -e "    ${DIM}· $line (skipped)${RESET}"
            else
                echo "    • $line"
            fi
        done <<< "$pending"
    else
        echo -e "${GREEN}  ✓ All AUR packages are up to date${RESET}"
    fi

    end_section
}

# Preview pending Flatpak updates
dry_run_flatpak() {
    if [[ "$ENABLE_FLATPAK" != "true" ]] || ! has_command flatpak; then
        return 0
    fi

    show_section "FLATPAK - Sandboxed Applications" "${CYAN}" "📦"

    local pending
    pending=$(flatpak remote-ls --updates 2>/dev/null || true)

    if [[ -n "$pending" ]]; then
        local count
        count=$(wc -l <<< "$pending")
        echo -e "${CYAN}  ${count} application(s) would be updated:${RESET}"
        while IFS= read -r line; do
            echo "    • $line"
        done <<< "$pending"
    else
        echo -e "${GREEN}  ✓ All Flatpak apps are up to date${RESET}"
    fi

    end_section
}

# Preview Docker container update
dry_run_docker() {
    if [[ "$ENABLE_DOCKER" != "true" ]] || ! has_command docker; then
        return 0
    fi

    show_section "DOCKER - Containers" "${BLUE}" "🐋"

    local running
    running=$(docker ps -q 2>/dev/null | wc -l)
    if [[ $running -gt 0 ]]; then
        echo -e "${CYAN}  Watchtower would check ${running} running container(s)${RESET}"
    else
        echo -e "${DIM}  · No active containers${RESET}"
    fi

    end_section
}

# Preview pending firmware updates
dry_run_firmware() {
    if [[ "$ENABLE_FIRMWARE" != "true" ]] || ! has_command fwupdmgr; then
        return 0
    fi

    show_section "FIRMWARE - System Updates" "${CYAN}" "💾"

    # get-updates without a forced refresh: read-only against cached metadata
    local updates check_exit=0
    updates=$(fwupdmgr get-updates 2>&1) || check_exit=$?

    if fwupd_no_updates "$check_exit" "$updates"; then
        echo -e "${GREEN}  ✓ All firmware is up to date${RESET}"
    else
        echo -e "${CYAN}  Firmware updates would be applied:${RESET}"
        grep -E "^[A-Za-z]|Version|Versi" <<< "$updates" | head -20 | while IFS= read -r line; do
            echo "    $line"
        done
    fi

    end_section
}

# Preview what the cleanup phase would remove
dry_run_cleanup() {
    show_section "SYSTEM CLEANUP" "${YELLOW}" "🧹"

    if [[ "$CLEANUP_ORPHANS" == "true" ]]; then
        local orphans
        orphans=$(pacman -Qtdq 2>/dev/null || true)
        if [[ -n "$orphans" ]]; then
            local count
            count=$(wc -l <<< "$orphans")
            echo -e "${YELLOW}  → ${count} orphan package(s) would be removed:${RESET}"
            while IFS= read -r pkg; do
                echo "    • $pkg"
            done <<< "$orphans"
        else
            echo -e "${GREEN}  ✓ No orphan packages${RESET}"
        fi
    fi

    if [[ "$CLEANUP_CACHE" == "true" ]]; then
        local cache_size
        cache_size=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | awk '{print $1}' || true)
        echo -e "${YELLOW}  → Pacman cache would be cleaned ${DIM}(current: ${cache_size:-unknown})${RESET}"
    fi

    if [[ "$CLEANUP_JOURNAL" == "true" ]]; then
        local journal_usage
        journal_usage=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.,]+[KMGTPE]?i?B?' | head -1 || true)
        echo -e "${YELLOW}  → Journal entries older than ${JOURNAL_VACUUM_DAYS} days would be removed ${DIM}(current: ${journal_usage:-unknown})${RESET}"
    fi

    if [[ "$CLEANUP_USER_CACHES" == "true" ]]; then
        # Mirrors cleanup_user_caches: same per-cache flags and thresholds
        local tool size_mb flag_var
        for tool in pip uv; do
            flag_var="CLEANUP_USER_CACHE_${tool^^}"
            [[ "${!flag_var}" == "true" ]] || continue
            has_command "$tool" || continue
            [[ -d "$HOME/.cache/$tool" ]] || continue
            size_mb=$(du -sm "$HOME/.cache/$tool" 2>/dev/null | awk '{print $1}' || echo 0)
            [[ "$size_mb" =~ ^[0-9]+$ ]] || size_mb=0
            if [[ $size_mb -gt $USER_CACHE_MIN_SIZE_MB ]]; then
                echo -e "${YELLOW}  → ~/.cache/${tool} would be purged ${DIM}(${size_mb} MB)${RESET}"
            else
                echo -e "${DIM}  · ~/.cache/${tool} kept (${size_mb} MB, below ${USER_CACHE_MIN_SIZE_MB} MB threshold)${RESET}"
            fi
        done

        local dir
        if [[ "$CLEANUP_USER_CACHE_AUR_BUILDS" == "true" ]]; then
            for dir in "$HOME/.cache/paru/clone" "$HOME/.cache/yay"; do
                [[ -d "$dir" ]] || continue
                echo -e "${YELLOW}  → ${dir/#$HOME/\~}: entries older than ${USER_CACHE_MAX_DAYS} days would be removed${RESET}"
            done
        fi
        if [[ "$CLEANUP_USER_CACHE_THUMBNAILS" == "true" && -d "$HOME/.cache/thumbnails" ]]; then
            echo -e "${YELLOW}  → ~/.cache/thumbnails: entries older than ${USER_CACHE_MAX_DAYS} days would be removed${RESET}"
        fi
    fi

    end_section
}
