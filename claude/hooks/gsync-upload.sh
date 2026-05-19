#!/usr/bin/env bash

# PostToolUse hook: upload markdown artifacts to Google Drive via gsync.
# Fires when the edited file lives inside an ai-artifacts/ git repo
# (any ancestor directory named ai-artifacts/ that contains a .git/).
# Stdout is reported back to the agent (includes Drive link on success).

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
GDRIVE_FOLDER="1Gh4vtsOQdSdDOud4AIZsv4oQzymzo32o"

[[ -z "$FILE_PATH" ]] && exit 0
[[ "$FILE_PATH" != *.md ]] && exit 0

# Walk up from the file's directory. If any ancestor is named ai-artifacts
# and contains a .git/, treat the file as an artifact.
in_artifacts_repo() {
  local dir
  dir=$(dirname "$1")
  while [[ "$dir" != "/" && -n "$dir" ]]; do
    if [[ "$(basename "$dir")" == "ai-artifacts" && -d "$dir/.git" ]]; then
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

in_artifacts_repo "$FILE_PATH" || exit 0

OUTPUT=$(npx gsync upload "$FILE_PATH" --folder="$GDRIVE_FOLDER" 2>&1)
if [[ $? -eq 0 ]]; then
  echo "$OUTPUT"
else
  echo "gsync upload failed for $FILE_PATH"
  echo "$OUTPUT"
fi

exit 0
