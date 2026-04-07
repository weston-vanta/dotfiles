---
name: design
description: Use when you have completed research and need to make architecture, technology, and design decisions before planning implementation work
---

# Design

## Overview

Take completed research and a set of requirements, clarify and refine them through interactive dialogue, and produce a reviewed design document. The design doc captures all decisions needed before implementation planning begins.

**Announce at start:** "I'm using the design skill to create a design document."

## Process

### 1. Read inputs

- Read the research document (path provided or invoke research skill if none exists)
- Read the user's design goal / requirements

### 2. Gather external resources

Ask the user: "Do you have any additional resources for this design? For example: Google Docs, Jira tickets, Figma links, or relevant websites."

If the user provides resources, **dispatch subagents in parallel** (one per resource) to fetch and summarize relevant content. Each subagent should use the appropriate tool for the resource type:

| Resource | Tool |
|----------|------|
| Google Docs/Sheets/Slides | `googleworkspace` CLI |
| Jira tickets | `acli` (Atlassian CLI) |
| Figma links | Figma MCP |
| Other websites | WebFetch |

Each subagent should:

1. Fetch the resource using the appropriate tool
2. Extract information relevant to the design goal
3. Return a structured summary: key requirements, constraints, decisions, and open questions found in the resource

Incorporate subagent findings into your understanding before proceeding to clarification.

### 3. Clarify requirements

Follow the brainstorming pattern:

- Ask questions **one at a time**
- **Multiple choice preferred** when possible (use the AskUserQuestion tool)
- Probe for missed requirements the user hasn't considered
- Explore ambiguous requirements until they're concrete
- Identify constraints (technical, organizational, timeline)
- Reference findings from external resources when relevant

### 4. Propose in sections

Present a summary of the following sections to the user, one by one. After each, ask for any corrections before proceeding.

You must present every section for every design -- if a section is not relevant, present your reasoning to the user for confirmation.

**Canonical sections**:

- Overview / Problem Statement
- Requirements Summary
- Out of Scope
- Architecture
- Technology Choices
- Key Design Decisions
- Security Considerations
- Testing Strategy
- Monitoring Strategy
- Deployment Strategy
- Project-specific sections as needed

### 5. Confirm output location

- Propose the most relevant `.ai-dev` directory
- Confirm with the user before writing
- File naming: `<topic>-design.md`

### 6. Write and review

**STOP**: You must use /writing-docs to write the design doc and manage the review loop.

Ensure the following frontmatter is included:

```yaml
---
created: YYYY-MM-DD
revised: YYYY-MM-DD
type: design
links:
  research: <path-to-research-doc>
---
```

### 7. Handoff

When the user approves the document:

"Design complete. Ready to move to planning?"

If yes, invoke the plan skill, passing the research and design doc paths.

## Guidelines

- **Requirements are the source of truth.** Every requirement identified during clarification must appear in the Requirements Summary. These drive the plan skill's test mapping.
- **Omit, don't stub.** If a section isn't relevant, leave it out entirely. Don't include empty sections or "N/A".
- **Be opinionated.** Present your recommended approach with reasoning. Offer alternatives where the tradeoff is genuine, but don't present false choices.
- **Out of Scope matters.** Explicitly listing what's out of scope prevents scope creep during planning and implementation.
