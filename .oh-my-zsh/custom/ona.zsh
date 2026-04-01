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
    open)
      _ona_open "$@"
      ;;
    run)
      _ona_run "$@"
      ;;
    agent-browser|ab)
      _ona_agent_browser "$@"
      ;;
    new)
      _ona_new "$@"
      ;;
    sync)
      _ona_sync "$@"
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
      "\(.id) \(.metadata.name) - \(.status.phase | sub("ENVIRONMENT_PHASE_"; ""))"'
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
      entry_name="${entry_name% - *}"
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

# Open an environment via SSH or VSCode
# Usage: ona open ssh [-f|--forward [-p port]...] [-n|--name session] [env-name]
#        ona open ssh exit  — close all forwarded port tunnels
#        ona open vscode [env-name]
_ona_open() {
  local mode="$1"
  shift

  case "$mode" in
    ssh)    _ona_open_ssh "$@" ;;
    vscode) _ona_open_vscode "$@" ;;
    *)
      echo "Usage: ona open <ssh|vscode> [options] [env-name]"
      return 1
      ;;
  esac
}

# SSH into a gitpod environment with proper environment setup
_ona_open_ssh() {
  if [[ "$1" == "exit" ]]; then
    _ona_ssh_exit
    return $?
  fi

  local forward=false
  local session_suffix=""
  local name=""
  local -a ports=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--forward)
        forward=true
        shift
        ;;
      -n|--name)
        session_suffix="$2"
        shift 2
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
    echo "Background tunnel established. Use 'ona open ssh exit' to close."
  else
    local session_name="${env_name}"
    [[ -n "$session_suffix" ]] && session_name="${env_name}-${session_suffix}"
    echo "Connecting to $env_name (id: $environment_id)..."
    ssh "$environment_id.gitpod.environment" -t "tmux new-session -A -s '${session_name}'"
  fi
}

