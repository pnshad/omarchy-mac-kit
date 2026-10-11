#!/usr/bin/env bash
# battery-limit (root): hold the battery at a charge limit (default 80%) through a patched
# applesmc driver with the SMC's BCLM key as a knob, built with DKMS. Only applesmc is replaced.
# The driver source here is GPL-2.0 (see LICENSE in this folder): Linux's applesmc.c as of
# kernel 7.2.5 plus applesmc-bclm.patch. It is shipped only for the kernels it was tested on and
# the installer refuses any other; DKMS does NOT rebuild it on a kernel update (a new kernel just
# loads the stock applesmc again, and the limit is not held until this folder is updated).
#   sudo modules/battery-limit/install.sh [LIMIT]   install, or change the limit (20-100)
#   sudo modules/battery-limit/install.sh --undo    back to the stock driver, charging to 100%
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
PKG=omk-applesmc-bclm VER=1.0
TESTED_KERNELS="7.2.5"           # base versions this applesmc.c matches; add one only after testing
DRIVER_VERSION=7.2.5-bclm1       # MODULE_VERSION in applesmc.c
SRC=/usr/src/$PKG-$VER
UNIT=/etc/systemd/system/omk-battery-limit.service
STATE=/var/lib/omk-battery-limit/limit

root_target_user "$@"
reload_applesmc() { modprobe -r applesmc 2>/dev/null || true; modprobe applesmc; }

if [[ ${1:-} == --undo ]]; then
  knob=$(ls /sys/devices/platform/applesmc.*/charge_control_end_threshold 2>/dev/null | head -1 || true)
  act systemctl disable --now omk-battery-limit.service 2>/dev/null || true
  if dry; then say "  would set the limit back to 100 and remove the DKMS module $PKG/$VER"; exit 0; fi
  [[ -n $knob && -w $knob ]] && echo 100 > "$knob"
  rm -f "$UNIT"; rm -rf "$(dirname "$STATE")"; systemctl daemon-reload
  dkms remove "$PKG/$VER" --all 2>/dev/null || true
  rm -rf "$SRC"; depmod -a
  reload_applesmc
  say "  removed; stock applesmc loaded ($(modinfo -F filename applesmc)); the battery charges to 100%"
  exit 0
fi

LIMIT=${1:-80}
[[ $LIMIT =~ ^[0-9]+$ ]] && (( LIMIT >= 20 && LIMIT <= 100 )) || die "limit must be 20-100"
kver=$(uname -r)
base=${kver%%-*}
if [[ " $TESTED_KERNELS " != *" $base "* ]]; then
  say "  refused: this driver source was tested on kernel(s) $TESTED_KERNELS; you run $kver."
  say "  Building it for another kernel can break fans and sensors. Nothing was changed."
  dry || exit 1
fi
if command -v pacman >/dev/null && pacman -Q applesmc-next-dkms >/dev/null 2>&1; then
  die "remove applesmc-next-dkms first (two applesmc replacements fight; see docs/gotchas.md)"
fi
if command -v dkms >/dev/null && dkms status 2>/dev/null | grep -qi 'applesmc-next'; then
  die "an applesmc-next DKMS module is installed: remove it first (docs/gotchas.md)"
fi
bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1 || true)
[[ -n $bat ]] || { say "  no battery found (if one is fitted, power the Mac off fully and on again)"; dry || exit 1; }
command -v dkms >/dev/null || { say "  dkms is not installed (Arch: pacman -S dkms; plus your kernel's headers)"; dry || exit 1; }

grant_confirm "build and install the DKMS module $PKG/$VER (GPL-2.0, from $HERE) for kernel $kver,
  replacing the stock applesmc driver (falls back to stock if it does not load)
add $UNIT (root): sets the limit at every boot and makes the charge knob writable by $TARGET_USER
create $STATE owned by $TARGET_USER (the limit chosen last; a Touch Bar strip's hold changes it)
set the limit to ${LIMIT}%"
dry && exit 0

# 1. build + install the module with DKMS for the running kernel only
if ! dkms status "$PKG/$VER" 2>/dev/null | grep -q "$kver.*installed"; then
  dkms remove "$PKG/$VER" --all 2>/dev/null || true
  rm -rf "$SRC"; install -d -m 0755 "$SRC"
  install -m 0644 "$HERE"/{applesmc.c,Makefile,dkms.conf} "$SRC"/
  dkms add "$PKG/$VER"
  dkms install "$PKG/$VER" -k "$kver"
fi

# 2. test-load; on any failure go straight back to the stock driver
reload_applesmc || true
knob=$(ls /sys/devices/platform/applesmc.*/charge_control_end_threshold 2>/dev/null | head -1 || true)
if [[ $(modinfo -F version applesmc 2>/dev/null) != "$DRIVER_VERSION" || -z $knob ]]; then
  say "FAIL: the patched applesmc did not load or has no charge knob (no BCLM key?) - rolling back"
  dkms remove "$PKG/$VER" --all 2>/dev/null || true
  rm -rf "$SRC"; depmod -a; reload_applesmc || true
  journalctl -k -n 15 --no-pager | grep -i -E "applesmc|bug|oops" || true
  exit 1
fi
compgen -G "$(dirname "$knob")/fan1_input" > /dev/null || warn "fan1_input missing after the swap"

# 3. the limit at every boot: the last one chosen (state file), else the installed one; then
#    the knob goes to the user so a Touch Bar strip can toggle it without root
install -d -o "$TARGET_USER" -m 755 "$(dirname "$STATE")"
echo "$LIMIT" > "$STATE"; chown "$TARGET_USER" "$STATE"
cat > "$UNIT" <<UNITEOF
[Unit]
Description=omarchy-mac-kit: hold the battery at the chosen charge limit (applesmc BCLM)

[Service]
Type=oneshot
ExecStartPre=/usr/bin/modprobe applesmc
ExecStart=/bin/sh -c 'L=\$\$(cat $STATE 2>/dev/null); case "\$\$L" in [2-9][0-9]|100) ;; *) L=${LIMIT};; esac; echo "\$\$L" > $knob; chown $TARGET_USER $knob'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNITEOF
chmod 0644 "$UNIT"
systemctl daemon-reload
systemctl enable omk-battery-limit.service >/dev/null 2>&1
systemctl restart omk-battery-limit.service
say "OK: limit $(cat "$knob")% · battery $(cat "$bat/capacity")% $(cat "$bat/status") · driver $(modinfo -F filename applesmc)"
