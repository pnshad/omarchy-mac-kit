#!/usr/bin/env bash
# mic (root): the built-in microphone on 2016-2019 MacBooks with the Cirrus CS8409 codec, through
# davidjo/snd_hda_macbookpro (GPL-2.0, not shipped here). On the stock driver the internal mic
# records silence. Only the codec module snd-hda-codec-cs8409 is swapped; the rest of the sound
# stack stays stock.
#
# Everything happens as root in a root-owned folder (never a module from your home):
#   build    clone snd_hda_macbookpro at the pinned commit into $WORK, fetch the matching
#            kernel.org source and check it against kernel.org's sha256sums.asc, build the module
#   test     load the built module for this boot only, record 3 s, report the levels
#   install  keep it (/lib/modules/<kernel>/updates), survives reboots; a kernel update needs
#            `build` + `install` again (until then the stock module loads)
#   undo     back to the stock module
#   sudo modules/mic/install.sh build|test|install|undo     (--undo = undo)
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
REPO=https://github.com/davidjo/snd_hda_macbookpro
COMMIT=89b22ff90b86468b186706861dd18663562defa7      # tested on kernel 7.2.5
WORK=/var/lib/omk-mic
SRC=$WORK/snd_hda_macbookpro
KO=$SRC/build/hda/codecs/cirrus/snd-hda-codec-cs8409.ko
cmd=${1:-}
[[ $cmd == --undo ]] && cmd=undo

root_target_user "$@"
TARGET_UID=$(id -u "$TARGET_USER" 2>/dev/null || id -u)
kver=$(uname -r)
dest=/lib/modules/$kver/updates/codecs/cirrus

if ! dry && ! grep -qs CS8409 /proc/asound/card*/codec#*; then
  die "no Cirrus CS8409 codec here: this module is for 2016-2019 MacBooks with it"
fi

as_user() {      # the user's PipeWire session, for stopping/starting audio and the test recording
  sudo -u "$TARGET_USER" XDG_RUNTIME_DIR=/run/user/$TARGET_UID \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$TARGET_UID/bus "$@"
}
audio_stop()  { as_user systemctl --user stop pipewire-pulse.socket pipewire.socket pipewire-pulse wireplumber pipewire 2>/dev/null; sleep 1; }
audio_start() { as_user systemctl --user start pipewire.socket pipewire-pulse.socket pipewire wireplumber pipewire-pulse 2>/dev/null; sleep 3; }

root_owned_ko() {
  [[ -f $KO ]] || die "not built yet: sudo $0 build"
  [[ $(stat -c %u "$KO") == 0 && $(stat -c %u "$WORK") == 0 ]] || die "$KO is not root-owned: rebuild with sudo $0 build"
  [[ $(( $(stat -c %a "$WORK") & 022 )) == 0 ]] || die "$WORK is writable by others: rebuild"
}

swap_in() {          # $1 = path to a .ko, or "stock"
  audio_stop
  modprobe -r snd_hda_intel 2>/dev/null; sleep 1
  rmmod snd_hda_codec_cs8409 2>/dev/null
  if [[ $1 == stock ]]; then modprobe snd_hda_codec_cs8409; else insmod "$1"; fi
  local rc=$?
  modprobe snd_hda_intel
  audio_start
  return $rc
}