# Open a gitpod environment in VSCode
_ona_open_vscode() {
  local environment_id env_name
  _ona_select_environment "$1" || return 1

  echo "Opening $env_name in VSCode..."
  gitpod environment open "$environment_id" --editor vscode --start
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

# Check if an environment with the given name already exists
# Returns 0 if it exists, 1 if not
_ona_environment_exists() {
  local name="$1"
  gitpod environment list -o json 2>/dev/null | \
    jq -e --arg name "$name" '.[] | select(.metadata.name == $name)' >/dev/null 2>&1
}

# Resolve env_name, branch_name, git_cmd for "ona new branch <desc>"
# Sets: env_name, branch_name, git_cmd in calling scope
_ona_new_branch() {
  local desc="$1"
  if [[ -z "$desc" ]]; then
    echo "Usage: ona new branch <short-description>"
    return 1
  fi
  branch_name="weston/$desc"
  env_name="$desc"
  git_cmd="git -C /workspaces/obsidian switch -c '$branch_name'"
}

# Resolve env_name, branch_name, git_cmd for "ona new jira <ticket>"
# Sets: env_name, branch_name, git_cmd in calling scope
_ona_new_jira() {
  local ticket="$1"
  if [[ -z "$ticket" ]]; then
    echo "Usage: ona new jira <ticket-id>"
    return 1
  fi
  echo "Fetching Jira ticket summary..."
  local summary
  summary=$(acli jira workitem view "$ticket" --json | jq -r '.fields.summary')
  if [[ -z "$summary" || "$summary" == "null" ]]; then
    echo "Error: Could not fetch summary for ticket $ticket"
    return 1
  fi
  echo "Ticket: $summary"
  echo "Generating branch name..."
  local desc
  desc=$(printf '%s' "$summary" | claude --model haiku --print "Summarize this Jira ticket title into a short, lowercase, hyphen-separated git branch slug (just the slug, nothing else): ")
  if [[ -z "$desc" ]]; then
    echo "Error: Failed to generate branch name"
    return 1
  fi
  branch_name="weston/$ticket-$desc"
  env_name="$desc"
  echo "Branch: $branch_name"
  git_cmd="git -C /workspaces/obsidian switch -c '$branch_name'"
}

# Resolve env_name, branch_name, git_cmd for "ona new pr <id>"
# Sets: env_name, branch_name, git_cmd in calling scope
_ona_new_pr() {
  local pr_id="$1"
  if [[ -z "$pr_id" ]]; then
    echo "Usage: ona new pr <pr-id>"
    return 1
  fi
  branch_name=$(gh pr view "$pr_id" --repo VantaInc/obsidian --json headRefName -q .headRefName 2>/dev/null)
  if [[ -z "$branch_name" ]]; then
    echo "Error: Could not find PR #$pr_id"
    return 1
  fi
  # Extract short description from branch (everything after last /)
  local short="${branch_name##*/}"
  # Strip leading jira ticket prefix if present (e.g., VANTA-1234-)
  env_name=$(printf '%s' "$short" | sed 's/^[A-Z]\{1,\}-[0-9]\{1,\}-//')
  [[ -z "$env_name" ]] && env_name="pr-$pr_id"
  echo "PR #$pr_id → branch: $branch_name"
  git_cmd="git -C /workspaces/obsidian switch '$branch_name'"
}

# Create a new Ona environment and switch to a branch
# Usage: ona new [-o|--open] branch <short-description>
#        ona new [-o|--open] jira <ticket-id>
#        ona new [-o|--open] pr <pr-id>
#        ona new [-o|--open] main [name]
_ona_new() {
  local open_in_vscode=false

  if [[ "$1" == "-o" || "$1" == "--open" ]]; then
    open_in_vscode=true
    shift
  fi

  local mode="$1"
  shift

  local env_name="" branch_name="" git_cmd=""

  case "$mode" in
    branch) _ona_new_branch "$@" || return 1 ;;
    jira)   _ona_new_jira "$@"   || return 1 ;;
    pr)     _ona_new_pr "$@"     || return 1 ;;
    main)   env_name="${1:-main}" ;;
    *)
      echo "Usage: ona new [-o|--open] <branch <desc>|jira <ticket>|pr <id>|main [name]>"
      return 1
      ;;
  esac

  if _ona_environment_exists "$env_name"; then
    echo "Error: Environment '$env_name' already exists"
    return 1
  fi

  local project_id="01992fca-c2a8-74d0-92dc-c356e45266ce"
  local class_id="019b3484-f550-77bc-8c28-86627185b6a3"

  echo "Creating environment '$env_name'..."
  if ! gitpod environment create "$project_id" \
    --name "$env_name" \
    --class-id "$class_id" \
    --logs 2>&1; then
    echo "Error: Failed to create environment"
    return 1
  fi

  if [[ -n "$git_cmd" ]]; then
    echo "Switching to branch $branch_name..."
    if ! ona run "$env_name" "$git_cmd"; then
      echo "Error: Failed to switch branch"
      return 1
    fi
  fi

  echo "Initializing ai-dev knowledge tracking..."
  ona run "$env_name" "cd /workspaces/obsidian && zsh -c 'source ~/.zshrc && ai init https://github.com/weston-vanta/obsidian-ai-dev/tree/main/.ai-dev'"

  if $open_in_vscode; then
    ona open vscode "$env_name"
  else
    echo "Connecting..."
    ona open ssh "$env_name"
  fi
}

# Pull latest main into ~/dotfiles, preserving working state
_ona_sync_local() {
  cd ~/dotfiles 2>/dev/null || { echo "SKIP: ~/dotfiles not found"; return 0; }

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  local dirty=false
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    dirty=true
    git stash --quiet || { echo "ERROR: failed to stash"; return 1; }
  fi

  if [[ "$branch" != "main" ]]; then
    git checkout main --quiet || { echo "ERROR: failed to checkout main"; return 1; }
  fi

  local before after
  before=$(git rev-parse --short HEAD)
  git pull --rebase origin main 2>&1
  local pull_rc=$?
  after=$(git rev-parse --short HEAD)

  if [[ "$branch" != "main" ]]; then
    git checkout "$branch" --quiet || echo "WARNING: failed to return to $branch"
  fi

  if $dirty; then
    git stash pop --index --quiet || echo "WARNING: failed to pop stash"
  fi

  if [[ $pull_rc -ne 0 ]]; then
    echo "ERROR: pull failed"
    return 1
  elif [[ "$before" == "$after" ]]; then
    echo "OK: already up to date ($before)"
  else
    echo "OK: updated $before → $after"
  fi
}

