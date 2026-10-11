#!/usr/bin/env bash
# wall: the hwdeck views as a 3 x 2 floating grid (Hyprland window rules).
#   modules/wall/install.sh [--undo]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"

if [[ ${1:-} == --undo ]]; then
  block_remove "$HYPR_DIR/hyprland.lua" hwdeck-grid --
  block_remove "$HYPR_DIR/hyprland.conf" hwdeck-grid "#"
  exit 0
fi
case $(hypr_flavour) in
lua)  block_add "$HYPR_DIR/hyprland.lua" hwdeck-grid -- < "$HERE/hwdeck-grid.lua" ;;
conf) block_add "$HYPR_DIR/hyprland.conf" hwdeck-grid "#" < "$HERE/hwdeck-grid.conf" ;;
*)    say "  no Hyprland config found in $HYPR_DIR: skipped. The rules, to add by hand:"
      sed 's/^/    /' "$HERE/hwdeck-grid.lua" ;;
esac
