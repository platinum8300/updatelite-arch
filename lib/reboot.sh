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

# Reboot detection: multiple independent signals combined with OR.
# Any one signal firing is enough — relying on a single mechanism (curated
# package list, hook output wording, etc.) produces recurring false negatives.
check_reboot_required() {
    local needs_reboot=false
    local reboot_reasons=()

    local boot_epoch
    boot_epoch=$(date -d "$(uptime -s)" +%s 2>/dev/null || echo 0)

    # Signal 1 — pacman hook flagged reboot during this session.
    # Honors the distro's own reboot policy (e.g. CachyOS needs-reboot hook).
    # Strip ANSI color codes before matching (pacman --color always embeds them).
    if [[ -n "${PACMAN_OUTPUT_LOG:-}" && -f "$PACMAN_OUTPUT_LOG" ]]; then
        # Process substitution instead of a pipe: a pipefail SIGPIPE from sed
        # must not mask a match when grep -q exits early.
        if grep -qiE "reboot[^\\n]{0,40}(recommended|required|needed)" \
            < <(sed 's/\x1b\[[0-9;]*m//g' "$PACMAN_OUTPUT_LOG"); then
            needs_reboot=true
            reboot_reasons+=("pacman hook flagged reboot")
        fi
    fi

    local running_kernel
    running_kernel=$(uname -r)

    # Signal 2 — running kernel's modules directory is gone.
    # Fires whenever the running kernel package was upgraded to another version.
    if [[ ! -d "/usr/lib/modules/$running_kernel" ]]; then
        needs_reboot=true
        reboot_reasons+=("running kernel modules removed ($running_kernel)")
    fi

    # Signal 3 — init or libc binary replaced after boot.
    # PID 1 and libc are still mapped from the pre-update files in RAM.
    # Use ctime (%Z): pacman preserves the archive's mtime, but ctime is updated
    # when the file is replaced on disk, so it tracks actual install time.
    if (( boot_epoch > 0 )); then
        local lib ctime
        for lib in /usr/lib/systemd/systemd /usr/lib/libc.so.6 /usr/lib64/libc.so.6; do
            [[ -r "$lib" ]] || continue
            ctime=$(stat -c %Z "$lib" 2>/dev/null || echo 0)
            if (( ctime > boot_epoch )); then
                needs_reboot=true
                reboot_reasons+=("$(basename "$lib") replaced after boot")
                break
            fi
        done
    fi

    # Signal 4 — installed kernel pkg version differs from running uname -r.
    # uname -r is like "6.19.9-2-cachyos-bore", pacman gives "6.19.9-2".
    local kernel_pkg=""
    for kernel in "linux-cachyos" "linux-cachyos-bore" "linux-cachyos-lts" "linux-zen" "linux-lts" "linux"; do
        kernel_pkg=$(pacman -Q "$kernel" 2>/dev/null | awk '{print $2}' || true)
        if [[ -n "$kernel_pkg" ]]; then
            break
        fi
    done
    if [[ -n "$kernel_pkg" && "$running_kernel" != "${kernel_pkg}-"* ]]; then
        # Skip if the modules-dir signal already reported the same condition
        if [[ -d "/usr/lib/modules/$running_kernel" ]]; then
            needs_reboot=true
            reboot_reasons+=("kernel pkg $kernel_pkg differs from running $running_kernel")
        fi
    fi

    # Signal 5 (informational fallback) — pacman.log shows a critical package
    # was upgraded after boot. Only triggers if the package list is reachable
    # and config defines CRITICAL_PACKAGES. Provides redundancy when the hook
    # output capture is missing (e.g. updatelite invoked in a custom flow).
    if [[ "$needs_reboot" != "true" && -n "${CRITICAL_PACKAGES:-}" && -f /var/log/pacman.log && $boot_epoch -gt 0 ]]; then
        local pkg log_line log_ts upgrade_ts
        local -a critical_list
        read -ra critical_list <<< "$CRITICAL_PACKAGES"
        for pkg in "${critical_list[@]}"; do
            log_line=$(grep "\[ALPM\] upgraded $pkg " /var/log/pacman.log | tail -1 || true)
            [[ -n "$log_line" ]] || continue
            log_ts=$(echo "$log_line" | grep -oP '\[\K[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' || true)
            [[ -n "$log_ts" ]] || continue
            upgrade_ts=$(date -d "${log_ts/T/ }" +%s 2>/dev/null || echo 0)
            if (( upgrade_ts > boot_epoch )); then
                needs_reboot=true
                reboot_reasons+=("$pkg upgraded after boot (pacman.log)")
                break
            fi
        done
    fi

    # Cleanup temp file
    [[ -n "${PACMAN_OUTPUT_LOG:-}" && -f "$PACMAN_OUTPUT_LOG" ]] && rm -f "$PACMAN_OUTPUT_LOG"

    # Show reboot notice or confirmation
    if [[ "$needs_reboot" == "true" ]]; then
        echo ""
        echo -e "${DIM}───────────────────────────────────────────────────────────${RESET}"
        echo ""
        echo -e "  ${BOLD}${YELLOW}! REBOOT RECOMMENDED${RESET}"
        echo ""

        if [[ ${#reboot_reasons[@]} -gt 0 ]]; then
            echo -e "${CYAN}  Detected signals:${RESET}"
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
