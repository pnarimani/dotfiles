# ~/.config/powershell/profile.ps1
# Windows PowerShell profile — dotfiles equivalent of .zshrc

# Editor
$env:EDITOR = 'nvim'
$env:VISUAL = 'nvim'

# PATH additions
$extraPaths = @(
    "$HOME\.local\bin",
    "$HOME\.cargo\bin"
)
foreach ($p in $extraPaths) {
    if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) {
        $env:PATH = "$p;$env:PATH"
    }
}

# Dotfiles bare-repo alias
function config { git --git-dir="$HOME/.cfg/" --work-tree="$HOME" @args }

# Zoxide (cross-platform directory jumper — install with: winget install ajeetdsouza.zoxide)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& zoxide init powershell | Out-String)
}

# Oh-My-Posh prompt (optional replacement for oh-my-zsh — install with: winget install JanDeDobbeleer.OhMyPosh)
# if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
#     oh-my-posh init pwsh | Invoke-Expression
# }

# Auto-attach to psmux session (mirrors the SSH tmux block in .zshrc)
# psmux ships tmux/pmux aliases and reads .tmux.conf natively.
# install: winget install psmux
if ((Get-Command tmux -ErrorAction SilentlyContinue) -and (-not $env:TMUX)) {
    tmux attach-session -t main 2>$null || tmux new-session -s main
}
