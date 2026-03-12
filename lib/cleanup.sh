#!/usr/bin/env bash
# cleanup.sh - System cleanup module (matches original visual style)
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

# Main cleanup function
system_cleanup() {
    show_section "SYSTEM CLEANUP" "${YELLOW}" "🧹"

    cleanup_orphans
    cleanup_cache
    cleanup_journal
    cleanup_user_caches

    # Flatpak cleanup
    if has_command flatpak; then
        clean_flatpak
    fi

    end_section
}

# Clean user tool caches (pip, uv, AUR builds, thumbnails)
cleanup_user_caches() {
    if [[ "$CLEANUP_USER_CACHES" != "true" ]]; then
        return 0
    fi

    echo -e "${YELLOW}  → Cleaning user tool caches...${RESET}"

    local total_freed_mb=0

    # pip — purge if size exceeds threshold
    if [[ "$CLEANUP_USER_CACHE_PIP" == "true" ]] && has_command pip && [[ -d "$HOME/.cache/pip" ]]; then
        local pip_size
        pip_size=$(du -sm "$HOME/.cache/pip" 2>/dev/null | awk '{print $1}' || echo 0)
        [[ "$pip_size" =~ ^[0-9]+$ ]] || pip_size=0
        if [[ $pip_size -gt $USER_CACHE_MIN_SIZE_MB ]]; then
            pip cache purge >/dev/null 2>&1 || true
            total_freed_mb=$((total_freed_mb + pip_size))
            echo -e "${GREEN}    ✓ pip: ${pip_size} MB freed${RESET}"
        else
            echo -e "${CYAN}    · pip: ${pip_size} MB (below ${USER_CACHE_MIN_SIZE_MB} MB threshold)${RESET}"
        fi
    fi

    # uv — prune (smart: only removes unused entries) if size exceeds threshold
    if [[ "$CLEANUP_USER_CACHE_UV" == "true" ]] && has_command uv && [[ -d "$HOME/.cache/uv" ]]; then
        local uv_size uv_after freed
        uv_size=$(du -sm "$HOME/.cache/uv" 2>/dev/null | awk '{print $1}' || echo 0)
        [[ "$uv_size" =~ ^[0-9]+$ ]] || uv_size=0
        if [[ $uv_size -gt $USER_CACHE_MIN_SIZE_MB ]]; then
            uv cache prune --quiet 2>/dev/null || true
            uv_after=$(du -sm "$HOME/.cache/uv" 2>/dev/null | awk '{print $1}' || echo 0)
            [[ "$uv_after" =~ ^[0-9]+$ ]] || uv_after=0
            freed=$((uv_size - uv_after))
            [[ $freed -lt 0 ]] && freed=0
            total_freed_mb=$((total_freed_mb + freed))
            echo -e "${GREEN}    ✓ uv: ${freed} MB freed${RESET}"
        else
            echo -e "${CYAN}    · uv: ${uv_size} MB (below ${USER_CACHE_MIN_SIZE_MB} MB threshold)${RESET}"
        fi
    fi

    # AUR build cache — remove clone dirs older than MAX_DAYS
    if [[ "$CLEANUP_USER_CACHE_AUR_BUILDS" == "true" ]]; then
        local aur_freed=0
        for cache_dir in "$HOME/.cache/paru/clone" "$HOME/.cache/yay"; do
            if [[ -d "$cache_dir" ]]; then
                local before after freed
                before=$(du -sm "$cache_dir" 2>/dev/null | awk '{print $1}' || echo 0)
                [[ "$before" =~ ^[0-9]+$ ]] || before=0
                find "$cache_dir" -mindepth 1 -maxdepth 1 -type d -atime "+${USER_CACHE_MAX_DAYS}" -exec rm -rf {} + 2>/dev/null || true
                after=$(du -sm "$cache_dir" 2>/dev/null | awk '{print $1}' || echo 0)
                [[ "$after" =~ ^[0-9]+$ ]] || after=0
                freed=$((before - after))
                [[ $freed -lt 0 ]] && freed=0
                aur_freed=$((aur_freed + freed))
            fi
        done
        total_freed_mb=$((total_freed_mb + aur_freed))
        if [[ $aur_freed -gt 0 ]]; then
            echo -e "${GREEN}    ✓ AUR builds: ${aur_freed} MB freed (entries >${USER_CACHE_MAX_DAYS} days)${RESET}"
        else
            echo -e "${CYAN}    · AUR builds: up to date${RESET}"
        fi
    fi

    # Thumbnails — remove files older than MAX_DAYS
    if [[ "$CLEANUP_USER_CACHE_THUMBNAILS" == "true" ]] && [[ -d "$HOME/.cache/thumbnails" ]]; then
        local before after freed
        before=$(du -sm "$HOME/.cache/thumbnails" 2>/dev/null | awk '{print $1}' || echo 0)
        [[ "$before" =~ ^[0-9]+$ ]] || before=0
        find "$HOME/.cache/thumbnails" -type f -atime "+${USER_CACHE_MAX_DAYS}" -delete 2>/dev/null || true
        after=$(du -sm "$HOME/.cache/thumbnails" 2>/dev/null | awk '{print $1}' || echo 0)
        [[ "$after" =~ ^[0-9]+$ ]] || after=0
        freed=$((before - after))
        [[ $freed -lt 0 ]] && freed=0
        total_freed_mb=$((total_freed_mb + freed))
        if [[ $freed -gt 0 ]]; then
            echo -e "${GREEN}    ✓ Thumbnails: ${freed} MB freed (entries >${USER_CACHE_MAX_DAYS} days)${RESET}"
        else
            echo -e "${CYAN}    · Thumbnails: up to date${RESET}"
        fi
    fi

    USER_CACHES_FREED="${total_freed_mb} MB"
    echo ""
}

# Remove orphan packages
cleanup_orphans() {
    if [[ "$CLEANUP_ORPHANS" != "true" ]]; then
        return 0
    fi

    echo -e "${YELLOW}  → Searching for orphan packages...${RESET}"

    local orphans
    orphans=$(pacman -Qtdq 2>/dev/null || true)

    if [[ -z "$orphans" ]]; then
        echo -e "${GREEN}    ✓ No orphan packages${RESET}"
        echo ""
        return 0
    fi

    local orphan_count
    orphan_count=$(echo "$orphans" | wc -l)

    echo -e "${RED}    Found: ${orphan_count} orphans${RESET}"
    while IFS= read -r pkg; do
        echo "      • $pkg"
    done <<< "$orphans"
    echo ""

    echo -e "${YELLOW}    → Removing orphans...${RESET}"
    if sudo pacman -Rns $orphans --noconfirm 2>&1 | grep -v "^::" || true; then
        ORPHANS_REMOVED=$orphan_count
        echo -e "${GREEN}    ✓ Orphans removed${RESET}"
    else
        echo -e "${RED}    ✗ Error removing orphans${RESET}"
    fi
    echo ""
}

# Clean package cache
cleanup_cache() {
    if [[ "$CLEANUP_CACHE" != "true" ]]; then
        return 0
    fi

    echo -e "${YELLOW}  → Cleaning pacman cache...${RESET}"

    # Get cache size before (use sudo to avoid permission errors, || true to handle any failure)
    local cache_before
    cache_before=$(sudo du -sb /var/cache/pacman/pkg/ 2>/dev/null | awk '{print $1}' || true)
    cache_before=${cache_before:-0}
    [[ "$cache_before" =~ ^[0-9]+$ ]] || cache_before=0

    # Remove partial and signature files
    sudo find /var/cache/pacman/pkg/ -name "*.part" -type f -delete 2>/dev/null || true
    sudo find /var/cache/pacman/pkg/ -name "*.sig" -type f -delete 2>/dev/null || true

    # Clean with pacman
    yes | sudo pacman -Sc >/dev/null 2>&1 || true

    # Clean paru cache if available
    if has_command paru; then
        yes | paru -Sc >/dev/null 2>&1 || true
    fi

    # Get cache size after
    local cache_after
    cache_after=$(sudo du -sb /var/cache/pacman/pkg/ 2>/dev/null | awk '{print $1}' || true)
    cache_after=${cache_after:-0}
    [[ "$cache_after" =~ ^[0-9]+$ ]] || cache_after=0

    local cache_diff=$((cache_before - cache_after))
    [[ $cache_diff -lt 0 ]] && cache_diff=0
    CACHE_FREED="$((cache_diff / 1048576)) MB"

    echo -e "${GREEN}    ✓ Cache cleaned: ${CACHE_FREED} freed${RESET}"
    echo ""
}

# Clean systemd journal
cleanup_journal() {
    if [[ "$CLEANUP_JOURNAL" != "true" ]]; then
        return 0
    fi

    echo -e "${YELLOW}  → Cleaning journal logs (>${JOURNAL_VACUUM_DAYS} days)...${RESET}"

    # Get journal size before
    local journal_before
    journal_before=$(sudo du -sb /var/log/journal/ 2>/dev/null | awk '{print $1}' || true)
    journal_before=${journal_before:-0}
    [[ "$journal_before" =~ ^[0-9]+$ ]] || journal_before=0

    sudo journalctl --vacuum-time="${JOURNAL_VACUUM_DAYS}d" >/dev/null 2>&1 || true

    # Get journal size after
    local journal_after
    journal_after=$(sudo du -sb /var/log/journal/ 2>/dev/null | awk '{print $1}' || true)
    journal_after=${journal_after:-0}
    [[ "$journal_after" =~ ^[0-9]+$ ]] || journal_after=0

    local journal_diff=$((journal_before - journal_after))
    [[ $journal_diff -lt 0 ]] && journal_diff=0
    JOURNAL_FREED="$((journal_diff / 1048576)) MB"

    echo -e "${GREEN}    ✓ Journal cleaned: ${JOURNAL_FREED} freed${RESET}"
    echo ""
}
