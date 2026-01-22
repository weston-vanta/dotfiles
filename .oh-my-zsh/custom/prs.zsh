# GitHub PR management functions
# These are automatically loaded by oh-my-zsh on shell startup

# Main prs command with subcommands
prs() {
  local subcommand="${1}"

  # If no argument or argument doesn't match known subcommands, treat as list
  case "$subcommand" in
    list|open|help|--help|-h)
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

Notes:
  - PR codespaces are named: [PR] <author>: <title>
  - Existing codespaces are reused when available
  - Stopped PR codespaces are cleaned up automatically before creating new ones
  - Requires: gh CLI, fzf (for interactive selection)
EOF
}
