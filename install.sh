#!/bin/sh

set -e

REPO_URL="git@github.com:$GITHUB_USER/config.git"
CONFIG_DIR="$HOME/.config"
ENV_SOURCE='[ -f "$HOME/.config/env.sh" ] && source "$HOME/.config/env.sh"'

if [ -d "$CONFIG_DIR" ]; then
  if [ ! -d "$CONFIG_DIR/.git" ]; then
    echo "🚫 $CONFIG_DIR already exists and is not a Git repo."
    echo "    Refusing to overwrite. Please back it up or remove it before continuing."
    exit 1
  fi

  EXISTING_REMOTE=$(git -C "$CONFIG_DIR" remote get-url origin 2>/dev/null || echo "")

  if [ "$EXISTING_REMOTE" != "$REPO_URL" ]; then
    echo "🚫 $CONFIG_DIR is a Git repo, but its origin is:"
    echo "    $EXISTING_REMOTE"
    echo "    Expected:"
    echo "    $REPO_URL"
    echo "    Refusing to proceed - either remove ~/.config or ensure it's the correct repo."
    exit 1
  else
    echo "ℹ️ $CONFIG_DIR is already cloned from the correct repo. Skipping clone."
    CLONED=0
  fi
else
  echo "Cloning dotfiles from $REPO_URL into $CONFIG_DIR..."
  git clone "$REPO_URL" "$CONFIG_DIR"
  CLONED=1
fi

if [ "$CLONED" -eq 1 ]; then
  for file in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc"; do
    if [ -f "$file" ]; then
      if ! grep -Fxq "$ENV_SOURCE" "$file"; then
        echo "Patching $file..."
        echo "$ENV_SOURCE" >> "$file"
      fi
    fi
  done
  echo "✅ Dotfiles installed and shell rc patched. Please restart your shell."
else
  echo "ℹ️ Skipped rc patching because no new clone occurred."
fi
