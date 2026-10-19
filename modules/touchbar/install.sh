#!/usr/bin/env bash
# touchbar: touchbar-strip (https://github.com/pnshad/touchbar-strip) as t1bridge's Touch Bar
# renderer, its config, and the drop-in that gives t1bridge Omarchy's desktop provider. Needs a
# working t1bridge (t1-touchbar.service, a user unit); see https://github.com/standardagents/t1bridge.
# The provider script is t1bridge's own (contrib/omarchy/t1bridge-omarchy-provider.sh, MIT): point
# T1BRIDGE_SRC at your t1bridge checkout, or install it to ~/.local/bin yourself.
#   modules/touchbar/install.sh [--undo]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
REPO=https://github.com/pnshad/touchbar-strip
COMMIT=44f7d6151111afa00d777fe1f499a5985f2dc693   # pinned; bump deliberately after reading the diff
TAG=${OMK_STRIP_TAG:-}                           # optional: a release tag that must point at COMMIT
LIB=$HOME/.local/lib/touchbar-strip
CONF=$HOME/.config/touchbar-strip/config.json
LINK=$HOME/.config/t1bridge/renderer
DROPIN=$HOME/.config/systemd/user/t1-touchbar.service.d/omk-provider.conf
PROVIDER=$OMK_BIN/t1bridge-omarchy-provider

if [[ ${1:-} == --undo ]]; then
  [[ -L $LINK && $(readlink "$LINK") == "$LIB/touchbar-strip" ]] && remove "$LINK"
  remove "$DROPIN" "$LIB/touchbar-strip"
  act systemctl --user daemon-reload
  act systemctl --user restart t1-touchbar.service || true
  say "  kept $CONF (your settings) and $PROVIDER (t1bridge's)"
  exit 0
fi

product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)
case $product in
MacBookPro13,2|MacBookPro13,3|MacBookPro14,2|MacBookPro14,3) say "  $product: a T1 Touch Bar Mac" ;;
*) say "  $product is not a T1 Touch Bar MacBook Pro"; dry || exit 0 ;;
esac
if ! dry && ! systemctl --user cat t1-touchbar.service > /dev/null 2>&1; then
  die "t1-touchbar.service (t1bridge) not found: install t1bridge first"
fi

src=
if use_sibling "$OMK_ROOT/../touchbar-strip" touchbar-strip; then
  src=$OMK_ROOT/../touchbar-strip
elif dry; then
  fetch_pinned "$REPO" "$COMMIT" "" "$TAG"
else
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  fetch_pinned "$REPO" "$COMMIT" "$tmp/touchbar-strip" "$TAG"
  src=$tmp/touchbar-strip
fi
if [[ -n $src ]]; then
  install_file "$src/touchbar-strip" "$LIB/touchbar-strip" 0755
else
  say "  would write $LIB/touchbar-strip (mode 0755)"
fi
if [[ -e $CONF ]]; then
  say "  kept your $CONF"
elif [[ -n $src ]]; then
  install_file "$src/config.example.json" "$CONF" 0600
else
  say "  would write $CONF from config.example.json (mode 0600)"
fi
dry || "$LIB/touchbar-strip" --check || warn "touchbar-strip --check reported problems (above)"

if [[ ! -x $PROVIDER ]]; then
  p=${T1BRIDGE_SRC:-}/contrib/omarchy/t1bridge-omarchy-provider.sh
  if [[ -n ${T1BRIDGE_SRC:-} && -f $p ]]; then install_file "$p" "$PROVIDER" 0755
  else say "  no $PROVIDER: set T1BRIDGE_SRC=<t1bridge checkout> to install it (volume/media keys need it)"; fi
fi
install_file "$HERE/t1-touchbar-omk.conf" "$DROPIN" 0644
act ln -sfn "$LIB/touchbar-strip" "$LINK"
act systemctl --user daemon-reload
act systemctl --user restart t1-touchbar.service
say "  logs: journalctl --user -u t1-touchbar -f    undo: ./install.sh --undo touchbar"
