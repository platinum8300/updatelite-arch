#!/usr/bin/env bash
# colors.sh - Color definitions and text styling

# Check if colors are enabled and terminal supports them
if [[ "${ENABLE_COLORS:-true}" == "true" ]] && [[ -t 1 ]]; then
    # Reset
    RESET='\033[0m'

    # Regular colors
    BLACK='\033[0;30m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[0;37m'

    # Bold colors
    BOLD='\033[1m'
    BOLD_RED='\033[1;31m'
    BOLD_GREEN='\033[1;32m'
    BOLD_YELLOW='\033[1;33m'
    BOLD_BLUE='\033[1;34m'
    BOLD_MAGENTA='\033[1;35m'
    BOLD_CYAN='\033[1;36m'
    BOLD_WHITE='\033[1;37m'

    # Dim (bright black)
    DIM='\033[90m'
else
    RESET=''
    BLACK=''
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''
    BOLD=''
    BOLD_RED=''
    BOLD_GREEN=''
    BOLD_YELLOW=''
    BOLD_BLUE=''
    BOLD_MAGENTA=''
    BOLD_CYAN=''
    BOLD_WHITE=''
    DIM=''
fi
