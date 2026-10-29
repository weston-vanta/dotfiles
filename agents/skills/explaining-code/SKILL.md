---
name: explaining-code
description: Use when someone needs to understand how a part of a codebase works or why it is shaped the way it is. That includes a pull request or stack large enough that reviewers need the design before the diffs, an existing system a newcomer or another team must learn, a planned design that needs review before anyone builds it, and any request for an explainer, walkthrough, architecture diagram, or review guide.
---

# Explaining Code

## Goal and terms

A reader of unfamiliar code wants to know what drives its complexity and whether that complexity is necessary. They should be able to work it out from a picture of the system rather than from paragraphs. The subject is one of three kinds: a **change**, an **existing system**, or a **plan**.

- **Reader questions:** at most five questions a staff-level reviewer would ask about why the subject has this shape. Lean toward questions about product requirements, the data model, interfaces, and architecture. The page answers them without ever stating them, so never write them, or the pushback you expect, as an FAQ.
- **Forcing facts:** facts the design cannot avoid. A fact is forcing only if the design would be simpler without it, so ask of each candidate: if this were false, what would we delete? Consequences of a forcing fact are not forcing facts themselves. If you find none, the subject may not need an explainer.
- **Assumed knowledge:** what the reader already takes for granted about how the codebase handles cross-cutting concerns, for example that every call is authorized at the API boundary. Leave it out unless it forces a less obvious design, in which case it is a forcing fact. The codebase's docs and conventions tell you what its reviewers assume.
- **Inclusion test:** draw something only if both hold: it belongs to the subject, and drawing it explains where data comes from or why the design has this shape. Anything else goes in the detail panel, or is left out as assumed knowledge.
- **At rest:** the page as it first loads, before the reader interacts with it.
- **Component:** any box in the diagram, at any level of nesting.

## Analyze

1. **Decide the audience and the subject's boundary.** Together they set the level of abstraction the diagram works at.
2. **Anticipate the reader questions.** Ask why the design has this shape, not how its edge cases behave. That means asking why the obvious approach fails, what forces this shape, and what it gains and costs against the alternative. The alternative is the previous code for a change, the rejected options for a plan, or a simpler design for an existing system. Write down your own answer to each.
3. **Push each answer down to the mechanism.** For the obvious approach find exactly what in the data model, architecture, or an interface prevents it. Keep asking why until the answer is a fact about the code rather than a restatement of the design. A fact stated at a high level often hides the deeper one that forces the design, such as a data model originally designed to support one feature now awkwardly supporting others.
4. **Find the forcing facts.** Collect the facts your answers depend on, test each against the definition, and verify the survivors in the current code.
5. **Trace each flow end to end,** listing every function it passes through and every call it makes. The trace is exhaustive so the diagram can be selective. For a plan, trace the proposed flows and verify the code they touch, and mark any claim you could not verify.

If the user offers a sketch, follow its choices and correct it wherever the code disagrees. Don't ask for one.

## The page

At rest, the reader sees a title, a narrative under 200 words, and one diagram with any controls in a single row directly above it.

- **The narrative** says what the subject does or what problem it solves, gives each forcing fact a line, and says in one sentence what the facts force the code to do.
- **The diagram is readable without interaction.** At 1280×800 everything above fits without scrolling in either direction, with no diagram label smaller than 12px. If it doesn't fit, the diagram is at the wrong level of abstraction. Rethink the level rather than shrinking type or deleting components one at a time.

Below the diagram are a step bar when a flow is selected, a **detail panel** that every interaction fills, and **collapsed sections** for supporting evidence the diagram doesn't carry. Make every component clickable to show its detail, including links to the code behind each claim.

Match each interaction to the axis the subject varies along:
- **Sequence:** step through a flow. A flow is one user action on a main path, named for what it accomplishes. Drop a flow that mostly repeats another.
- **Time or scope:** highlight what a phase of a change or plan adds or changes.
- **Structure or alternatives:** highlight an area, or switch between options.

Readers figure out controls on their own, so don't explain them. Clicking outside any component clears the selection.

## The diagram

- **Group components by layer,** and lay them out along the dominant direction of the flow.
- **Draw each component at its interface.** Show the functions a call enters or leaves the component through, nested inside it, so the reader can see which one makes which call. What happens inside a component belongs in its detail panel.
- **Apply the inclusion test** to every component, arrow, and label. Draw every route that carries the subject's data, including duplicate paths to the same data, so duplication and inconsistency are visible without being stated.
- **Let shape carry the forcing facts.** Where a component's shape is the fact, draw it, for example a store split across many collections as several boxes.
- **Use the system's own names:** verified identifiers for code, and product terms for anything users see. Never coin names. Most boxes carry only a name.
- **Make user-facing components evoke the real UI,** while keeping them simple. The reader starts from what users are trying to do.
- **Fix unclear parts in this order:** change the structure (level, shape, grouping), then add an interaction, then use the detail panel. Add a label, number, or prose only as a last resort. Order belongs in a flow's steps, not in numbers on the diagram.
- **One step, one arrow.** A step usually highlights the single arrow it describes, so the reader always knows where they are.
- **Show how the system works at rest.** What a change or plan adds is revealed through highlights, not in the diagram at rest or in the narrative.

## Build and verify

1. **Build** with the available design skills (in Claude Code, `artifact-design` and `artifact-diagramming`). `template.html` beside this file is an optional starting point. It provides the page frame, clickable components, highlighting, a step bar, and a detail panel. Check the rendered page at 1280×800.
2. **Test with fresh agents who see only full-page screenshots,** never the source, your notes, or your answers. Make sure no screenshot catches a transition halfway. The template turns transitions off in automated browsers. A round is one first-glance test and one question test, each run by a new agent. After each round, fix what they found in the order above.
   - **First glance:** show the diagram at rest without the narrative. Ask what makes the design complex, and whether anything is hard to read. It passes when they name the forcing facts.
   - **Question test:** show the page at rest, every flow step, and every highlight or option, along with the reader questions. Grade the answers against yours. It passes when every answer is correct. Leave out the detail panels of individual components, because the diagram and its interactions should carry the answers, and the review below checks the panels.

   Stop after the first round in which both tests pass, or after three rounds, and tell the user what is still unclear. If you can't run these tests, say so.
3. **Review for accuracy and completeness.** Give a fresh agent the page and the code, but not your notes.
  - It checks that every drawn component, call, route, and detail-panel claim is true.
  - It also checks that every value a flow shows the reader, and whatever decides which values appear, can be traced along drawn arrows to its source. A gap counts only if it passes the inclusion test, and the reviewer must justify each one against it.
  - It checks each forcing fact for depth: does it name what in the data model, architecture, or an interface stops the obvious approach, or only a consequence of that? A consequence is a finding, and the reviewer names the deeper fact and verifies it in the code. Rerun the question test if the diagram changes.
4. **Iterate with the user,** updating the same page in place.
