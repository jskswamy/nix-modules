# Shell aliases
# Edit this file directly - changes take effect immediately (just restart fish)

alias lg="lazygit"
alias gw="git-workspace"
alias gll="gita ll"      # Quick repo status across all repos
alias gf="gita fetch"    # Fetch all repos in parallel
alias gp="gita pull"     # Pull all repos
alias tmux="tmux new-session -A"
alias diff="difft"
alias ls="eza --icons=always"
alias cat="bat"
alias weather='curl "wttr.in/chennai"'
alias ips="ifconfig | rg 'inet ' | rg -v 127.0.0.1 | cut -d\\  -f2 | sort"
alias picocom="ls -l /dev | rg --regexp 'tty.\\w*UART' | awk '{print \"/dev/\"\$9}'"
alias vim="nvim"
alias vi="nvim"
alias cdr="cd (git rev-parse --show-toplevel)"
alias chrome="/Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome"

# Claude Code profile aliases
# Default 'claude' uses ~/.claude (personal) - no alias needed
alias claude-work='env CLAUDE_CONFIG_DIR=$HOME/.claude-work claude'
alias claude-personal='env CLAUDE_CONFIG_DIR=$HOME/.claude claude'
