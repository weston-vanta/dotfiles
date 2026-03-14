#!/usr/bin/env bash

# PostToolUse hook: upload .ai-dev doc files to Google Drive via gsync.
# Stdout is reported back to the agent (includes Drive link on success).

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
GDRIVE_FOLDER="1Gh4vtsOQdSdDOud4AIZsv4oQzymzo32o"

[[ -z "$FILE_PATH" ]] && exit 0

if [[ "$FILE_PATH" =~ /.ai-dev/.*-(research|design|plan)\.md$ ]]; then
  OUTPUT=$(npx gsync upload "$FILE_PATH" --folder="$GDRIVE_FOLDER" 2>&1)
  if [[ $? -eq 0 ]]; then
    echo "$OUTPUT"
  else
    echo "gsync upload failed for $FILE_PATH"
    echo "$OUTPUT"
  fi
fi

exit 0
