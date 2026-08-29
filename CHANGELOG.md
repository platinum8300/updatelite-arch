# Changelog - updateLITE Arch Edition

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-08-29

### Added
- AUR updates escalate instead of stopping at the helper. A package the helper
  cannot build is retried with `makepkg` straight from its AUR git repository,
  which is the reference way to build an AUR package and is unaffected by a
  helper's own source handling: Shelly 3.1.1 neither extracts `.pkg.zst` sources
  nor reads arch-specific `source_x86_64` arrays, so packages such as
  `darkly-bin` and `electron41-bin` could never be installed through it. If the
  build ends in an internal compiler error, it is retried once on an older
  installed GCC, since an ICE is a fault in the compiler or the machine rather
  than in the package.
- Memory of deterministic failures, in `~/.cache/updatelite/aur-failures`. A
  package that failed is not rebuilt on every subsequent run; it is listed in one
  line with the reason. Records are keyed on the package version and the
  toolchain, so a new release or a new compiler retries automatically without
  the user clearing anything.
- Per-package build logs under `$LOG_DIR/build/`. The terminal shows one status
  line per attempt and, on failure, the tail of the log where the error is.
  Streaming entire builds buried a run in configure output; discarding it made a
  long build look like a freeze.
- Blocking file conflicts are reported with the path and whether any package
  owns it, which is what distinguishes a leftover from a real collision.

### Fixed
- updateLITE no longer refuses to start where sudo is passwordless. With
  `NOPASSWD: ALL` there is no credential for `sudo -v` to refresh, so it asks for
  a password regardless and fails outright with no terminal to answer, even
  though every command in the run would have succeeded.
- `aur_helper_kind` classifies on the basename. `AUR_HELPER` may hold a path, and
  treating `/usr/bin/shelly` as a pacman-style helper sent every call through
  flags Shelly rejects.
- The AUR tests no longer reach the network or the package database: the
  `makepkg` path is stubbed and fixture packages are named so they cannot
  collide with a real one.

## [1.3.3] - 2026-08-29

### Fixed
- Shelly backend: unattended runs no longer stall on Shelly's PKGBUILD review.
  Shelly stops at `Proceed with update to <pkg>? (y/N)` whenever a PKGBUILD
  changed or raised a security warning, and `--no-confirm` does not cover it:
  there is no review-skipping flag on the AUR verbs, and Shelly's automatic
  answer is to decline. An unattended run blocked on the prompt until someone
  typed a key. The AUR verbs are now fed a stream of confirmations, matching
  what the pacman-style backend already does with `--skipreview`. AUR build
  scripts therefore run without a human reading them first, which is the
  standing trade-off of an unattended AUR updater; use `AUR_SKIP_PACKAGES` to
  hold a package back.
- Shelly backend: single-package rebuilds use `update aur`, not `install aur`.
  The 3.0 reorganisation moved the verbs but did not drop `aur update`, and
  `install aur` takes a different path for an already-installed package.
  `update aur` also rejects `--singlepane`, which was being passed to it.
- Shelly backend: after a failed bulk upgrade, only the packages that are still
  pending are retried. Shelly aborts the whole transaction at the first failure,
  so the original list still names packages it had already installed; rebuilding
  those cost several minutes each and reported them as fresh work.
- Shelly backend: the individual retry no longer discards build output. A
  rebuild can take many minutes per package, so a silent retry pass was
  indistinguishable from a hang. Progress is now reported per package.
- Shelly backend: the retry pass skips PKGBUILD `check()` functions, mirroring
  the pacman backend's retry without test verification, so a failing test suite
  no longer holds a package back.

## [1.3.2] - 2026-08-29

### Fixed
- Shelly backend: adapt to the Shelly 3.0 CLI, which moved AUR actions from
  `shelly aur <verb>` to `shelly <verb> aur` and dropped the `aur update` verb
  in favour of `install aur`. Against Shelly 3.x the old spelling made Shelly
  treat `aur` as a search term and exit non-zero, which the pending-update
  parser turned into an empty list, so every run reported "All AUR packages are
  up to date" and no AUR package was ever upgraded. The installed dialect is now
  detected from the helper's version, so both 2.x and 3.x keep working.
- Shelly backend: a helper that cannot be queried is no longer reported as a
  system with nothing to update. Listing failures propagate, the AUR section
  warns instead of printing a success mark, and upgrades that cannot be verified
  are counted as failed rather than credited as successful. Applies to
  `--dry-run` as well.

### Changed
- Shelly backend: pending packages are listed as `name old -> new`, matching the
  format paru reports, instead of showing only one version. Shelly 3.x returns
  both the installed and the candidate version; the parser previously used the
  installed one.

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
