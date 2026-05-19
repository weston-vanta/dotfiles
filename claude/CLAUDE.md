# CLAUDE.md (user-level)

Loaded for every Claude Code session, regardless of project. Settings here apply globally unless a project-level `CLAUDE.md` overrides them.

## Agent skills

### Issue tracker

Issues live in Jira project `COL`, under a personal epic, managed via the `acli jira` CLI. See `~/.claude/resources/issue-tracker.md`.

### Triage labels

Default canonical labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `~/.claude/resources/triage-labels.md`.

### Domain docs

Single-context layout by default (one `CONTEXT.md` + `docs/adr/` at the repo root). See `~/.claude/resources/domain.md`.
