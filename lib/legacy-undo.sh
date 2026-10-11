#!/usr/bin/env bash
# Undo for the modules that moved to omarchy-mac-kit-extras (wall, screensaver), kept so that
# anyone who installed them from an older omarchy-mac-kit can still take them out from here.
# omarchy-mac-kit-extras owns them now; its `./install.sh --undo wall|screensaver` does the same.
#   lib/legacy-undo.sh wall|screensaver
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/common.sh"
UNITS=$HOME/.config/systemd/user

case ${1:-} in
wall)
  block_remove "$HYPR_DIR/hyprland.lua" hwdeck-grid --
  block_remove "$HYPR_DIR/hyprland.conf" hwdeck-grid "#"
  ;;
screensaver)
  act systemctl --user disable --now omk-rainpass.timer 2>/dev/null || true
  remove "$UNITS/omk-rainpass.timer" "$UNITS/omk-rainpass.service"
  act systemctl --user daemon-reload || true
  remove "$OMK_OVERRIDE_DIR/omarchy-screensaver"
  block_remove "$HYPR_DIR/hyprland.lua" rainpass --
  block_remove "$HYPR_DIR/hyprland.conf" rainpass "#"
  path_override_remove
  remove "$OMK_BIN/omk-screensaver" "$OMK_BIN/omk-deckwall" "$OMK_BIN/omk-rainpass"
  ;;
*) die "usage: $0 wall|screensaver" ;;
esac
