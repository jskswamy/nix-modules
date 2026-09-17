function godir --description "fzf-pick a directory under ~/source and cd into it"
  cd (fd . $HOME/source --exclude vendor --exclude node_modules --type d | fzf --reverse --ansi --preview 'exa --color always -l --git --git-ignore {}')
end
