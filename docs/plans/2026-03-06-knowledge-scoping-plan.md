# Knowledge Scoping Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update knowledge extraction to produce scoped index + detail files, and create a `research` skill that queries the `.ai-dev` knowledge layer.

**Architecture:** The extraction prompt produces per-directory `.ai-dev/` directories containing a `knowledge.md` index and topic-based detail files. A new `research` skill dispatches a subagent that globs for indices, reads relevant detail files, and synthesizes answers.

**Tech Stack:** Markdown prompts, Claude Code skills (SKILL.md with YAML frontmatter), zsh (bootstrap.sh)

---

### Task 1: Update Extraction Prompt — File Structure

**Files:**
- Modify: `.claude/prompts/knowledge-extraction.md`

**Step 1: Update step 4 (Write knowledge files)**

Replace the current step 4:
```markdown
4. **Write knowledge files**: For each directory that has scoped insights:
   - Run `mkdir -p <dir>/.ai-dev` to ensure the directory exists
   - Read the existing `.ai-dev/knowledge.md` if present
   - Write an updated `.ai-dev/knowledge.md` that merges new insights with existing content
```

With:
```markdown
4. **Write knowledge files**: For each directory that has scoped insights:
   - Run `mkdir -p <dir>/.ai-dev` to ensure the directory exists
   - Group insights by topic.
   - Read the existing `.ai-dev/knowledge.md` index if present. Match each topic group to an existing detail file or decide to create a new one.
   - Read and update only the matched detail files. Create new detail files for unmatched topic groups.
   - Update `.ai-dev/knowledge.md` index with one-line summaries for any new or changed detail files.
```

**Step 2: Replace the Format section**

Replace:
```markdown
## Format

Use markdown with topic headings. Keep entries concise (1-3 sentences each).
```

With:
```markdown
## Format

Each `.ai-dev/` directory contains:
- `knowledge.md` — Index file with one-line summaries linking to detail files
- `<topic>.md` — Detail files named by topic, chosen based on content (not a fixed taxonomy)

Index entries look like:
- [Architecture](architecture.md) — Component relationships and data flow

Detail files use markdown with topic headings. Keep entries concise (1-3 sentences each).
```

**Step 3: Verify the full prompt reads correctly**

Read `.claude/prompts/knowledge-extraction.md` end-to-end and confirm all sections are consistent.

**Step 4: Commit**

```bash
git add .claude/prompts/knowledge-extraction.md
git commit -m "ai: update extraction prompt for index + detail file structure"
```

---

### Task 2: Create Research Skill

**Files:**
- Create: `.claude/skills/research/SKILL.md`

**Step 1: Create the skill directory**

```bash
mkdir -p .claude/skills/research
```

**Step 2: Write SKILL.md**

Create `.claude/skills/research/SKILL.md` with:

```markdown
---
name: research
description: Use when working in an unfamiliar part of the codebase, when a task spans multiple components, or when you need to understand patterns and conventions before making changes
---

# Research Codebase Knowledge

## Overview

Query the `.ai-dev` knowledge layer across the repository. Dispatches a subagent that finds, reads, and synthesizes relevant knowledge from `.ai-dev/` directories.

## When to Use

- Starting work in an unfamiliar area of the codebase
- Task spans multiple components or directories
- Need to understand existing patterns, conventions, or gotchas before making changes
- Looking for prior knowledge about a specific topic (debugging approaches, architecture decisions, etc.)

## How It Works

Dispatch a subagent (Agent tool) with the following instructions and the user's query:

### Subagent Instructions

You are a research agent. Answer the following query using knowledge stored in `.ai-dev/` directories throughout this repository.

**Process:**

1. Glob for `**/.ai-dev/knowledge.md` to find all index files.
2. Read the index files. Each contains one-line summaries linking to detail files.
3. Identify which detail files are relevant to the query — use both the summaries and the directory paths to judge relevance.
4. Read only the relevant detail files.
5. Synthesize a focused answer to the query. Do not dump raw file contents — summarize and connect the relevant knowledge.

**If there are many index files**, prioritize by directory path relevance to the query. Expand to less-obvious directories only if initial results are insufficient.

**Always cite** which `.ai-dev/` directories your answer draws from, so the caller knows where to look for more detail.
```

**Step 3: Commit**

```bash
git add .claude/skills/research/SKILL.md
git commit -m "ai: add research skill for querying .ai-dev knowledge layer"
```

---

### Task 3: Add Skills Symlink to Bootstrap

**Files:**
- Modify: `bootstrap.sh:97-99`

**Step 1: Add skills symlink**

In the `==> Symlinking Claude Code config` section of `bootstrap.sh`, after the existing `create_symlink` calls, add:

```bash
create_symlink ".claude/skills" "$HOME/.claude/skills"
```

**Step 2: Verify bootstrap is correct**

Read `bootstrap.sh` and confirm the new line is in the right section, after the other `.claude/` symlinks.

**Step 3: Commit**

```bash
git add bootstrap.sh
git commit -m "bootstrap: symlink .claude/skills directory"
```

---

### Task 4: Update .git-ai Excludes for New File Structure

The `.ai-dev/` directories will now contain multiple `.md` files, not just `knowledge.md`. The current `.git-ai` exclude pattern in `ai.zsh` already allows `!**/.ai-dev/*` which covers all files in `.ai-dev/` directories — no changes needed.

**Step 1: Verify exclude pattern**

Read `.oh-my-zsh/custom/ai.zsh:122-135` and confirm `!**/.ai-dev/*` covers the new detail files.

**Step 2: No commit needed if pattern already covers it.**
