#!/bin/bash

set -euo pipefail

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
echo "==> Symlinking root dotfiles"
create_symlink ".gitconfig" "$HOME/.gitconfig"
create_symlink ".oh-my-zsh" "$HOME/.oh-my-zsh"
create_symlink ".zshrc" "$HOME/.zshrc"

echo "Setting zsh as the default shell."
sudo chsh "$(id -un)" --shell "/usr/bin/zsh"

echo
echo "Done!"
