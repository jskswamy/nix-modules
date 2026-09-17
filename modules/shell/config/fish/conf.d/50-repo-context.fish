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

    # Slow path: only check remotes when inside a git worktree
    # (git-dir differs from git-common-dir in worktrees but not in main checkouts)
    # This avoids false positives when a repo merely has a client remote configured
    if test $matched -eq 0
        set -l git_dir (git rev-parse --git-dir 2>/dev/null)
        set -l git_common (git rev-parse --git-common-dir 2>/dev/null)
        if test -n "$git_dir" -a "$git_dir" != "$git_common"
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
