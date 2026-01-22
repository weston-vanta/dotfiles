# Gitpod ONA environment management functions
# These are automatically loaded by oh-my-zsh on shell startup

# Main ona command with subcommands
ona() {
  local subcommand="${1}"
  shift

  case "$subcommand" in
    list|ls)
      _ona_list "$@"
      ;;
    ssh)
      _ona_ssh "$@"
      ;;
    pane)
      _ona_pane "$@"
      ;;
    help|--help|-h|"")
      _ona_help
      ;;
    *)
      echo "Unknown subcommand: $subcommand"
      echo ""
      _ona_help
      return 1
      ;;
  esac
}

# List all gitpod environments in a user-friendly format
_ona_list() {
  gitpod environment list -o json | \
    jq -r '.[] | "\(.status.content.git.branch) - \(.status.phase)"'
}

# Ensure Gitpod SSH config exists with ControlPath configured
_ona_ensure_ssh_config() {
  local ssh_config="$HOME/.ssh/gitpod/config"
  local ssh_control_path="$HOME/.ssh/gitpod/control"

  if [[ ! -f "$ssh_config" ]]; then
    echo "Setting up Gitpod SSH config..."
    gitpod environment ssh-config
  fi

  if ! grep -q "ControlPath" "$ssh_config" && grep -q "ControlMaster" "$ssh_config"; then
    echo "Adding ControlPath configuration to SSH config..."
    sed -i.bak "/ControlMaster/a\\
  ControlPath $ssh_control_path/%C
" "$ssh_config"
    mkdir -p "$ssh_control_path"
  fi
}

# Add port forward to ssh_cmd if port is available
# Usage: _ona_add_port_forward <port>
# Modifies: ssh_cmd variable in calling scope
_ona_add_port_forward() {
  local port="$1"
  if lsof -ti :"$port" &> /dev/null; then
    echo "Warning: Port $port is already in use, skipping port forward"
  else
    ssh_cmd="$ssh_cmd -L 127.0.0.1:$port:127.0.0.1:$port"
  fi
}

# SSH into a gitpod environment with proper environment setup
# Usage: ona ssh [-f|--forward-only] [branch-name]
_ona_ssh() {
  local forward_only=false
  local branch_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--forward-only)
        forward_only=true
        shift
        ;;
      *)
        branch_name="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$branch_name" ]]; then
    if command -v fzf &> /dev/null; then
      branch_name=$(ona list | fzf --prompt="Select Environment: " | awk '{print $1;}')
      [[ -z "$branch_name" ]] && return 1
    else
      echo "Please provide a branch name, or install fzf for interactive selection"
      echo "Usage: ona ssh [-f|--forward-only] <branch-name>"
      echo ""
      echo "Available environments:"
      _ona_list
      return 1
    fi
  fi

  local environment_id=$(gitpod environment list -o json | \
    jq -r --arg branch "$branch_name" 'first(.[] | select(.status.content.git.branch == $branch)).id')

  if [[ -z "$environment_id" ]]; then
    echo "Error: Environment with branch '$branch_name' not found"
    echo ""
    echo "Available environments:"
    _ona_list
    return 1
  fi

  _ona_ensure_ssh_config

  if $forward_only; then
    echo "Creating background tunnel to $branch_name (id: $environment_id)..."
  else
    echo "Connecting to $branch_name (id: $environment_id)..."
    [[ -n "$TMUX" ]] && tmux set-option -p @codespace_name "$branch_name"
  fi

  local ssh_cmd="ssh"
  $forward_only && ssh_cmd="$ssh_cmd -f -N"

  _ona_add_port_forward 8080
  _ona_add_port_forward 9000

  eval $ssh_cmd "$environment_id.gitpod.environment"

  if $forward_only; then
    echo "Background tunnel established. Use 'ssh -O exit $environment_id.gitpod.environment' to close."
  else
    [[ -n "$TMUX" ]] && tmux set-option -pu @codespace_name
  fi
}

# Open a new tmux pane and SSH into a gitpod environment
# Usage: ona pane [-h|-v] [branch-name]
_ona_pane() {
  local split_direction="v"
  local branch_name=""

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
        branch_name="$1"
        shift
        ;;
    esac
  done

  tmux split-window -$split_direction "zsh -i -c 'ona ssh $branch_name'"
}

# Show help message
_ona_help() {
  cat <<EOF
Usage: ona <subcommand> [options]

Manage Ona environments with tmux niceties

Subcommands:
  list, ls                     List all Gitpod environments
  ssh [-f|--forward-only] [branch]
                               SSH into an environment (interactive if no branch provided)
                               -f, --forward-only: Create background tunnel without shell
  pane [-h|-v] [branch]        Open a new tmux pane connected to an environment
                               -h: horizontal split
                               -v: vertical split (default)
  help                         Show this help message

Examples:
  ona list                        # List all Gitpod environments
  ona ssh my-branch               # SSH into environment with branch 'my-branch'
  ona ssh -f my-branch            # Create background tunnel to 'my-branch'
  ona pane                        # Open new pane with interactive selection (requires fzf)
  ona pane my-branch              # Open new pane connected to specific branch
  ona pane -v my-branch           # Open new vertical pane connected to specific branch
EOF
}
