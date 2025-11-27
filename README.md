# weston.fribley dotfiles

This repository contains configuration files that automatically set up a consistent development environment across different machines and GitHub Codespaces. All tools are configured with the Catppuccin Frappe color theme.

## Tools Configured

- **Zsh** with Oh My Zsh framework (headline theme)
- **Ghostty** terminal emulator (FiraCode Nerd Font)
- **tmux** terminal multiplexer (Ctrl+Space prefix)
- **Neovim** with LazyVim distribution
- **Git** user configuration

## Installation

### GitHub Codespaces

This repository works automatically with GitHub Codespaces. When you create a new Codespace, the `bootstrap.sh` script will execute automatically and set up all configurations via symlinks.

### Manual Installation

```bash
git clone <repository-url> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

The bootstrap script creates symlinks from this repository to your home directory for all configuration files.
