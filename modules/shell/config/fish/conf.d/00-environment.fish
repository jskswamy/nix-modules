# Environment variables and PATH configuration
# Edit this file directly - changes take effect immediately (just restart fish)

# Locale and general environment
set -gx LC_CTYPE en_US.UTF-8
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx EDITOR "nvim"
set -gx VISUAL "nvim"
set -gx GPG_TTY (tty)
set -gx ALTERNATE_EDITOR ""

# Tooling environment variables
set -gx GIT_WORKSPACE "$HOME/source"
set -gx GOPATH "$HOME/go"
set -gx GO111MODULE on
set -gx GOPRIVATE source.golabs.io
set -gx NIX_IGNORE_SYMLINK_STORE 1
set -gx MANPAGER "bat -l man -p"
set -gx BAT_THEME "ansi"
set -gx DOCKER_HOST "unix://$HOME/.colima/default/docker.sock"
# Set SSH_AUTH_SOCK for GPG agent SSH support
# Check multiple paths since gpgconf may not be in PATH during early startup
if command -q gpgconf
    set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
else if test -x "$HOME/.nix-profile/bin/gpgconf"
    set -gx SSH_AUTH_SOCK ("$HOME/.nix-profile/bin/gpgconf" --list-dirs agent-ssh-socket)
else if test -x /run/current-system/sw/bin/gpgconf
    set -gx SSH_AUTH_SOCK (/run/current-system/sw/bin/gpgconf --list-dirs agent-ssh-socket)
else if test -x /opt/homebrew/bin/gpgconf
    set -gx SSH_AUTH_SOCK (/opt/homebrew/bin/gpgconf --list-dirs agent-ssh-socket)
else if test -e "$HOME/.gnupg/S.gpg-agent.ssh"
    # Fallback to hardcoded socket path if gpgconf unavailable
    set -gx SSH_AUTH_SOCK "$HOME/.gnupg/S.gpg-agent.ssh"
end
# Tell GPG agent about current TTY for pinentry prompts (SSH and GPG signing)
if status is-interactive; and command -q gpg-connect-agent
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
end
set -gx GNUPGHOME "$HOME/.gnupg"
set -gx UV_MANAGED_PYTHON true
set -gx FABRIC_COMMIT_PATTERN semantic_commit

# Suppress devbox's "(devbox)" prompt prefix — starship's nix_shell module
# already shows 🐧 when IN_NIX_SHELL is set, so the prefix is redundant.
# Devbox uses different gates per shell: $DEVBOX_NO_PROMPT for bash/zsh,
# and the lowercase fish variable $devbox_no_prompt for fish.
set -gx DEVBOX_NO_PROMPT 1
set -g devbox_no_prompt 1

# FZF configuration
set -gx FZF_TMUX 1
set -gx FZF_TMUX_HEIGHT 80
set -gx FZF_ALT_C_COMMAND "fd -t d . $HOME"
set -l find_source_code_command "fd . $HOME/source/ --exclude vendor --exclude node_modules"
set -gx FZF_CTRL_T_COMMAND $find_source_code_command
set -gx FZF_CTRL_T_OPTS "--preview 'bat --color always {} 2>/dev/null or cat -n {} || eza --color always -l --git --git-ignore {} 2>/dev/null || tree -C {} 2>/dev/null | head -200' --select-1 --exit-0"
set -gx FZF_CTRL_R_OPTS "--sort --exact --preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
# Use terminal's 16 ANSI palette so fzf colors follow the active theme
# (dark/light auto). Selection row uses `reverse` on default fg/bg so the
# terminal inverts its own colors — same trick as tig, guaranteed readable
# on any theme without picking a fixed shade that clashes somewhere.
set -gx FZF_DEFAULT_OPTS "--color=16,fg+:-1:reverse,bg+:-1,hl+:-1:reverse"
set -gx fzf_fd_opts --hidden --exclude=.git --exclude=node_modules

# PATH additions (use fish_add_path to avoid duplicates)
fish_add_path -g $GOPATH/bin
fish_add_path -g "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
fish_add_path -g "$HOME/.cargo/bin"
fish_add_path -g "$HOME/dot-files/bin"
fish_add_path -g "$HOME/.Spacevim/bin"
fish_add_path -g "$HOME/.bin"
fish_add_path -g "$HOME/.local/bin"
fish_add_path -g "$HOME/Library/Flutter/bin"
fish_add_path -g "$PWD/node_modules/.bin"
fish_add_path -g /run/current-system/sw/bin
fish_add_path -g /opt/homebrew/bin
fish_add_path -g "/Applications/Keybase.app/Contents/SharedSupport/bin"
fish_add_path -g "$HOME/.codeium/windsurf/bin"
