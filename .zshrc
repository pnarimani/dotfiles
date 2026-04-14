export ZSH="$HOME/.oh-my-zsh"
export EDITOR=nvim

ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

alias config="/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME"

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

# Auto-start or attach to tmux when logging in via SSH
if [[ -n "$PS1" ]] && [[ -n "$SSH_CONNECTION" ]]; then
    if command -v tmux &> /dev/null; then
        tmux attach-session -t ssh_main || tmux new-session -s ssh_main
    fi
fi
