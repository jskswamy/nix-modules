# Custom fish functions
# Edit this file directly - changes take effect immediately (just restart fish)

function hackspace
    set -l default_name (basename $PWD)
    read -P "Session name [$default_name]: " session_name
    if test -z "$session_name"
        set session_name $default_name
    end
    env HACKSPACE_NAME=$session_name tmuxp load -a -y ~/.config/tmuxp/hackspace.yml
end

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
