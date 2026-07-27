#Requires -Version 7
[CmdletBinding()]
param(
    [string]$DotfilesRepo = 'git@github.com:pnarimani/dotfiles.git'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$BareDir  = Join-Path $HOME '.cfg'
$GitExe   = 'git'

Write-Host '=== Dotfiles Bootstrap Script (Windows) ==='
Write-Host "Repository : $DotfilesRepo"
Write-Host "Bare repo  : $BareDir"

# 1. Check Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error 'Git is not installed. Install it from https://git-scm.com and re-run.'
    exit 1
}

# 2. Clone bare repo
if (-not (Test-Path -LiteralPath $BareDir)) {
    Write-Host 'Cloning bare repository...'
    & $GitExe clone --bare $DotfilesRepo $BareDir
} else {
    Write-Host "Bare repository already exists at $BareDir"
}

# Helper: run git against the bare repo
function Invoke-Config {
    & $GitExe --git-dir="$BareDir/" --work-tree="$HOME" @args
}

# 3. Hide untracked files
Write-Host 'Configuring Git to hide untracked files...'
Invoke-Config config --local status.showUntrackedFiles no

# 4. Checkout (with backup on conflict)
Write-Host 'Checking out dotfiles...'
$checkoutOutput = Invoke-Config checkout 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host 'Checkout successful!'
} else {
    Write-Host 'Some files already exist. Backing them up to ~/.cfg-backup/ ...'
    $backupDir = Join-Path $HOME '.cfg-backup'
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    # Parse conflicting file paths from git output
    $conflicting = $checkoutOutput |
        Where-Object { $_ -match '^\s+\S' } |
        ForEach-Object { $_.Trim() }

    foreach ($file in $conflicting) {
        $fullPath = Join-Path $HOME $file
        if (Test-Path -LiteralPath $fullPath) {
            $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $dest = Join-Path $backupDir "$([System.IO.Path]::GetFileName($file)).backup.$timestamp"
            Move-Item -LiteralPath $fullPath -Destination $dest -Force
        }
    }

    Write-Host 'Retrying checkout...'
    Invoke-Config checkout -f
    Write-Host 'Checkout completed with backups created.'
}

# 5. Add `config` function to PowerShell profile
$profilePath = $PROFILE.CurrentUserAllHosts
Write-Host "Adding 'config' function to PowerShell profile ($profilePath)..."

$profileDir = Split-Path $profilePath
if (-not (Test-Path -LiteralPath $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$configFunction = @"

# Dotfiles bare-repo alias (added by install.ps1)
function config { git --git-dir="`$HOME/.cfg/" --work-tree="`$HOME" @args }
"@

if (Test-Path -LiteralPath $profilePath) {
    $existing = Get-Content -LiteralPath $profilePath -Raw
    if ($existing -notmatch 'function config') {
        Add-Content -LiteralPath $profilePath -Value $configFunction
        Write-Host "Added 'config' function to $profilePath"
    } else {
        Write-Host "'config' function already present in $profilePath"
    }
} else {
    Set-Content -LiteralPath $profilePath -Value $configFunction
    Write-Host "Created $profilePath with 'config' function"
}

# 6. Source the dotfiles PowerShell profile if it exists
$dotfilesProfile = Join-Path $HOME '.config\powershell\profile.ps1'
if (Test-Path -LiteralPath $dotfilesProfile) {
    $sourceLine = ". `"$dotfilesProfile`""
    $profileContent = if (Test-Path -LiteralPath $profilePath) { Get-Content -LiteralPath $profilePath -Raw } else { '' }
    if ($profileContent -notmatch [regex]::Escape($dotfilesProfile)) {
        Add-Content -LiteralPath $profilePath -Value "`n# Dotfiles PowerShell profile`n$sourceLine"
        Write-Host "Sourced dotfiles PowerShell profile in $profilePath"
    }
}

Write-Host ''
Write-Host '=== Bootstrap completed! ==='
Write-Host 'Use the alias in a new PowerShell session:'
Write-Host '    config status'
Write-Host '    config add .ideavimrc'
Write-Host "    config commit -m 'update config'"
Write-Host '    config push'
Write-Host ''
Write-Host 'Reload your shell or run: . $PROFILE'
Write-Host 'On new machines, run:'
Write-Host '    irm https://raw.githubusercontent.com/pnarimani/dotfiles/main/install.ps1 | iex'
