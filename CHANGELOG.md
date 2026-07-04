# Changelog - updateLITE Arch Edition

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1] - 2026-07-04

### Fixed
- Installer shell detection no longer relies solely on `$SHELL`: when it is
  unset or points to a non-existent binary, the login shell from the user
  database (`getent passwd`) is used instead, falling back to `sh`.

## [1.3.0] - 2026-07-03

### Added
- `--dry-run` (`-n`): preview pending pacman/AUR/Flatpak/firmware updates,
  orphan packages and cache/journal sizes without changing anything. Uses
  `checkupdates` (pacman-contrib) when available for an accurate repo preview.
- `--no-cleanup` and `--no-services` flags to skip those phases.
- `AUR_SKIP_PACKAGES` is now honored: matching packages are excluded from AUR
  updates (`--ignore` for paru/yay, per-package updates for Shelly) and shown
  as skipped instead of failed.
- `ENABLE_PHRASES=false` now actually hides the header/footer phrases.
- sudo keepalive: authentication is requested once at the start and refreshed
  in the background, so long AUR builds no longer stall asking for a password.
- Shell completions (bash/zsh/fish) updated with the new flags.
- `DEP_MISMATCH_HOLDS` config option: hold back packages whose pinned
  dependency version does not match the installed one ("package:dependency"
  pairs). Replaces a hardcoded kernel/driver check and is empty by default.

### Fixed
- A pacman or Docker failure no longer aborts the whole run: exit codes are
  captured safely under `set -e`, so the PGP recovery path, the summary and
  the reboot check now run even after an update error.
- PGP error detection reads the already-captured pacman output instead of
  re-running a full `pacman -Syyu` just to inspect the error.
- Orphan removal errors are reported again (the success branch was
  unconditional) and no longer count removed orphans on failure.
- Flatpak updates are no longer capped at 10 entries in tracking and summary.
- `chaotic-keyring` is only reinstalled during PGP recovery when the
  Chaotic-AUR repo is actually configured.
- The pacman output temp file is removed on every exit path via an EXIT trap.
- Installer no longer aborts silently during version verification (a SIGPIPE
  from piping --version into head, fatal under pipefail).

### Changed
- Distro detection now reads /etc/os-release, so any Arch derivative (Garuda,
  EndeavourOS, ...) shows its real name in the header and in --version;
  previously only CachyOS and Arch were recognized.
- Reboot notice restyled to match the rest of the interface (single-line
  separators instead of a double-line box).
- Warning markers use a fixed-width `!` and the services/summary icons no
  longer use variation-selector emojis, fixing column alignment in some
  terminals.
- Removed a duplicate phrase and the unused `add_custom_phrase` helper.

## [1.2.1] - 2026-06-29

### Changed
- AUR helper auto-detection now prefers Shelly, then paru, then yay (previously
  paru, then yay, then Shelly). Shelly is the default package manager on CachyOS
  (the primary target) since 2026, so `AUR_HELPER=auto` now selects it when
  present. Set `AUR_HELPER` explicitly (`paru`/`yay`/`shelly`) to override.

## [1.2.0] - 2026-06-29

### Added
- Shelly support as an AUR backend, alongside paru and yay. `AUR_HELPER` now
  accepts `shelly`, and auto-detection falls back to Shelly when neither paru
  nor yay is present — which is the out-of-the-box case on CachyOS installs from
  June 2026 onward, where paru is no longer shipped by default.
  - The AUR module was refactored into an orchestrator plus per-dialect backends:
    `update_aur_pacman` (paru/yay, unchanged behavior) and `update_aur_shelly`.
  - The Shelly backend mirrors the existing strategy (list pending, bulk upgrade,
    per-package fallback, then diff to score results) using Shelly's own verbs
    (`aur list-updates`, `aur upgrade`, `aur update`) and parses its JSON output
    for reliable, locale-independent results.
  - New `aur_helper_kind` helper classifies a helper as `shelly` or `pacman`.
- Package cache cleanup is now AUR-helper aware: it prunes the paru/yay build
  cache via `-Sc`, and skips that step for Shelly (which builds in ephemeral
  temporary directories, already covered by `pacman -Sc`).

## [1.1.8] - 2026-04-19

### Fixed
- Pacman download progress bars no longer visible when running updatelite (pacman 7.x)
  - Pacman 7.x is stricter about TTY detection: it suppresses progress bars when stdout
    is a pipe, which broke real-time output when capturing via `tee`
  - Replaced `| tee` with `script(1)` to create a pseudo-TTY, restoring percentage
    display and live progress while still capturing output for reboot detection

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
