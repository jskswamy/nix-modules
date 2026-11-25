# The orgs this watches are NOT set here — they are generated into
# conf.d/49-repo-context-orgs.fish from `shell.repoContext.orgs`, which
# sorts alphabetically before this file and so runs first. Keeping the
# list out of this file is what lets the function itself be public.

function _url_matches_client_org
    set -l url $argv[1]
    for org in $_REPO_CONTEXT_ORGS
        # Match both HTTPS (/org) and SSH (:org) URL formats
        if string match -q "*/$org*" -- $url; or string match -q "*:$org*" -- $url
            return 0
        end
    end
    return 1
end

function _repo_context_check --on-variable PWD
    set -l matched 0

    # Fast path: check directory path (no subprocess)
    for org in $_REPO_CONTEXT_ORGS
        if string match -q "*/$org*" -- $PWD
            set matched 1
            break
        end
    end

    # Slow path: only check remotes when inside a git worktree.
    # Walk up in pure Fish to find `.git`: in a normal checkout `.git` is a
    # directory (`test -d`), whereas in a worktree `.git` is a regular file
    # (`test -f`). This avoids spawning `git` on every `cd` and startup.
    if test $matched -eq 0
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
                if test -n "$remote_url" && _url_matches_client_org $remote_url
                    set matched 1
                    break
                end
            end
        end
    end

    if test $matched -eq 1
        set -gx REPO_CONTEXT client
    else
        set -e REPO_CONTEXT
    end
end

# Run at shell startup to catch the initial directory
_repo_context_check
