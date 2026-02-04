#!/usr/bin/env bash
# utils.sh - Common utility functions
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

# Script version
VERSION="1.0.0"

# Tracking variables
declare -g UPDATES_PACMAN=0
declare -g UPDATES_PACMAN_INSTALLED=0
declare -g UPDATES_AUR=0
declare -g UPDATES_AUR_FAILED=0
declare -g UPDATES_FLATPAK=0
declare -g UPDATES_DOCKER=0
declare -g ORPHANS_REMOVED=0
declare -g CACHE_FREED=""
declare -g JOURNAL_FREED=""
declare -g START_TIME=0
declare -g LOG_LINE_START=0

# Package lists for summary
declare -ga PACMAN_PACKAGES=()
declare -ga AUR_PACKAGES=()
declare -ga FLATPAK_PACKAGES=()

# Initialize tracking
init_tracking() {
    UPDATES_PACMAN=0
    UPDATES_PACMAN_INSTALLED=0
    UPDATES_AUR=0
    UPDATES_AUR_FAILED=0
    UPDATES_FLATPAK=0
    UPDATES_DOCKER=0
    ORPHANS_REMOVED=0
    CACHE_FREED=""
    JOURNAL_FREED=""
    START_TIME=$(date +%s)
    PACMAN_PACKAGES=()
    AUR_PACKAGES=()
    FLATPAK_PACKAGES=()

    # Save initial pacman log line count
    if [[ -f /var/log/pacman.log ]]; then
        LOG_LINE_START=$(wc -l < /var/log/pacman.log)
    else
        LOG_LINE_START=0
    fi
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}ERROR: Do not run this script as root. It will use sudo when needed.${RESET}"
        exit 1
    fi
}

# Check required dependencies
check_deps() {
    local missing=()

    command -v pacman &>/dev/null || missing+=("pacman")
    command -v sudo &>/dev/null || missing+=("sudo")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}ERROR: Missing required dependencies: ${missing[*]}${RESET}"
        exit 1
    fi

    # Check for gum (optional but recommended)
    if ! command -v gum &>/dev/null; then
        echo -e "${YELLOW}  ⚠️  gum not found. Install for better experience: sudo pacman -S gum${RESET}"
    fi
}

# Check if a command exists
has_command() {
    command -v "$1" &>/dev/null
}

# Check if a systemd service is active
is_service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

# Draw section header (matches original style)
show_section() {
    local title="$1"
    local color="$2"
    local icon="$3"

    echo ""
    echo -e "${BOLD}${color}${icon} ${title}${RESET}"
    echo -e "${DIM}─────────────────────────────────────────────${RESET}"
}

# End section (just adds spacing)
end_section() {
    echo ""
}

# Get elapsed time
get_elapsed_time() {
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    echo "${minutes} min ${seconds} sec"
}

# Progress bar (matches original style)
progress_bar() {
    local current=$1
    local total=$2
    local width=20

    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done

    echo "$bar $percent%"
}

# Log message if logging is enabled
log_message() {
    if [[ "$ENABLE_LOGGING" != "true" ]]; then
        return
    fi

    local level="${1:-INFO}"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p "$LOG_DIR"
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/updatelite.log"
}
