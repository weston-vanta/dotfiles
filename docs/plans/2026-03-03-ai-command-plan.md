# `ai` Command Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the SessionEnd hook with an `ai` zsh command that manages LLM-extracted knowledge in a shadow git repo.

**Architecture:** A single `.oh-my-zsh/custom/ai.zsh` file following existing subcommand patterns. Shadow repo operations use `git --git-dir=.git-ai --work-tree=.`. Knowledge extraction reuses the existing `claude -p` approach with a standalone prompt file.

**Tech Stack:** zsh, jq, git, claude CLI

**Design doc:** `docs/plans/2026-03-03-ai-command-design.md`

---

### Task 1: Create the extraction prompt file

**Files:**
- Create: `.claude/prompts/knowledge-extraction.md`

**Step 1: Create the prompt file**

Extract the prompt from the existing hook (`session-end-knowledge.sh` lines 41-74) into a standalone markdown file at `.claude/prompts/knowledge-extraction.md`. Keep the content identical — this is a pure extraction, not a rewrite.

**Step 2: Commit**

```bash
git add .claude/prompts/knowledge-extraction.md
git commit -m "ai: extract knowledge prompt into standalone file"
```

---

### Task 2: Create `ai.zsh` with command dispatch, help, and core helpers

**Files:**
- Create: `.oh-my-zsh/custom/ai.zsh`

**Step 1: Write the command skeleton**

Create `.oh-my-zsh/custom/ai.zsh` with:
- `ai()` main function dispatching to `init`, `update`, `sync`, `help`
- `_ai_help` with usage text following the `ona`/`prs` help format (heredoc, two-column subcommands, examples section)
- `_ai_git` helper: `git --git-dir="$(_ai_repo_root)/.git-ai" --work-tree="$(_ai_repo_root)" "$@"`
- `_ai_repo_root` helper: `git rev-parse --show-toplevel`
- `_ai_transcript_dir` helper: derives `~/.claude/projects/` subdirectory from repo root (replace `/` with `-` in the absolute path)
- `_ai_preprocess_transcript` helper: takes a file path argument, runs the jq filter from the existing hook, outputs cleaned JSONL to stdout. The jq filter is the `read -r -d '' jq_filter` block from `session-end-knowledge.sh` lines 16-38.

Reference: follow the pattern from `ona.zsh` for the dispatch structure and help formatting. Follow `prs.zsh` for the `case` statement style (it handles unknown args differently than `ona`).

**Step 2: Commit**

```bash
git add .oh-my-zsh/custom/ai.zsh
git commit -m "ai: add command skeleton with helpers"
```

---

### Task 3: Implement `ai init`

**Files:**
- Modify: `.oh-my-zsh/custom/ai.zsh`

**Step 1: Write `_ai_init`**

Add the `_ai_init` function:

1. `cd` to repo root (`_ai_repo_root`)
2. Check if `.git-ai` already exists — if so, print "Shadow repo already initialized" and return 0
3. Run `git init --bare .git-ai`
4. Write `.git-ai/info/exclude` with these exact contents (from the design doc):
   ```
   # Exclude all files
   *
   # Allow directory traversal
   !*/
   # Re-include .ai-dev and contents
   !**/.ai-dev
   !**/.ai-dev/*
   # Block traversal into heavy/irrelevant directories
   node_modules/
   .git/
   .vscode/
   .claude/
   ```
5. Idempotently add `.git-ai` and `.ai-dev` to `.git/info/exclude` (grep before appending each line)
6. Prompt for remote URL: `read -p "Remote URL for shadow repo (blank to skip): " remote_url` — if non-empty, run `_ai_git remote add origin "$remote_url"`
7. If any `.ai-dev/` directories exist, stage and create initial commit: `_ai_git add .ai-dev/ && _ai_git commit -m "ai: initial knowledge import"`

**Step 2: Write `_ai_ensure_init`**

Add `_ai_ensure_init`:
- If `.git-ai/` doesn't exist at repo root, call `_ai_init`
- If it does exist, just ensure `.git/info/exclude` entries are present (the idempotent grep+append from step 5 above — extract this into a small helper `_ai_ensure_main_excludes`)

**Step 3: Commit**

```bash
git add .oh-my-zsh/custom/ai.zsh
git commit -m "ai: implement init and auto-init"
```

---

### Task 4: Implement `ai update`

**Files:**
- Modify: `.oh-my-zsh/custom/ai.zsh`

**Step 1: Write `_ai_update`**

Add the `_ai_update` function:

1. Call `_ai_ensure_init`
2. `cd` to repo root
3. Get transcript directory via `_ai_transcript_dir`. If it doesn't exist, print "No Claude Code transcripts found for this project" and return 0.
4. Determine the last-update timestamp:
   - If `.ai-dev/.last-update` exists, use its modification time
   - Otherwise, use epoch (process all transcripts)
