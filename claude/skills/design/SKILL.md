---
name: design
description: Use when you have a PRD and completed research and need to make architecture, technology, and design decisions before planning implementation work
---

# Design

## Overview

Take a PRD, completed research, and produce a reviewed design document through interactive dialogue. The design doc captures all decisions needed before implementation planning begins.

**Announce at start:** "I'm using the design skill to create a design document."

## Process

### 1. Read inputs

- Read the PRD (path provided or invoke requirements skill if none exists)
- Read the research document (path provided or invoke research skill if none exists)
- Read the user's design goal if it adds context beyond the PRD

### 2. Verify requirements

Review the PRD and confirm your understanding. If anything is ambiguous for design purposes, ask the user to clarify. Do not re-elicit requirements — the PRD is the source of truth.

### 3. Explore the design space

Decide *how* the system should work. The PRD established *what*; now make the design decisions. This is where the real design happens — not in requirements gathering or section writing.

- **One question at a time.** Ask one question, wait for the answer, then proceed. Use AskUserQuestion for simple choices; use plain text for code-heavy questions.
- **Exception: code-heavy questions.** When a question involves code snippets, API shapes, or type signatures, present it in plain text instead of AskUserQuestion. The tool's preview feature cannot reliably display full code blocks.
- **Start with the hardest question.** Identify the central design tension (e.g., API shape, data flow, ownership model) and explore it first. Easier decisions fall into place once the hard ones are resolved.
- **Present concrete alternatives with code.** Show what each option looks like in practice, not just in the abstract. Name the tradeoffs.
- **Follow the user's curiosity.** When the user pushes back or wants to probe deeper, that's signal — the design is getting stronger. Don't rush to close questions.
- **Let decisions compound.** Each resolved question constrains the next. Revisit earlier decisions if a later exploration reveals a better path.
- **Exit condition.** Move to section proposal when the major design decisions are resolved — you should be able to write the Architecture section without open questions. If you're unsure, ask the user if they're ready to move to section proposals.

### 4. Propose in sections

Present a summary of the following sections to the user, one by one. After each, ask for any corrections before proceeding.

**Expect iteration.** Review feedback on any section may surface new design questions that weren't visible during initial exploration. When this happens, return to "Explore the design space" rather than trying to resolve it inline during the review loop.

Present every section to the user for discussion — if a section is not relevant, explain why and confirm with the user before omitting it from the document.

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
  prd: <path-to-prd>
  research: <path-to-research-doc>
---
```

### 7. Handoff

When the user approves the document:

"Design complete. Ready to move to planning?"

If yes, invoke the plan skill, passing the PRD, research, and design doc paths.

## Guidelines

- **One question at a time.** Never batch multiple questions into a single message — not during design exploration, not during section review. Ask one question, wait for the answer, then ask the next. Batching forces the user to context-switch and leads to shallow answers.
- **The PRD is the source of truth for requirements.** Every requirement in the PRD must appear in the Requirements Summary. The design skill may refine how requirements are grouped or phrased, but must not add, remove, or contradict PRD requirements without the user's approval. These drive the plan skill's test mapping.
- **Omit, don't stub.** If a section isn't relevant to the written document, leave it out entirely. Don't include empty sections or "N/A". (Every section is still *discussed* during step 4 — omission applies to the final document, not the conversation.)
- **Be opinionated.** Present your recommended approach with reasoning. Offer alternatives where the tradeoff is genuine, but don't present false choices.
- **Out of Scope matters.** Explicitly listing what's out of scope prevents scope creep during planning and implementation.
