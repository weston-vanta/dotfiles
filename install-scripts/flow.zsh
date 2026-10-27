#!/usr/bin/env zsh
# Installs flow (github.com/weston-vanta/flow), the supervisor for agents across dev
# environments.
#
# Clones flow to $FLOW_DIR (default /workspaces/flow) unless something is already there,
# then runs the clone's scripts/install.sh, which pulls it, links its state/ to the shared
# state directory ($FLOW_STATE_DIR, default /efs-home/flow/state), and builds
# target/release/flow. Both steps are idempotent, so post-start-install.sh runs this on
# every machine start too. A machine without the clone's parent directory (the Mac has no
# /workspaces) is skipped.

set -euo pipefail

FLOW_REPO="https://github.com/weston-vanta/flow.git"
export FLOW_DIR="${FLOW_DIR:-/workspaces/flow}"

if [[ ! -d ${FLOW_DIR:h} ]]; then
  echo "flow: no ${FLOW_DIR:h} on this machine, skipping"
  exit 0
fi

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

# .zshrc puts target/release on PATH for shells; install.sh runs outside one, so it
# would otherwise ask for a PATH entry that is already taken care of.
if ! PATH="$FLOW_DIR/target/release:$PATH" bash "$FLOW_DIR/scripts/install.sh"; then
  echo "WARNING: flow's install.sh failed; fix the cause above, then re-run:"
  echo "  bash $FLOW_DIR/scripts/install.sh"
fi
