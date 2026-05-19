# Issue tracker: Jira (via acli)

Issues for this repo (and any repo without a project-level override) live in Jira project `COL`, under a personal epic to keep them scoped to me.

- **Project key**: `COL`
- **Parent epic**: `<PERSONAL_EPIC_KEY>` — replace with the actual epic key once created
- **CLI**: Atlassian's `acli`, using the `jira` subcommand. Run `acli jira --help` for current syntax; do not assume command shapes from memory.

## When a skill says "publish to the issue tracker"

Create a Jira issue in project `COL`, parented to `<PERSONAL_EPIC_KEY>`, using `acli jira`. The issue title and body come from the skill; the project and parent come from this file.

## When a skill says "fetch the relevant ticket"

The user will normally pass the issue key (e.g. `COL-1234`). Read it via `acli jira`.

## Project-level overrides

If a repo has its own `CLAUDE.md` with an `## Agent skills` → `### Issue tracker` section, that wins.
