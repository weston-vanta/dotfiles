#!/usr/bin/env bash

# SessionEnd hook: commit and push any changes in the sibling ai-artifacts repo.
# Silent no-op when no artifacts repo is found or there's nothing to commit.

set -uo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

[[ -z "$CWD" ]] && exit 0
[[ ! -d "$CWD" ]] && exit 0

# Walk up from CWD looking for a sibling ai-artifacts repo.
# A sibling means: at some ancestor, there's a peer directory named ai-artifacts
# that is itself a git repo.
find_artifacts_repo() {
  local dir="$1"
  while [[ "$dir" != "/" && -n "$dir" ]]; do
    if [[ -d "$dir/ai-artifacts/.git" ]]; then
      echo "$dir/ai-artifacts"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

ARTIFACTS_REPO=$(find_artifacts_repo "$CWD") || exit 0

cd "$ARTIFACTS_REPO" || exit 0

# Stage everything; if nothing changed, exit silently.
git add -A
if git diff --cached --quiet; then
  exit 0
fi

MSG="session sync $(date '+%Y-%m-%d %H:%M')"

if ! git commit -m "$MSG" >/dev/null 2>&1; then
  echo "ai-artifacts: commit failed in $ARTIFACTS_REPO"
  exit 0
fi

if git remote get-url origin >/dev/null 2>&1; then
  if git push origin HEAD >/dev/null 2>&1; then
    echo "ai-artifacts: committed and pushed ($MSG)"
  else
    echo "ai-artifacts: committed locally but push failed in $ARTIFACTS_REPO"
  fi
else
  echo "ai-artifacts: committed locally (no remote configured)"
fi

exit 0
