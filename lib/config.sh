#!/usr/bin/env bash
# config.sh - Configuration loading and defaults
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

# Default configuration values
declare -g ENABLE_PACMAN="${ENABLE_PACMAN:-true}"
declare -g ENABLE_AUR="${ENABLE_AUR:-true}"
declare -g ENABLE_FLATPAK="${ENABLE_FLATPAK:-true}"
declare -g ENABLE_DOCKER="${ENABLE_DOCKER:-false}"

declare -g AUR_HELPER="${AUR_HELPER:-auto}"
declare -g AUR_SKIP_PACKAGES="${AUR_SKIP_PACKAGES:-}"

declare -g CLEANUP_ORPHANS="${CLEANUP_ORPHANS:-true}"
declare -g CLEANUP_CACHE="${CLEANUP_CACHE:-true}"
declare -g CLEANUP_JOURNAL="${CLEANUP_JOURNAL:-true}"
declare -g JOURNAL_VACUUM_DAYS="${JOURNAL_VACUUM_DAYS:-7}"

declare -g ENABLE_LOGGING="${ENABLE_LOGGING:-false}"
declare -g LOG_DIR="${LOG_DIR:-$HOME/logs/updatelite}"

declare -g ENABLE_PHRASES="${ENABLE_PHRASES:-true}"
declare -g ENABLE_COLORS="${ENABLE_COLORS:-true}"

declare -g CRITICAL_PACKAGES="${CRITICAL_PACKAGES:-linux systemd glibc gcc-libs linux-firmware mesa}"

# Config file location
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/updatelite"
CONFIG_FILE="$CONFIG_DIR/config"

# Load configuration from file (safe parsing, no eval/source)
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 0
    fi

    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # Remove quotes from value
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"

        # Only set known configuration keys
        case "$key" in
            ENABLE_PACMAN|ENABLE_AUR|ENABLE_FLATPAK|ENABLE_DOCKER|\
            AUR_HELPER|AUR_SKIP_PACKAGES|\
            CLEANUP_ORPHANS|CLEANUP_CACHE|CLEANUP_JOURNAL|JOURNAL_VACUUM_DAYS|\
            ENABLE_LOGGING|LOG_DIR|\
            ENABLE_PHRASES|ENABLE_COLORS|\
            CRITICAL_PACKAGES)
                declare -g "$key=$value"
                ;;
        esac
    done < "$CONFIG_FILE"
}

# Create default config if it doesn't exist
create_default_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        return 0
    fi

    mkdir -p "$CONFIG_DIR"

    cat > "$CONFIG_FILE" << 'CONFIGEOF'
# updateLITE Arch Edition - configuration
# Location: ~/.config/updatelite/config

# Modules (true/false)
ENABLE_PACMAN=true
ENABLE_AUR=true
ENABLE_FLATPAK=true
ENABLE_DOCKER=false

# AUR helper (paru/yay/auto)
AUR_HELPER=auto

# Packages to skip during AUR update (space-separated)
AUR_SKIP_PACKAGES=

# Cleanup options
CLEANUP_ORPHANS=true
CLEANUP_CACHE=true
CLEANUP_JOURNAL=true
JOURNAL_VACUUM_DAYS=7

# Logging
ENABLE_LOGGING=false
LOG_DIR=$HOME/logs/updatelite

# Interface
ENABLE_PHRASES=true
ENABLE_COLORS=true

# Critical packages that require reboot (space-separated)
CRITICAL_PACKAGES=linux systemd glibc gcc-libs linux-firmware mesa
CONFIGEOF

    echo "Created default config at $CONFIG_FILE"
}

# Detect distribution
detect_distro() {
    if [[ -f /etc/cachyos-release ]]; then
        echo "cachyos"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# Detect kernel variant
detect_kernel() {
    local kernel
    kernel=$(uname -r)
    if [[ "$kernel" == *cachyos* ]]; then
        echo "${kernel##*-}"
    else
        echo "generic"
    fi
}

# Detect AUR helper
detect_aur_helper() {
    if [[ "$AUR_HELPER" != "auto" ]]; then
        if command -v "$AUR_HELPER" &>/dev/null; then
            echo "$AUR_HELPER"
            return
        fi
    fi

    if command -v paru &>/dev/null; then
        echo "paru"
    elif command -v yay &>/dev/null; then
        echo "yay"
    else
        echo "none"
    fi
}
