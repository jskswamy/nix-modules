# Fast direnv integration for Fish.
#
# Standard `direnv hook fish` runs `direnv export fish` on every `fish_prompt`,
# which adds a full subprocess spawn on every Enter. This hook only invokes
# direnv when PWD changes, after a command touches direnv/.envrc, or at shell
# startup when an .envrc exists in PWD or an ancestor directory.
if status is-interactive; and command -q direnv
    function __direnv_has_envrc
        set -l dir "$PWD"
        while test -n "$dir"
            if test -f "$dir/.envrc"
                return 0
            end
            if test "$dir" = /
                return 1
            end
            set dir (string replace -r '/[^/]*$' '' -- "$dir")
            test -z "$dir"; and set dir /
        end
        return 1
    end

    function __direnv_eval_now
        command direnv export fish | source
    end

    function __direnv_on_pwd --on-variable PWD
        if set -q DIRENV_DIR; or __direnv_has_envrc
            __direnv_eval_now
        end
    end

    function __direnv_on_postexec --on-event fish_postexec
        if string match -qri '(^|\s)(direnv|mkenvrc)\b|\.envrc' -- "$argv[1]"
            __direnv_eval_now
        end
    end

    # Initial load at startup only if we are already inside a direnv tree.
    if set -q DIRENV_DIR; or __direnv_has_envrc
        __direnv_eval_now
    end
end
