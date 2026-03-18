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
- File naming: `<topic>-research.md`

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

## Document Structure

- **Summary** -- key findings in 2-3 sentences
- **Findings** -- organized by topic, citing sources
- **Open Questions** -- anything unresolved that may affect design
- **References** -- list of files, `.ai-dev` entries, and external resources consulted
