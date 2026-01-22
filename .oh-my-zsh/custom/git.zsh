# Custom git commands
# These are automatically loaded by oh-my-zsh on shell startup

# Remove the default oh-my-zsh alias so we can define our own function
unalias gg 2>/dev/null

# Main gg command with subcommands
gg() {
  local subcommand="$1"
  shift

  case "$subcommand" in
    switch|sw)
      _g_switch "$@"
      ;;
    help|--help|-h|"")
      _g_help
      ;;
    *)
      echo "Unknown subcommand: $subcommand"
      echo ""
      _g_help
      return 1
      ;;
  esac
}

# Interactive git switch using fzf
# Usage: g switch [branch-name]
_g_switch() {
  local branch="$1"

  if [[ -z "$branch" ]]; then
    if command -v fzf &> /dev/null; then
      branch=$(git branch --all --format='%(refname:short)' | \
        sed 's|^origin/||' | \
        sort -u | \
        grep -v '^HEAD$' | \
        fzf --prompt="Switch to branch: " --preview="git log --oneline --color=always -20 {}")
      [[ -z "$branch" ]] && return 1
    else
      echo "Please provide a branch name, or install fzf for interactive selection"
      echo "Usage: g switch <branch-name>"
      return 1
    fi
  fi

  git switch "$branch"
}

# Show help message
_g_help() {
  cat <<EOF
Usage: gg <subcommand> [options]

Custom git commands with interactive features

Subcommands:
  switch, sw [branch]   Switch to a branch (interactive if no branch provided)
  help                  Show this help message

Examples:
  gg switch              # Interactively choose a branch to switch to
  gg switch main         # Switch to main branch
  gg sw feature-branch   # Switch to feature-branch
EOF
}
