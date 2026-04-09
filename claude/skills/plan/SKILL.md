---
name: plan
description: Use when you have a PRD, research, and design for a multi-step task, before touching any code.
---

# Plan

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the plan skill to create implementation plans."

## Process

### 1. Read inputs

- Read the PRD.
- Read the research document.
- Read the design document.
- Read the user's scope of work, if any.

### 2. Scope check

If the design covers multiple independent subsystems, suggest splitting this into multiple plans. Each plan should produce working, testable, shippable software on its own.

If the user agrees to multiple plans, propose plan groupings for user refinement. Once approved you may proceed.

### 3. Confirm output location

- Propose the most relevant `.ai-dev` directory (typically the same as the design doc)
- Confirm with the user before writing
- File naming: `<topic>-plan.md` (or `<topic>-plan-1.md`, `<topic>-plan-2.md` for multiple)

### 4. Write plans

For each plan document, write with frontmatter:

```yaml
---
created: YYYY-MM-DD
revised: YYYY-MM-DD
type: plan
links:
  prd: <path-to-prd>
  research: <path-to-research-doc>
  design: <path-to-design-doc>
---
```
**IMPORTANT:** do NOT use writing-docs to write the first draft. You will complete a self-review (step 5), only then use writing-docs for human-in-the-loop review.

### 5. Self-Review

After writing the complete plan, look at the PRD, research, and design with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Design spec coverage:** Skim each section/requirement in the design. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

### 6. Human-in-the-loop review

Invoke `/skill writing-docs` to manage the review loop with the user.

### 7. Handoff

When all plans are approved:

Announce: "Plans complete. Ready to implement with subagents?"

If yes:
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development.
- Fresh subagent per task + two-stage review.

## Plan Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

### Bite-sized task granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

### Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

### Task Structure

````markdown
## Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

### No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

### Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits
