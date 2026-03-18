# AI knowledge management functions
# These are automatically loaded by oh-my-zsh on shell startup

# Main ai command with subcommands
ai() {
  local subcommand="${1}"
  shift

  case "$subcommand" in
    init)
      _ai_init "$@"
      ;;
    update)
      _ai_update "$@"
      ;;
    sync)
      _ai_sync "$@"
      ;;
    git)
      _ai_git "$@"
      ;;
    help|--help|-h|"")
      _ai_help
      ;;
    *)
      echo "Unknown subcommand: $subcommand"
      echo ""
      _ai_help
      return 1
      ;;
  esac
}

# --- Helpers ---

# Get the git repository root
_ai_repo_root() {
  git rev-parse --show-toplevel
}

# Run git commands against the .git-ai secondary git directory
_ai_git() {
  git --git-dir="$(_ai_repo_root)/.git-ai" --work-tree="$(_ai_repo_root)" "$@"
}

# Stage all .ai-dev files visible to the shadow repo
# Returns 1 if nothing was staged
_ai_stage() {
  local files
  files=$(_ai_git status -u --porcelain | sed -n 's/^.. //p' | grep '\.ai-dev/')
  [[ -n "$files" ]] || return 1
  printf '%s\n' "$files" | while IFS= read -r f; do _ai_git add -- "$f"; done
}

# Derive the Claude Code transcript directory for the current repo
# Convention: take absolute repo root path and replace all / with -
# E.g. /Users/weston/Workspaces/myproject -> ~/.claude/projects/-Users-weston-Workspaces-myproject
_ai_transcript_dir() {
  local repo_root
  repo_root="$(_ai_repo_root)" || return 1
  local dir_name="${repo_root//\//-}"
  echo "$HOME/.claude/projects/$dir_name"
}

