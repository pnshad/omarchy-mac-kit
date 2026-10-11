#!/usr/bin/env bash
# fans-ram (root): /usr/local/bin/omk-hw and a sudoers rule that lets YOU (the sudo user) run
# exactly `omk-hw fan-max`, `omk-hw fan-auto` and `omk-hw mem-trim` without a password, for a
# Touch Bar strip's fans-max and mem-trim holds. Nothing else.
#   sudo modules/fans-ram/install.sh [--undo]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
BIN=/usr/local/bin/omk-hw
RULE=/etc/sudoers.d/omk-hw

root_target_user "$@"
if [[ ${1:-} == --undo ]]; then
  dry || { [[ -x $BIN ]] && "$BIN" fan-auto 2>/dev/null || true; }
  remove "$BIN" "$RULE"
  exit 0
fi
compgen -G "/sys/devices/platform/applesmc.*/fan1_manual" > /dev/null \
  || say "  note: no applesmc fans found here; mem-trim still works, fan-max will refuse"
rule="$TARGET_USER ALL=(root) NOPASSWD: $BIN fan-max, $BIN fan-auto, $BIN mem-trim"
grant_confirm "install $BIN (root-owned, 0755): fans to max / auto, drop caches + compact memory
add $RULE (0440), checked with visudo -cf first:
    $rule"
dry && exit 0
install -m 0755 -o root -g root "$HERE/omk-hw" "$BIN"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf '# omarchy-mac-kit fans-ram: only these three commands, nothing else.\n%s\n' "$rule" > "$tmp"
visudo -cf "$tmp" > /dev/null || die "visudo rejected the rule; nothing installed in sudoers"
install -m 0440 -o root -g root "$tmp" "$RULE"
say "  installed $BIN and $RULE"
