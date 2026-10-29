# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A personal dotfiles repository that manages a complete development environment with unified **Catppuccin Frappe** theming across Ghostty, tmux, Neovim, and Zsh. Designed for local macOS.

## Installation

```bash
./bootstrap.sh           # Non-interactive (auto-approves overwrites)
./bootstrap.sh -i        # Interactive mode (prompts before removing existing files)
```

The bootstrap script symlinks everything from this repo into `$HOME`:
- `.config/*` directories → `~/.config/`
- `agents/AGENTS.md` → `~/.claude/CLAUDE.md`, `agents/claude/settings.json` → `~/.claude/settings.json` (individual files, not the whole directory, since `~/.claude/` holds transient data)
- `agents/skills/*` → `~/.claude/skills/*` (one link per skill, since `~/.claude/skills/` also holds skills from other sources)
- `.gitconfig`, `.oh-my-zsh`, `.zshrc` → `~/`

It then runs `install-scripts/*.zsh`, which install Neovim, herdr, googleworkspace-cli (`gws`), and flow.

On cloud dev environments with a shared network mount at `$EFS_MOUNT_POINT`, `post-start-install.sh` runs after the mount is set up. It replaces the paths listed at the top of the script with symlinks into the mount so they persist across environments, then re-links the agent config into the shared `~/.claude` and runs `install-scripts/flow.zsh` to bring flow up to date. Only paths belong in this repo, never the mount's contents.

`.config/herdr/` is the one `.config` entry linked file-by-file rather than as a
directory, because `~/.config/herdr/` also holds sockets, logs, session state, and
built plugins. Only `config.toml` belongs in this repo.

There is no build system, test suite, or linter for the dotfiles themselves.

## Architecture

**Symlink-based**: All configs live in this repo and are symlinked to `$HOME`. The repo *is* the source of truth — edit files here, not in `~/.config/`.

**Custom zsh functions** live in `.oh-my-zsh/custom/*.zsh` and are auto-loaded by Oh My Zsh. Each file defines a command:

| File | Command | Purpose | Key Dependencies |
|------|---------|---------|------------------|
| `prs.zsh` | `prs` | GitHub PR management (list/open/view with rich rendering) | `gh`, `jq`, `glow`, `fzf` |
| `contrib.zsh` | `contrib` | Per-user contribution reports for a repo: `prs` (merged PRs, merge rate, lines touched) and `reviews` (review counts by outcome) | `gh`, `jq` |
| `ona.zsh` | `ona` | Gitpod/ONA environment management with SSH tunneling | `ssh`, `fzf` |
| `git.zsh` | `gg` | Interactive git branch switching | `fzf` |
| `imageutils.zsh` | `dotviu` | Render Graphviz `.dot` files in terminal | `graphviz`, `viu` |

**Neovim** uses LazyVim distribution with Lazy.nvim package manager. Custom plugin configs go in `.config/nvim/lua/plugins/`. The colorscheme is set in `.config/nvim/lua/config/lazy.lua`.

**tmux** uses `Ctrl+Space` as prefix (not `Ctrl+b`). Pane borders show remote environment name when SSH'd into one. Config at `.config/tmux/tmux.conf`.

**herdr** (agent workspace manager) also uses `Ctrl+Space` as prefix (not `Ctrl+b`),
with `prefix+space` / `prefix+shift+space` for next/previous agent. Config at
`.config/herdr/config.toml`, symlinked to `~/.config/herdr/config.toml`. Run
`herdr --default-config` for the full reference and `herdr config check` to validate.
Unlike tmux, herdr has no `send-prefix` action, so `<C-Space>` cannot be passed
through to apps in a pane — it is unreachable in Neovim (treesitter incremental
selection, blink.cmp manual complete).

**Agent config** lives in `agents/` (no dot, to distinguish from project-level `.claude/` directories). `agents/AGENTS.md` holds harness-neutral, user-scoped rules and is symlinked to `~/.claude/CLAUDE.md`; harness-specific config sits in a subdirectory (`agents/claude/settings.json`). Skills written here live in `agents/skills/<name>/`, each linked into `~/.claude/skills/`; skills from flow and other sources are linked by their own installers.

**flow** ([weston-vanta/flow](https://github.com/weston-vanta/flow)), the supervisor for agent sessions across dev environments, does not install anything into the agent config. `install-scripts/flow.zsh` clones it to `/workspaces/flow` and runs its `scripts/install.sh`, which pulls the clone, links its `state/` to the shared state directory on EFS, builds the binary, and links it into `~/.local/bin`. Machines without the shared state mount (the Mac) skip it.

## Conventions

- Shell functions use a subcommand pattern: `command subcmd [args]` with a `help` subcommand.
- `prs` uses GitHub's GraphQL API via `gh api graphql` for rich PR data, and REST API for simpler queries.
- The `prs` and `ona` commands use `fzf` for interactive selection when no argument is given.
- Heredocs and `printf` are preferred over `echo` for piping content to `jq` and `glow`.
