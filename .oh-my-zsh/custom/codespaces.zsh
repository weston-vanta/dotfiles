# Codespace management functions
# These are automatically loaded by oh-my-zsh on shell startup

# Main cs command with subcommands
cs() {
  local subcommand="${1}"
  shift

  case "$subcommand" in
    list|ls)
      _cs_list "$@"
      ;;
    ssh)
      _cs_ssh "$@"
      ;;
    pane)
      _cs_pane "$@"
      ;;
    help|--help|-h|"")
      _cs_help
      ;;
    *)
      echo "Unknown subcommand: $subcommand"
      echo ""
      _cs_help
      return 1
      ;;
  esac
}

# List all running codespaces in a user-friendly format
_cs_list() {
  gh cs list --json displayName,repository,state | \
    jq -r '.[] | "\(.displayName) (\(.repository)) - \(.state)"'
}

# SSH into a codespace with proper environment setup
# Usage: cs ssh [codespace-name]
_cs_ssh() {
  local codespace_display_name="${1}"

  # If no name provided, get list and use fzf for selection (if available)
  if [ -z "$codespace_display_name" ]; then
    if command -v fzf &> /dev/null; then
      codespace_display_name=$(cs list | fzf --prompt="Select Codespace: " | awk '{print $1;}')
      [ -z "$codespace_display_name" ] && return 1
    else
      echo "Please provide a codespace name, or install fzf for interactive selection"
      echo "Usage: cs pane <codespace-name>"
      echo ""
      echo "Available codespaces:"
      _cs_list
      return 1
    fi
  fi

  local codespace_name=$(gh cs list --json name,displayName | \
    jq -r --arg display_name "$codespace_display_name" 'first(.[] | select(.displayName == $display_name)).name')

  echo "Connecting to $codespace_name..."

  if [ -n "$TMUX" ]; then
    tmux set-option -p @codespace_name "$codespace_display_name"
  fi

  gh cs ssh -c "$codespace_name"
  
  if [ -n "$TMUX" ]; then
    tmux set-option -pu @codespace_name
  fi
}

# Open a new tmux pane and SSH into a codespace
# Usage: cs pane [-h|-v] [codespace-name]
_cs_pane() {
  local split_direction="v"  # Default to vertical
  local codespace_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h)
        split_direction="h"
        shift
        ;;
      -v)
        split_direction="v"
        shift
        ;;
      *)
        codespace_name="$1"
        shift
        ;;
    esac
  done

  # Split pane and connect
  # Use zsh -i -c to ensure functions are loaded in the new pane
  tmux split-window -$split_direction "zsh -i -c 'cs ssh $codespace_name'"
}

# Show help message
_cs_help() {
  cat <<EOF
Usage: cs <subcommand> [options]

Manage GitHub Codespaces from tmux

Subcommands:
  list, ls              List all running Codespaces
  ssh [name]            SSH into a Codespace (interactive if no name provided)
  pane [-h|-v] [name]   Open a new tmux pane connected to a Codespace
                        -h: horizontal split (default)
                        -v: vertical split
  help                  Show this help message

Examples:
  cs list                          # List all running Codespaces
  cs ssh my-codespace              # SSH into a specific Codespace
  cs pane                          # Open new pane with interactive selection (requires fzf)
  cs pane my-codespace             # Open new pane connected to specific Codespace
  cs pane -v my-codespace          # Open new vertical pane connected to specific Codespace
EOF
}
