#!/usr/bin/env bash
# services.sh - Systemd service verification module (matches original visual style)
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

# Check critical services status
check_services() {
    show_section "SERVICE VERIFICATION" "${RED}" "⚙️"

    local failed_services
    failed_services=$(systemctl --failed --no-pager --no-legend 2>/dev/null)

    if [[ -n "$failed_services" ]]; then
        echo -e "${RED}  ⚠️  FAILED SERVICES DETECTED:${RESET}"
        echo ""
        while IFS= read -r line; do
            echo -e "${RED}    • ${line}${RESET}"
        done <<< "$failed_services"
        echo ""
        echo -e "${YELLOW}  Suggestion: Check with 'systemctl status <service>'${RESET}"
    else
        echo -e "${GREEN}  ✓ All services running correctly${RESET}"
    fi

    end_section
}
