#!/usr/bin/env zsh
# Installs herdr (herdr.dev) — the agent workspace manager — and its Claude
# integration.
#
# The integration installs a SessionStart hook to ~/.claude/hooks/ and registers
# it in ~/.claude/settings.json. bootstrap.sh symlinks that settings file into
# this repo before it runs install scripts, so the hook entry lands in
# agents/claude/settings.json and reappears as a diff whenever herdr bumps the
# integration version — re-commit it. The hook script itself is managed and
# overwritten by herdr, so it is deliberately not tracked here.

set -euo pipefail

if command -v herdr &>/dev/null; then
  echo "herdr already installed: $(herdr --version)"
elif command -v brew &>/dev/null; then
  echo "==> Installing herdr"
  brew install herdr
else
  # Soft failure: bootstrap runs with `set -e`, and everything else it installs
  # is still useful without herdr.
  echo "WARNING: Homebrew not found, skipping herdr. See https://herdr.dev"
  return 0 2>/dev/null || exit 0
fi

# Idempotent, and the path that upgrades an out-of-date integration in place.
echo "==> Installing herdr's Claude integration"
herdr integration install claude
