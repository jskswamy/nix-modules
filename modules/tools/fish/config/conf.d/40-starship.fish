# Starship customization: applied once on first prompt so it runs after
# starship's own fish init has defined fish_right_prompt and the
# enable_transience helpers.

function __starship_customize --on-event fish_prompt
    functions -e __starship_customize  # one-shot

    # Hide the right prompt on narrow terminals so it doesn't eat typing room.
    # Forward $argv so starship's inner sees `--final-rendering` (fish 4.1+
    # native transience flag) and clears the right prompt on command submit.
    if functions -q fish_right_prompt
        functions -c fish_right_prompt __starship_rprompt_inner
        function fish_right_prompt
            if test "$COLUMNS" -ge 100
                __starship_rprompt_inner $argv
            end
        end
    end

    # Transient prompts: past prompts in scrollback collapse to just the
    # character module; the right side is dropped entirely.
    function starship_transient_prompt_func
        starship module character
    end

    function starship_transient_rprompt_func
    end

    if functions -q enable_transience
        enable_transience
    end
end
