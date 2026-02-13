# GitHub PR management functions
# These are automatically loaded by oh-my-zsh on shell startup

# Main prs command with subcommands
prs() {
  local subcommand="${1}"

  # If no argument or argument doesn't match known subcommands, treat as list
  case "$subcommand" in
    list|open|view|help|--help|-h)
      shift
      ;;
    "")
      subcommand="list"
      ;;
    *)
      # Unknown arg - treat as list with team filter for backward compatibility
      subcommand="list"
      ;;
  esac

  case "$subcommand" in
    list)
      _prs_list "$@"
      ;;
    open)
      _prs_open "$@"
      ;;
    view)
      _prs_view "$@"
      ;;
    help|--help|-h)
      _prs_help
      ;;
  esac
}

# List open GitHub PRs where the current user is a reviewer
# Usage: _prs_list [team-name] [--all] [template]
#   team-name: optional filter to show only PRs from authors in that team
#              use "mine" to show PRs authored by you
#   --all: show all PRs from team without filtering by review-requested
#   template: optional custom template (uses default if not provided)
_prs_list() {
  local org="VantaInc"
  local repo="$org/obsidian"
  local team=""
  local all_prs=false
  local template=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        all_prs=true
        shift
        ;;
      *)
        # First non-flag arg is team, second is template
        if [[ -z "$team" ]]; then
          team="$1"
        elif [[ -z "$template" ]]; then
          template="$1"
        fi
        shift
        ;;
    esac
  done

  # Set default template if not provided
  [[ -z "$template" ]] && template=$(cat <<'EOF'
{{range .}}
{{autocolor "white+b" (hyperlink .url (truncate 100 .title))}} {{autocolor "yellow+d" (printf "(#%v)" .number)}}
by {{autocolor "green+b" .author.login}} updated {{timeago .updatedAt}} | {{.reviewDecision}} | {{.mergeable}}
{{autocolor "blue+ud" (hyperlink .url .url)}}
{{end}}
EOF
  )

  local search_query=""

  if [[ "$team" == "mine" ]]; then
    search_query="author:$GITHUB_USER"
  elif [[ -n "$team" ]]; then
    local members=$(gh api "orgs/$org/teams/$team/members" --jq '.[].login' 2>/dev/null)
    [[ -z "$members" ]] && echo "Error: Could not fetch members for team '$team'" >&2 && return 1

    local author_filter=$(echo "$members" | awk '{printf "%sauthor:%s", (NR>1?" OR ":""), $0}')
    if [[ "$all_prs" == "true" ]]; then
      search_query="($author_filter)"
    else
      search_query="($author_filter) review-requested:$GITHUB_USER"
    fi
    echo "Search query:\n$search_query"
  else
    search_query="review-requested:$GITHUB_USER"
  fi

  gh pr list --repo "$repo" --state open --search "$search_query" \
    --json number,title,author,url,updatedAt,mergeable,reviewDecision,state \
    --template "$template"
}

