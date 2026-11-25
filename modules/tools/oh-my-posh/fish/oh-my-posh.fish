# Oh My Posh context hook and narrow-terminal right-prompt guard for Fish.
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

# Hide the idle right prompt on narrow panes (< 100 cols) without invoking
# `oh-my-posh print right`, while still allowing command tooltips to render
# when `_omp_tooltip_command` is active.
if functions -q fish_right_prompt; and not functions -q __omp_rprompt_inner
    functions -c fish_right_prompt __omp_rprompt_inner
    function fish_right_prompt
        if test -n "$_omp_tooltip_command"; or test "$COLUMNS" -ge 100
            __omp_rprompt_inner $argv
        end
    end
end
