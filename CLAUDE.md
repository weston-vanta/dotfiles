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
- `claude/` contents (settings, prompts, skills, hooks) → `~/.claude/` (individual files/dirs, not the whole directory)
- `.gitconfig`, `.oh-my-zsh`, `.zshrc` → `~/`

There is no build system, test suite, or linter for the dotfiles themselves.

## Architecture

**Symlink-based**: All configs live in this repo and are symlinked to `$HOME`. The repo *is* the source of truth — edit files here, not in `~/.config/`.

**Custom zsh functions** live in `.oh-my-zsh/custom/*.zsh` and are auto-loaded by Oh My Zsh. Each file defines a command:

| File | Command | Purpose | Key Dependencies |
|------|---------|---------|------------------|
| `prs.zsh` | `prs` | GitHub PR management (list/open/view with rich rendering) | `gh`, `jq`, `glow`, `fzf` |
| `ona.zsh` | `ona` | Gitpod/ONA environment management with SSH tunneling | `ssh`, `fzf` |
| `git.zsh` | `gg` | Interactive git branch switching | `fzf` |
| `imageutils.zsh` | `dotviu` | Render Graphviz `.dot` files in terminal | `graphviz`, `viu` |
| `ai.zsh` | `ai` | AI knowledge management (extract from transcripts, sync to shadow repo) | `jq`, `claude`, `git` |

**Neovim** uses LazyVim distribution with Lazy.nvim package manager. Custom plugin configs go in `.config/nvim/lua/plugins/`. The colorscheme is set in `.config/nvim/lua/config/lazy.lua`.

**tmux** uses `Ctrl+Space` as prefix (not `Ctrl+b`). Pane borders show remote environment name when SSH'd into one. Config at `.config/tmux/tmux.conf`.

**Claude Code** config lives in `claude/` (no dot, to distinguish from project-level `.claude/` directories) and is symlinked as individual files into `~/.claude/` (not the whole directory, since `~/.claude/` contains transient data like history and sessions). The `ai` command manages knowledge extraction from Claude Code transcripts into `.ai-dev/knowledge.md` files, tracked in a shadow git repo (`.git-ai`).

## Conventions

- Shell functions use a subcommand pattern: `command subcmd [args]` with a `help` subcommand.
- `prs` uses GitHub's GraphQL API via `gh api graphql` for rich PR data, and REST API for simpler queries.
- The `prs` and `ona` commands use `fzf` for interactive selection when no argument is given.
- Heredocs and `printf` are preferred over `echo` for piping content to `jq` and `glow`.
