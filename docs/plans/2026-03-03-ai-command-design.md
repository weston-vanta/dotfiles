# Design: `ai` Command for LLM Knowledge Management

## Summary

Replace the SessionEnd Claude Code hook with a new `ai` zsh command that manages LLM-extracted knowledge within an "AI shadow repo" — a separate git repository (`.git-ai`) coexisting in the same working tree as the main repo, tracking only `.ai-dev/` directories.

## Subcommands

```
ai init          # Bootstrap the shadow repo
ai update        # Extract knowledge from new Claude Code transcripts
ai sync          # Commit + push .ai-dev changes to shadow repo
ai help          # Usage info
```

## Shadow Repo Concept

Each project gets a separate git repo using `.git-ai` as the git directory. This repo shares the same working tree as the main repo but only tracks `.ai-dev/` directories and their contents.

**Isolation rules:**
- `.git-ai/info/exclude` ignores everything *except* `.ai-dev/**`
- The main repo's `.git/info/exclude` ignores both `.git-ai` and `.ai-dev`

All shadow repo git operations use a helper: `_ai_git` wraps `git --git-dir=.git-ai --work-tree=.`

## `ai init`

1. Verify we're in a git repo root
2. `git init` with `GIT_DIR=.git-ai`
3. Write `.git-ai/info/exclude`:
   ```
   # Exlude all files
   *
   # Allow directory traversal
   !*/
   # Re-include .ai-dev and contents
   !**/.ai-dev
   !**/.ai-dev/*
   # Block traversal into heavy/irrelevant diretories
   node_modules/
   .git/
   .vscode/
   .claude/
   ```
4. Idempotently add `.git-ai` and `.ai-dev` to `.git/info/exclude`
5. Prompt for remote URL, add as `origin`
6. If `.ai-dev/` content already exists, create initial commit

## `ai update`

### Transcript discovery

- Derive the `~/.claude/projects/` subdirectory from the current repo root (path separators become dashes, e.g., `-Users-weston-Workspaces-myproject`)
- Find JSONL transcript files in that directory newer than `.ai-dev/.last-update`
- If `.last-update` doesn't exist, process all transcripts

### Processing pipeline (per transcript, sequential)

1. Pre-process with `_ai_preprocess_transcript` (reusable jq helper):
   - Filter to `assistant`/`user` message types
   - Strip metadata fields (usage, id, model, stop_reason, stop_sequence, type)
   - Truncate thinking blocks to 500 chars
   - Truncate large tool inputs to 500 chars per field
   - Truncate tool results to 2000 chars
2. Pipe to `claude -p --permission-mode acceptEdits` with the extraction prompt from `.claude/prompts/knowledge-extraction.md`
3. After all transcripts processed successfully, write current timestamp to `.ai-dev/.last-update`

### Extraction prompt

Stored at `.claude/prompts/knowledge-extraction.md`. Same content as the current hook prompt — instructs the LLM to:
- Triage trivial sessions (skip if no actionable knowledge)
- Identify directories that gained knowledge from files read/edited/discussed
- Write/merge `.ai-dev/knowledge.md` files with concise, topic-headed entries
- Focus on: architecture, patterns, dev tools, gotchas, dependencies
- Never record session-specific details or duplicate CLAUDE.md/README content

## `ai sync`

1. Call `_ai_ensure_init` (auto-init if needed)
2. `_ai_git add .ai-dev/`
3. Exit early if nothing to commit (`_ai_git diff --cached --quiet`)
4. Commit with message: `ai: update knowledge YYYY-MM-DD HH:MM` on the first line, followed by a blank line, then a short LLM-generated description of the changes.
5. Push to `origin` (warn and skip if no remote configured)

## Auto-Init

Both `update` and `sync` call `_ai_ensure_init`:
- If `.git-ai/` doesn't exist, run full init flow (including remote URL prompt)
- If `.git-ai/` exists, idempotently ensure main repo excludes are set

## Helper Functions

| Function | Purpose |
|----------|---------|
| `_ai_git` | Wrapper for `git --git-dir=.git-ai --work-tree=.` |
| `_ai_repo_root` | `git rev-parse --show-toplevel` |
| `_ai_ensure_init` | Auto-init guard for `update` and `sync` |
| `_ai_preprocess_transcript` | Reusable jq transcript cleaner (file path in, JSONL out) |
| `_ai_transcript_dir` | Derives `~/.claude/projects/` subdirectory for current repo |

## File Changes

| Action | File |
|--------|------|
| Create | `.oh-my-zsh/custom/ai.zsh` |
| Create | `.claude/prompts/knowledge-extraction.md` |
| Delete | `.claude/hooks/session-end-knowledge.sh` |
| Edit   | `.claude/settings.json` — remove `SessionEnd` hook |
| Edit   | `bootstrap.sh` — remove hook symlink line, add prompt symlink |
| Edit   | `CLAUDE.md` — add `ai` command to table, update hook references |
| Rename | `.ai/knowledge.md` → `.ai-dev/knowledge.md` |

## Dependencies

- `jq` — transcript pre-processing
- `claude` CLI — knowledge extraction (`claude -p`)
- `git` — shadow repo operations
