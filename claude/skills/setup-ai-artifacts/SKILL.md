---
name: setup-ai-artifacts
description: One-time setup of the sibling ai-artifacts/ git repo that stores agent-generated artifacts (research, design, plan, etc.) for every host repo in this workspace parent dir. Run when a skill needs to write an artifact but `../ai-artifacts/` doesn't exist yet.
disable-model-invocation: true
---

# Setup AI Artifacts Repo

See `~/.claude/resources/ai-artifacts.md` for the full convention. This skill bootstraps the repo on first use.

## When to run

Other skills (notably `writing-docs`) call this out when they need to write an artifact and can't find a sibling `ai-artifacts/` repo. Run it once per workspace parent dir (the directory that contains host repos).

## Process

### 1. Find the workspace parent dir

Determine the host repo:

```
host_repo=$(git rev-parse --show-toplevel)
workspace=$(dirname "$host_repo")
```

If the current directory isn't a git repo, ask the user where the host work lives — don't guess.

### 2. Check if the artifacts repo already exists

```
if [ -d "$workspace/ai-artifacts/.git" ]; then exists; fi
```

If it does, tell the user the path, confirm it's correct, and exit — no setup needed.

### 3. Confirm location and remote with the user

Present the defaults and let the user override:

- **Location**: `$workspace/ai-artifacts/` (sibling of the host repo).
- **Remote**: ask the user — typical answer is a private GitHub repo like `git@github.com:<user>/ai-artifacts.git`. Don't guess. If they don't have one yet, prompt them to create it (empty, private) and paste the URL back.

Show both choices, get explicit confirmation, then proceed.

### 4. Clone or init

If the user provides a remote and it already has content:

```
git clone <remote> <location>
```

Otherwise, init fresh and wire up the remote:

```
mkdir -p <location>
cd <location>
git init
git remote add origin <remote>
```

### 5. Seed with a README and initial commit

Create `<location>/README.md` with a short explanation:

```markdown
# AI Artifacts

Agent-generated artifacts for host repos in `<workspace>`.

Layout: `<host-repo-slug>/<feature-slug>/<topic>.md` (flat inside each feature).

Managed by Claude Code skills via dotfiles. See `~/.claude/resources/ai-artifacts.md` for the convention.
```

Then:

```
git add README.md
git commit -m "init: ai-artifacts repo"
git push -u origin HEAD
```

If the push fails because the remote is empty and the default branch differs, fall back to `git push -u origin main` (or `master`) — ask the user which branch name to use if it's ambiguous.

### 6. Verify the hooks

Confirm that the gsync upload hook and the SessionEnd commit/push hook are in place by inspecting `~/.claude/settings.json`. Both should already be registered via the dotfiles — flag it to the user if either is missing.

### 7. Done

Tell the user the path of the new artifacts repo and that subsequent `writing-docs` (and similar) sessions will write here automatically. The SessionEnd hook will commit and push at the end of each session.
