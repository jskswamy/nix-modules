# The orgs this watches are NOT set here — they are generated into
# conf.d/49-repo-context-orgs.fish from `tools.fish.repoContext`, which
# sorts alphabetically before this file and so runs first. Keeping the
# lists out of this file is what lets the function itself be public.
#
# That file holds parallel lists, one entry per org: _REPO_CONTEXT_ORGS and
# the _NAMES/_COLORS/_ICONS of the context each org belongs to.

# Print the index of the first org that $argv[1] (a path or remote URL)
# belongs to; fail when none does.
function _repo_context_org_index
    set -l target $argv[1]
    set -l i 0
    for org in $_REPO_CONTEXT_ORGS
        set i (math $i + 1)
        # Match both HTTPS (/org) and SSH (:org) URL formats
        if string match -q "*/$org*" -- $target; or string match -q "*:$org*" -- $target
            echo $i
            return 0
        end
    end
    return 1
end

function _repo_context_check --on-variable PWD
    # Fast path: check directory path (no subprocess)
    set -l idx (_repo_context_org_index $PWD)

    # Slow path: only check remotes when inside a git worktree.
    # Walk up in pure Fish to find `.git`: in a normal checkout `.git` is a
    # directory (`test -d`), whereas in a worktree `.git` is a regular file
    # (`test -f`). This avoids spawning `git` on every `cd` and startup.
    if test -z "$idx"
        set -l dir "$PWD"
        set -l is_worktree 0
        while test -n "$dir"
            if test -f "$dir/.git"
                set is_worktree 1
                break
            else if test -d "$dir/.git"
                break
            end
            if test "$dir" = /
                break
            end
            set dir (string replace -r '/[^/]*$' '' -- "$dir")
            test -z "$dir"; and set dir /
        end

        if test $is_worktree -eq 1
            for remote_name in (git remote 2>/dev/null)
                set -l remote_url (git remote get-url $remote_name 2>/dev/null)
                test -n "$remote_url"; or continue
                set idx (_repo_context_org_index $remote_url); and break
            end
        end
    end

    if test -n "$idx"
        # An orgs file from before named contexts has no _NAMES: say client.
        set -l name client
        set -q _REPO_CONTEXT_NAMES[$idx]; and set name $_REPO_CONTEXT_NAMES[$idx]
        set -gx REPO_CONTEXT $name
        set -gx REPO_CONTEXT_COLOR $_REPO_CONTEXT_COLORS[$idx]
        set -gx REPO_CONTEXT_ICON $_REPO_CONTEXT_ICONS[$idx]
    else
        set -e REPO_CONTEXT REPO_CONTEXT_COLOR REPO_CONTEXT_ICON
    end
end

# Run at shell startup to catch the initial directory
_repo_context_check
