#!/bin/bash

set -euo pipefail

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default to non-interactive mode (auto-approve removals)
# Set to false for interactive prompts
AUTO_APPROVE="${AUTO_APPROVE:-true}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--interactive)
      AUTO_APPROVE=false
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [-i|--interactive]"
      exit 1
      ;;
  esac
done

# Function to create symlinks with proper error handling
create_symlink() {
  local source="$1"
  local destination="$2"

  # Make source path absolute if it isn't already
  if [[ "$source" != /* ]]; then
    source="$DOTFILES_DIR/$source"
  fi

  if [[ ! -e "$source" ]]; then
    echo "Warning: Source '$source' does not exist, skipping..."
    return 0
  fi

  # Create parent directory if it doesn't exist
  local parent_dir
  parent_dir="$(dirname "$destination")"
  if [[ ! -d "$parent_dir" ]]; then
    echo "Creating directory: $parent_dir"
    mkdir -p "$parent_dir"
  fi

  # Handle existing destination
  if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ -L "$destination" ]]; then
      local current_target
      current_target="$(readlink "$destination")"
      if [[ "$current_target" == "$source" ]]; then
        echo "Already linked: $destination -> $source"
        return 0
      else
        echo "Removing existing symlink: $destination -> $current_target"
        rm "$destination"
      fi
    else
      echo "Warning: $destination already exists and is not a symlink"
      if [[ "$AUTO_APPROVE" == "true" ]]; then
        echo "Auto-approving removal (non-interactive mode)"
        rm -rf "$destination"
      else
        read -p "Remove it and create symlink? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          rm -rf "$destination"
        else
          echo "Skipping: $destination"
          return 0
        fi
      fi
    fi
  fi

  # Create the symlink
  echo "Linking: $destination -> $source"
  ln -s "$source" "$destination"
}

echo "Bootstrapping dotfiles repo at $DOTFILES_DIR"
echo

echo "==> Symlinking .config directories"
for config_dir in "$DOTFILES_DIR/.config"/*; do
  if [[ -d "$config_dir" ]]; then
    dir_name="$(basename "$config_dir")"
    create_symlink "$config_dir" "$HOME/.config/$dir_name"
  fi
done

echo
echo "==> Symlinking Claude Code config"
create_symlink ".claude/settings.json" "$HOME/.claude/settings.json"
create_symlink ".claude/prompts" "$HOME/.claude/prompts"
create_symlink ".claude/skills" "$HOME/.claude/skills"

echo
echo "==> Symlinking SSH custom config"
create_symlink ".ssh/custom" "$HOME/.ssh/custom"
mkdir -p "$HOME/.ssh/custom/sockets"

# Idempotently add Include directive to ~/.ssh/config
SSH_CONFIG="$HOME/.ssh/config"
INCLUDE_LINE="Include ~/.ssh/custom/config"
if [[ ! -f "$SSH_CONFIG" ]]; then
  echo "Creating $SSH_CONFIG with Include directive"
  mkdir -p "$HOME/.ssh"
  printf '%s\n\n' "$INCLUDE_LINE" > "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
elif ! grep -qF "$INCLUDE_LINE" "$SSH_CONFIG"; then
  echo "Adding Include directive to $SSH_CONFIG"
  printf '%s\n\n%s' "$INCLUDE_LINE" "$(cat "$SSH_CONFIG")" > "$SSH_CONFIG"
fi

echo
echo "==> Symlinking root dotfiles"
create_symlink ".gitconfig" "$HOME/.gitconfig"
create_symlink ".oh-my-zsh" "$HOME/.oh-my-zsh"
create_symlink ".zshrc" "$HOME/.zshrc"

echo "Setting zsh as the default shell."
sudo chsh "$(id -un)" --shell "/usr/bin/zsh"

echo
echo "Done!"
