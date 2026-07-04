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

    echo ""
    if [[ $pacman_exit -eq 0 ]]; then
        echo -e "${GREEN}  ✓ Pacman update completed${RESET}"
    else
        echo -e "${RED}  ✗ Pacman error. Continuing...${RESET}"
        echo -e "${YELLOW}    Suggestion: sudo pacman -S archlinux-keyring${RESET}"
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
