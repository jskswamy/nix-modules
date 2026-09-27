function hackspace
    set -l default_name (basename $PWD)
    read -P "Session name [$default_name]: " session_name
    if test -z "$session_name"
        set session_name $default_name
    end
    env HACKSPACE_NAME=$session_name tmuxp load -a -y ~/.config/tmuxp/hackspace.yml
end
