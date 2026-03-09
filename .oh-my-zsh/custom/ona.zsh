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
    start)
      _ona_start "$@"
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
    jq -r '.[] |
      (.status.content.git.branch // "unknown") as $branch |
      "\(.id) \(.metadata.name)/\($branch) - \(.status.phase | sub("ENVIRONMENT_PHASE_"; ""))"'
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
  if nc -z 127.0.0.1 "$port" 2>/dev/null; then
    echo "Warning: Port $port is already in use, skipping port forward"
  else
    ssh_cmd="$ssh_cmd -L 127.0.0.1:$port:127.0.0.1:$port"
  fi
}

# Select an environment from `ona list`, by name or fzf
# Sets: environment_id, env_name in calling scope
# Usage: _ona_select_environment [env-name]
_ona_select_environment() {
  local name="$1"
  local selected

  if [[ -z "$name" ]]; then
    if command -v fzf &> /dev/null; then
      selected=$(ona list | fzf --prompt="Select Environment: ")
      [[ -z "$selected" ]] && return 1
    else
      echo "Please provide an environment name, or install fzf for interactive selection"
      echo ""
      echo "Available environments:"
      _ona_list
      return 1
    fi
  else
    selected=$(ona list | awk -v name="$name" '{split($2, a, "/"); if (a[1] == name) {print; exit}}')
    if [[ -z "$selected" ]]; then
      echo "Error: Environment '$name' not found"
      echo ""
      echo "Available environments:"
      _ona_list
      return 1
    fi
  fi

  environment_id=$(awk '{print $1}' <<< "$selected")
  env_name=$(awk '{print $2}' <<< "$selected")
}

# Start a gitpod environment
# Usage: ona start [env-name]
_ona_start() {
  local environment_id env_name
  _ona_select_environment "$1" || return 1

  echo "Starting $env_name (id: $environment_id)..."
  gitpod environment start "$environment_id"
}

# SSH into a gitpod environment with proper environment setup
# Usage: ona ssh [-f|--forward-only] [env-name]
_ona_ssh() {
  local forward_only=false
  local name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--forward-only)
        forward_only=true
        shift
        ;;
      *)
        name="$1"
        shift
        ;;
    esac
  done

  local environment_id env_name
  _ona_select_environment "$name" || return 1

  _ona_ensure_ssh_config

  if $forward_only; then
    echo "Creating background tunnel to $env_name (id: $environment_id)..."
  else
    echo "Connecting to $env_name (id: $environment_id)..."
    [[ -n "$TMUX" ]] && tmux set-option -p @remote_env_name "$env_name"
  fi

  local ssh_cmd="ssh"
  $forward_only && ssh_cmd="$ssh_cmd -f -N"

  _ona_add_port_forward 8080
  _ona_add_port_forward 9000
  _ona_add_port_forward 9223

  eval $ssh_cmd "$environment_id.gitpod.environment"

  if $forward_only; then
    echo "Background tunnel established. Use 'ssh -O exit $environment_id.gitpod.environment' to close."
  else
    [[ -n "$TMUX" ]] && tmux set-option -pu @remote_env_name
  fi
}

# Open a new tmux pane and SSH into a gitpod environment
# Usage: ona pane [-h|-v] [env-name]
_ona_pane() {
  local split_direction="v"
  local name=""

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
        name="$1"
        shift
        ;;
    esac
  done

  tmux split-window -$split_direction "zsh -i -c 'ona ssh $name'"
}

# Show help message
_ona_help() {
  cat <<EOF
Usage: ona <subcommand> [options]

Manage Ona environments with tmux niceties

Subcommands:
  list, ls                     List all Gitpod environments
  start [name]                 Start an environment (interactive if no name provided)
  ssh [-f|--forward-only] [name]
                               SSH into an environment (interactive if no name provided)
                               -f, --forward-only: Create background tunnel without shell
  pane [-h|-v] [name]          Open a new tmux pane connected to an environment
                               -h: horizontal split
                               -v: vertical split (default)
  help                         Show this help message

Examples:
  ona list                        # List all Gitpod environments
  ona start research              # Start the 'research' environment
  ona ssh research                # SSH into the 'research' environment
  ona ssh -f research             # Create background tunnel to 'research'
  ona pane                        # Open new pane with interactive selection (requires fzf)
  ona pane research               # Open new pane connected to 'research'
EOF
}
