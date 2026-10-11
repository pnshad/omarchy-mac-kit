#!/usr/bin/env bash
# hwdeck: the terminal dashboards (https://github.com/pnshad/hwdeck), one Python file, to
# ~/.local/bin/hwdeck. Uses a sibling checkout ../hwdeck when there is one, else clones the
# pinned tag.
#   modules/hwdeck/install.sh [--undo]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
REPO=https://github.com/pnshad/hwdeck
COMMIT=03fb89448691dc92468621d7c61a456176680d67   # pinned; bump deliberately after reading the diff
TAG=${OMK_HWDECK_TAG:-}                          # optional: a release tag that must point at COMMIT

if [[ ${1:-} == --undo ]]; then
  remove "$OMK_BIN/hwdeck"
  exit 0
fi
src=
if use_sibling "$OMK_ROOT/../hwdeck" hwdeck; then
  src=$OMK_ROOT/../hwdeck/hwdeck
elif dry; then
  fetch_pinned "$REPO" "$COMMIT" "" "$TAG"
  src=/dev/null
else
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  fetch_pinned "$REPO" "$COMMIT" "$tmp/hwdeck" "$TAG"
  src=$tmp/hwdeck/hwdeck
fi
install_file "$src" "$OMK_BIN/hwdeck" 0755
dry || "$OMK_BIN/hwdeck" --version
