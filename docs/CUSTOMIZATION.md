# Customization Guide

This guide explains how to customize updateLITE Arch Edition for your needs.

## Configuration File

Location: `~/.config/updatelite/config`

Create from template:
```bash
updatelite --create-config
```

## Module Configuration

### Disabling Modules

To disable a module, set its flag to `false`:

```bash
ENABLE_DOCKER=false
ENABLE_FLATPAK=false
```

### AUR Helper Selection

By default, updateLITE Arch Edition auto-detects your AUR helper. To force a specific one:

```bash
AUR_HELPER=paru
# or
AUR_HELPER=yay
```

### Skipping AUR Packages

Some AUR packages may cause issues. Skip them:

```bash
AUR_SKIP_PACKAGES=nvidia-dkms-git problematic-pkg-git
```

## Cleanup Settings

### Orphan Packages

Disable automatic orphan removal:

```bash
CLEANUP_ORPHANS=false
```

### Package Cache

Keep more versions in cache:

Edit `lib/cleanup.sh` and change:
```bash
sudo paccache -rk2  # Keep 2 versions
# to
sudo paccache -rk3  # Keep 3 versions
```

Or disable entirely:
```bash
CLEANUP_CACHE=false
```

### Journal Retention

Keep logs longer:

```bash
JOURNAL_VACUUM_DAYS=30
```

## Critical Packages

Customize which packages trigger reboot warnings:

```bash
CRITICAL_PACKAGES=linux linux-lts systemd glibc nvidia
```

## Custom Phrases

Edit `lib/phrases.sh` to add your own phrases:

```bash
PHRASES=(
    "Your custom phrase here"
    "Another phrase"
    # ... existing phrases
)
```

## Logging

Enable file logging:

```bash
ENABLE_LOGGING=true
LOG_DIR=$HOME/logs/updatelite
```

Logs will be written to `$LOG_DIR/updatelite.log`

## Colors

Disable colored output:

```bash
ENABLE_COLORS=false
```

## Adding New Modules

1. Create `lib/mymodule.sh`:

```bash
#!/usr/bin/env bash
# mymodule.sh - Description

update_mymodule() {
    if [[ "$ENABLE_MYMODULE" != "true" ]]; then
        return 0
    fi

    print_section "My Module"

    # Your code here

    print_success "Done"
}
```

2. Add config variable to `lib/config.sh`:

```bash
declare -g ENABLE_MYMODULE="${ENABLE_MYMODULE:-false}"
```

3. Source it in the main script:

```bash
source "$LIB_DIR/mymodule.sh"
```

4. Call it in the main function:

```bash
update_mymodule
```

## Shell Aliases

### Fish

Add to `~/.config/fish/config.fish`:

```fish
alias up='updatelite'
alias upd='updatelite --dry-run'
```

### Bash/Zsh

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias up='updatelite'
alias upd='updatelite --dry-run'
```

## Systemd Timer (Automatic Updates)

Create `~/.config/systemd/user/updatelite.service`:

```ini
[Unit]
Description=updateLITE Arch Edition system maintenance

[Service]
Type=oneshot
ExecStart=%h/.local/bin/updatelite --no-services
```

Create `~/.config/systemd/user/updatelite.timer`:

```ini
[Unit]
Description=Run updateLITE Arch Edition weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
```

Enable:
```bash
systemctl --user enable --now updatelite.timer
```

## Environment Variables

Override config at runtime:

```bash
ENABLE_DOCKER=true updatelite
```
