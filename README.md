# weston.fribley dotfiles

This repository contains configuration files that automatically set up a consistent development environment across different machines. All tools are configured with the Catppuccin Frappe color theme.

## Tools Configured

- **Zsh** with Oh My Zsh framework (headline theme)
- **Ghostty** terminal emulator (FiraCode Nerd Font)
- **tmux** terminal multiplexer (Ctrl+Space prefix)
- **Neovim** with LazyVim distribution
- **Git** user configuration

## Installation

### Manual Installation

```bash
git clone <repository-url> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

The bootstrap script creates symlinks from this repository to your home directory for all configuration files.

## Custom zsh functions

- `prs` -- view and open GitHub PRs (`prs help` for usage).
- `ona` -- interact with Ona environments (`ona help` for usage).
- `gg` -- interactive git branch switching via fzf.
- `dotviu` -- render Graphviz `.dot` files in the terminal.
- `ai` -- AI knowledge management (extract from transcripts, sync to shadow repo).