report() {
  say "--- module: $(modinfo -F filename snd_hda_codec_cs8409 2>/dev/null)"
  journalctl -k -b --since "-1min" --no-pager -o cat | grep -i -E "cs8409|snd_hda|cirrus|bug|oops" | tail -8
  say "--- recording 3 s from the default source (speak or tap near the keyboard)"
  as_user timeout 3.5 pw-record --rate 16000 --channels 1 --format s16 - 2>/dev/null | python3 -c '
import sys, array, math
b = sys.stdin.buffer.read(); a = array.array("h", b[:len(b) // 2 * 2])
n = 4000
for i in range(0, len(a) - n, n):
    w = a[i:i + n]; m = sum(w) / n
    rms = math.sqrt(sum((x - m) ** 2 for x in w) / n)
    print(round(20 * math.log10(max(rms, 0.5) / 32768), 1), end=" ")
print("dBFS per 0.25 s  (silence is about -93; a working mic reads about -60 to -30)")'
  say "--- check by ear: the speakers play, the volume keys work"
}

case $cmd in
build)
  grant_confirm "clone $REPO at $COMMIT into $WORK (root-owned, 0755)
download linux-${kver%%-*}.tar.xz and sha256sums.asc from cdn.kernel.org and check the sha256
build snd-hda-codec-cs8409.ko there as root with the upstream build script (nothing is installed)"
  dry && exit 0
  set -e
  install -d -m 0755 -o root -g root "$WORK"
  rm -rf "$SRC"
  git clone -q "$REPO" "$SRC"
  git -C "$SRC" -c advice.detachedHead=false checkout -q "$COMMIT"
  [[ $(git -C "$SRC" rev-parse HEAD) == "$COMMIT" ]] || die "checkout is not $COMMIT"
  base=${kver%%-*}; major=${base%%.*}
  install -d -m 0755 "$SRC/build"
  tarball=$SRC/build/linux-$base.tar.xz
  curl -fsSL -o "$tarball" "https://cdn.kernel.org/pub/linux/kernel/v$major.x/linux-$base.tar.xz"
  curl -fsSL -o "$WORK/sha256sums.asc" "https://cdn.kernel.org/pub/linux/kernel/v$major.x/sha256sums.asc"
  want=$(awk -v f="linux-$base.tar.xz" '$2 == f { print $1 }' "$WORK/sha256sums.asc")
  have=$(sha256sum "$tarball" | cut -d' ' -f1)
  [[ -n $want && $want == "$have" ]] || die "kernel source sha256 mismatch (want '$want', have '$have')"
  say "  kernel source sha256 ok ($have)"
  # --dkms: the upstream script prepares and patches the sources without installing anything.
  # It always runs `wget -c URL -P build`; a stand-in wget (root-owned, in $WORK/bin) hands it the
  # tarball already downloaded and checked above, so nothing unchecked is used and wget need not be
  # installed. The upstream script exits 0 even when it fails, so the module itself is checked.
  install -d -m 0755 "$WORK/bin"
  cat > "$WORK/bin/wget" <<'SHIM'
#!/bin/sh
# omarchy-mac-kit mic build: stand-in for `wget -c URL -P DIR` (the upstream script's only use).
url= dir=.
while [ $# -gt 0 ]; do
  case $1 in -P) dir=$2; shift ;; -c|-q|-nv) ;; *) url=$1 ;; esac; shift
done
f=$dir/$(basename "$url")
[ -s "$f" ] && exit 0
exec curl -fsSL -o "$f" "$url"
SHIM
  chmod 0755 "$WORK/bin/wget"
  rm -rf "$SRC/build/hda"
  (cd "$SRC" && PATH="$WORK/bin:$PATH" bash install.cirrus.driver.sh -k "$kver" --dkms)
  [[ -d $SRC/build/hda ]] || die "the upstream script did not prepare build/hda (see its output above)"
  (cd "$SRC" && make KERNELRELEASE="$kver")    # the top Makefile, as the upstream script does
  [[ -f $KO ]] || die "no module was built (see the make output above)"
  chown -R root:root "$WORK"; chmod -R go-w "$WORK"
  [[ -f $KO ]] || die "build finished without $KO"
  say "  built $KO (sha256 $(sha256sum "$KO" | cut -c1-16)...); next: sudo $0 test" ;;
test)
  dry && { say "  would load $KO for this boot only and record 3 s"; exit 0; }
  root_owned_ko
  if swap_in "$KO"; then report; else say "FAIL: insmod refused it - back to stock"; swap_in stock; fi ;;
install)
  grant_confirm "copy $KO to $dest (kept across reboots, for kernel $kver only) and run depmod"
  dry && exit 0
  root_owned_ko
  install -d "$dest" && install -m 0644 -o root -g root "$KO" "$dest/snd-hda-codec-cs8409.ko" && depmod -a
  swap_in "$dest/snd-hda-codec-cs8409.ko" && report ;;
undo)
  if dry; then say "  would remove $dest/snd-hda-codec-cs8409.ko and load the stock module"; exit 0; fi
  rm -f "$dest/snd-hda-codec-cs8409.ko"; depmod -a
  swap_in stock; say "  stock module back: $(modinfo -F filename snd_hda_codec_cs8409)" ;;
*)
  say "usage: sudo $0 build|test|install|undo"; dry || exit 2 ;;
esac
