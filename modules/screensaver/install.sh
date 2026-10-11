#!/usr/bin/env bash
# screensaver: digital rain as Omarchy's idle screensaver, handing over to a live hwdeck wall,
# plus an hourly rain pass over the wall (a pixel refresh) that ends on a red column.
#   Omarchy:         everything (screensaver takeover via the user override dir, rule, timer)
#   plain Hyprland:  the rain pass, its rule and the timer; no takeover
#   no Hyprland:     the programs only (`omk-screensaver --demo` in any terminal)
#   modules/screensaver/install.sh [--undo]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
UNITS=$HOME/.config/systemd/user

if [[ ${1:-} == --undo ]]; then
  act systemctl --user disable --now omk-rainpass.timer 2>/dev/null || true
  remove "$UNITS/omk-rainpass.timer" "$UNITS/omk-rainpass.service"
  act systemctl --user daemon-reload || true
  remove "$OMK_OVERRIDE_DIR/omarchy-screensaver"
  block_remove "$HYPR_DIR/hyprland.lua" rainpass --
  block_remove "$HYPR_DIR/hyprland.conf" rainpass "#"
  path_override_remove
  remove "$OMK_BIN/omk-screensaver" "$OMK_BIN/omk-deckwall" "$OMK_BIN/omk-rainpass"
  exit 0
fi

for f in omk-screensaver omk-deckwall omk-rainpass; do
  install_file "$HERE/$f" "$OMK_BIN/$f" 0755
done
flavour=$(hypr_flavour)
if [[ -z $flavour ]]; then
  say "  no Hyprland config: installed the programs only; try: omk-screensaver --demo"
  exit 0
fi
case $flavour in
lua)  block_add "$HYPR_DIR/hyprland.lua" rainpass -- < "$HERE/rainpass.lua" ;;
conf) block_add "$HYPR_DIR/hyprland.conf" rainpass "#" < "$HERE/rainpass.conf" ;;
esac
install_file "$HERE/omk-rainpass.service" "$UNITS/omk-rainpass.service" 0644
install_file "$HERE/omk-rainpass.timer" "$UNITS/omk-rainpass.timer" 0644
act systemctl --user daemon-reload
act systemctl --user enable --now omk-rainpass.timer
if is_omarchy && [[ $flavour == lua ]]; then
  ensure_override_dir
  install_file "$HERE/omarchy-screensaver.user-override" "$OMK_OVERRIDE_DIR/omarchy-screensaver" 0755
  path_override_add
  [[ -x $OMK_BIN/hwdeck ]] || say "  note: install the hwdeck and wall modules too, or the idle wall has nothing to show"
else
  say "  not Omarchy: no screensaver takeover; the hourly rain pass runs while an hwdeck view is open"
fi
say "  try one now: omk-rainpass --force"
