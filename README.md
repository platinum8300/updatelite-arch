<p align="center">
  <img src="cover.png" alt="updateLITE Arch Edition" width="600">
</p>

# updateLITE Arch Edition

System maintenance tool for **Arch Linux** and **CachyOS**

A modular, user-friendly script that handles system updates, cleanup, and maintenance in one command.

## Features

- **Unified Updates**: Pacman, AUR (paru/yay), Flatpak, and Docker
- **Smart Cleanup**: Orphan packages, cache, and journal management
- **Service Monitoring**: Detect failed systemd services
- **Reboot Detection**: Know when critical packages require a restart
- **Modular Design**: Enable only what you need
- **Multi-Shell Support**: Fish, Bash, and Zsh integration
- **CachyOS Optimized**: Automatic detection of CachyOS-specific features

## Quick Install

```bash
git clone https://github.com/platinum8300/updatelite-arch.git
cd updatelite
./install.sh
```

## Usage

```bash
# Run full system maintenance
updatelite

# Preview changes without applying
updatelite --dry-run

# Skip cleanup phase
updatelite --no-cleanup

# Show all options
updatelite --help
```

## Configuration

Configuration file location: `~/.config/updatelite/config`

Create default config:
```bash
updatelite --create-config
```

### Key Options

| Option | Default | Description |
|--------|---------|-------------|
| `ENABLE_PACMAN` | true | Update system packages |
| `ENABLE_AUR` | true | Update AUR packages |
| `ENABLE_FLATPAK` | true | Update Flatpak apps |
| `ENABLE_DOCKER` | false | Update Docker images |
| `AUR_HELPER` | auto | paru, yay, or auto-detect |
| `CLEANUP_ORPHANS` | true | Remove orphan packages |
| `CLEANUP_CACHE` | true | Clean package cache |
| `JOURNAL_VACUUM_DAYS` | 7 | Keep journal for N days |

See [config/updatelite.conf.example](config/updatelite.conf.example) for all options.

## Requirements

**Required:**
- Arch Linux or CachyOS
- Bash 4.0+
- sudo

**Recommended:**
- pacman-contrib (for cache cleanup)
- paru or yay (for AUR support)

## CLI Options

```
Usage: updatelite [OPTIONS]

Options:
  -n, --dry-run      Preview changes without applying
  --no-cleanup       Skip system cleanup phase
  --no-services      Skip service status check
  --create-config    Create default configuration file
  -v, --version      Show version information
  -h, --help         Show help message
```

## Directory Structure

```
~/.local/bin/updatelite           # Main script
~/.local/share/updatelite/lib/    # Library modules
~/.config/updatelite/config       # Configuration
```

## Uninstall

```bash
./uninstall.sh
```

Or manually:
```bash
rm ~/.local/bin/updatelite
rm -rf ~/.local/share/updatelite
rm -rf ~/.config/updatelite  # Optional: keeps your config
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the **GNU Affero General Public License v3.0** (AGPL-3.0).

See [LICENSE](LICENSE) for the full text.

## Acknowledgments

- The Arch Linux and CachyOS communities
- Contributors and users who provide feedback
