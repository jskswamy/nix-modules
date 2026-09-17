# gitax - Interactive gita context switcher using fzf (like kubectx)
# Usage:
#   gitax        - Select group interactively
#   gitax <name> - Switch to named group directly
#   gitax -      - Clear context (none)
#   gitax .      - Auto context (based on cwd)
#   gitax -c     - Show current context

function gitax --description "Switch gita context interactively (like kubectx)"
    # Handle arguments
    if test (count $argv) -gt 0
        switch $argv[1]
            case '-'
                gita context none
                echo "Cleared context (all repos)"
                return 0
            case '.'
                gita context auto
                set -l new_context (gita context 2>/dev/null | string split ':' | head -1)
                echo "Auto context: $new_context"
                return 0
            case '-c' '--current'
                set -l current (gita context 2>/dev/null | string split ':' | head -1)
                if test -z "$current" -o "$current" = "none"
                    echo "No context (all repos)"
                else
                    echo "Context: $current"
                end
                return 0
            case '-h' '--help'
                echo "gitax - Interactive gita context switcher"
                echo ""
                echo "Usage:"
                echo "  gitax          Select group interactively"
                echo "  gitax <name>   Switch to named group"
                echo "  gitax -        Clear context (none)"
                echo "  gitax .        Auto context (based on cwd)"
                echo "  gitax -c       Show current context"
                return 0
            case '*'
                # Direct group name provided
                gita context $argv[1]
                echo "Context: $argv[1]"
                return 0
        end
    end

    # Get current context for highlighting
    set -l current (gita context)

    # Get all groups (space-separated) and split into array
    set -l groups_raw (gita group ls 2>/dev/null)
    if test -z "$groups_raw"
        echo "No gita groups found. Create groups with: gita group add repo1 repo2 -n groupname"
        return 1
    end

    # Split space-separated groups into array
    set -l groups (string split ' ' $groups_raw)

    # Use fzf (or gum/sk as fallback) for selection
    # Include special options: none (all repos), auto (based on cwd)
    set -l selected
    if type -q gum
        set selected (printf '%s\n' "none" "auto" $groups | gum filter --placeholder="Select context...")
    else if type -q fzf
        set selected (printf '%s\n' "none" "auto" $groups | fzf --prompt="gita context> " \
            --header="Current: $current | none=all, auto=by cwd")
    else if type -q sk
        set selected (printf '%s\n' "none" "auto" $groups | sk --prompt="gita context> " \
            --header="Current: $current")
    else
        echo "Error: gum, fzf, or sk not found"
        return 1
    end

    # Handle selection
    if test -z "$selected"
        return 0  # User cancelled
    end

    switch $selected
        case "none"
            gita context none
            echo "Cleared context (all repos)"
        case "auto"
            gita context auto
            set -l new_context (gita context 2>/dev/null | string split ':' | head -1)
            echo "Auto context: $new_context (based on cwd)"
        case '*'
            gita context $selected
            echo "Context: $selected"
    end
end