5. Find `.jsonl` files in the transcript directory newer than the timestamp. Use `find "$transcript_dir" -maxdepth 1 -name '*.jsonl' -newer .ai-dev/.last-update` (or without `-newer` if no `.last-update` file). Sort by modification time (oldest first) so knowledge builds incrementally.
6. If no new transcripts found, print "No new transcripts to process" and return 0.
7. Print count: "Processing N new transcript(s)..."
8. Read the extraction prompt from `~/.claude/prompts/knowledge-extraction.md` (this is where the symlinked file lives at runtime).
9. Loop over each transcript:
   - Print "  Processing: $(basename $transcript)..."
   - Pipe through `_ai_preprocess_transcript "$transcript" | claude -p --permission-mode acceptEdits "$prompt"`
   - If `claude` fails, print error and continue to next transcript (don't abort the whole run)
10. After the loop, `mkdir -p .ai-dev && touch .ai-dev/.last-update`
11. Print summary: "Done. Updated .ai-dev/knowledge.md files."

**Step 2: Commit**

```bash
git add .oh-my-zsh/custom/ai.zsh
git commit -m "ai: implement update subcommand"
```

---

### Task 5: Implement `ai sync`

**Files:**
- Modify: `.oh-my-zsh/custom/ai.zsh`

**Step 1: Write `_ai_sync`**

Add the `_ai_sync` function:

1. Call `_ai_ensure_init`
2. `cd` to repo root
3. Stage: `_ai_git add .ai-dev/`
4. Check for changes: `_ai_git diff --cached --quiet && echo "Nothing to sync." && return 0`
5. Generate commit message:
   - First line: `ai: update knowledge $(date '+%Y-%m-%d %H:%M')`
   - Get the staged diff: `_ai_git diff --cached`
   - Pipe the diff to `claude -p "Summarize the following knowledge file changes in 1-2 concise sentences. Output ONLY the summary, no preamble."` to generate the description
   - Combine: first line + blank line + LLM description
6. Commit: `_ai_git commit -m "$commit_msg"`
7. Push: check if remote `origin` exists (`_ai_git remote get-url origin 2>/dev/null`). If yes, push. If no, print "No remote configured. Run: ai init to add one." and skip.

**Step 2: Commit**

```bash
git add .oh-my-zsh/custom/ai.zsh
git commit -m "ai: implement sync subcommand"
```

---

### Task 6: Remove the old SessionEnd hook

**Files:**
- Delete: `.claude/hooks/session-end-knowledge.sh`
- Modify: `.claude/settings.json`
- Modify: `bootstrap.sh`

**Step 1: Delete the hook script**

```bash
rm .claude/hooks/session-end-knowledge.sh
```

If `.claude/hooks/` is now empty, remove the directory too.

**Step 2: Edit `.claude/settings.json`**

Remove the entire `"hooks"` key and its contents (lines 7-20). The resulting JSON should have `model`, `statusLine`, and `enabledPlugins` only.

**Step 3: Edit `bootstrap.sh`**

- Remove line 98: `mkdir -p "$HOME/.claude/hooks"`
- Remove line 100: `create_symlink ".claude/hooks/session-end-knowledge.sh" "$HOME/.claude/hooks/session-end-knowledge.sh"`
- Add a new symlink line for the prompts directory: `create_symlink ".claude/prompts" "$HOME/.claude/prompts"` (symlink the whole directory since it only contains our files)

**Step 4: Commit**

```bash
git rm .claude/hooks/session-end-knowledge.sh
git add .claude/settings.json bootstrap.sh
git commit -m "ai: remove SessionEnd hook in favor of ai command"
```

---

### Task 7: Migrate `.ai/` to `.ai-dev/` and update docs

**Files:**
- Rename: `.ai/knowledge.md` → `.ai-dev/knowledge.md`
- Delete: `.ai/` directory (after migration)
- Modify: `CLAUDE.md`

**Step 1: Migrate knowledge file**

```bash
mkdir -p .ai-dev
mv .ai/knowledge.md .ai-dev/knowledge.md
rm -rf .ai/
```

**Step 2: Update `CLAUDE.md`**

In the custom zsh functions table, add a row for the `ai` command:

```
| `ai.zsh` | `ai` | AI knowledge management (extract from transcripts, sync to shadow repo) | `jq`, `claude`, `git` |
```

Replace the Claude Code paragraph (line 40) that references the SessionEnd hook. New text:

```
**Claude Code** config is symlinked as individual files into `~/.claude/` (not the whole directory, since `~/.claude/` contains transient data like history and sessions). The `ai` command manages knowledge extraction from Claude Code transcripts into `.ai-dev/knowledge.md` files, tracked in a shadow git repo (`.git-ai`).
```

**Step 3: Commit**

```bash
git add .ai-dev/knowledge.md CLAUDE.md
git rm -r .ai/
git commit -m "ai: migrate .ai/ to .ai-dev/, update docs"
```
