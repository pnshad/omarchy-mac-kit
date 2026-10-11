#!/usr/bin/env bash
# smc-power (root): a small root service that reads the Apple SMC's power keys every 2 s and
# publishes them, world-readable, at /run/omk-smc-power.json: whole-system watts (PSTR) and
# adapter watts (PDTR). Read-only towards the SMC. Intel Macs with applesmc only.
#   sudo modules/smc-power/install.sh [--rails] [--undo]
#   --rails  also publish the per-rail keys (CPU package, cores, graphics, ...)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
BIN=/usr/local/bin/omk-smc-power
UNIT=/etc/systemd/system/omk-smc-power.service
TMPF=/etc/tmpfiles.d/omk-smc-power.conf

root_target_user "$@"
if [[ ${1:-} == --undo ]]; then
  act systemctl disable --now omk-smc-power.service 2>/dev/null || true
  remove "$UNIT" "$TMPF" /run/omk-smc-power.json "$BIN"
  act systemctl daemon-reload
  exit 0
fi
smc=$(ls -d /sys/devices/platform/applesmc.* 2>/dev/null | head -1 || true)
if [[ -z $smc ]]; then
  say "  skipped: no applesmc here (Intel Macs only)"
  dry || exit 0
  smc=/sys/devices/platform/applesmc.768
fi
rails=no; [[ " $* " == *" --rails "* ]] && rails=yes
grant_confirm "install $BIN (root-owned) and $UNIT: a root service, no network, no capabilities,
  read-only except $smc (to select which SMC key to read)
publish $( [[ $rails == yes ]] && echo "every power key (per-rail too)" || echo "PSTR and PDTR only") at /run/omk-smc-power.json, readable by every user"
dry && exit 0
install -m 0755 -o root -g root "$HERE/omk-smc-power" "$BIN"
sed "s|@SMC@|$smc|" "$HERE/omk-smc-power.service" > "$UNIT"
[[ $rails == yes ]] && sed -i 's|^# Environment=OMK_SMC_RAILS=1.*|Environment=OMK_SMC_RAILS=1|' "$UNIT"
chmod 0644 "$UNIT"
install -m 0644 "$HERE/omk-smc-power.tmpfiles" "$TMPF"
systemd-tmpfiles --create "$TMPF"
systemctl daemon-reload
systemctl enable --now omk-smc-power.service
sleep 4
journalctl -u omk-smc-power -n 3 --no-pager -o cat || true
cat /run/omk-smc-power.json && echo
say "  installed omk-smc-power"
