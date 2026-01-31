# Changelog - updateLITE Arch Edition

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-XX

### Initial Public Release

#### Added
- Modular Bash script architecture with lib/ directory
- Support for Arch Linux (and derivatives)
- Automatic detection of AUR helper (paru/yay)
- Configuration system in ~/.config/updatelite/
- Update modules:
  - Pacman (system packages)
  - AUR (via paru or yay)
  - Flatpak (applications)
  - Docker (images, optional)
- Maintenance modules:
  - Orphan package removal
  - Package cache cleanup
  - Journal vacuum
  - Service status check
- Reboot detection for critical package updates
- Multi-shell support (Fish, Bash, Zsh)
- Installer and uninstaller scripts
- Dry-run mode for previewing changes
- Motivational phrases on completion
- Comprehensive documentation

#### Technical
- Bash 4.0+ compatibility
- Safe configuration parsing (no eval/source)
- Proper error handling with tracking
- Colorized output with fallback for non-TTY
