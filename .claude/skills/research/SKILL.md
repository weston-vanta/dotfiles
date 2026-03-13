---
name: research
description: Use when working in an unfamiliar part of the codebase, when a task spans multiple components, or when you need to understand patterns and conventions before making changes
---

# Research

## Overview

Investigate a codebase question or topic and produce a reviewed markdown research document. Queries the `.ai-dev` knowledge layer, explores the codebase directly, gathers external resources, and asks clarifying questions to build understanding.

**Announce at start:** "I'm using the research skill to investigate this."

## Process

### 1. Understand the question

- Read any provided context (links to docs, files, prior research)
- Identify the **research variant** (see below) -- this determines document structure
- Ask clarifying questions one at a time to narrow the research scope
- Multiple choice preferred when possible

### 2. Investigate

- Glob for `**/.ai-dev/knowledge.md` to find existing knowledge
- Read relevant knowledge index files and detail files
- Explore the codebase directly: read source files, grep for patterns, check git history

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

### 4. Confirm output location

- Propose the most relevant `.ai-dev` directory for the research doc
- Confirm with the user before writing
- File naming: `YYYY-MM-DD-<topic>-research.md`

### 5. Write and review

Write the research document with frontmatter:

```yaml
---
created: YYYY-MM-DD
revised: YYYY-MM-DD
type: research
---
```

Cite which `.ai-dev/` directories, source files, and external resources your findings draw from.

**GATE: All output goes through writing-docs.** Do not present research findings in chat. Write the document to the agreed-upon file path and invoke the writing-docs skill for the review loop. The user reviews and refines the document on disk, not in conversation.

### 6. Handoff

When the user approves the document:

"Research complete. Ready to move to design?"

If yes, invoke the design skill, passing the research doc path.

## Research Variants

Choose the document structure that fits the research question. Default to **General** if none of the specific variants apply.

### General Research

For codebase exploration, understanding patterns, or investigating a topic.

- **Summary** -- key findings in 2-3 sentences
- **Findings** -- organized by topic, citing sources
- **Open Questions** -- anything unresolved that may affect design
- **References** -- list of files, `.ai-dev` entries, and external resources consulted

### PR Review

For building background understanding of the systems and codebase areas involved in a pull request. Trigger: user asks for context on a PR, asks to review a PR, or provides a PR number/link.

**Goal:** Give the reader a complete picture of the systems, features, and code involved so they can review the PR with full context. This is **not** an assessment of the PR itself -- no opinions on the changes, no suggestions for next steps, no summary of review comments.

**Investigation steps specific to PR review:**

1. Fetch the PR metadata and description via `gh`
2. Follow **every link** in the PR description (Jira tickets, related PRs, docs, design docs) -- use step 3's external resources process
3. Read the changed files **in full** (not just the diff hunks) to understand the systems being modified
4. For each changed area, trace the code paths: callers, callees, related modules, data flow
5. Check `git log` for recent history of the changed files and directories -- what's been happening in this area lately? Include relevant commit messages verbatim.
6. Find and read related PRs that recently touched the same files/modules (use `gh pr list --search` with file paths or component names)
7. Read relevant tests to understand expected behavior and invariants
8. Determine `product-platform` ownership of changed files: first check PR comments for an automated ownership breakdown; if none exists, consult MAINTAINERS files in the repo

**Document structure for PR review:**

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
