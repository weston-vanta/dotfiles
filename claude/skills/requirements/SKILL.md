---
name: requirements
description: Use when the user describes a feature, system, or change and you need to align on what to build before designing or implementing. Produces a PRD through interactive dialogue. Use this before the design or plan skills when requirements are not yet written down.
---

# Requirements Elicitation

## Overview

Turn a high-level task description into a reviewed PRD (Product Requirements Document) through interactive dialogue. The PRD describes **what** the system should do — never **how** it should do it.

**Announce at start:** "I'm using the requirements skill to develop a PRD."

## Process

### 1. Read inputs

- Read any existing code, schemas, documents, or prior work related to the task
- If the user provided links or file paths, read them before asking questions
- The goal is to ask informed questions, not generic ones

### 2. Gather external resources

Ask the user: "Do you have any additional resources for these requirements? For example: Google Docs, Jira tickets, Figma links, or relevant websites."

If resources are provided, dispatch subagents in parallel to fetch and summarize relevant content, then incorporate findings before proceeding to clarification.

### 3. Clarify requirements

This is the core of the skill. Ask questions **one at a time** — each answer may change what you need to ask next.

- **Multiple choice preferred** when possible (use the AskUserQuestion tool)
- **Fall back to plain text** when the question needs code examples, detailed comparisons, or side-by-side options that the AskUserQuestion tool can't display well
- **Probe for what's out of scope** — explicitly excluded features prevent scope creep later
- **Ask about behavior, not implementation** — instead of "should this be a hook or a component?", ask "does the caller need access to form state outside the form?" The implementation follows from the behavioral requirement.

During this conversation, you will naturally discuss implementation details — API shapes, component names, library choices, code examples. This is necessary for alignment. But these details do **not** belong in the PRD. You may track them in a separate working document if useful.

### 4. Push for simplification

When a requirement introduces complexity, probe whether it's essential. Watch for:
- Two concepts that could be one
- Premature optimization
- Abstractions that generalize without a clear use case
- Features that exist to support other features rather than user needs

### 5. Revisit earlier decisions

Later answers often invalidate earlier ones. When a new answer simplifies or changes the model, go back and reconcile — don't just append. Tell the user what changed and why.

### 6. Confirm output location

- Propose the most relevant `.ai-dev` directory, or the directory the user is working in
- Confirm with the user before writing
- File naming: `<topic>-prd.md`

### 7. Write and review

**STOP**: You must use /writing-docs to write the PRD and manage the review loop.

Ensure the following frontmatter is included:

```yaml
---
created: YYYY-MM-DD
revised: YYYY-MM-DD
type: requirements
---
```

### 8. Handoff

When the user approves the document:

"Requirements complete. Ready to move to research or design?"

If yes, invoke the appropriate skill, passing the PRD path.

## PRD rules

The PRD contains only **user-observable features**, where "user" could be end-users, API consumers, or other stakeholders.

**Include:**
- What the system does (behaviors, capabilities)
- What the user observes (UI states, error display, loading indicators)
- Constraints on behavior (validation timing, type safety guarantees)
- What is explicitly out of scope

**Exclude:**
- Code examples
- Specific library or component names (except when they are the input contract, e.g. "Zod schema")
- API signatures, prop tables, hook names
- File locations, architecture decisions
- Implementation strategies

**Litmus test:** For each statement in the PRD, ask: "Could an engineer implement this in two completely different ways and both satisfy this requirement?" If yes, it belongs. If it prescribes a specific implementation, it's a design decision — leave it out.

## Guidelines

- **Don't write the PRD too early.** You need several rounds of questions before requirements stabilize. Don't write the doc after the first two questions.
- **Don't let implementation creep in.** During discussion you'll explore APIs, component structures, type signatures. These are valuable for alignment but are design, not requirements.
- **Be opinionated.** If the user's description implies requirements they haven't stated, surface them. If a requirement seems like it will cause problems, say so.
- **Out of Scope matters.** Explicitly listing what's out of scope prevents scope creep during design and implementation.
