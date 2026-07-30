#!/usr/bin/env zsh
# Installs flow (github.com/weston-vanta/flow) — the agent skill pipeline.
#
# Clones the repo to ~/.flow/source unless that path already exists. On a machine
# where flow is developed, ~/.flow/source is a symlink to the working checkout, so
# the guard below deliberately leaves it alone. flow's own installer then
# bootstraps the flow home and wires the skills into every harness it detects.

set -euo pipefail

FLOW_REPO="git@github.com:weston-vanta/flow.git"
FLOW_SOURCE="$HOME/.flow/source"

if [[ -e "$FLOW_SOURCE" || -L "$FLOW_SOURCE" ]]; then
  echo "flow source already present at $FLOW_SOURCE"
else
  echo "Cloning flow into $FLOW_SOURCE"
  mkdir -p "$(dirname "$FLOW_SOURCE")"
  git clone --quiet "$FLOW_REPO" "$FLOW_SOURCE"
fi

# A non-zero exit means unresolved collisions. Report it but let bootstrap carry
# on, rather than aborting the remaining install scripts.
if ! "$FLOW_SOURCE/install.sh"; then
  echo
  echo "WARNING: flow's installer reported collisions and did not finish."
  echo "Review the list above, then re-run with the entries you approve:"
  echo "  $FLOW_SOURCE/install.sh --replace <name1,name2,...>"
fi
