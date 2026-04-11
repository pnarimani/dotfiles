#!/usr/bin/env bash

set -euo pipefail

# Configuration
DOTFILES_REPO="${1:-git@github.com:pnarimani/dotfiles.git}"
BARE_DIR="$HOME/.cfg"
ALIAS_NAME="config"
ALIAS_CMD="/usr/bin/git --git-dir=$BARE_DIR/ --work-tree=$HOME"

echo "=== Dotfiles Bootstrap Script ==="
echo "Repository: $DOTFILES_REPO"
echo "Bare repo will be at: $BARE_DIR"

# 1. Check if Git is installed
if ! command -v git >/dev/null 2>&1; then
  echo "Error: Git is not installed. Please install it first."
  exit 1
fi

# 2. Clone the bare repository if it doesn't exist
if [ ! -d "$BARE_DIR" ]; then
  echo "Cloning bare repository..."
  git clone --bare "$DOTFILES_REPO" "$BARE_DIR"
else
  echo "Bare repository already exists at $BARE_DIR"
fi

# 3. Define the alias function temporarily
config() {
  /usr/bin/git --git-dir="$BARE_DIR/" --work-tree="$HOME" "$@"
}

# 4. Hide untracked files
echo "Configuring Git to hide untracked files..."
config config --local status.showUntrackedFiles no

# 5. Checkout (with backup on conflict)
echo "Checking out dotfiles..."
if config checkout; then
  echo "Checkout successful!"
else
  echo "Some files already exist. Backing them up to ~/.cfg-backup/..."
  mkdir -p ~/.cfg-backup
  config checkout 2>&1 | grep -E '^\s+' | awk '{print $1}' | while read -r file; do
    if [ -f "$file" ] || [ -d "$file" ]; then
      mv "$file" "$HOME/.cfg-backup/$(basename "$file").backup.$(date +%s)"
    fi
  done
  echo "Retrying checkout..."
  config checkout -f
  echo "Checkout completed with backups created."
fi

# 6. Add alias permanently to common shells
echo "Adding alias to shell configs..."
ALIAS_LINE="alias $ALIAS_NAME='$ALIAS_CMD'"

for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
  if [ -f "$rc" ]; then
    if ! grep -q "alias $ALIAS_NAME=" "$rc"; then
      echo "$ALIAS_LINE" >> "$rc"
      echo "Added alias to $rc"
    fi
  fi
done

# Optional: Add to .profile for broader compatibility
if [ -f "$HOME/.profile" ]; then
  if ! grep -q "alias $ALIAS_NAME=" "$HOME/.profile"; then
    echo "$ALIAS_LINE" >> "$HOME/.profile"
  fi
fi

echo ""
echo "=== Bootstrap completed! ==="
echo "Use the alias:   $ALIAS_NAME status"
echo "                $ALIAS_NAME add .ideavimrc"
echo "                $ALIAS_NAME commit -m 'update tmux'"
echo "                $ALIAS_NAME push"
echo ""
echo "Reload your shell or run: source ~/.zshrc (or ~/.bashrc)"
echo "On new machines, just run: bash <(curl -fsSL https://raw.githubusercontent.com/pnarimani/dotfiles/main/install.sh)"
