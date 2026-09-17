# Fish syntax-highlight colors tuned for both light and dark terminal themes.
#
# Why a fish_prompt event instead of plain `set -g` at conf.d load time?
# Fish's theme loader (`__fish_config_interactive`) runs after conf.d and
# unconditionally re-applies saved theme values in global scope. Globals
# shadow universals, so `set -U` doesn't help either.
# Registering on `fish_prompt` guarantees our overrides run last, just before
# the first prompt is rendered. The handler self-deregisters so there's no
# per-prompt overhead.

function __fish_color_fix --on-event fish_prompt --description "Apply readable color overrides once"
    set -g fish_color_quote green
    set -g fish_color_host_remote green

    # Search/selection highlight backgrounds — `white` is invisible on light themes.
    set -g fish_color_search_match --background=brblack
    set -g fish_color_selection --background=brblack

    # Pager (tab-completion menu) — yellow descriptions and brwhite progress
    # vanish on warm/cream backgrounds.
    set -g fish_pager_color_description green
    set -g fish_pager_color_progress green

    functions -e __fish_color_fix
end
