set -gx GNUPGHOME "$HOME/.gnupg"

# Fast path: reuse existing SSH_AUTH_SOCK or the standard GPG agent socket
# without forking `gpgconf` on every shell startup.
if test -z "$SSH_AUTH_SOCK"
    if test -S "$GNUPGHOME/S.gpg-agent.ssh"
        set -gx SSH_AUTH_SOCK "$GNUPGHOME/S.gpg-agent.ssh"
    else if command -q gpgconf
        set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
    else if test -x "$HOME/.nix-profile/bin/gpgconf"
        set -gx SSH_AUTH_SOCK ("$HOME/.nix-profile/bin/gpgconf" --list-dirs agent-ssh-socket)
    else if test -x /run/current-system/sw/bin/gpgconf
        set -gx SSH_AUTH_SOCK (/run/current-system/sw/bin/gpgconf --list-dirs agent-ssh-socket)
    else if test -x /opt/homebrew/bin/gpgconf
        set -gx SSH_AUTH_SOCK (/opt/homebrew/bin/gpgconf --list-dirs agent-ssh-socket)
    end
end

# Only fork `tty` / `gpg-connect-agent` when GPG_TTY is not yet set (for
# example when Home Manager's gpg-agent fish integration is not enabled).
if status is-interactive; and test -z "$GPG_TTY"
    set -gx GPG_TTY (tty)
    if command -q gpg-connect-agent
        gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
    end
end
