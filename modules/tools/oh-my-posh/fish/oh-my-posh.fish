# Oh My Posh context hook and narrow-terminal right-prompt guard for Fish.
#
# Oh My Posh invokes `set_poshcontext` before rendering the prompt, allowing
# lightweight env vars to feed text segments and tooltips in config.toml
# without shelling out from inside Oh My Posh.
function set_poshcontext
    set -e POSH_FLAKE_AGE
    if test -f flake.nix
        set -gx POSH_NIX_FLAKE 1
        # shortcut: flake.lock mtime stands in for its lastModified, so a
        # fresh clone reads as fresh; parse the lock if that misleads.
        if test -f flake.lock
            set -l days (math --scale 0 (path mtime --relative flake.lock) / 86400)
            test $days -ge 30; and set -gx POSH_FLAKE_AGE $days
        end
    else
        set -e POSH_NIX_FLAKE
    end

    # Rex session label for the window title, looked up once per shell.
    if set -q REX_BLOCK; and not set -q POSH_REX
        set -gx POSH_REX (rex session inspect $REX_BLOCK --json 2>/dev/null | string match -rg '^  "label": "(.*)",$')
    end

    if test -n "$DEVBOX_SHELL_ENABLED"
        set -gx POSH_DEVBOX shell
    else if test -f devbox.json
        set -gx POSH_DEVBOX project
    else
        set -e POSH_DEVBOX
    end
end

# Populate tooltip-only env vars (POSH_AIDE, POSH_BEADS) lazily, only when
# rendering that command's tooltip, keeping `set_poshcontext` subprocess-free
# on normal prompts.
if functions -q _omp_get_prompt; and not functions -q __omp_get_prompt_inner
    functions -c _omp_get_prompt __omp_get_prompt_inner
    function _omp_get_prompt
        if test "$argv[1]" = tooltip
            if contains -- --command=aide $argv; and command -q aide
                set -fx POSH_AIDE (aide prompt --compact 2>/dev/null)
            else if contains -- --command=bd $argv; and command -q bd
                set -l open (bd count --status open 2>/dev/null)
                and set -fx POSH_BEADS "$open open · "(bd count --status in_progress 2>/dev/null)" active"
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
