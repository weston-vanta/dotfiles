#!/usr/bin/env zsh

set -euo pipefail

NVIM_VERSION="stable"
INSTALL_DIR="$HOME/.local"

if command -v nvim &>/dev/null; then
  echo "neovim already installed: $(nvim --version | head -1)"
  return 0 2>/dev/null || exit 0
fi

echo "==> Installing Neovim ($NVIM_VERSION)"

case "$(uname -s)" in
  Linux)
    mkdir -p "$INSTALL_DIR"
    tarball="nvim-linux-$(uname -m).tar.gz"
    url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${tarball}"

    echo "Downloading $url"
    curl -fsSL "$url" -o "/tmp/$tarball"
    tar -xzf "/tmp/$tarball" -C "$INSTALL_DIR" --strip-components=1
    rm "/tmp/$tarball"
    ;;
  Darwin)
    if command -v brew &>/dev/null; then
      brew install neovim
    else
      echo "Error: Homebrew not found. Install neovim manually."
      return 1 2>/dev/null || exit 1
    fi
    ;;
  *)
    echo "Error: Unsupported OS: $(uname -s)"
    return 1 2>/dev/null || exit 1
    ;;
esac

echo "Installed: $(nvim --version | head -1)"
