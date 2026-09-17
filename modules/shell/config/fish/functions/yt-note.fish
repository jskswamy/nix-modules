function yt-note --description "Capture notes from YouTube videos using Claude"
    set -l templates_dir "$HOME/.claude/templates"
    set -l template_file "$templates_dir/video.md"

    set -l url ""
    set -l save_file ""

    # Parse arguments
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -o --output
                set i (math $i + 1)
                set save_file $argv[$i]
            case -h --help
                echo "Usage: yt-note [OPTIONS] <youtube-url>"
                echo ""
                echo "Capture notes from YouTube videos using Claude."
                echo ""
                echo "Options:"
                echo "  -o, --output FILE   Save output to file instead of stdout"
                echo "  -h, --help          Show this help"
                echo ""
                echo "Examples:"
                echo "  yt-note https://youtube.com/watch?v=xxx"
                echo "  yt-note -o notes/video.md https://youtu.be/xxx"
                return 0
            case '*'
                set url $argv[$i]
        end
        set i (math $i + 1)
    end

    # Validate
    if test -z "$url"
        echo "Error: YouTube URL required"
        echo "Usage: yt-note [-o output.md] <youtube-url>"
        return 1
    end

    if not test -f "$template_file"
        echo "Error: Video template not found at $template_file"
        return 1
    end

    # Check for yt-dlp
    if not command -q yt-dlp
        echo "Error: yt-dlp is required but not installed"
        echo "Install with: nix-env -iA nixpkgs.yt-dlp"
        return 1
    end

    echo "Fetching transcript: $url" >&2

    # Create temp directory for subtitles
    set -l tmpdir (mktemp -d)

    # Download subtitles
    yt-dlp --write-auto-sub --skip-download --sub-lang en -o "$tmpdir/%(title)s.%(ext)s" "$url" 2>/dev/null

    # Find the subtitle file
    set -l sub_file (find "$tmpdir" -name "*.vtt" -o -name "*.srt" | head -1)

    if test -z "$sub_file"
        echo "Error: Could not extract transcript. Video may not have captions." >&2
        rm -rf "$tmpdir"
        return 1
    end

    echo "Template: video" >&2
    echo "" >&2

    # Clean up VTT format (remove timestamps and formatting)
    set -l transcript (cat "$sub_file" | sed '/^WEBVTT/d' | sed '/^Kind:/d' | sed '/^Language:/d' | sed '/^[0-9]/d' | sed '/-->/d' | sed 's/<[^>]*>//g' | tr '\n' ' ' | sed 's/  */ /g')

    # Clean up temp files
    rm -rf "$tmpdir"

    if test -n "$save_file"
        mkdir -p (dirname "$save_file")
        echo "$transcript" | claude -p "Process this video transcript according to the template instructions" \
            --system-prompt-file "$template_file" \
            --output-format text > "$save_file"
        echo "Saved to: $save_file" >&2
    else
        echo "$transcript" | claude -p "Process this video transcript according to the template instructions" \
            --system-prompt-file "$template_file" \
            --output-format text
    end
end
