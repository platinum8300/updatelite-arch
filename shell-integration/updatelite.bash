# updateLITE Arch Edition - bash shell integration
# Source this file in ~/.bashrc

# Bash completion for updatelite
_updatelite_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local opts="-n --dry-run --no-cleanup --no-services --create-config -v --version -h --help"
    COMPREPLY=($(compgen -W "$opts" -- "$cur"))
}

complete -F _updatelite_completions updatelite
