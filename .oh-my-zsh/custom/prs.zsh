# GitHub PR management functions
# These are automatically loaded by oh-my-zsh on shell startup

# Main prs command with subcommands
prs() {
  local subcommand="$1"

  case "$subcommand" in
    list|open|view)
      shift
      "_prs_$subcommand" "$@"
      ;;
    help|--help|-h)
      _prs_help
      ;;
    "")
      _prs_list
      ;;
    *)
      # Unknown arg - treat as list with team filter for backward compatibility
      _prs_list "$@"
      ;;
  esac
}

# Interactively select a PR using fzf
# Usage: _prs_select_fzf <prompt> [team-name]
#   Prints the selected PR number to stdout, or returns 1 if none selected
_prs_select_fzf() {
  local prompt="$1"
  local team="$2"

  command -v fzf &> /dev/null || {
    echo "Error: Please provide a PR number, or install fzf for interactive selection" >&2
    return 1
  }

  echo "Fetching PRs..." >&2
  local fzf_template='{{range .}}{{.number}}	{{.title}} (by {{.author.login}})
{{end}}'
  local pr_list=$(_prs_list "$team" "$fzf_template")

  [[ -z "$pr_list" ]] && { echo "No open PRs found" >&2; return 1; }

  local selection=$(echo "$pr_list" | fzf --prompt="$prompt" --delimiter="\t" --with-nth=2)
  [[ -z "$selection" ]] && { echo "No PR selected" >&2; return 1; }

  echo "$selection" | cut -f1
}

# Print a horizontal separator line
_prs_separator() {
  echo "  \033[2m$(printf '%.0s─' {1..60})\033[0m"
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

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        all_prs=true
        shift
        ;;
      *)
        if [[ -z "$team" ]]; then
          team="$1"
        elif [[ -z "$template" ]]; then
          template="$1"
        fi
        shift
        ;;
    esac
  done

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

# Switch to a PR branch and save PR context file
# Usage: prs open [team-name] [pr-number]
#   team-name: optional filter for interactive selection (use "mine" for your authored PRs)
#   pr-number: optional PR number to open directly (uses fzf if not provided)
_prs_open() {
  local pr_number=""
  local team=""

  while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ ^[0-9]+$ ]]; then
      pr_number="$1"
    else
      team="$1"
    fi
    shift
  done

  command -v gh &> /dev/null || { echo "Error: GitHub CLI (gh) not found" >&2; return 1; }

  if [[ -z "$pr_number" ]]; then
    pr_number=$(_prs_select_fzf "Select PR to open: " "$team") || return 1
  fi

  # Fetch branch name
  local branch
  branch=$(gh pr view "$pr_number" --json headRefName --jq '.headRefName' 2>&1) || {
    echo "Error: Could not fetch PR #$pr_number" >&2
    echo "$branch" >&2
    return 1
  }

  # Fetch and switch to branch
  git fetch origin "$branch" || { echo "Error: Failed to fetch branch '$branch'" >&2; return 1; }

  git switch "$branch" || {
    echo "Error: Failed to switch to '$branch'. Stash or commit changes first." >&2
    return 1
  }

  # Save PR context
  local context_file="PR_CONTEXT.md"
  prs view "$pr_number" | sed $'s/\033\[[0-9;]*m//g' > "$context_file"
  echo "Switched to '$branch' — PR context saved to $context_file"
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

  while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ ^[0-9]+$ ]]; then
      pr_number="$1"
    else
      team="$1"
    fi
    shift
  done

  command -v gh &> /dev/null || { echo "Error: GitHub CLI (gh) not found. Install from https://cli.github.com" >&2; return 1; }
  command -v jq &> /dev/null || { echo "Error: jq not found. Install with: brew install jq" >&2; return 1; }
  command -v glow &> /dev/null || { echo "Error: glow not found. Install with: brew install glow" >&2; return 1; }

  # Default team to "mine" when no arguments provided
  [[ -z "$team" && -z "$pr_number" ]] && team="mine"

  if [[ -z "$pr_number" ]]; then
    pr_number=$(_prs_select_fzf "Select PR to view: " "$team") || return 1
  fi

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
  _prs_separator

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

  _prs_separator

  if [[ "$thread_count" -eq 0 ]]; then
    echo "  ${green}No unresolved threads${reset}"
    echo ""
    return
  fi

  echo "  ${bold}Unresolved Threads (${thread_count})${reset}"
  _prs_separator

  jq -c '.[]' <<< "$threads_json" | while IFS= read -r thread; do
    local file_path=$(jq -r '.path' <<< "$thread")
    local line_num=$(jq -r '.line // ""' <<< "$thread")

    echo ""
    if [[ -n "$line_num" && "$line_num" != "null" ]]; then
      echo "  ${bold_white}${file_path}:${line_num}${reset}"
    else
      echo "  ${bold_white}${file_path}${reset}"
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
  open [team-name] [pr-number]
                        Switch to a PR branch and save context file (PR_CONTEXT.md)
                        team-name: optional filter for interactive selection (use "mine" for your authored PRs)
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
  prs open                      # Interactively select a PR to check out (requires fzf)
  prs open mine                 # Interactively select from your authored PRs
  prs open 1234                 # Switch to PR #1234's branch and save context
  prs view 1234                 # View PR #1234 details and unresolved threads
  prs view                      # Interactively select from your PRs to view
  prs view backend-team         # Interactively select from backend-team's PRs to view

Notes:
  - prs open saves PR context to PR_CONTEXT.md in the repo root (add to .gitignore)
  - Requires: gh CLI, fzf (for interactive selection)
  - prs view requires: gh CLI, jq, glow, fzf (for interactive selection)
EOF
}
