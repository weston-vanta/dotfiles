#!/usr/bin/env zsh
# Installs flow (github.com/weston-vanta/flow), the supervisor for agents across dev
# environments.
#
# flow installs where its shared state mount is: $EFS_MOUNT_POINT, holding the shared state
# directory ($FLOW_STATE_DIR, default $EFS_MOUNT_POINT/flow/state). bootstrap.sh runs this
# script on every machine, so the Mac and a bootstrap that runs before the mount is up skip
# it; post-start-install.sh, which has a similar mount check, installs it on the next start.
#
# Clones flow to $FLOW_DIR (default /workspaces/flow) unless something is already there,
# then runs the clone's scripts/install.sh, which pulls it, links its state/ to the shared
# state directory, builds target/release/flow, and links the binary into ~/.local/bin. Both
# steps are idempotent, so post-start-install.sh runs this on every machine start too.

set -euo pipefail

if [[ -z ${EFS_MOUNT_POINT:-} ]] || ! command -v mountpoint >/dev/null ||
  ! mountpoint -q "$EFS_MOUNT_POINT"; then
  echo "flow: no shared state mount on this machine, skipping"
  exit 0
fi

FLOW_REPO="https://github.com/weston-vanta/flow.git"
export FLOW_DIR="${FLOW_DIR:-/workspaces/flow}"
export FLOW_STATE_DIR="${FLOW_STATE_DIR:-$EFS_MOUNT_POINT/flow/state}"

# Failures below are soft: bootstrap and post-start run with `set -e`, and the rest of
# what they set up is still useful without flow.
if [[ -e $FLOW_DIR ]]; then
  echo "flow: checkout already present at $FLOW_DIR"
else
  echo "flow: cloning into $FLOW_DIR"
  if ! git clone --quiet "$FLOW_REPO" "$FLOW_DIR"; then
    echo "WARNING: could not clone $FLOW_REPO, skipping flow"
    exit 0
  fi
fi

# The shell rc puts ~/.local/bin on PATH for shells; install.sh runs outside one here.
if ! PATH="$HOME/.local/bin:$PATH" bash "$FLOW_DIR/scripts/install.sh"; then
  echo "WARNING: flow's install.sh failed; fix the cause above, then re-run:"
  echo "  bash $FLOW_DIR/scripts/install.sh"
fi
