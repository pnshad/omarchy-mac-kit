#!/usr/bin/env bash
# lock-fingerprint (root): Touch ID on Omarchy's lock screen for T1 MacBooks without wedging the
# T1. Each fingerprint verify is a Secure Enclave keybag handoff and too many of them wedge it,
# while Omarchy's lock restarts a failed verify every 250 ms. This replaces
# /etc/pam.d/omarchy-lock-fingerprint with a stack that
#   1. waits, doing nothing, while the lid is closed or the panel is blanked
#      (/usr/local/bin/omk-lock-wait-lid-open), then
#   2. keeps ONE verify open for the whole lock (pam_fprintd timeout=-1), 3 tries.
# The password still unlocks as before. Needs t1bridge's Touch ID (fprintd) working first.
#   sudo modules/lock-fingerprint/install.sh [--undo]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
PAM=/etc/pam.d/omarchy-lock-fingerprint
HELPER=/usr/local/bin/omk-lock-wait-lid-open

root_target_user "$@"
if [[ ${1:-} == --undo ]]; then
  if [[ -f $PAM.omk-backup ]]; then act mv -f "$PAM.omk-backup" "$PAM"; say "  restored the previous $PAM"
  else remove "$PAM"; say "  there was no $PAM before: fingerprint unlock is off again"; fi
  remove "$HELPER"
  exit 0
fi
if ! dry; then
  is_omarchy || die "Omarchy not found: this PAM file is for Omarchy's lock screen"
  [[ -e /usr/lib/security/pam_fprintd.so || -e /lib/security/pam_fprintd.so || -e /usr/lib64/security/pam_fprintd.so ]] \
    || die "pam_fprintd is not installed (fprintd); set up Touch ID with t1bridge first"
fi
grant_confirm "install $HELPER (root-owned, 0755): blocks while the lid is closed or the panel is off
replace $PAM (the old one kept as $PAM.omk-backup):
$(grep -v '^#' "$HERE/omarchy-lock-fingerprint.pam" | sed 's/^/    /')"
dry && exit 0
install -m 0755 -o root -g root "$HERE/omk-lock-wait-lid-open" "$HELPER"
[[ -f $PAM && ! -f $PAM.omk-backup ]] && cp -p "$PAM" "$PAM.omk-backup"
install -m 0644 -o root -g root "$HERE/omarchy-lock-fingerprint.pam" "$PAM"
say "  installed. Test: lock (omarchy-system-lock), touch the sensor once; the password still works."
say "  Never cancel a Touch ID prompt in a loop or script extra verifies (docs/gotchas.md)."
