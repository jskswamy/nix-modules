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

# Populate POSH_AIDE lazily only when rendering the `aide` command tooltip,
# keeping `set_poshcontext` subprocess-free on normal prompts.
if functions -q _omp_get_prompt; and not functions -q __omp_get_prompt_inner
    functions -c _omp_get_prompt __omp_get_prompt_inner
    function _omp_get_prompt
        if test "$argv[1]" = tooltip; and contains -- --command=aide $argv
            if command -q aide
                set -lx POSH_AIDE (aide prompt --compact 2>/dev/null)
                __omp_get_prompt_inner $argv
                return
            end
        end
        __omp_get_prompt_inner $argv
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
