if [[ -n "$SSH_CONNECTION" ]] && [[ -n "$TMUX" ]]; then
    tmux_socket="${TMUX%%,*}"
    if [[ ! -S "$tmux_socket" ]]; then
        unset TMUX
    fi
fi

export ZSH="$HOME/.oh-my-zsh"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
export EDITOR=nvim
export VISUAL=nvim

ZSH_THEME="robbyrussell"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

source $ZSH/oh-my-zsh.sh

alias config="/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME"

eval "$(zoxide init zsh)"

if [[ "$(uname)" == "Linux" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# Auto-start or attach to tmux when logging in via SSH
if [[ -n "$PS1" ]] && [[ -n "$SSH_CONNECTION" ]] && [[ -z "$TMUX" ]]; then
    if command -v tmux &> /dev/null; then
        tmux attach-session -t ssh_main || tmux new-session -s ssh_main
    fi
fi
