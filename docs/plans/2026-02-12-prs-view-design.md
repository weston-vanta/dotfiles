# Design: `prs view` command

## Overview

Add a `prs view` subcommand to `prs.zsh` that fetches and displays PR details (title, description, unresolved review threads) in a layout modeled after GitHub's PR conversation page.

## Command Interface

```
prs view [team-name] [pr-number]
```

- **team-name**: Optional filter for fzf selection. Defaults to `"mine"` (your authored PRs). Same selection UX as `prs open`.
- **pr-number**: Optional. If provided, view that PR directly. If omitted, fzf interactive selection.
- **Dependencies**: `gh`, `jq`, `glow`, `fzf` (only when no PR number given)

Examples:

```
prs view 1234          # View PR #1234 directly
prs view               # fzf select from your PRs (default: mine)
prs view backend-team  # fzf select from backend-team's PRs
```

## Output Layout

```
  PR Title (#1234)                              OPEN
  author:head-branch -> base-branch          APPROVED
  https://github.com/VantaInc/obsidian/pull/1234
────────────────────────────────────────────────────

  [PR body rendered as markdown via glow]

────────────────────────────────────────────────────
  Unresolved Threads (3)
────────────────────────────────────────────────────

  src/api/handler.ts
  ┌─────────────────────────────────────────┐
  │ diff hunk                               │
  └─────────────────────────────────────────┘
  alice: "Should this handle null?"
  bob: "Good point, will fix"

  src/models/user.ts
  ┌─────────────────────────────────────────┐
  │ diff hunk                               │
  └─────────────────────────────────────────┘
  carol: "Missing validation here"
```

Formatting:
- Header: title bold white, number yellow, state colored (green=open, purple=merged, red=closed)
- Branch: `author:head -> base`
- Body: piped through `glow` for terminal markdown rendering
- Threads: grouped by file, diff hunk displayed, then all comments with author and body
- Comment bodies rendered through `glow` for inline markdown
- Horizontal rules separate sections

## Data Fetching

Single `gh api graphql` query fetching:
- PR metadata: `title`, `body`, `author`, `number`, `url`, `state`, `baseRefName`, `headRefName`, `reviewDecision`
- `reviewThreads(first: 100)` with `isResolved`, `isOutdated`, `path`, `line`, `diffSide`
- Thread `comments(first: 50)` with `author`, `body`, `createdAt`, `diffHunk`

Client-side filtering via `jq`: exclude resolved threads (`isResolved == true`) and outdated threads (`isOutdated == true`).

## Argument Parsing

Same pattern as `_prs_open`:
1. Parse flags and positional args in a while loop
2. Numeric args treated as PR number, others as team filter
3. If no PR number, require fzf and use `_prs_list` with team filter for interactive selection
4. Default team to `"mine"` when no arguments provided

## Error Handling

- Missing `gh`: error with install link (same as `prs open`)
- Missing `glow`: error suggesting `brew install glow`
- Missing `fzf`: error if no PR number provided (same as `prs open`)
- PR not found: surface the `gh api` error
- No unresolved threads: print "No unresolved threads" (positive signal)

## Decisions

- **Single GraphQL query** over hybrid approach: GraphQL is required for thread resolution status, and adding metadata fields is trivial. One call is simpler and faster.
- **Skip outdated threads**: matches GitHub's default collapsed view. No flag to toggle.
- **glow for markdown**: purpose-built terminal renderer, required dependency.
- **mine as default team**: when no args given, fzf selects from your authored PRs.
