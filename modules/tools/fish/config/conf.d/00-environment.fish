# Environment variables and PATH configuration
# Edit this file directly - changes take effect immediately (just restart fish)

# Locale: name one only if the system has it, so a minimal image without
# en_US does not get "cannot change locale" warnings from every tool.
# C.UTF-8 is built into glibc and so is the fallback there. `locale -a`
# spells these en_US.utf8 / C.utf8 on Linux; the UTF-8 spelling below is
# accepted by both.
set -l available
command -q locale; and set available (locale -a 2>/dev/null)
set -l loc
if set -q available[1]
    if string match -qri '^en_US\.utf-?8$' -- $available
        set loc en_US.UTF-8
    else if string match -qri '^C\.utf-?8$' -- $available
        set loc C.UTF-8
    end
end
if test -n "$loc"
    set -gx LC_CTYPE $loc
    set -gx LANG $loc
    set -gx LC_ALL $loc
end

# General environment
set -gx ALTERNATE_EDITOR ""

# Tooling environment variables
set -gx GOPATH "$HOME/go"
set -gx GO111MODULE on
set -gx NIX_IGNORE_SYMLINK_STORE 1
# Only where colima has been set up; elsewhere this would point docker at a
# socket that does not exist and hide the real one.
test -d "$HOME/.colima"; and set -gx DOCKER_HOST "unix://$HOME/.colima/default/docker.sock"
set -gx UV_MANAGED_PYTHON true
set -gx FABRIC_COMMIT_PATTERN semantic_commit

# Suppress devbox's "(devbox)" prompt prefix — starship's nix_shell module
# already shows 🐧 when IN_NIX_SHELL is set, so the prefix is redundant.
# Devbox uses different gates per shell: $DEVBOX_NO_PROMPT for bash/zsh,
# and the lowercase fish variable $devbox_no_prompt for fish.
set -gx DEVBOX_NO_PROMPT 1
set -g devbox_no_prompt 1

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
