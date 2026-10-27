# Sourced by every zsh, interactive or not, so tools and agents see the same env.

# Linux: put Homebrew on the PATH. Here rather than .zshrc so that non-interactive
# shells (bootstrap's install scripts, agents) can find brew-installed tools.
if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# User-installed CLIs (claude, herdr, flow) live in ~/.local/bin. Here rather than
# .zshrc so that non-interactive shells (ssh commands, herdr servers) see them.
path=($HOME/.local/bin ${path:#$HOME/.local/bin})

# Personal tools (e.g. `wt`, overlayfs worktrees)
export PATH=$HOME/dotfiles/bin:$PATH

# Obsidian CDE: share the pnpm store and turbo cache across the main checkout,
# the wt base, and every wt worktree. Both must live on /workspaces (ext4) so
# pnpm can hardlink; /home is a different filesystem.
if [[ -d /workspaces/obsidian ]]; then
  export PNPM_STORE_DIR=/workspaces/obsidian/.pnpm-store
  export TURBO_CACHE_DIR=/workspaces/turbo-cache
fi
