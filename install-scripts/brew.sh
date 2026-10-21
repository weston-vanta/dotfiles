#!/bin/bash

set -euo pipefail

# Linux Homebrew isn't on bash's PATH: .zshenv adds it, but only for zsh.
if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
fi

if command -v brew &>/dev/null; then
  echo "Homebrew already installed: $(brew --version | head -1)"
  exit 0
fi

echo "==> Installing Homebrew"
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
