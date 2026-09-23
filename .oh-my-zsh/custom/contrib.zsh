# Contribution reporting functions
# These are automatically loaded by oh-my-zsh on shell startup

# Main contrib command with subcommands
contrib() {
  local subcommand="$1"

  case "$subcommand" in
    prs|report)
      shift
      _contrib_prs "$@"
      ;;
    reviews)
      shift
      _contrib_reviews "$@"
      ;;
    help|--help|-h)
      _contrib_help
      ;;
    *)
      # Bare invocation (or a leading username) is a PR report
      _contrib_prs "$@"
      ;;
  esac
}

# Default org used when --repo is omitted or given as a bare repo name
_CONTRIB_ORG="VantaInc"

# Print a horizontal separator line
_contrib_separator() {
  printf '  \033[2m%s\033[0m\n' "$(printf '%.0s─' {1..62})"
}

# Insert thousands separators into an integer
# Usage: _contrib_commify 42318  ->  42,318
_contrib_commify() {
  printf '%s' "$1" | sed -e :a -e 's/\(.*[0-9]\)\([0-9]\{3\}\)/\1,\2/;ta'
}

# Repo to report on when --repo is omitted: the current directory's repo,
# falling back to the org's main monorepo
_contrib_default_repo() {
  local repo
  repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
  [[ -n "$repo" ]] && { printf '%s\n' "$repo"; return 0; }
  printf '%s\n' "$_CONTRIB_ORG/obsidian"
}

