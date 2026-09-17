#!/usr/bin/env fish

function kubeswitch
    fd . -t f -e yaml ~/.tmuxp --exec echo "{/.}" | fzf --bind 'enter:execute-silent(tmuxp load --yes {1})+abort'
end
