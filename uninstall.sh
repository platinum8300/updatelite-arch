#!/usr/bin/env bash
#
# updatelite uninstaller
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Installation paths
INSTALL_BIN="$HOME/.local/bin/updatelite"
INSTALL_LIB="$HOME/.local/share/updatelite"
CONFIG_DIR="$HOME/.config/updatelite"
FISH_INTEGRATION="$HOME/.config/fish/conf.d/updatelite.fish"

print_header() {
    echo -e "\n${BOLD}${RED}═══════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}   updateLITE Arch Edition uninstaller${RESET}"
    echo -e "${BOLD}${RED}═══════════════════════════════════════════════════════${RESET}\n"
}

print_success() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

# Confirm uninstall
confirm() {
    read -r -p "Are you sure you want to uninstall updatelite? [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Remove files
remove_files() {
    # Remove main script
    if [[ -f "$INSTALL_BIN" ]]; then
        rm -f "$INSTALL_BIN"
        print_success "Removed: $INSTALL_BIN"
    fi

    # Remove library
    if [[ -d "$INSTALL_LIB" ]]; then
        rm -rf "$INSTALL_LIB"
        print_success "Removed: $INSTALL_LIB"
    fi

    # Remove fish integration
    if [[ -f "$FISH_INTEGRATION" ]]; then
        rm -f "$FISH_INTEGRATION"
        print_success "Removed: $FISH_INTEGRATION"
    fi
}

# Handle config
handle_config() {
    if [[ -d "$CONFIG_DIR" ]]; then
        echo ""
        read -r -p "Remove configuration directory ($CONFIG_DIR)? [y/N] " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            print_success "Removed: $CONFIG_DIR"
        else
            print_info "Configuration preserved at: $CONFIG_DIR"
        fi
    fi
}

# Main
main() {
    print_header

    if ! confirm; then
        echo "Uninstall cancelled."
        exit 0
    fi

    echo ""
    print_info "Removing updatelite..."
    echo ""

    remove_files
    handle_config

    echo ""
    echo -e "${GREEN}${BOLD}Uninstall complete!${RESET}"
    echo ""
}

main "$@"
