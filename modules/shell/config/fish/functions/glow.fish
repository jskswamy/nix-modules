function glow --description "glow, but pin light/dark style to macOS appearance"
    # glow's auto style-detection queries the terminal's background color;
    # run inside herdr's PTY that query is unanswered and it silently
    # defaults to "dark", rendering pale-gray text unreadable against
    # Ghostty's light theme. Ask macOS directly instead.
    set -l style dark
    if test "(defaults read -g AppleInterfaceStyle 2>/dev/null)" != Dark
        set style light
    end
    command glow -s $style -p -w (tput cols) $argv
end
