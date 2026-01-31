#!/usr/bin/env bash
# reboot.sh - Reboot detection module (matches original visual style)

# Check if reboot is required based on updated critical packages
check_reboot_required() {
    local log_file="/var/log/pacman.log"

    if [[ ! -f "$log_file" ]]; then
        return 0
    fi

    # Get system boot time as Unix timestamp
    local boot_time
    boot_time=$(date -d "$(uptime -s)" +%s 2>/dev/null || echo 0)

    # Get critical packages list
    local critical_pkgs
    IFS=' ' read -ra critical_pkgs <<< "$CRITICAL_PACKAGES"

    local needs_reboot=false
    local reboot_packages=()

    # Check if any critical package was upgraded AFTER boot time
    for pkg in "${critical_pkgs[@]}"; do
        # Get the last upgrade line for this package
        local last_upgrade
        last_upgrade=$(grep "\[ALPM\] upgraded $pkg " "$log_file" | tail -1 || true)

        if [[ -n "$last_upgrade" ]]; then
            # Extract timestamp from log line: [2026-01-31T10:37:24+0100]
            local log_timestamp
            log_timestamp=$(echo "$last_upgrade" | grep -oP '\[\K[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' || true)

            if [[ -n "$log_timestamp" ]]; then
                # Convert to Unix timestamp (replace T with space for date parsing)
                local upgrade_time
                upgrade_time=$(date -d "${log_timestamp/T/ }" +%s 2>/dev/null || echo 0)

                # Only flag if upgrade happened AFTER boot
                if [[ $upgrade_time -gt $boot_time ]]; then
                    needs_reboot=true
                    reboot_packages+=("$pkg")
                fi
            fi
        fi
    done

    # Also check for kernel mismatch (running kernel vs installed kernel)
    local running_kernel
    running_kernel=$(uname -r)

    # Check for cachyos kernel first, then standard linux
    local kernel_pkg=""
    for kernel in "linux-cachyos" "linux-cachyos-bore" "linux-cachyos-lts" "linux-zen" "linux-lts" "linux"; do
        kernel_pkg=$(pacman -Q "$kernel" 2>/dev/null | awk '{print $2}' || true)
        if [[ -n "$kernel_pkg" ]]; then
            break
        fi
    done

    if [[ -n "$kernel_pkg" ]]; then
        # Extract version numbers for comparison
        # running_kernel: 6.18.8-1-cachyos-bore -> 6.18.8
        # kernel_pkg: 6.18.8-1 -> 6.18.8
        local running_ver="${running_kernel%%[-_]*}"
        local pkg_ver="${kernel_pkg%%-*}"

        if [[ "$running_ver" != "$pkg_ver" ]]; then
            needs_reboot=true
            reboot_packages+=("kernel (running: $running_ver, installed: $pkg_ver)")
        fi
    fi

    # Show reboot notice or confirmation
    if [[ "$needs_reboot" == "true" ]]; then
        echo ""
        echo -e "${BOLD}${YELLOW}╔════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${YELLOW}║            ⚠️  REBOOT RECOMMENDED ⚠️                     ║${RESET}"
        echo -e "${BOLD}${YELLOW}╚════════════════════════════════════════════════════════╝${RESET}"
        echo ""

        if [[ ${#reboot_packages[@]} -gt 0 ]]; then
            echo -e "${CYAN}  Critical packages updated:${RESET}"
            for pkg in "${reboot_packages[@]}"; do
                echo -e "    ${YELLOW}→${RESET} $pkg"
            done
        fi

        echo ""
        echo -e "${DIM}  A system reboot is recommended to apply all changes.${RESET}"
    else
        echo ""
        echo -e "${GREEN}  ✓ No reboot required${RESET}"
    fi
}