# Open a PR in a GitHub Codespace
# Usage: prs open [team-name] [--dry-run] [pr-number]
#   team-name: optional filter for interactive selection (use "mine" for your authored PRs)
#   --dry-run: print commands instead of executing them
#   pr-number: optional PR number to open directly (ignores team filter, uses fzf if not provided)
_prs_open() {
  local org="VantaInc"
  local repo="$org/obsidian"
  local dry_run=false
  local pr_number=""
  local team=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      *)
        # If it's a number, treat as PR number, otherwise treat as team
        if [[ "$1" =~ ^[0-9]+$ ]]; then
          pr_number="$1"
        else
          team="$1"
        fi
        shift
        ;;
    esac
  done

  # Check for required commands
  command -v gh &> /dev/null || { echo "Error: GitHub CLI (gh) not found. Install from https://cli.github.com" >&2; return 1; }

  # If no PR number provided, use fzf for interactive selection
  if [[ -z "$pr_number" ]]; then
    command -v fzf &> /dev/null || { echo "Error: Please provide a PR number, or install fzf for interactive selection\nUsage: prs open <pr-number>" >&2; return 1; }

    echo "Fetching PRs..."
    local fzf_template='{{range .}}{{.number}}	{{.title}} (by {{.author.login}})
{{end}}'
    local pr_list=$(_prs_list "$team" "$fzf_template")

    [[ -z "$pr_list" ]] && echo "No open PRs found" >&2 && return 1

    local selection=$(echo "$pr_list" | fzf --prompt="Select PR: " --delimiter="\t" --with-nth=2)
    [[ -z "$selection" ]] && echo "No PR selected" >&2 && return 1

    pr_number=$(echo "$selection" | cut -f1)
  fi

  # Fetch PR details
  echo "Fetching PR $pr_number..."
  local pr_data=$(gh pr view "$pr_number" --repo "$repo" --json headRefName,author,title 2>&1) || {
    echo "Error: PR #$pr_number not found or not accessible" >&2
    echo "$pr_data" >&2
    return 1
  }

  echo "$pr_data"

  local branch=$(echo "$pr_data" | jq -r '.headRefName')
  local author=$(echo "$pr_data" | jq -r '.author.login')
  local title=$(echo "$pr_data" | jq -r '.title')

  [[ -n "$branch" && -n "$author" && -n "$title" ]] || { echo "Error: Failed to fetch required PR details" >&2; return 1; }

  local codespace_name="[$pr_number] $author"

  # Check if codespace already exists
  echo "Fetching codespaces..."
  local codespaces_json=$(gh cs list --json name,displayName,state 2>/dev/null)
  local existing_codespace=$(echo "$codespaces_json" | jq -r --arg name "$codespace_name" 'first(.[] | select(.displayName == $name)) | .name')

  if [[ -n "$existing_codespace" ]]; then
    echo "Found existing codespace $codespace_name, opening in VS Code..."
    gh cs code -c "$existing_codespace"
    return $?
  fi

  # Clean up stopped PR codespaces
  echo "Cleaning up stopped PR codespaces..."
  local stopped_prs=$(echo "$codespaces_json" | jq -r '.[] | select(.displayName | startswith("[PR] ")) | select(.state == "Stopped") | .name')

  if [[ -n "$stopped_prs" ]]; then
    local -a stopped_array=("${(@f)stopped_prs}")
    echo "Deleting ${#stopped_array[@]} stopped PR codespace(s)..."
    local current=1
    for cs_name in "${stopped_array[@]}"; do
      echo "  Deleting ($current/${#stopped_array[@]}): $cs_name"
      [[ "$dry_run" == "true" ]] && echo "    [DRY RUN] gh cs delete -c \"$cs_name\" --force" || gh cs delete -c "$cs_name" --force 2>&1 | grep -v "^$" || true
      ((current++))
    done
  fi

  # Create new codespace
  echo "Creating new codespace for PR $pr_number..."
  echo "  Repository: $repo\n  Branch: $branch\n  Name: $codespace_name"

  if [[ "$dry_run" == "true" ]]; then
    echo "[DRY RUN] gh cs create --repo \"$repo\" --branch \"$branch\" --display-name \"$codespace_name\""
    echo "[DRY RUN] gh cs code -c \"<codespace name>\""
    return
  fi

  gh cs create --repo "$repo" --branch "$branch" --display-name "$codespace_name" || {
    echo "Error: Failed to create codespace. Check the error above." >&2
    return 1
  }

  echo "Codespace created and opening in VS Code..."
  local codespace_id=$(gh cs list --json name,displayName | jq -r --arg name "$codespace_name" 'map(select(.displayName == $name)) | .[0].name')
  gh cs code -c "$codespace_id"
}

# View PR details: title, description, and unresolved review threads
# Usage: prs view [team-name] [pr-number]
#   team-name: optional filter for interactive selection (default: "mine" for your authored PRs)
#   pr-number: optional PR number to view directly (uses fzf if not provided)
_prs_view() {
  local org="VantaInc"
  local repo="$org/obsidian"
  local pr_number=""
  local team=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      *)
        if [[ "$1" =~ ^[0-9]+$ ]]; then
          pr_number="$1"
        else
          team="$1"
        fi
        shift
        ;;
    esac
  done

  # Check for required commands
  command -v gh &> /dev/null || { echo "Error: GitHub CLI (gh) not found. Install from https://cli.github.com" >&2; return 1; }
  command -v jq &> /dev/null || { echo "Error: jq not found. Install with: brew install jq" >&2; return 1; }
  command -v glow &> /dev/null || { echo "Error: glow not found. Install with: brew install glow" >&2; return 1; }

  # Default team to "mine" when no arguments provided
  [[ -z "$team" && -z "$pr_number" ]] && team="mine"

  # If no PR number provided, use fzf for interactive selection
  if [[ -z "$pr_number" ]]; then
    command -v fzf &> /dev/null || { echo "Error: Please provide a PR number, or install fzf for interactive selection\nUsage: prs view <pr-number>" >&2; return 1; }

    echo "Fetching PRs..."
    local fzf_template='{{range .}}{{.number}}	{{.title}} (by {{.author.login}})
{{end}}'
    local pr_list=$(_prs_list "$team" "$fzf_template")

    [[ -z "$pr_list" ]] && echo "No open PRs found" >&2 && return 1

    local selection=$(echo "$pr_list" | fzf --prompt="Select PR to view: " --delimiter="\t" --with-nth=2)
    [[ -z "$selection" ]] && echo "No PR selected" >&2 && return 1

    pr_number=$(echo "$selection" | cut -f1)
  fi

  # Fetch and render PR data
  _prs_view_render "$org" "$repo" "$pr_number"
}

