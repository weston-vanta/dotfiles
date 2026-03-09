---
name: plan
description: Use when you have a completed design document and need to break it into fine-grained implementation tasks before writing code
---

# Plan

## Overview

Take completed research, a design document, and a user-specified scope of work. Produce one or more fine-grained implementation plan documents with TDD-structured tasks. Every design requirement must map to tests.

**Announce at start:** "I'm using the plan skill to create implementation plans."

## Process

### 1. Read inputs

- Read the research document
- Read the design document
- Read the user's scope of work (which subset of the design to plan now)

### 2. Propose work groupings

Analyze the scoped work and propose how to split it into separate plan documents.

- **Favor logically independent groupings** that can be implemented in parallel
- Do not separate by component unless each group is also logically independent
- Present proposed groupings to the user and wait for approval
- A single plan document is fine when the scope is small enough

### 3. Confirm output location

- Propose the most relevant `.ai-dev` directory (typically the same as the design doc)
- Confirm with the user before writing
- File naming: `YYYY-MM-DD-<topic>-plan.md` (or `-plan-1.md`, `-plan-2.md` for multiple)

### 4. Write plans

For each plan document, write with frontmatter:

```yaml
---
created: YYYY-MM-DD
revised: YYYY-MM-DD
type: plan
links:
  research: <path-to-research-doc>
  design: <path-to-design-doc>
---
```

**REQUIRED SUB-SKILL:** Use writing-docs for the review loop on each plan document.

### 5. Handoff

When all plans are approved:

"Plans complete. Ready to implement?"

## Task Structure

Each task in the plan follows this structure:

```markdown
### Task N: [Descriptive Name]

**Goal:** One sentence describing what this task accomplishes.

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**

\```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
\```

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**

\```python
def function(input):
    return expected
\```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/path/test.py -v`
Expected: ALL PASS

**Step 5: Commit**

\```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
\```
```

## Planning Rules

### TDD enforcement

- TDD is the default for all plans
- Only skip TDD if the user explicitly agrees the work is trivial
- Surface the TDD decision: "This plan will use TDD. The scope is simple enough that we could skip it -- your preference?"
- **Every requirement from the design must map to at least one test** (unit, integration, or end-to-end)

### Task granularity

Each step is one action:
- "Write the failing test" -- one step
- "Run it to make sure it fails" -- one step
- "Implement the minimal code" -- one step
- "Run the tests" -- one step

### Commits

- Commits are **explicit steps** in the plan, not implied
- Place commits at **logical boundaries** that produce consistent, reviewable units of work
- Not every test cycle needs a commit -- group related changes when it makes sense
- Commit messages should be meaningful and conventional

### Detail level

- **Exact file paths** for every file touched
- **Complete code** in the plan (not "add validation here")
- **Exact commands** with expected output for verification steps
- **Line ranges** when modifying existing files

### Requirement traceability

Include a traceability section at the top of each plan:

```markdown
## Requirement Traceability

| Requirement | Test(s) | Task(s) |
|------------|---------|---------|
| R1: User can log in | test_login_success, test_login_failure | Task 2, Task 3 |
| R2: Sessions expire | test_session_expiry | Task 5 |
```

Every requirement from the design doc must appear in this table with at least one test.
