---
name: research
description: Use when working in an unfamiliar part of the codebase, when a task spans multiple components, or when you need to understand patterns and conventions before making changes
---

# Research

## Overview

Investigate a codebase question or topic and produce a reviewed markdown research document. Queries the `.ai-dev` knowledge layer, explores the codebase directly, and asks clarifying questions to build understanding.

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
- Synthesize findings -- don't just dump raw file contents

### 3. Confirm output location

- Propose the most relevant `.ai-dev` directory for the research doc
- Confirm with the user before writing
- File naming: `YYYY-MM-DD-<topic>-research.md`

### 4. Write and review

- Write the research document with frontmatter:

```yaml
---
created: YYYY-MM-DD
revised: YYYY-MM-DD
type: research
---
```

- **REQUIRED SUB-SKILL:** Use writing-docs for the review loop
- Cite which `.ai-dev/` directories and source files your findings draw from

### 5. Handoff

When the user approves the document:

"Research complete. Ready to move to design?"

If yes, invoke the design skill, passing the research doc path.

## Research Document Structure

- **Summary** -- key findings in 2-3 sentences
- **Findings** -- organized by topic, citing sources
- **Open Questions** -- anything unresolved that may affect design
- **References** -- list of files and `.ai-dev` entries consulted
