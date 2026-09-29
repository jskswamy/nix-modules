function godir --description "fzf-pick a directory under GIT_WORKSPACE and cd into it"
    set -q GIT_WORKSPACE; or set -gx GIT_WORKSPACE "$HOME/source"
    cd (fd . $GIT_WORKSPACE --exclude vendor --exclude node_modules --type d | fzf --reverse --ansi --preview 'exa --color always -l --git --git-ignore {}')
end
