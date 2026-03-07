# updateLITE Arch Edition - zsh shell integration
# Source this file in ~/.zshrc

# Zsh completion for updatelite
_updatelite() {
    local -a opts
    opts=(
        '--create-config[Create default config file]'
        '-v[Show version]'
        '--version[Show version]'
        '-h[Show help]'
        '--help[Show help]'
    )
    _describe 'options' opts
}

compdef _updatelite updatelite