# Pre-process a Claude Code transcript file for LLM consumption
# Usage: _ai_preprocess_transcript "/path/to/transcript.jsonl"
# Outputs cleaned JSONL to stdout
_ai_preprocess_transcript() {
  local transcript_path="$1"

  read -r -d '' jq_filter <<'JQ' || true
select(.type == "assistant" or .type == "user")
| {type, timestamp, message: .message}
| .message |= (del(.usage, .id, .model, .stop_reason, .stop_sequence, .type) // .)
| if (.message.content | type) == "array" then
    .message.content |= [.[] |
      if .type == "thinking" then
        {type, thinking: .thinking[:500]}
      elif .type == "tool_use" then
        {type, name, input: (.input | with_entries(
          if (.value | type) == "string" and (.value | length) > 500 then
            .value = .value[:500] + "...[truncated]"
          else . end
        ))}
      elif .type == "tool_result" then
        {type, tool_use_id} +
        if (.content | tostring | length) > 2000 then
          {content_truncated: (.content | tostring[:2000] + "...")}
        else {content} end
      else . end
    ]
  else . end
JQ

  jq -c "$jq_filter" "$transcript_path"
}

# --- Subcommands ---

# Ensure .git-ai and .ai-dev are excluded from the main repo
_ai_ensure_main_excludes() {
  local exclude_file="$(_ai_repo_root)/.git/info/exclude"
  local entry
  for entry in ".git-ai" ".ai-dev"; do
    grep -qxF "$entry" "$exclude_file" 2>/dev/null || echo "$entry" >> "$exclude_file"
  done
}

# Auto-init: initialize if needed, or just ensure excludes are current
_ai_ensure_init() {
  if [[ ! -d "$(_ai_repo_root)/.git-ai" ]]; then
    _ai_init
  else
    _ai_ensure_main_excludes
  fi
}

# Initialize the .git-ai shadow repo
_ai_init() {
  local repo_root
  repo_root="$(_ai_repo_root)" || return 1
  cd "$repo_root" || return 1

  if [[ -d ".git-ai" ]]; then
    echo "Shadow repo already initialized at .git-ai"
    return 0
  fi

  git init --bare .git-ai

  cat > .git-ai/info/exclude <<'EXCLUDE'
# Exclude all files
*
# Allow directory traversal
!*/
# Re-include .ai-dev and contents (root and nested)
!.ai-dev
!.ai-dev/**
!**/.ai-dev
!**/.ai-dev/**
# Block traversal into heavy/irrelevant directories
node_modules/
.git/
.vscode/
.claude/
EXCLUDE

  _ai_ensure_main_excludes

  local remote_url
  vared -p "Remote URL for shadow repo (blank to skip): " -c remote_url
  if [[ -n "$remote_url" ]]; then
    _ai_git remote add origin "$remote_url"
  fi

  if _ai_stage; then
    _ai_git commit -m "ai: initial knowledge import"
  fi

  echo "Shadow repo initialized at .git-ai"
}

_ai_update() {
  _ai_ensure_init

  local repo_root
  repo_root="$(_ai_repo_root)" || return 1
  cd "$repo_root" || return 1

  local transcript_dir
  transcript_dir="$(_ai_transcript_dir)" || return 1

  if [[ ! -d "$transcript_dir" ]]; then
    echo "No Claude Code transcripts found for this project"
    return 0
  fi

  # Find transcripts, optionally filtering by last-update timestamp or provided date
  local -a transcripts
  local since_date="$1"
  local newer_ref=""

  if [[ -n "$since_date" ]]; then
    # Validate YYYY-MM-DD format
    if [[ ! "$since_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      echo "Error: date must be in YYYY-MM-DD format"
      return 1
    fi
    newer_ref=$(mktemp)
    trap "rm -f '$newer_ref'" EXIT
    if [[ "$OSTYPE" == darwin* ]]; then
      touch -t "$(date -j -f '%Y-%m-%d' "$since_date" '+%Y%m%d0000')" "$newer_ref"
    else
      touch -d "$since_date" "$newer_ref"
    fi
  elif [[ -f ".ai-dev/.last-update" ]]; then
    newer_ref=".ai-dev/.last-update"
  fi

  # Collect .jsonl files sorted oldest-first, optionally filtered by date
  if [[ -n "$newer_ref" ]]; then
    transcripts=( ${transcript_dir}/*.jsonl(N.e{'[[ $REPLY -nt '$newer_ref' ]]'}Om) )
  else
    transcripts=( ${transcript_dir}/*.jsonl(N.Om) )
  fi

  [[ -n "$since_date" ]] && rm -f "$newer_ref" && trap - EXIT

  if [[ ${#transcripts[@]} -eq 0 ]]; then
    echo "No new transcripts to process"
    return 0
  fi

  echo "Processing ${#transcripts[@]} new transcript(s)..."

  # Read the extraction prompt from the dotfiles repo
  local prompt prompt_file
  local script_dir="${${(%):-%x}:A:h}"
  prompt_file="${script_dir:h:h}/.claude/prompts/knowledge-extraction.md"
  if [[ ! -f "$prompt_file" ]]; then
    echo "Error: knowledge extraction prompt not found at $prompt_file"
    return 1
  fi
  prompt=$(cat "$prompt_file")

  for transcript in "${transcripts[@]}"; do
    echo "  Processing: $(basename "$transcript")..."
    if ! _ai_preprocess_transcript "$transcript" | claude -p --permission-mode acceptEdits "$prompt"; then
      echo "  Warning: Failed to process $(basename "$transcript")"
      continue
    fi
  done

  mkdir -p .ai-dev && date '+%Y-%m-%d' > .ai-dev/.last-update && touch .ai-dev/.last-update

  echo "Done. Updated .ai-dev/knowledge.md files."
}

_ai_sync() {
  _ai_ensure_init

  local repo_root
  repo_root="$(_ai_repo_root)" || return 1
  cd "$repo_root" || return 1

  _ai_stage

  if _ai_git diff --cached --quiet; then
    echo "Nothing to sync."
    return 0
  fi

  # Generate commit message
  local first_line="ai: update knowledge $(date '+%Y-%m-%d %H:%M')"

  local diff description
  diff=$(_ai_git diff --cached)
  description=$(printf '%s' "$diff" | claude -p "Summarize the following knowledge file changes in 1-2 concise sentences. Output ONLY the summary, no preamble." 2>/dev/null) || description=""

  local commit_msg="$first_line"
  if [[ -n "$description" ]]; then
    commit_msg="${first_line}

${description}"
  fi

  _ai_git commit -m "$commit_msg"

  if _ai_git remote get-url origin &>/dev/null; then
    _ai_git push origin HEAD
  else
    echo "No remote configured. Run: ai init to add one."
  fi

  echo "Synced."
}

# --- Help ---

# Show help message
_ai_help() {
  cat <<EOF
Usage: ai <subcommand> [options]

Manage AI knowledge for the current repository

Subcommands:
  init                         Initialize .git-ai tracking for the current repo
  update [YYYY-MM-DD]          Process new transcripts and update knowledge
  sync                         Commit and push knowledge to the ai branch
  git <args>                   Run git commands against the .git-ai shadow repo
  help                         Show this help message

Examples:
  ai init                         # Initialize AI knowledge tracking
  ai update                       # Process new transcripts into knowledge
  ai update 2025-01-15            # Process all transcripts since Jan 15, 2025
  ai sync                         # Commit and push knowledge updates
EOF
}
