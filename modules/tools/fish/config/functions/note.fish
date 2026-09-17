function note --description "Capture notes from URLs using Claude"
    set -l templates_dir "$HOME/.claude/templates"
    set -l output_dir "$HOME/Notes/captured"

    # Default template
    set -l template "article"
    set -l url ""
    set -l save_file ""

    # Parse arguments
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -t --template
                set i (math $i + 1)
                set template $argv[$i]
            case -o --output
                set i (math $i + 1)
                set save_file $argv[$i]
            case -l --list
                echo "Available templates:"
                for f in $templates_dir/*.md
                    echo "  - "(basename $f .md)
                end
                return 0
            case -h --help
                echo "Usage: note [OPTIONS] <url>"
                echo ""
                echo "Capture notes from URLs using Claude with templates."
                echo ""
                echo "Options:"
                echo "  -t, --template TYPE   Template to use (article, tool, person, book, organisation)"
                echo "  -o, --output FILE     Save output to file instead of stdout"
                echo "  -l, --list            List available templates"
                echo "  -h, --help            Show this help"
                echo ""
                echo "Examples:"
                echo "  note https://example.com                     # Uses article template"
                echo "  note -t tool https://github.com/user/repo    # Uses tool template"
                echo "  note -t person https://en.wikipedia.org/...  # Uses person template"
                echo "  note -t book https://goodreads.com/book/...  # Uses book template"
                echo "  note -o notes/myfile.md https://example.com  # Save to file"
                return 0
            case '*'
                # Assume it's the URL
                set url $argv[$i]
        end
        set i (math $i + 1)
    end

    # Validate
    if test -z "$url"
        echo "Error: URL required"
        echo "Usage: note [-t template] <url>"
        return 1
    end

    set -l template_file "$templates_dir/$template.md"
    if not test -f "$template_file"
        echo "Error: Template '$template' not found"
        echo "Available templates:"
        for f in $templates_dir/*.md
            echo "  - "(basename $f .md)
        end
        return 1
    end

    # Fetch and process
    echo "Fetching: $url" >&2
    echo "Template: $template" >&2
    echo "" >&2

    if test -n "$save_file"
        # Ensure output directory exists
        mkdir -p (dirname "$save_file")
        curl -sL "$url" | claude -p "Process this content according to the template instructions" \
            --system-prompt-file "$template_file" \
            --output-format text > "$save_file"
        echo "Saved to: $save_file" >&2
    else
        curl -sL "$url" | claude -p "Process this content according to the template instructions" \
            --system-prompt-file "$template_file" \
            --output-format text
    end
end
