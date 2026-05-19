# AI Artifacts Repo

A separate, privately-tracked git repo that stores every agent-generated artifact (research, design, plan, etc.) produced while working on other repos. Nothing agent-generated lives inside a host repo's working tree.

## Location

By default, the artifacts repo lives as a **sibling of the host repo**, named `ai-artifacts/`:

```
~/Workspaces/
├── vanta-foo/              ← host repo
├── vanta-bar/              ← host repo
└── ai-artifacts/           ← artifacts for everything in this parent dir
```

Each workspace parent dir gets its own `ai-artifacts/` repo with its own remote. If the user keeps host repos in multiple parent dirs (e.g. `~/Workspaces/` and `~/code/`), each parent gets a separate artifacts repo.

If `../ai-artifacts/` is missing when a skill needs to write an artifact, run `/setup-ai-artifacts` to create or clone it. That skill confirms the location and remote with the user before touching the filesystem.

## Layout

```
ai-artifacts/
├── <host-repo-slug>/
│   └── <feature-slug>/
│       ├── research.md
│       ├── design.md
│       └── plan.md
└── README.md
```

- **`<host-repo-slug>`**: `basename` of the host repo's working tree (i.e. the directory name).
- **`<feature-slug>`**: kebab-case feature name. Claude proposes it from conversation context, the current git branch, and existing features already under `ai-artifacts/<host-repo-slug>/`, then confirms with the user. Once confirmed, it's reused for the rest of the session.
- **Flat layout** inside each feature dir — files are named by topic (`research.md`, `design.md`, `plan.md`, etc.). History lives in git, not in filenames.

## Hooks

- **PostToolUse (gsync upload)**: when a file inside any `ai-artifacts/` repo is edited or written, the gsync hook uploads it to Google Drive. The Drive link is reported back to the agent.
- **SessionEnd (commit + push)**: at session end, the artifacts repo is auto-committed and pushed to its remote. No manual `git add`/`commit`/`push` required.

## Finding the artifacts repo from a file path

Walk up parent directories from the host repo. If any sibling is a directory named `ai-artifacts/` containing a `.git/`, that's the artifacts repo. Hooks use the same lookup against the edited file's path.

## When to write here

Any skill that produces a doc the user is meant to review (research notes, design docs, plans, PRDs, etc.) writes to `ai-artifacts/<host-repo>/<feature>/<topic>.md` by default. Production code, tests, and other in-tree changes still go inside the host repo.