_prs_view_render() {
  local org="$1" repo="$2" pr_number="$3"

  echo "Fetching PR #$pr_number..."

  local query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      title
      body
      number
      url
      state
      reviewDecision
      author { login }
      baseRefName
      headRefName
      reviewThreads(first: 100) {
        nodes {
          isResolved
          isOutdated
          path
          line
          comments(first: 50) {
            nodes {
              author { login }
              body
              createdAt
              diffHunk
            }
          }
        }
      }
    }
  }
}'

  local result
  result=$(gh api graphql \
    -f query="$query" \
    -f owner="$org" \
    -f repo="${repo#*/}" \
    -F pr="$pr_number" 2>&1) || {
    echo "Error: Failed to fetch PR #$pr_number" >&2
    echo "$result" >&2
    return 1
  }

  local pr_json=$(jq '.data.repository.pullRequest' <<< "$result")

  [[ "$pr_json" == "null" ]] && { echo "Error: PR #$pr_number not found" >&2; return 1; }

  _prs_view_display "$pr_json"
}

_prs_view_display() {
  local pr_json="$1"

  # Extract metadata
  local title=$(jq -r '.title' <<< "$pr_json")
  local number=$(jq -r '.number' <<< "$pr_json")
  local state=$(jq -r '.state' <<< "$pr_json")
  local review_decision=$(jq -r '.reviewDecision // "PENDING"' <<< "$pr_json")
  local author=$(jq -r '.author.login' <<< "$pr_json")
  local head_ref=$(jq -r '.headRefName' <<< "$pr_json")
  local base_ref=$(jq -r '.baseRefName' <<< "$pr_json")
  local url=$(jq -r '.url' <<< "$pr_json")
  local body=$(jq -r '.body // ""' <<< "$pr_json")

  # Color codes
  local reset='\033[0m'
  local bold_white='\033[1;37m'
  local yellow='\033[0;33m'
  local green='\033[0;32m'
  local red='\033[0;31m'
  local magenta='\033[0;35m'
  local cyan='\033[0;36m'
  local dim='\033[2m'
  local bold='\033[1m'

  # State color
  local state_color
  case "$state" in
    OPEN)   state_color="$green" ;;
    MERGED) state_color="$magenta" ;;
    CLOSED) state_color="$red" ;;
    *)      state_color="$reset" ;;
  esac

  # Review decision color
  local decision_color
  case "$review_decision" in
    APPROVED)          decision_color="$green" ;;
    CHANGES_REQUESTED) decision_color="$red" ;;
    *)                 decision_color="$yellow" ;;
  esac

  # --- Header ---
  echo ""
  echo "  ${bold_white}${title}${reset} ${yellow}(#${number})${reset}  ${state_color}${state}${reset}"
  echo "  ${cyan}${author}:${head_ref}${reset} ${dim}->${reset} ${cyan}${base_ref}${reset}  ${decision_color}${review_decision}${reset}"
  echo "  ${dim}${url}${reset}"
  echo "  ${dim}$(printf '%.0s─' {1..60})${reset}"

  # --- Body ---
  if [[ -n "$body" ]]; then
    echo ""
    printf '%s\n' "$body" | glow -s dark -w 80
    echo ""
  else
    echo "\n  ${dim}No description provided.${reset}\n"
  fi

  # --- Unresolved Threads ---
  local threads_json=$(jq '[.reviewThreads.nodes[] | select(.isResolved == false and .isOutdated == false)]' <<< "$pr_json")
  local thread_count=$(jq 'length' <<< "$threads_json")

  echo "  ${dim}$(printf '%.0s─' {1..60})${reset}"

  if [[ "$thread_count" -eq 0 ]]; then
    echo "  ${green}No unresolved threads${reset}"
    echo ""
    return
  fi

  echo "  ${bold}Unresolved Threads (${thread_count})${reset}"
  echo "  ${dim}$(printf '%.0s─' {1..60})${reset}"

  # Iterate threads
  jq -c '.[]' <<< "$threads_json" | while IFS= read -r thread; do
    local path=$(jq -r '.path' <<< "$thread")
    local line_num=$(jq -r '.line // ""' <<< "$thread")

    echo ""
    if [[ -n "$line_num" && "$line_num" != "null" ]]; then
      echo "  ${bold_white}${path}:${line_num}${reset}"
    else
      echo "  ${bold_white}${path}${reset}"
    fi

    # Show diff hunk from first comment (all comments in a thread share the same hunk)
    local diff_hunk=$(jq -r '.comments.nodes[0].diffHunk // ""' <<< "$thread")
    if [[ -n "$diff_hunk" ]]; then
      echo "  ${dim}┌──${reset}"
      printf '%s\n' "$diff_hunk" | while IFS= read -r hunk_line; do
        local hunk_color="$reset"
        case "$hunk_line" in
          +*) hunk_color="$green" ;;
          -*) hunk_color="$red" ;;
          @@*) hunk_color="$cyan" ;;
        esac
        echo "  ${dim}│${reset} ${hunk_color}${hunk_line}${reset}"
      done
      echo "  ${dim}└──${reset}"
    fi

    # Show comments
    jq -c '.comments.nodes[]' <<< "$thread" | while IFS= read -r comment; do
      local comment_author=$(jq -r '.author.login' <<< "$comment")
      local comment_body=$(jq -r '.body' <<< "$comment")
      local comment_date=$(jq -r '.createdAt' <<< "$comment")

      echo ""
      echo "  ${bold}${comment_author}${reset} ${dim}${comment_date}${reset}"
      printf '%s\n' "$comment_body" | glow -s dark -w 76 | while IFS= read -r rendered_line; do
        echo "  ${rendered_line}"
      done
    done
  done

  echo ""
}

