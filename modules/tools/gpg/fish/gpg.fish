set -gx GPG_TTY (tty)
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