# jq program that aggregates a merged-PR list into the PR report summary
_contrib_prs_jq_program() {
  cat <<'JQ'
def median:
  sort
  | if length == 0 then 0
    elif length % 2 == 1 then .[length / 2 | floor]
    else (.[length / 2 - 1] + .[length / 2]) / 2
    end;

($opened | length) as $openedCount
| ($opened | map(select(.mergedAt != null)) | length) as $openedMerged
| ($opened | map(select(.state == "CLOSED")) | length) as $openedClosed
| ($opened | map(select(.state == "OPEN")) | length) as $openedOpen
| (map(.additions + .deletions)) as $lines
| {
    user: $user,
    repo: $repo,
    base: $base,
    since: $since,
    months: $months,
    mergedPrs: length,
    openedPrs: $openedCount,
    openedMerged: $openedMerged,
    openedClosed: $openedClosed,
    openedOpen: $openedOpen,
    mergeRate: (if $openedCount == 0 then null else ($openedMerged / $openedCount) end),
    additions: (map(.additions) | add // 0),
    deletions: (map(.deletions) | add // 0),
    filesChanged: (map(.changedFiles) | add // 0),
    linesTouched: ($lines | add // 0),
    avgLinesPerPr: (if length == 0 then 0 else (($lines | add) / length) end),
    medianLinesPerPr: ($lines | median),
    largestPr: (
      sort_by(.additions + .deletions)
      | last
      | if . == null then null
        else { number, title, url, lines: (.additions + .deletions) }
        end
    ),
    byMonth: (
      group_by(.mergedAt[0:7])
      | map({
          month: .[0].mergedAt[0:7],
          prs: length,
          additions: (map(.additions) | add),
          deletions: (map(.deletions) | add),
          linesTouched: (map(.additions + .deletions) | add)
        })
      | sort_by(.month)
    )
  }
JQ
}

# Fetch PRs matching a search, retrying transient GitHub failures
# Usage: _contrib_fetch_prs <repo> <state> <json-fields> <search-query>
#   Prints the PR list JSON to stdout, or returns 1 after exhausting retries
_contrib_fetch_prs() {
  local repo="$1" state="$2" fields="$3" search="$4"
  local attempt result

  # Heavy GraphQL queries (additions/deletions across many PRs) 502 intermittently
  for attempt in 1 2 3; do
    result=$(gh pr list --repo "$repo" --state "$state" --limit 1000 \
      --search "$search" \
      --json "$fields" 2>&1)

    # gh can exit 0 while emitting an HTTP error, so validate the payload itself
    if jq -e 'type == "array"' <<< "$result" &> /dev/null; then
      printf '%s\n' "$result"
      return 0
    fi
  done

  echo "Error: Failed to fetch PRs for '$repo' after 3 attempts" >&2
  printf '%s\n' "$result" >&2
  return 1
}

# Parse the options every subcommand shares, then resolve defaults.
# Assigns to the caller's `user months repo base output_json` locals, which zsh
# scopes dynamically. Returns 2 when help was shown, 1 on a usage error.
_contrib_parse_opts() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--months)
        months="$2"
        shift 2
        ;;
      -r|--repo)
        repo="$2"
        shift 2
        ;;
      -b|--base|--branch)
        base="$2"
        shift 2
        ;;
      --json)
        output_json=true
        shift
        ;;
      -h|--help)
        _contrib_help
        return 2
        ;;
      -*)
        echo "Unknown option: $1" >&2
        echo "" >&2
        _contrib_help >&2
        return 1
        ;;
      *)
        user="$1"
        shift
        ;;
    esac
  done

  command -v gh &> /dev/null || { echo "Error: GitHub CLI (gh) not found. Install from https://cli.github.com" >&2; return 1; }
  command -v jq &> /dev/null || { echo "Error: jq not found. Install with: brew install jq" >&2; return 1; }

  [[ "$months" =~ ^[0-9]+$ && "$months" -gt 0 ]] || {
    echo "Error: --months must be a positive integer (got '$months')" >&2
    return 1
  }

  [[ -z "$user" ]] && user="${GITHUB_USER:-$(gh api user --jq '.login' 2>/dev/null)}"
  [[ -z "$user" ]] && {
    echo "Error: Could not determine a GitHub user. Pass one explicitly: contrib <user>" >&2
    return 1
  }

  [[ -z "$repo" ]] && repo=$(_contrib_default_repo)
  # A bare repo name is qualified with the default org
  [[ "$repo" != */* ]] && repo="$_CONTRIB_ORG/$repo"

  if [[ -z "$base" ]]; then
    base=$(gh repo view "$repo" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null)
    [[ -z "$base" ]] && {
      echo "Error: Could not resolve the default branch for '$repo'. Pass one with --base." >&2
      return 1
    }
  fi

  return 0
}

# Report merged PRs, merge rate, and lines touched on the base branch by a user
# Usage: contrib prs [user] [-m <months>] [-r <owner/repo>] [-b <branch>] [--json]
_contrib_prs() {
  local user="" months=6 repo="" base="" output_json=false

  _contrib_parse_opts "$@"
  case $? in
    2) return 0 ;;
    0) ;;
    *) return 1 ;;
  esac

  local since=$(date -v-${months}m +%Y-%m-%d)

  [[ "$output_json" == false ]] && echo "Fetching PRs for $user in $repo since $since..." >&2

  # Two populations: PRs merged in the window (the line-count metrics) and PRs
  # opened in the window (the merge-rate denominator)
  local prs opened
  prs=$(_contrib_fetch_prs "$repo" merged \
    number,title,url,additions,deletions,changedFiles,mergedAt \
    "author:$user base:$base merged:>=$since") || return 1
  opened=$(_contrib_fetch_prs "$repo" all \
    number,state,createdAt,mergedAt \
    "author:$user base:$base created:>=$since") || return 1

  local summary
  summary=$(jq \
    --arg user "$user" \
    --arg repo "$repo" \
    --arg base "$base" \
    --arg since "$since" \
    --argjson months "$months" \
    --argjson opened "$opened" \
    "$(_contrib_prs_jq_program)" <<< "$prs") || return 1

  # GitHub's search API caps results at 1000 — say so rather than silently truncating
  [[ "$(jq -r '.mergedPrs' <<< "$summary")" == "1000" || "$(jq -r '.openedPrs' <<< "$summary")" == "1000" ]] && \
    echo "Warning: hit GitHub's 1000-result search cap; totals are a lower bound. Try a smaller --months." >&2

  if [[ "$output_json" == true ]]; then
    printf '%s\n' "$summary"
  else
    _contrib_prs_display "$summary"
  fi
}

# Render the PR report summary for the terminal
_contrib_prs_display() {
  local summary="$1"

  local reset=$'\033[0m'
  local bold_white=$'\033[1;37m'
  local green=$'\033[0;32m'
  local red=$'\033[0;31m'
  local cyan=$'\033[0;36m'
  local yellow=$'\033[0;33m'
  local dim=$'\033[2m'
  local bold=$'\033[1m'

  local user=$(jq -r '.user' <<< "$summary")
  local repo=$(jq -r '.repo' <<< "$summary")
  local base=$(jq -r '.base' <<< "$summary")
  local since=$(jq -r '.since' <<< "$summary")
  local months=$(jq -r '.months' <<< "$summary")
  local merged_prs=$(jq -r '.mergedPrs' <<< "$summary")
  local opened_prs=$(jq -r '.openedPrs' <<< "$summary")

  # --- Header ---
  printf '\n  %s%s%s %s·%s %s%s%s\n' \
    "$bold_white" "$user" "$reset" "$dim" "$reset" "$cyan" "$repo" "$reset"
  printf '  %sbase:%s · last %s month(s), merged since %s%s\n' \
    "$dim" "$base" "$months" "$since" "$reset"
  _contrib_separator

  if [[ "$merged_prs" -eq 0 ]]; then
    printf '\n  %sNo PRs by %s merged into %s in this window' "$dim" "$user" "$base"
    [[ "$opened_prs" -gt 0 ]] && printf ' (%s opened, none merged yet)' "$(_contrib_commify "$opened_prs")"
    printf '.%s\n\n' "$reset"
    return
  fi

  local additions=$(jq -r '.additions' <<< "$summary")
  local deletions=$(jq -r '.deletions' <<< "$summary")
  local lines_touched=$(jq -r '.linesTouched' <<< "$summary")
  local files_changed=$(jq -r '.filesChanged' <<< "$summary")
  local avg_lines=$(jq -r '.avgLinesPerPr | round' <<< "$summary")
  local median_lines=$(jq -r '.medianLinesPerPr | round' <<< "$summary")

  # --- Totals ---
  printf '  %-16s %s%s%s\n' "PRs merged" "$bold_white" "$(_contrib_commify "$merged_prs")" "$reset"
  if [[ "$opened_prs" -gt 0 ]]; then
    local opened_merged=$(jq -r '.openedMerged' <<< "$summary")
    local opened_closed=$(jq -r '.openedClosed' <<< "$summary")
    local opened_open=$(jq -r '.openedOpen' <<< "$summary")
    local merge_rate=$(jq -r '.mergeRate * 100 | round' <<< "$summary")
    printf '  %-16s %s%s%s/%s %s(%s%%)%s\n' \
      "Merge rate" "$bold_white" "$(_contrib_commify "$opened_merged")" "$reset" \
      "$(_contrib_commify "$opened_prs")" "$dim" "$merge_rate" "$reset"
    printf '  %-16s %sof PRs opened since %s · %s closed · %s still open%s\n' \
      "" "$dim" "$since" "$(_contrib_commify "$opened_closed")" \
      "$(_contrib_commify "$opened_open")" "$reset"
  fi
  printf '  %-16s %s%s%s %s(%s+%s%s %s/ %s-%s%s%s)%s\n' \
    "Lines touched" "$bold_white" "$(_contrib_commify "$lines_touched")" "$reset" \
    "$dim" "$green" "$(_contrib_commify "$additions")" "$reset" \
    "$dim" "$red" "$(_contrib_commify "$deletions")" "$reset" "$dim" "$reset"
  printf '  %-16s %s\n' "Files changed" "$(_contrib_commify "$files_changed")"
  printf '  %-16s %s avg %s·%s %s median\n' \
    "Lines per PR" "$(_contrib_commify "$avg_lines")" "$dim" "$reset" "$(_contrib_commify "$median_lines")"

  local largest_number=$(jq -r '.largestPr.number' <<< "$summary")
  local largest_lines=$(jq -r '.largestPr.lines' <<< "$summary")
  local largest_title=$(jq -r '.largestPr.title' <<< "$summary")
  printf '  %-16s %s#%s%s %s lines\n' \
    "Largest PR" "$yellow" "$largest_number" "$reset" "$(_contrib_commify "$largest_lines")"
  printf '  %-16s %s%s%s\n' "" "$dim" "$largest_title" "$reset"

  # --- Monthly breakdown ---
  _contrib_separator
  printf '  %s%-9s %6s %9s %9s %9s%s\n' \
    "$bold" "Month" "PRs" "Added" "Removed" "Touched" "$reset"

  jq -c '.byMonth[]' <<< "$summary" | while IFS= read -r month_row; do
    local month=$(jq -r '.month' <<< "$month_row")
    local month_prs=$(jq -r '.prs' <<< "$month_row")
    local month_add=$(jq -r '.additions' <<< "$month_row")
    local month_del=$(jq -r '.deletions' <<< "$month_row")
    local month_touched=$(jq -r '.linesTouched' <<< "$month_row")

    printf '  %-9s %6s %s%9s%s %s%9s%s %9s\n' \
      "$month" "$(_contrib_commify "$month_prs")" \
      "$green" "$(_contrib_commify "$month_add")" "$reset" \
      "$red" "$(_contrib_commify "$month_del")" "$reset" \
      "$(_contrib_commify "$month_touched")"
  done

  _contrib_separator
  printf '\n'
}

# jq program that aggregates a reviewed-PR list into the review report summary
_contrib_reviews_jq_program() {
  cat <<'JQ'
def pct($n; $total): if $total == 0 then 0 else ($n / $total * 100) end;

# One entry per review the user submitted inside the window, tagged with the
# PR it landed on. Pending (draft) reviews have no submittedAt and were never
# submitted. The search is bounded by updated: (a superset, since submitting a
# review bumps a PR's updated_at), so the window is enforced here.
[ .[]
  | .number as $pr
  | .reviews[]
  | select(.author.login == $user and .submittedAt != null and .state != "PENDING")
  | select(.submittedAt[0:10] >= $since)
  | { pr: $pr, state, submittedAt }
] as $reviews
| ($reviews | map(select(.state == "APPROVED")) | length) as $approved
| ($reviews | map(select(.state == "CHANGES_REQUESTED")) | length) as $changesRequested
| ($reviews | map(select(.state == "COMMENTED")) | length) as $commented
| ($reviews | map(select(.state == "DISMISSED")) | length) as $dismissed
| {
    user: $user,
    repo: $repo,
    base: $base,
    since: $since,
    months: $months,
    prsReviewed: ($reviews | map(.pr) | unique | length),
    reviews: ($reviews | length),
    approved: $approved,
    changesRequested: $changesRequested,
    commented: $commented,
    dismissed: $dismissed,
    approvedPct: pct($approved; ($reviews | length)),
    changesRequestedPct: pct($changesRequested; ($reviews | length)),
    commentedPct: pct($commented; ($reviews | length)),
    reviewsPerPr: (
      ($reviews | map(.pr) | unique | length) as $prs
      | if $prs == 0 then 0 else ($reviews | length) / $prs end
    ),
    byMonth: (
      $reviews
      | group_by(.submittedAt[0:7])
      | map({
          month: .[0].submittedAt[0:7],
          reviews: length,
          approved: (map(select(.state == "APPROVED")) | length),
          commented: (map(select(.state == "COMMENTED")) | length),
          prs: (map(.pr) | unique | length)
        })
      | sort_by(.month)
    )
  }
JQ
}

# Report review activity by a user on PRs targeting the base branch
# Usage: contrib reviews [user] [-m <months>] [-r <owner/repo>] [-b <branch>] [--json]
_contrib_reviews() {
  local user="" months=6 repo="" base="" output_json=false

  _contrib_parse_opts "$@"
  case $? in
    2) return 0 ;;
    0) ;;
    *) return 1 ;;
  esac

  local since=$(date -v-${months}m +%Y-%m-%d)

  [[ "$output_json" == false ]] && echo "Fetching reviews by $user in $repo since $since..." >&2

  # reviewed-by finds the PRs; the reviews payload carries the per-review state.
  # updated: bounds the search without excluding in-window reviews of older PRs
  local prs
  prs=$(_contrib_fetch_prs "$repo" all \
    number,reviews \
    "reviewed-by:$user base:$base updated:>=$since") || return 1

  local summary
  summary=$(jq \
    --arg user "$user" \
    --arg repo "$repo" \
    --arg base "$base" \
    --arg since "$since" \
    --argjson months "$months" \
    "$(_contrib_reviews_jq_program)" <<< "$prs") || return 1

  # GitHub's search API caps results at 1000 — say so rather than silently truncating
  [[ "$(jq -r 'length' <<< "$prs")" == "1000" ]] && \
    echo "Warning: hit GitHub's 1000-result search cap; totals are a lower bound. Try a smaller --months." >&2

  if [[ "$output_json" == true ]]; then
    printf '%s\n' "$summary"
  else
    _contrib_reviews_display "$summary"
  fi
}

# Render the review report summary for the terminal
_contrib_reviews_display() {
  local summary="$1"

  local reset=$'\033[0m'
  local bold_white=$'\033[1;37m'
  local green=$'\033[0;32m'
  local cyan=$'\033[0;36m'
  local yellow=$'\033[0;33m'
  local dim=$'\033[2m'
  local bold=$'\033[1m'

  local user=$(jq -r '.user' <<< "$summary")
  local repo=$(jq -r '.repo' <<< "$summary")
  local base=$(jq -r '.base' <<< "$summary")
  local since=$(jq -r '.since' <<< "$summary")
  local months=$(jq -r '.months' <<< "$summary")
  local prs_reviewed=$(jq -r '.prsReviewed' <<< "$summary")
  local reviews=$(jq -r '.reviews' <<< "$summary")

  # --- Header ---
  printf '\n  %s%s%s %s·%s %s%s%s\n' \
    "$bold_white" "$user" "$reset" "$dim" "$reset" "$cyan" "$repo" "$reset"
  printf '  %sbase:%s · last %s month(s), reviews submitted since %s%s\n' \
    "$dim" "$base" "$months" "$since" "$reset"
  _contrib_separator

  if [[ "$reviews" -eq 0 ]]; then
    printf '\n  %sNo reviews by %s on PRs targeting %s in this window.%s\n\n' \
      "$dim" "$user" "$base" "$reset"
    return
  fi

  local approved=$(jq -r '.approved' <<< "$summary")
  local changes=$(jq -r '.changesRequested' <<< "$summary")
  local commented=$(jq -r '.commented' <<< "$summary")
  local dismissed=$(jq -r '.dismissed' <<< "$summary")
  local approved_pct=$(jq -r '.approvedPct | round' <<< "$summary")
  local changes_pct=$(jq -r '.changesRequestedPct | round' <<< "$summary")
  local commented_pct=$(jq -r '.commentedPct | round' <<< "$summary")
  local per_pr=$(jq -r '.reviewsPerPr' <<< "$summary")

  # --- Totals ---
  printf '  %-16s %s%s%s\n' "PRs reviewed" "$bold_white" "$(_contrib_commify "$prs_reviewed")" "$reset"
  printf '  %-16s %s%s%s %s(%.1f per PR)%s\n' \
    "Reviews" "$bold_white" "$(_contrib_commify "$reviews")" "$reset" "$dim" "$per_pr" "$reset"
  printf '  %-16s %s%s%s %s(%s%%)%s\n' \
    "Approved" "$green" "$(_contrib_commify "$approved")" "$reset" "$dim" "$approved_pct" "$reset"
  printf '  %-16s %s%s%s %s(%s%%)%s\n' \
    "Commented" "$cyan" "$(_contrib_commify "$commented")" "$reset" "$dim" "$commented_pct" "$reset"
  printf '  %-16s %s%s%s %s(%s%%)%s\n' \
    "Changes req'd" "$yellow" "$(_contrib_commify "$changes")" "$reset" "$dim" "$changes_pct" "$reset"
  [[ "$dismissed" -gt 0 ]] && \
    printf '  %-16s %s%s%s\n' "Dismissed" "$dim" "$(_contrib_commify "$dismissed")" "$reset"

  # --- Monthly breakdown ---
  _contrib_separator
  printf '  %s%-9s %8s %9s %10s %6s%s\n' \
    "$bold" "Month" "Reviews" "Approved" "Commented" "PRs" "$reset"

  jq -c '.byMonth[]' <<< "$summary" | while IFS= read -r month_row; do
    local month=$(jq -r '.month' <<< "$month_row")
    local month_reviews=$(jq -r '.reviews' <<< "$month_row")
    local month_approved=$(jq -r '.approved' <<< "$month_row")
    local month_commented=$(jq -r '.commented' <<< "$month_row")
    local month_prs=$(jq -r '.prs' <<< "$month_row")

    printf '  %-9s %8s %s%9s%s %s%10s%s %6s\n' \
      "$month" "$(_contrib_commify "$month_reviews")" \
      "$green" "$(_contrib_commify "$month_approved")" "$reset" \
      "$cyan" "$(_contrib_commify "$month_commented")" "$reset" \
      "$(_contrib_commify "$month_prs")"
  done

  _contrib_separator
  printf '\n'
}

# Show help message
_contrib_help() {
  cat <<EOF
Usage: contrib [subcommand] [user] [options]

Report a user's contribution and review activity on a repo's base branch

Subcommands:
  prs [user] [options]
                        Merged PRs, merge rate, and lines touched
                        (the default action)
  reviews [user] [options]
                        Review counts by outcome
  help                  Show this help message

Options (shared by both reports):
  -m, --months <n>      Look back this many months (default: 6)
  -r, --repo <repo>     Target repo as owner/repo, or a bare name under
                        $_CONTRIB_ORG (default: current directory's repo,
                        falling back to $_CONTRIB_ORG/obsidian)
  -b, --base <branch>   Base branch PRs must target
                        (default: the repo's default branch)
      --json            Emit the raw summary as JSON instead of a table

Examples:
  contrib                             # Your PR report, last 6 months, current repo
  contrib octocat                     # Another user, same defaults
  contrib reviews                     # Your review report
  contrib reviews octocat -m 3        # Another user's reviews, last 3 months
  contrib prs -r VantaInc/vanta       # A specific repo
  contrib prs -b develop              # A non-default base branch
  contrib reviews --json | jq .       # Machine-readable output

Notes on \`contrib prs\`:
  - The PR count and line counts come from PRs merged into the base branch, so
    they describe the same population. Commits pushed directly to the branch
    (bypassing a PR) are not counted.
  - "Merge rate" is merged/opened over a different population: PRs *created* in
    the window, whatever their state now. Its numerator will not match "PRs
    merged", which is keyed on merge date. PRs still open count against the
    rate, so recently opened work drags it down.
  - "Lines touched" is additions + deletions as GitHub reports them per PR,
    including generated files and lockfiles.

Notes on \`contrib reviews\`:
  - Counts every review the user submitted, so a PR reviewed twice contributes
    two reviews. "PRs reviewed" counts each PR once.
  - The window is on review *submission* date, so reviews of PRs opened before
    the window still count. GitHub has no review-date search qualifier, so this
    searches PRs updated in the window and filters by submission date.
  - The monthly table is keyed on submission date too, so a PR reviewed across
    two months appears in both months' "PRs" column and that column will not
    sum to the total.
  - Percentages are shares of the user's total reviews. Draft (pending) reviews
    are excluded since they were never submitted.
  - Review *requests* are not reported: GitHub's \`review-requested\` qualifier
    silently expands team membership, so CODEOWNERS fan-out is indistinguishable
    from a personal request and any reviewed/assigned ratio would be misleading.

Notes on both:
  - GitHub's search API returns at most 1000 PRs; the reports warn when that
    cap is reached rather than silently truncating.
  - Requires: gh CLI, jq
EOF
}
