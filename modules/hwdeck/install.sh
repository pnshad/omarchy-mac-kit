#!/usr/bin/env bash
# hwdeck: the terminal dashboards (https://github.com/pnshad/hwdeck), one Python file, to
# ~/.local/bin/hwdeck. Uses a sibling checkout ../hwdeck when there is one, else clones the
# pinned tag.
#   modules/hwdeck/install.sh [--undo]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
REPO=https://github.com/pnshad/hwdeck
TAG=${OMK_HWDECK_TAG:-v0.5.0}          # pinned; bump deliberately

if [[ ${1:-} == --undo ]]; then
  remove "$OMK_BIN/hwdeck"
  exit 0
fi
src=$OMK_ROOT/../hwdeck/hwdeck
if [[ -f $src ]]; then
  say "  hwdeck from the local checkout $(cd "$(dirname "$src")" && pwd)"
else
  say "  hwdeck from $REPO at tag $TAG"
  if dry; then
    say "  would run: git clone --depth 1 --branch $TAG $REPO <temp dir>"
    src=/dev/null
  else
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    git clone -q --depth 1 --branch "$TAG" "$REPO" "$tmp/hwdeck"
    src=$tmp/hwdeck/hwdeck
  fi
fi
install_file "$src" "$OMK_BIN/hwdeck" 0755
dry || "$OMK_BIN/hwdeck" --version
