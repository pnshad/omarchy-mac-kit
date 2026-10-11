#!/usr/bin/env bash
# lid: closing the lid locks, freezes GUI apps, turns the panel off and saves power, without
# suspend (omk-lid); a sleep/awake mode; and two Omarchy fixes as user overrides:
#   omarchy-brightness-keyboard   "off" remembers the level only when above 0 (Omarchy saved 0)
#   omarchy-hw-external-monitors  a T1 Touch Bar (DRM connector card*-USB-*) is not a monitor;
#                                 installed only when such a connector exists
# Omarchy laptops only (it calls Omarchy's lid and lock commands).
#   modules/lid/install.sh [--undo]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
bindings=$HYPR_DIR/bindings.lua
[[ -f $bindings ]] || bindings=$HYPR_DIR/hyprland.lua

if [[ ${1:-} == --undo ]]; then
  block_remove "$HYPR_DIR/bindings.lua" lid --
  block_remove "$HYPR_DIR/hyprland.lua" lid --
  remove "$OMK_OVERRIDE_DIR/omarchy-brightness-keyboard" "$OMK_OVERRIDE_DIR/omarchy-hw-external-monitors"
  path_override_remove
  remove "$OMK_BIN/omk-lid"
  say "  kept ~/.config/omk/lid-mode and lid-stop (your settings); delete them by hand if you like"
  exit 0
fi

if ! is_omarchy || [[ $(hypr_flavour) != lua ]]; then
  say "  skipped: the lid module needs Omarchy (Hyprland Lua config and Omarchy's lid commands)"
  dry || exit 0
fi
[[ -d /proc/acpi/button/lid ]] || compgen -G "/sys/class/drm/card*-eDP-*" > /dev/null \
  || say "  note: no laptop lid or panel found; installing anyway"
install_file "$HERE/omk-lid" "$OMK_BIN/omk-lid" 0755
if [[ ! -e $OMK_CONFIG/lid-stop ]]; then
  printf '# Process names (one per line) that omk-lid stops while the lid is closed in sleep mode\n# and resumes on open, with everything they started. Example: claude\n' \
    | put "$OMK_CONFIG/lid-stop" 0644
fi
block_add "$bindings" lid -- < "$HERE/lid-bindings.lua"
ensure_override_dir
install_file "$HERE/omarchy-brightness-keyboard.user-override" "$OMK_OVERRIDE_DIR/omarchy-brightness-keyboard" 0755
if compgen -G "/sys/class/drm/card*-USB-*" > /dev/null; then
  say "  a USB display connector (T1 Touch Bar) exists: installing the external-monitor fix"
  install_file "$HERE/omarchy-hw-external-monitors.user-override" "$OMK_OVERRIDE_DIR/omarchy-hw-external-monitors" 0755
elif dry; then
  say "  (the external-monitor fix is added only when a card*-USB-* connector exists)"
fi
path_override_add
say "  mode: omk-lid mode | omk-lid toggle"
