# Custom fish functions
# Edit this file directly - changes take effect immediately (just restart fish)

function gcloud_tmux
    # Get available gcloud configurations
    set configs (gcloud config configurations list --format="value(name)" | tail -n +2)

    if test (count $configs) -eq 0
        echo "No gcloud configurations found"
        return 1
    end

    # Use fzf to select configuration
    set selected_config (printf '%s\n' $configs | fzf --height=40% --layout=reverse --prompt="Select gcloud config: ")

    if test -z "$selected_config"
        echo "No configuration selected"
        return 1
    end

    # Launch tmuxp with selected configuration
    echo "Launching tmuxp with gcloud config: $selected_config"
    env GCLOUD_CONFIG=$selected_config tmuxp load gcloud-env
end
