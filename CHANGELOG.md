# Changelog - updateLITE Arch Edition

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.2] - 2026-03-08

### Fixed
- Installer: shell integration for zsh/bash now copies files to an installed path (`~/.local/share/updatelite/shell-integration/`) instead of pointing to the cloned repository directory
- Shell completions: removed references to non-existent flags (`--dry-run`, `-n`, `--no-cleanup`, `--no-services`) across all shell integrations (fish, zsh, bash)

## [1.1.1] - 2026-03-08

### Fixed
- AUR update tracking: packages updated during a partially failed bulk run were not counted (e.g., fagram-bin updated successfully but shown as 0 upgraded)
- AUR summary: failed packages (e.g., sha256sum mismatch) incorrectly appeared in the "Updated Packages" section
- AUR retry logic: exit code not reset before retry attempt, causing unnecessary fallback to individual updates

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
