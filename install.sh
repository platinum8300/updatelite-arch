#!/usr/bin/env bash
#
# updatelite installer
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
INSTALL_BIN="$HOME/.local/bin"
INSTALL_LIB="$HOME/.local/share/updatelite/lib"
CONFIG_DIR="$HOME/.config/updatelite"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header() {
    echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}     updateLITE Arch Edition installer${RESET}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${RESET}\n"
}

print_success() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${RESET} $1"
}

# Check requirements
check_requirements() {
    print_info "Checking requirements..."

    # Check bash version
    if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
        print_error "Bash 4.0+ required (found: $BASH_VERSION)"
        exit 1
    fi
    print_success "Bash version: $BASH_VERSION"

    # Check if Arch-based
    if [[ ! -f /etc/arch-release ]] && [[ ! -f /etc/cachyos-release ]]; then
        print_error "This script requires Arch Linux or CachyOS"
        exit 1
    fi
    print_success "Distribution: $(cat /etc/os-release | grep '^NAME=' | cut -d= -f2 | tr -d '\"')"

    # Check pacman
    if ! command -v pacman &>/dev/null; then
        print_error "pacman not found"
        exit 1
    fi
    print_success "pacman found"

    # Check sudo
    if ! command -v sudo &>/dev/null; then
        print_error "sudo not found"
        exit 1
    fi
    print_success "sudo found"
}

# Install dependencies
install_deps() {
    print_info "Checking optional dependencies..."

    local to_install=()

    if ! command -v paccache &>/dev/null; then
        to_install+=("pacman-contrib")
    fi

    if [[ ${#to_install[@]} -gt 0 ]]; then
        print_info "Installing: ${to_install[*]}"
        sudo pacman -S --noconfirm "${to_install[@]}"
        print_success "Dependencies installed"
    else
        print_success "All dependencies satisfied"
    fi
}

# Install files
install_files() {
    print_info "Installing updatelite..."

    # Create directories
    mkdir -p "$INSTALL_BIN"
    mkdir -p "$INSTALL_LIB"
    mkdir -p "$CONFIG_DIR"

    # Copy main script
    cp "$SCRIPT_DIR/updatelite" "$INSTALL_BIN/updatelite"
    chmod +x "$INSTALL_BIN/updatelite"
    print_success "Installed: $INSTALL_BIN/updatelite"

    # Copy library files
    cp "$SCRIPT_DIR/lib/"*.sh "$INSTALL_LIB/"
    print_success "Installed: $INSTALL_LIB/"

    # Copy example config if no config exists
    if [[ ! -f "$CONFIG_DIR/config" ]]; then
        if [[ -f "$SCRIPT_DIR/config/updatelite.conf.example" ]]; then
            cp "$SCRIPT_DIR/config/updatelite.conf.example" "$CONFIG_DIR/config"
            print_success "Created: $CONFIG_DIR/config"
        fi
    else
        print_warning "Config exists, not overwriting: $CONFIG_DIR/config"
    fi
}

# Detect current shell
detect_shell() {
    local shell_name
    shell_name=$(basename "$SHELL")
    echo "$shell_name"
}

# Setup shell integration
setup_shell() {
    local current_shell
    current_shell=$(detect_shell)

    print_info "Detected shell: $current_shell"

    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$INSTALL_BIN:"* ]]; then
        print_warning "$INSTALL_BIN is not in PATH"

        case "$current_shell" in
            fish)
                print_info "Add to ~/.config/fish/config.fish:"
                echo -e "  ${CYAN}fish_add_path $INSTALL_BIN${RESET}"
                ;;
            zsh)
                print_info "Add to ~/.zshrc:"
                echo -e "  ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
                ;;
            bash)
                print_info "Add to ~/.bashrc:"
                echo -e "  ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
                ;;
        esac
    else
        print_success "$INSTALL_BIN is in PATH"
    fi

    # Copy shell integration if available
    local integration_dir="$SCRIPT_DIR/shell-integration"

    case "$current_shell" in
        fish)
            if [[ -f "$integration_dir/updatelite.fish" ]]; then
                local fish_conf="$HOME/.config/fish/conf.d"
                mkdir -p "$fish_conf"
                cp "$integration_dir/updatelite.fish" "$fish_conf/"
                print_success "Fish integration installed"
            fi
            ;;
        zsh)
            if [[ -f "$integration_dir/updatelite.zsh" ]]; then
                print_info "To enable zsh integration, add to ~/.zshrc:"
                echo -e "  ${CYAN}source $integration_dir/updatelite.zsh${RESET}"
            fi
            ;;
        bash)
            if [[ -f "$integration_dir/updatelite.bash" ]]; then
                print_info "To enable bash integration, add to ~/.bashrc:"
                echo -e "  ${CYAN}source $integration_dir/updatelite.bash${RESET}"
            fi
            ;;
    esac
}

# Verify installation
verify_install() {
    print_info "Verifying installation..."

    if [[ -x "$INSTALL_BIN/updatelite" ]]; then
        print_success "updatelite is installed and executable"

        # Try to run version check
        if "$INSTALL_BIN/updatelite" --version &>/dev/null; then
            local version
            version=$("$INSTALL_BIN/updatelite" --version | head -1)
            print_success "Version: $version"
        fi
    else
        print_error "Installation verification failed"
        exit 1
    fi
}

# Main
main() {
    print_header

    check_requirements
    echo ""

    install_deps
    echo ""

    install_files
    echo ""

    setup_shell
    echo ""

    verify_install
    echo ""

    echo -e "${GREEN}${BOLD}Installation complete!${RESET}"
    echo ""
    echo "Usage:"
    echo -e "  ${CYAN}updatelite${RESET}           Run system maintenance"
    echo -e "  ${CYAN}updatelite --help${RESET}    Show all options"
    echo ""
}

main "$@"
