if [[ -n "$SSH_CONNECTION" ]] && [[ -n "$TMUX" ]]; then
    tmux_socket="${TMUX%%,*}"
    if [[ ! -S "$tmux_socket" ]]; then
        unset TMUX
    fi
fi

export ZSH="$HOME/.oh-my-zsh"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
export EDITOR=nvim

ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

export PATH="$HOME/.local/bin:$PATH"
fpath=("$HOME/.config/zsh/completions" $fpath)

source $ZSH/oh-my-zsh.sh

alias config="/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME"

eval "$(zoxide init zsh)"

unity_worktree() {
    emulate -L zsh
    setopt pipefail

    local action="${1:-}"
    local worktree_name requested_base_branch repo_hint
    local repo_root base_branch worktree_path
    local library_source library_target
    local parallel_jobs
    local -a library_entries

    case "$action" in
        create)
            if (( $# < 2 || $# > 4 )); then
                echo "usage: unity_worktree create <worktree-name> [base-branch] [repository-path]" >&2
                return 1
            fi

            worktree_name="$2"
            requested_base_branch="${3:-}"
            repo_hint="${4:-$PWD}"
            ;;
        remove)
            if (( $# < 2 || $# > 3 )); then
                echo "usage: unity_worktree remove <worktree-name> [repository-path]" >&2
                return 1
            fi

            worktree_name="$2"
            repo_hint="${3:-$PWD}"
            ;;
        *)
            echo "usage: unity_worktree <create|remove> <worktree-name> [base-branch] [repository-path]" >&2
            return 1
            ;;
    esac

    if ! command -v git >/dev/null 2>&1; then
        echo "git is required." >&2
        return 1
    fi

    if [[ "$action" == "create" ]] && ! command -v rsync >/dev/null 2>&1; then
        echo "rsync is required." >&2
        return 1
    fi

    repo_root="$(git -C "$repo_hint" rev-parse --show-toplevel 2>/dev/null)" || {
        echo "could not find a git repository from: $repo_hint" >&2
        return 1
    }

    worktree_path="${repo_root:h}/${worktree_name}"

    if [[ "$action" == "remove" ]]; then
        if [[ ! -e "$worktree_path" ]]; then
            echo "worktree path does not exist: $worktree_path" >&2
            return 1
        fi

        git -C "$repo_root" worktree remove --force "$worktree_path" || return 1
        echo "removed worktree at $worktree_path"
        return 0
    fi

    base_branch="$requested_base_branch"
    if [[ -z "$base_branch" ]]; then
        base_branch="$(git -C "$repo_root" branch --show-current 2>/dev/null)"
    fi

    if [[ -z "$base_branch" ]]; then
        echo "could not determine the base branch; pass it explicitly when HEAD is detached." >&2
        return 1
    fi

    if [[ -e "$worktree_path" ]]; then
        echo "worktree path already exists: $worktree_path" >&2
        return 1
    fi

    if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$worktree_name"; then
        git -C "$repo_root" worktree add "$worktree_path" "$worktree_name" || return 1
    else
        git -C "$repo_root" worktree add -b "$worktree_name" "$worktree_path" "$base_branch" || return 1
    fi

    library_source="$repo_root/Library"
    library_target="$worktree_path/Library"

    if [[ ! -d "$library_source" ]]; then
        echo "created worktree at $worktree_path, but no Library directory was found at $library_source" >&2
        return 1
    fi

    mkdir -p "$library_target" || return 1

    library_entries=(
        "$library_source"/*(N)
        "$library_source"/.[!.]*(N)
        "$library_source"/..?*(N)
    )

    if (( ${#library_entries} == 0 )); then
        echo "created worktree at $worktree_path; Library is empty." >&2
        return 0
    fi

    parallel_jobs="${UNITY_WORKTREE_RSYNC_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null)}"
    [[ -n "$parallel_jobs" ]] || parallel_jobs=4

    printf '%s\0' "${library_entries[@]}" \
        | xargs -0 -P "$parallel_jobs" -I{} rsync -a "{}" "$library_target/" || return 1

    echo "created worktree at $worktree_path from $base_branch"
}

if [[ "$(uname)" == "Linux" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# Auto-start or attach to tmux when logging in via SSH
if [[ -n "$PS1" ]] && [[ -n "$SSH_CONNECTION" ]] && [[ -z "$TMUX" ]]; then
    if command -v tmux &> /dev/null; then
        tmux attach-session -t ssh_main || tmux new-session -s ssh_main
    fi
fi
