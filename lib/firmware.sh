#!/usr/bin/env bash
#
# firmware.sh - Firmware update module
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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# True when fwupdmgr get-updates indicates there is nothing to apply.
# Exit code 2 is fwupdmgr's documented "no updates available"; the message
# match covers wordings across locales. Shared with the dry-run preview so
# both paths classify fwupdmgr output identically.
fwupd_no_updates() {
    local exit_code="$1" output="$2"
    if [[ $exit_code -eq 2 || -z "$output" ]]; then
        return 0
    fi
    grep -qiE "no upgrades|no updates|no hay|ninguna actualiz" <<< "$output"
}

# Update firmware via fwupd
update_firmware() {
    if [[ "$ENABLE_FIRMWARE" != "true" ]]; then
        return 0
    fi

    if ! has_command fwupdmgr; then
        return 0
    fi

    show_section "FIRMWARE - System Updates" "${CYAN}" "💾"

    echo -e "${CYAN}  → Refreshing firmware metadata...${RESET}"

    # Refresh metadata (suppress output, check for errors)
    fwupdmgr refresh --force >/dev/null 2>&1 || true

    echo -e "${CYAN}  → Checking for firmware updates...${RESET}"
    echo ""

    # Check for updates - capture exit code properly
    local updates
    local check_exit
    updates=$(fwupdmgr get-updates 2>&1) && check_exit=0 || check_exit=$?

    if fwupd_no_updates "$check_exit" "$updates"; then
        echo -e "${GREEN}  ✓ All firmware is up to date${RESET}"
        end_section
        return 0
    fi

    # Show available updates
    echo -e "${CYAN}  Available firmware updates:${RESET}"
    echo "$updates" | grep -E "^[A-Za-z]|Version|Versión" | head -20 | while IFS= read -r line; do
        echo "    $line"
    done
    echo ""

    # Apply updates
    echo -e "${CYAN}  → Installing firmware updates...${RESET}"
    echo ""

    local fw_exit
    fwupdmgr update -y 2>&1 && fw_exit=0 || fw_exit=$?

    echo ""
    # Only count as updated if exit code is 0 (success with updates applied)
    if [[ $fw_exit -eq 0 ]]; then
        echo -e "${GREEN}  ✓ Firmware updates applied${RESET}"
        UPDATES_FIRMWARE=1
    elif [[ $fw_exit -eq 2 ]]; then
        # Exit code 2 = nothing to do
        echo -e "${GREEN}  ✓ No firmware updates needed${RESET}"
    else
        echo -e "${YELLOW}  ! Firmware update finished (may require reboot)${RESET}"
        UPDATES_FIRMWARE=1
    fi

    end_section
}
