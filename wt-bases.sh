#!/usr/bin/env bash
#
# Run by post-start-install.sh. Gives each repo in WT_BASES that is checked out
# here a wt base: sets its wt.warm commands, and builds a missing base in the
# background so it never holds up environment start. The build logs to
# ~/.cache/wt/base-init-<repo>.log.

set -euo pipefail

WT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/wt"

# Repo path -> its wt.warm commands, one per line.
declare -A WT_BASES=(
  [/workspaces/obsidian]="just pp"
)

for repo in "${!WT_BASES[@]}"; do
  [[ -e "$repo/.git" ]] || continue

  git -C "$repo" config --local --unset-all wt.warm || true
  while IFS= read -r cmd; do
    git -C "$repo" config --local --add wt.warm "$cmd"
  done <<<"${WT_BASES[$repo]}"

  # wt writes .base-stats.json once base-init finishes, so a .base without it
  # was left half-built by a failed run.
  [[ -f "$repo.wt/.base-stats.json" ]] && continue

  log="$HOME/.cache/wt/base-init-$(basename "$repo").log"
  mkdir -p "$(dirname "$log")"
  # The lock skips the build while an earlier post-start is still running one.
  # zsh reads ~/.zshenv, so `just` and the shared pnpm store match a user's shell.
  # shellcheck disable=SC2016  # expanded by the inner zsh
  setsid flock -n "$log.lock" zsh -c '
    exec >"$3" 2>&1
    if [[ -e "$2.wt/.base" ]]; then "$1" --repo "$2" base-remove --force; fi
    "$1" --repo "$2" base-init
  ' _ "$WT" "$repo" "$log" </dev/null >/dev/null 2>&1 &
done