# Show help message
_prs_help() {
  cat <<EOF
Usage: prs <subcommand> [options]

Manage GitHub Pull Requests assigned for review

Subcommands:
  list [team-name] [--all]
                        List open PRs where you are a reviewer
                        team-name: optional filter to show only PRs from authors in that team
                                   use "mine" to show PRs you authored
                        --all: show all PRs from team (without filtering by review-requested)
  open [team-name] [--dry-run] [pr-number]
                        Open a PR in a GitHub Codespace
                        team-name: optional filter for interactive selection (use "mine" for your authored PRs)
                        --dry-run: print commands instead of executing them
                        pr-number: optional PR number (uses fzf for interactive selection if not provided)
  view [team-name] [pr-number]
                        View PR details: title, description, and unresolved threads
                        team-name: optional filter for interactive selection (default: "mine")
                        pr-number: optional PR number (uses fzf for interactive selection if not provided)
  help                  Show this help message

Examples:
  prs                           # List all open PRs where you are a reviewer
  prs backend-team              # List PRs from backend-team members where you're a reviewer
  prs backend-team --all        # List all PRs from backend-team members
  prs list mine                 # List your authored PRs
  prs list                      # Explicitly list PRs
  prs open                      # Interactively select a PR to open (requires fzf)
  prs open mine                 # Interactively select from your authored PRs
  prs open 1234                 # Open PR #1234 in a codespace
  prs open --dry-run 1234       # Preview commands for opening PR #1234 without executing
  prs view 1234                   # View PR #1234 details and unresolved threads
  prs view                        # Interactively select from your PRs to view
  prs view backend-team           # Interactively select from backend-team's PRs to view

Notes:
  - PR codespaces are named: [PR] <author>: <title>
  - Existing codespaces are reused when available
  - Stopped PR codespaces are cleaned up automatically before creating new ones
  - Requires: gh CLI, fzf (for interactive selection)
  - prs view requires: gh CLI, jq, glow, fzf (for interactive selection)
EOF
}
