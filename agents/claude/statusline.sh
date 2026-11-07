#!/usr/bin/env bash
# Claude Code statusline: model, context token usage, session cost.
# Simplified from obsidian's .claude/statusline/full.sh.

input=$(cat)

IFS=$'\t' read -r model used_pct size cost < <(
  printf '%s' "$input" | jq -r '[
    (.model.display_name // "Unknown" | sub(" context\\)"; ")")),
    (.context_window.used_percentage // 0 | floor),
    (.context_window.context_window_size // 200000),
    (.cost.total_cost_usd // 0)
  ] | @tsv'
)

used_k=$((size * used_pct / 100 / 1000))
if ((size >= 1000000)); then
  limit="$((size / 1000000))M"
else
  limit="$((size / 1000))K"
fi

# Autocompact buffer is fixed at 33k tokens; warn as usage approaches it.
compact_pct=$(((size - 33000) * 100 / size))
warn_pct=$((compact_pct - 10))
if ((used_pct >= compact_pct)); then
  ctx_color=$'\033[1;31m'
elif ((used_pct >= warn_pct)); then
  ctx_color=$'\033[1;33m'
elif ((used_pct >= 50)); then
  ctx_color=$'\033[33m'
else
  ctx_color=$'\033[32m'
fi

reset=$'\033[0m'
printf '%s[%s]%s %s%sK/%s (%s%%)%s %s$%.2f%s\n' \
  $'\033[36m' "$model" "$reset" \
  "$ctx_color" "$used_k" "$limit" "$used_pct" "$reset" \
  $'\033[33m' "$cost" "$reset"
