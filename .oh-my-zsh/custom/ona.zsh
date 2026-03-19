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
    run)
      _ona_run "$@"
      ;;
    agent-browser|ab)
      _ona_agent_browser "$@"
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

# Add port forward to ssh_cmd if port is available
# Usage: _ona_add_port_forward <port>
# Modifies: ssh_cmd array in calling scope
_ona_add_port_forward() {
  local port="$1"
  if nc -z 127.0.0.1 "$port" 2>/dev/null; then
    echo "Warning: Port $port is already in use, skipping port forward"
  else
    ssh_cmd+=(-L "127.0.0.1:$port:127.0.0.1:$port")
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
    selected=$(ona list | while IFS= read -r line; do
      local entry_name="${line#* }"
      entry_name="${entry_name%%/*}"
      if [[ "$entry_name" == "$name" ]]; then
        echo "$line"
        break
      fi
    done)
    if [[ -z "$selected" ]]; then
      echo "Error: Environment '$name' not found"
      echo ""
      echo "Available environments:"
      _ona_list
      return 1
    fi
  fi

  environment_id="${selected%% *}"
  env_name="${selected#* }"
  env_name="${env_name% - *}"
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
# Usage: ona ssh [-f|--forward [-p port]...] [env-name]
#        ona ssh exit  — close all forwarded port tunnels
_ona_ssh() {
  if [[ "$1" == "exit" ]]; then
    _ona_ssh_exit
    return $?
  fi

  local forward=false
  local name=""
  local -a ports=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--forward)
        forward=true
        shift
        ;;
      -p|--port)
        ports+=("$2")
        shift 2
        ;;
      *)
        name="$1"
        shift
        ;;
    esac
  done

  # Default ports when forwarding is requested but no specific ports given
  if $forward && [[ ${#ports[@]} -eq 0 ]]; then
    ports=(8080 9000 9223)
  fi

  local environment_id env_name
  _ona_select_environment "$name" || return 1


  if $forward; then
    echo "Creating background tunnel to $env_name (id: $environment_id)..."
    local -a ssh_cmd=(ssh -f -N)
    for port in "${ports[@]}"; do
      _ona_add_port_forward "$port"
    done
    "${ssh_cmd[@]}" "$environment_id.gitpod.environment"
    echo "Background tunnel established. Use 'ona ssh exit' to close."
  else
    echo "Connecting to $env_name (id: $environment_id)..."
    ssh "$environment_id.gitpod.environment" -t "tmux new-session -A -s '${env_name}'"
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

  tmux split-window -${split_direction} "zsh -i -c \"ona ssh '${name}'\""
}

# Close all active Gitpod SSH control connections
_ona_ssh_exit() {
  local control_dir="$HOME/.ssh/gitpod/control"
  if [[ ! -d "$control_dir" ]]; then
    echo "No control socket directory found at $control_dir"
    return 0
  fi

  local sockets=("$control_dir"/*(N))
  if [[ ${#sockets[@]} -eq 0 ]]; then
    echo "No active connections found"
    return 0
  fi

  for socket in "${sockets[@]}"; do
    echo "Closing connection: $(basename "$socket")"
    ssh -O exit -S "$socket" dummy 2>/dev/null
  done

  echo "All connections closed"
}

# Run a command on a remote environment via SSH
# Usage: ona run <env-name> <command...>
_ona_run() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: ona run <environment> <command...>"
    return 1
  fi

  local name="$1"
  shift

  local environment_id env_name
  _ona_select_environment "$name" || return 1


  ssh "$environment_id.gitpod.environment" "$@"
}

# Open agent-browser in a remote environment
# Usage: ona agent-browser <env-name> <port>
_ona_agent_browser() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: ona agent-browser <environment> <port>"
    return 1
  fi

  local name="$1"
  local port="$2"

  echo "Checking if local dev server is running on $name..."
  if ! ona run "$name" curl -s -o /dev/null -w '%{http_code}' http://localhost:8080 | grep -q 200; then
    echo "Error: Local dev server is not responding on localhost:8080 in $name"
    return 1
  fi
  echo "Dev server is running."

  echo "Opening agent-browser on port $port..."
  ona run "$name" "AGENT_BROWSER_STREAM_PORT=$port agent-browser open 'http://127.0.0.1:8080/internal/auth/impersonate/5df91759d463fd48218e9f15'"
}

# Show help message
_ona_help() {
  cat <<EOF
Usage: ona <subcommand> [options]

Manage Ona environments with tmux niceties

Subcommands:
  list, ls                     List all Gitpod environments
  start [name]                 Start an environment (interactive if no name provided)
  ssh [-f|--forward] [-p port]... [name]
                               SSH into an environment (interactive if no name provided)
                               -f, --forward: Create background tunnel with port forwarding (no shell)
                               -p, --port: Forward specific port(s) (default: 8080,9000,9223)
  ssh exit                     Close all active SSH tunnels to Ona environments
  pane [-h|-v] [name]          Open a new tmux pane connected to an environment
                               -h: horizontal split
                               -v: vertical split (default)
  run <name> <command...>      Run a command on a remote environment via SSH
  agent-browser, ab <name> <port>
                               Open agent-browser in a remote environment
  help                         Show this help message

Examples:
  ona list                        # List all Gitpod environments
  ona start research              # Start the 'research' environment
  ona ssh research                # SSH into the 'research' environment (no port forwarding)
  ona ssh --forward research      # Create background tunnel to 'research' (default ports)
  ona ssh --forward -p 3000 research  # Tunnel only port 3000 to 'research'
  ona ssh exit                     # Close all active SSH tunnels
  ona pane                        # Open new pane with interactive selection (requires fzf)
  ona pane research               # Open new pane connected to 'research'
  ona run research ls -la         # Run 'ls -la' on the 'research' environment
  ona agent-browser research 9222 # Open agent-browser on port 9222
EOF
}
