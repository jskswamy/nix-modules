# Oh My Posh context hook for Fish.
#
# Oh My Posh invokes `set_poshcontext` before rendering the prompt, allowing
# lightweight env vars to feed text segments and tooltips in config.toml
# without shelling out from inside Oh My Posh.
function set_poshcontext
    if test -f flake.nix
        set -gx POSH_NIX_FLAKE 1
    else
        set -e POSH_NIX_FLAKE
    end

    if test -n "$DEVBOX_SHELL_ENABLED"
        set -gx POSH_DEVBOX shell
    else if test -f devbox.json
        set -gx POSH_DEVBOX project
    else
        set -e POSH_DEVBOX
    end
end
