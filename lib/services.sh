#!/usr/bin/env bash
# services.sh - Systemd service verification module (matches original visual style)

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