# Sync dotfiles locally or across all running environments
# Usage: ona sync [all]
_ona_sync() {
  if [[ "$1" != "all" ]]; then
    _ona_sync_local
    return $?
  fi

  local env_json
  env_json=$(gitpod environment list -o json) || { echo "Failed to list environments"; return 1; }

  local -a ids names
  while IFS=$'\t' read -r id name; do
    ids+=("$id")
    names+=("$name")
  done < <(printf '%s' "$env_json" | jq -r '.[] | select(.status.phase == "ENVIRONMENT_PHASE_RUNNING") | [.id, .metadata.name] | @tsv')

  if [[ ${#ids[@]} -eq 0 ]]; then
    echo "No running environments found"
    return 0
  fi

  echo "Syncing dotfiles to ${#ids[@]} running environment(s)..."
  echo ""

  local failed=0
  for i in {1..${#ids[@]}}; do
    local id="${ids[$i]}"
    local name="${names[$i]}"
    local host="${id}.gitpod.environment"

    printf "%-20s " "$name"

    local output
    output=$(ssh "$host" 'zsh -s' < <(typeset -f _ona_sync_local; echo '_ona_sync_local') 2>&1)

    if [[ $? -ne 0 ]]; then
      echo "ERROR: ssh failed"
      ((failed++))
    else
      echo "$output"
    fi
  done

  [[ $failed -gt 0 ]] && return 1
  return 0
}

# Show help message
_ona_help() {
  cat <<EOF
Usage: ona <subcommand> [options]

Manage Ona environments with tmux niceties

Subcommands:
  list, ls                     List all Gitpod environments
  start [name]                 Start an environment (interactive if no name provided)
  open ssh [-f|--forward] [-p port]... [-n|--name session] [name]
                               SSH into an environment (interactive if no name provided)
                               -f, --forward: Create background tunnel with port forwarding (no shell)
                               -n, --name: Suffix for tmux session name (<env>-<session>)
                               -p, --port: Forward specific port(s) (default: 8080,9000,9223)
  open ssh exit                Close all active SSH tunnels to Ona environments
  open vscode [name]           Open an environment in VSCode
  new [-o|--open] branch <desc>  Create environment, branch weston/<desc>
  new [-o|--open] jira <ticket-id>
                               Create environment, branch from Jira ticket
  new [-o|--open] pr <pr-id>   Create environment on PR's branch
  new [-o|--open] main [name]  Create environment on main (default name: main)
                               -o, --open: open in VSCode instead of SSH
  run <name> <command...>      Run a command on a remote environment via SSH
  agent-browser, ab <name> <port>
                               Open agent-browser in a remote environment
  sync                         Pull latest dotfiles locally (~/dotfiles)
  sync all                     Pull latest dotfiles on all running environments
  help                         Show this help message

Examples:
  ona list                        # List all Gitpod environments
  ona start research              # Start the 'research' environment
  ona open ssh research                # SSH into the 'research' environment
  ona open ssh --name debug research   # Session named 'research/main-debug'
  ona open ssh --forward research      # Create background tunnel (default ports)
  ona open ssh --forward -p 3000 research  # Tunnel only port 3000
  ona open ssh exit                    # Close all active SSH tunnels
  ona open vscode research             # Open 'research' in VSCode
  ona run research ls -la         # Run 'ls -la' on the 'research' environment
  ona agent-browser research 9222 # Open agent-browser on port 9222
  ona new branch fix-auth-bug         # Create env, branch weston/fix-auth-bug, SSH in
  ona new -o branch fix-auth-bug     # Same but open in VSCode
  ona new jira VANTA-1234            # Create env from Jira ticket title
  ona new pr 567                     # Create env on PR #567's branch
  ona new main                       # Create env 'main' on main branch
  ona sync                        # Pull latest dotfiles locally
  ona sync all                    # Pull latest dotfiles on all running envs
EOF
}
