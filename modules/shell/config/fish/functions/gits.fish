# gits - Get readable git repo status summary
# Usage:
#   gits              - Summary of all repos (or current context)
#   gits -g           - Select group, then summarize
#   gits -g work      - Summary of specific group

function gits --description "Get readable gita status summary"
    set -l group ""
    set -l select_group 0

    # Parse arguments
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case '--group' '-g'
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv); and not string match -q '-*' $argv[$next_i]
                    set i $next_i
                    set group $argv[$i]
                else
                    set select_group 1
                end
            case '--help' '-h'
                echo "gits - Git status summary"
                echo ""
                echo "Usage:"
                echo "  gits              Summary of current context"
                echo "  gits -g           Select group interactively"
                echo "  gits -g <group>   Summary of specific group"
                return 0
            case '*'
                echo "Unknown option: $argv[$i]"
                return 1
        end
        set i (math $i + 1)
    end

    # If -g was provided without a group, use gum/fzf
    if test $select_group -eq 1
        set -l groups_raw (gita group ls 2>/dev/null)
        if test -z "$groups_raw"
            echo "No gita groups found."
            return 1
        end
        set -l groups (string split ' ' $groups_raw)

        if type -q gum
            set group (printf '%s\n' $groups | gum filter --placeholder="Select group...")
        else if type -q fzf
            set group (printf '%s\n' $groups | fzf --prompt="Select group> ")
        else
            echo "Error: gum or fzf not found"
            return 1
        end

        if test -z "$group"
            return 0
        end
    end

    # Switch context if group specified
    set -l original_context ""
    if test -n "$group"
        set original_context (gita context 2>/dev/null)
        gita context $group 2>/dev/null
    end

    # Get gita ll output with spinner
    set -l ll_output
    set -l tmpfile (mktemp)
    gum spin --spinner dot --title "Fetching repo status..." -- bash -c "gita ll > $tmpfile 2>&1"
    set ll_output (cat $tmpfile)
    rm -f $tmpfile

    # Restore context
    if test -n "$group"
        if test "$original_context" = "none" -o -z "$original_context"
            gita context none 2>/dev/null
        else
            gita context $original_context 2>/dev/null
        end
    end

    if test -z "$ll_output"
        gum style --foreground 196 "No repos found"
        return 1
    end

    # Parse repos into categories
    set -l uncommitted
    set -l uncommitted_details
    set -l ready_to_push
    set -l no_remote
    set -l clean
    set -l total 0

    for line in $ll_output
        set total (math $total + 1)

        # Strip ANSI color codes for reliable parsing
        set -l clean_line (echo $line | sed 's/\x1b\[[0-9;]*m//g')
        set -l repo (echo $clean_line | awk '{print $1}')
        set -l branch (echo $clean_line | awk '{print $2}')
        set -l status_part (echo $clean_line | awk '{print $3}')

        # Check for no remote (∅ symbol)
        if string match -q '*∅*' "$clean_line"
            set -a no_remote "$repo ($branch)"
            continue
        end

        # Check for uncommitted work (+, *, ?)
        if string match -q '*+*' "$status_part"; or string match -q '*\**' "$status_part"; or string match -q '*\?*' "$status_part"
            set -a uncommitted "$repo"
            # Get detailed status for this repo
            set -l repo_path (gita ls -p $repo 2>/dev/null)
            if test -n "$repo_path" -a -d "$repo_path"
                set -l staged (git -C "$repo_path" diff --cached --name-only 2>/dev/null | wc -l | string trim)
                set -l modified (git -C "$repo_path" diff --name-only 2>/dev/null | wc -l | string trim)
                set -l untracked (git -C "$repo_path" ls-files --others --exclude-standard 2>/dev/null | wc -l | string trim)
                set -l detail "$repo ($branch)"
                set -l parts
                test "$staged" -gt 0; and set -a parts "✏️ $staged staged"
                test "$modified" -gt 0; and set -a parts "📝 $modified modified"
                test "$untracked" -gt 0; and set -a parts "❓ $untracked untracked"
                if test (count $parts) -gt 0
                    set detail "$detail - "(string join ", " $parts)
                end
                set -a uncommitted_details "$detail"
            else
                set -a uncommitted_details "$repo ($branch)"
            end
            continue
        end

        # Check for ready to push (↑)
        if string match -q '*↑*' "$status_part"
            set -a ready_to_push "$repo ($branch)"
            continue
        end

        # Otherwise clean
        set -a clean "$repo"
    end

    # Display header
    echo ""
    if test -n "$group"
        gum style --foreground 212 --bold "📊 Git Status - $group ($total repos)"
    else
        set -l ctx (gita context 2>/dev/null | string split ':' | head -1)
        if test -n "$ctx" -a "$ctx" != "none"
            gum style --foreground 212 --bold "📊 Git Status - $ctx ($total repos)"
        else
            gum style --foreground 212 --bold "📊 Git Status - All repos ($total)"
        end
    end
    echo ""

    # Display uncommitted work
    if test (count $uncommitted) -gt 0
        gum style --foreground 196 --bold "🔴 UNCOMMITTED WORK ("(count $uncommitted)" repos)"
        for detail in $uncommitted_details
            echo "   $detail"
        end
        echo ""
    end

    # Display ready to push
    if test (count $ready_to_push) -gt 0
        gum style --foreground 226 --bold "🟡 READY TO PUSH ("(count $ready_to_push)" repos)"
        for repo in $ready_to_push
            echo "   ↑ $repo"
        end
        echo ""
    end

    # Display no remote
    if test (count $no_remote) -gt 0
        gum style --foreground 208 --bold "⚠️  NO REMOTE ("(count $no_remote)" repos)"
        for repo in $no_remote
            echo "   $repo"
        end
        echo ""
    end

    # Display clean repos
    if test (count $clean) -gt 0
        gum style --foreground 82 --bold "✅ CLEAN ("(count $clean)" repos)"
        echo "   "(string join ", " $clean)
        echo ""
    end
end
