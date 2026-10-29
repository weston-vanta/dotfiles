#!/usr/bin/env bash
#
# Run by the dev environment's post-start step after it mounts shared storage
# at $EFS_MOUNT_POINT. Replaces selected home paths with symlinks into that
# mount so they are shared across environments, then brings flow up to date
# (install-scripts/flow.zsh).
#
# Having this hook replaces the environment's default shared-storage hook, so
# it covers everything that one shares.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EFS="${EFS_MOUNT_POINT:-}"

if [[ -z "$EFS" || "$EFS" == "$HOME" ]] || ! mountpoint -q "$EFS"; then
  echo "EFS is not mounted beside the home directory, skipping shared links"
  echo "flow: its shared state is on EFS, skipping"
  exit 0
fi

SHARED_DIRS=(.claude .config/gh .config/gws .config/acli)
# Environment setup creates a fresh local ~/.claude.json, so the EFS copy wins.
SHARED_FILES=(.claude.json)
# Nothing in setup creates these, so a local regular file means the tool
# replaced the symlink (e.g. on re-login) and holds the freshest credentials.
SHARED_FILES_PREFER_LOCAL=(.codex/auth.json)

# Directories: local contents are merged into EFS without overwriting what is
# already there. Files: an existing EFS copy wins over the local one, unless
# kind is file-prefer-local.
link_shared() {
  local kind="$1" rel="$2"
  local local_path="$HOME/$rel" efs_path="$EFS/$rel"

  if [[ -L "$local_path" && "$(readlink "$local_path")" == "$efs_path" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$efs_path")" "$(dirname "$local_path")"

  if [[ "$kind" == dir ]]; then
    mkdir -p "$efs_path"
    if [[ -d "$local_path" && ! -L "$local_path" ]]; then
      rsync -a --ignore-existing "$local_path/" "$efs_path/"
    fi
    rm -rf "$local_path"
  elif [[ "$kind" == file-prefer-local && -f "$local_path" && ! -L "$local_path" ]]; then
    mv -f "$local_path" "$efs_path"
  elif [[ -e "$local_path" || -L "$local_path" ]]; then
    [[ -e "$efs_path" ]] || mv "$local_path" "$efs_path"
    rm -f "$local_path"
  fi

  echo "Linking: $local_path -> $efs_path"
  ln -s "$efs_path" "$local_path"
}

for rel in "${SHARED_DIRS[@]}"; do
  link_shared dir "$rel"
done
for rel in "${SHARED_FILES[@]}"; do
  link_shared file "$rel"
done
for rel in "${SHARED_FILES_PREFER_LOCAL[@]}"; do
  link_shared file-prefer-local "$rel"
done

# bootstrap.sh links these into the local ~/.claude, which is now replaced by
# the EFS copy.
ln -sfn "$DOTFILES_DIR/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
ln -sfn "$DOTFILES_DIR/agents/claude/settings.json" "$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude/skills"
for skill_dir in "$DOTFILES_DIR/agents/skills"/*/; do
  skill_link="$HOME/.claude/skills/$(basename "$skill_dir")"
  # ln -sfn would nest the link inside a real directory, so leave one in place for bootstrap.sh to replace.
  if [[ -d "$skill_link" && ! -L "$skill_link" ]]; then
    echo "Skipping $skill_link: a directory is in the way; run bootstrap.sh to replace it"
    continue
  fi
  ln -sfn "${skill_dir%/}" "$skill_link"
done

# flow's state/ links into the mount, so this runs once the shared links are up.
zsh "$DOTFILES_DIR/install-scripts/flow.zsh"
