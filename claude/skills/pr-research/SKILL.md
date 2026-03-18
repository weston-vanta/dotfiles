---
name: pr-research
description: Use when asked to review a PR, given a PR number/link, or asked for context on a pull request - builds background understanding of the systems and code involved. Designed for non-interactive use via claude -p.
---

# PR Research

## Overview

Build background understanding of the systems and codebase areas involved in a pull request, producing a markdown research document. Queries the `.ai-dev` knowledge layer, explores the codebase directly, and gathers external resources.

This skill runs **non-interactively** — do not ask clarifying questions. Work with whatever context is provided.

**Goal:** Give the reader a complete picture of the systems, features, and code involved so they can review the PR with full context. This is **not** an assessment of the PR itself -- no opinions on the changes, no suggestions for next steps, no summary of review comments.

## Process

### 1. Gather PR context

- Look for a `pr-*.md` file in the repo root (written by `prs research` before invoking this skill) and read it for PR metadata, description, and diff
- If no local file exists, fetch the PR metadata and description via `gh`
- Follow **every link** in the PR description (Jira tickets, related PRs, docs, design docs) -- use step 3's external resources process

### 2. Investigate the codebase

- Glob for `**/.ai-dev/knowledge.md` to find existing knowledge about the affected areas
- Read relevant knowledge index files and detail files
- Read the changed files **in full** (not just the diff hunks) to understand the systems being modified
- For each changed area, trace the code paths: callers, callees, related modules, data flow
- Check `git log` for recent history of the changed files and directories -- what's been happening in this area lately? Include relevant commit messages verbatim.
- Find and read related PRs that recently touched the same files/modules (use `gh pr list --search` with file paths or component names)
- Read relevant tests to understand expected behavior and invariants
- Determine `product-platform` ownership of changed files: first check PR comments for an automated ownership breakdown; if none exists, consult MAINTAINERS files in the repo

**Depth matters.** The goal is to give the reader enough context to act without needing to go read the source themselves:

- Include **code snippets** for key logic, not just descriptions of what code does
- Show **diffs or before/after** when the research involves changes
- Provide **background and context** -- why does this code exist? What problem does it solve? What came before?
- Quote **relevant comments, commit messages, and PR descriptions** verbatim when they add context
- Don't just summarize -- give the reader the primary sources inline

### 3. Gather external resources

Scan all available context (PR descriptions, ticket references, doc links, error messages) for **links and references to external systems**. Dispatch subagents in parallel to fetch and summarize each one:

| Resource | Tool |
|----------|------|
| Jira tickets | `acli` (Atlassian CLI) or Jira MCP |
| Google Docs/Sheets/Slides | `googleworkspace` CLI |
| Figma links | Figma MCP |
| Other websites/docs | WebFetch |
| GitHub issues/PRs | `gh` CLI |

Each subagent should:

1. Fetch the resource using the appropriate tool
2. Extract information relevant to the research question
3. Return a structured summary: key context, requirements, decisions, and open questions found in the resource

If no external links are found, note that and move on. Do not skip this step -- actively look for references to follow.

### 4. Write the research document

Write to the most relevant `.ai-dev` directory, creating one if needed (e.g., alongside the primary changed module).

File naming: `YYYY-MM-DD-pr-<number>-research.md`

Write the research document with frontmatter:

```yaml
---
created: YYYY-MM-DD
revised: YYYY-MM-DD
type: research
pr: <number>
---
```

**Document structure:**

- **Review investment** -- this section goes first. Rate as **stamp** (no real review needed), **light** (simple, safe changes with little `product-platform` ownership), **moderate**, or **deep** (block time, test locally). One-line rating followed by a brief justification citing:
  - *Ownership*: how much of the change falls under `product-platform`? More ownership = more investment.
  - *Complexity*: straightforward change, or tricky logic / multiple interacting systems / subtle invariants?
  - *Risk*: could this break things in production? Data migrations, auth changes, payment logic, etc.
  Then list the changed files owned by `product-platform` (with their paths). To determine ownership: first check PR comments for an automated ownership breakdown; if none exists, consult MAINTAINERS files in the repo.
- **Summary** -- what systems/features are involved, in 2-3 sentences
- **Motivation** -- what's driving this change? Link to tickets, incidents, design docs, and include their content inline. The reader should understand the *why* without clicking through.
- **System context** -- how the affected code fits into the larger system. Architecture, data flow, key abstractions. Include code snippets of the important interfaces and types.
- **Recent history** -- what's been happening in these areas of the codebase recently? Summarize relevant recent commits and PRs with dates and authors. Quote commit messages that add context.
- **Code walkthrough** -- for each changed file/area, explain what the existing code does, how it works, and what its responsibilities are. Include code snippets of surrounding context, not just the changed lines.
- **References** -- PR link, ticket links, related PRs, files read, external resources consulted

Cite which `.ai-dev/` directories, source files, and external resources your findings draw from.
