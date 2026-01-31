# updateLITE Arch Edition - fish shell integration
# Source this file or place in ~/.config/fish/conf.d/

# Wrapper function
function updatelite --description "updateLITE Arch Edition - System maintenance for Arch/CachyOS"
    # Find the actual script
    set -l script_path

    if test -x "$HOME/.local/bin/updatelite"
        set script_path "$HOME/.local/bin/updatelite"
    else if test -x /usr/local/bin/updatelite
        set script_path /usr/local/bin/updatelite
    else if test -x /usr/bin/updatelite
        set script_path /usr/bin/updatelite
    else
        echo "updatelite not found in PATH" >&2
        return 1
    end

    # Execute
    command $script_path $argv
end

# Completions
complete -c updatelite -s n -l dry-run -d "Preview changes without applying"
complete -c updatelite -l no-cleanup -d "Skip system cleanup"
complete -c updatelite -l no-services -d "Skip service check"
complete -c updatelite -l create-config -d "Create default config file"
complete -c updatelite -s v -l version -d "Show version"
complete -c updatelite -s h -l help -d "Show help"
