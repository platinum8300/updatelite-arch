#!/usr/bin/env bash
# flatpak.sh - Flatpak update module (matches original visual style)

# Update Flatpak applications
update_flatpak() {
    if [[ "$ENABLE_FLATPAK" != "true" ]]; then
        return 0
    fi

    if ! has_command flatpak; then
        return 0
    fi

    show_section "FLATPAK - Sandboxed Applications" "${CYAN}" "📦"

    echo -e "${CYAN}  → Checking Flatpak updates...${RESET}"
    echo ""

    # Check for pending apps (|| true to handle no updates)
    local flatpak_pending
    flatpak_pending=$(flatpak remote-ls --updates 2>/dev/null || true)

    if [[ -n "$flatpak_pending" ]]; then
        echo -e "${CYAN}  Applications with updates available:${RESET}"
        while IFS= read -r line; do
            echo "    • $line"
            FLATPAK_PACKAGES+=("$line")
        done <<< "$(echo "$flatpak_pending" | head -10)"
        echo ""

        # Update showing all warnings
        local flatpak_exit=0
        flatpak update -y || flatpak_exit=$?

        # Count flatpak updates
        if [[ $flatpak_exit -eq 0 && ${#FLATPAK_PACKAGES[@]} -gt 0 ]]; then
            UPDATES_FLATPAK=${#FLATPAK_PACKAGES[@]}
        fi

        echo ""
        if [[ $flatpak_exit -eq 0 ]]; then
            echo -e "${GREEN}  ✓ Flatpak update completed${RESET}"
        else
            echo -e "${YELLOW}  ⚠️  Some Flatpak updates may have failed${RESET}"
        fi
    else
        echo -e "${GREEN}  ✓ All Flatpak apps are up to date${RESET}"
    fi

    end_section
}

# Clean unused Flatpak runtimes
clean_flatpak() {
    if ! has_command flatpak; then
        return 0
    fi

    echo -e "${YELLOW}  → Cleaning unused Flatpak runtimes...${RESET}"
    # Suppress all output (pinned runtime info, etc.)
    flatpak uninstall --unused -y >/dev/null 2>&1 || true
    echo -e "${GREEN}    ✓ Flatpak cleaned${RESET}"
}
