#!/usr/bin/env zsh
# Installs googleworkspace-cli — the `gws` command for Drive, Gmail, Calendar,
# Sheets, Docs, Chat, and Admin.

set -euo pipefail

if command -v gws &>/dev/null; then
  echo "googleworkspace-cli already installed: $(gws --version)"
elif command -v brew &>/dev/null; then
  echo "==> Installing googleworkspace-cli"
  brew install googleworkspace-cli
else
  # Soft failure: bootstrap runs with `set -e`, and everything else it installs
  # is still useful without gws.
  echo "WARNING: Homebrew not found, skipping googleworkspace-cli."
  return 0 2>/dev/null || exit 0
fi
