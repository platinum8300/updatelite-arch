# Changelog - updateLITE Arch Edition

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.5] - 2026-03-12

### Added
- User tool cache cleanup: new section in System Cleanup that intelligently manages pip, uv, AUR build and thumbnail caches
  - **pip**: purged if total size exceeds `USER_CACHE_MIN_SIZE_MB` (default 500 MB)
  - **uv**: pruned (unused entries only) if total size exceeds threshold
  - **AUR builds** (paru/yay clone dirs): entries older than `USER_CACHE_MAX_DAYS` (default 30 days) are removed
  - **Thumbnails**: files older than `USER_CACHE_MAX_DAYS` are removed
- New config options: `CLEANUP_USER_CACHES`, `CLEANUP_USER_CACHE_PIP`, `CLEANUP_USER_CACHE_UV`, `CLEANUP_USER_CACHE_AUR_BUILDS`, `CLEANUP_USER_CACHE_THUMBNAILS`, `USER_CACHE_MIN_SIZE_MB`, `USER_CACHE_MAX_DAYS`
- Summary now shows `User: X MB` freed alongside Cache and Journal

## [1.1.4] - 2026-03-12

### Fixed
- AUR: clean all `*.part` files from paru clone cache before attempting updates — the previous fix mapped package names to clone directories, but the directory name (`pkgbase`) can differ from the AUR package name, causing partial downloads to persist and fail with curl error 33

## [1.1.3] - 2026-03-12

### Fixed
- AUR: automatically clear paru clone cache for all pending packages before attempting download, preventing stale or partial downloads from causing build failures

### Removed
- Hardcoded list of problematic AUR packages (`clean_problematic_packages`) — no longer needed with the new generic cache cleanup

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
