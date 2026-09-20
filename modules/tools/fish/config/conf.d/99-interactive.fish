# Interactive-only settings
# Edit this file directly - changes take effect immediately (just restart fish)

if status --is-interactive
    # Initialize shell navigation tools
    # jump - directory bookmarking
    if command -q jump
        source (jump shell fish | psub)
    end
    # any-nix-shell - nix-shell detection
    if command -q any-nix-shell
        any-nix-shell fish | source
    end
    # zoxide is managed by Home Manager (programs.zoxide.enableFishIntegration)

    # Source additional fish functions from functions/
    for func_file in ~/.config/fish/functions/*.fish
        source $func_file
    end

    # increase open file limit
    ulimit -S -n 16384

    # Ghostty cursor behavior
    if string match -q -- '*ghostty*' $TERM
        set -g fish_vi_force_cursor 1
    end
end
