#!/usr/bin/env bash
# s2idle: a side kernel that suspends (s2idle) on 2016-2017 MacBook Pros (MacBookPro14,x), where
# the stock Omarchy kernel hangs on every suspend. It is linux-omarchy 7.2.5 (omarchy-pkgs at a
# pinned commit of PR 596: brcmfmac keep D0, Thunderbolt host router awake, applespi backlight,
# applesmc fans) plus PR 544's ACPICA patch (0771: keeps the parent-derived PCI bus, the 12 s per
# controller resume delay), built as its OWN package `linux-omarchy-s2idle`: it installs beside
# the stock kernel with its own Limine entry, omarchy-update never touches it, and the stock entry
# stays the default and the fallback. Recipe proven on a MacBookPro14,3 (18/18 resumes, PR 596)
# and a MacBookPro14,2 (2026-10-19).
#
#   modules/s2idle/install.sh build          as YOU (not root): sparse-clone omarchy-pkgs at the
#                                            pinned commit, fetch and sha256-check the 0771 patch,
#                                            edit the PKGBUILD (edit-pkgbuild.sh), makepkg. Hours.
#   sudo modules/s2idle/install.sh install   root: pacman -U the two packages, a udev rule that
#                                            stops the T1 and Thunderbolt from waking the machine,
#                                            and the Limine cmdline for the s2idle entry only
#   sudo modules/s2idle/install.sh undo      root: remove all three (--undo = undo)
#
# Nothing here changes what the lid does or which entry boots by default. Boot the s2idle entry
# from the Limine menu and test with rtcwake first (docs/gotchas.md).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../lib/common.sh"
REPO=https://github.com/angellindo/omarchy-pkgs                      # PR 596's head
COMMIT=eff70691b56a75805a0c5b6298fdd984f7d974a9                       # linux-omarchy 7.2.5-7 + the 14,x patches
P0771=0771-acpica-preserve-parent-derived-pci-bus.patch               # PR 544
P0771_URL=https://raw.githubusercontent.com/Clowdyffs/omarchy-pkgs/4d81f4f8ad65b14f94a1f7e21d98b52a21e2e184/pkgbuilds/linux-omarchy/$P0771
P0771_SHA256=5894f4b9e312d310f74b7465b953f1ecfa58328cc18b303614a2d2d4d7b8a067
PKG=linux-omarchy-s2idle
RULE=/etc/udev/rules.d/90-omk-s2idle-wakeup.rules
DROPIN=/etc/limine-entry-tool.d/omk-s2idle.conf
ARGS="mem_sleep_default=s2idle button.lid_init_state=open intel_iommu=off"   # the recipe's three
cmd=${1:-}
[[ $cmd == --undo ]] && cmd=undo

# work dir: sources, build tree and packages all OUTSIDE the kit (about 25 GB while building)
work_dir() { echo "${OMK_S2IDLE_WORK:-$1/.cache/omk/s2idle}"; }

on_s2idle_kernel() { [[ $(uname -r) == *-omarchy-s2idle ]]; }
pkg_files() {      # pkg_files DIR: the two package files, newest first; empty when missing
  ls -t "$1"/$PKG-[0-9]*.pkg.tar.* "$1"/$PKG-headers-[0-9]*.pkg.tar.* 2>/dev/null || true
}
drop_args() {      # drop_args CMDLINE: the cmdline without any earlier copy of the three args
  local w out=()
  for w in $1; do
    case $w in mem_sleep_default=*|button.lid_init_state=*|intel_iommu=*) ;; *) out+=("$w") ;; esac
  done
  echo "${out[*]:-}"
}
set_wakeup() {     # set_wakeup enabled|disabled: the same devices the rule covers, right now
  local d
  for d in /sys/bus/usb/devices/*; do
    [[ $(cat "$d/idVendor" 2>/dev/null) == 05ac && $(cat "$d/idProduct" 2>/dev/null) == 8600 && -w $d/power/wakeup ]] \
      && echo "$1" > "$d/power/wakeup"
  done
  for d in /sys/bus/pci/devices/*; do
    [[ $(cat "$d/vendor" 2>/dev/null) == 0x8086 && -w $d/power/wakeup ]] || continue
    case $(cat "$d/device" 2>/dev/null) in 0x15d2|0x15d4) echo "$1" > "$d/power/wakeup" ;; esac
  done
  return 0
}

case $cmd in
build)
  [[ $(id -u) != 0 ]] || die "run build as yourself, not root (makepkg refuses root)"
  WORK=$(work_dir "$HOME"); SRC=$WORK/src; RECIPE=$WORK/recipe
  product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)
  case $product in MacBookPro14,*) ;; *) say "  note: this machine is $product; the patches are for MacBookPro14,x (tested 14,2 and 14,3)" ;; esac
  say "  will: sparse-clone $REPO (pkgbuilds/linux-omarchy) at $COMMIT into $SRC"
  say "        fetch $P0771 from PR 544 and check sha256 $P0771_SHA256"
  say "        copy the recipe to $RECIPE, keep PKGBUILD.orig, apply $HERE/edit-pkgbuild.sh"
  say "        makepkg --skippgpcheck with BUILDDIR/SRCDEST/PKGDEST under $WORK (about 25 GB, 2-3 h on a 2017 MacBook Pro)"
  say "        packages land in $WORK/pkgs; nothing is installed. Run it in tmux or nohup."
  if dry; then say "  (dry run: nothing fetched or built)"; exit 0; fi
  for t in git curl makepkg pacman; do command -v $t >/dev/null || die "$t is not installed"; done
  if [[ -n $(pkg_files "$WORK/pkgs") ]]; then
    say "  packages already built in $WORK/pkgs:"; pkg_files "$WORK/pkgs" | sed 's/^/    /'
    read -r -p "  Build again? [y/N] " a; [[ $a == y || $a == Y ]] || { say "  kept; next: sudo $0 install"; exit 0; }
  fi
  install -d -m 0755 "$WORK" "$WORK/bld" "$WORK/srcdest" "$WORK/pkgs"
  rm -rf "$SRC" "$RECIPE"
  git clone -q --filter=blob:none --no-checkout "$REPO" "$SRC"
  git -C "$SRC" sparse-checkout set pkgbuilds/linux-omarchy
  git -C "$SRC" -c advice.detachedHead=false checkout -q "$COMMIT"
  [[ $(git -C "$SRC" rev-parse HEAD) == "$COMMIT" ]] || die "$REPO checkout is $(git -C "$SRC" rev-parse HEAD), not the pinned $COMMIT"
  say "  $REPO at $COMMIT (verified)"
  cp -r "$SRC/pkgbuilds/linux-omarchy" "$RECIPE"
  cp "$RECIPE/PKGBUILD" "$RECIPE/PKGBUILD.orig"
  if [[ -f $WORK/$P0771 ]] && [[ $(sha256sum "$WORK/$P0771" | cut -d' ' -f1) == "$P0771_SHA256" ]]; then
    say "  $P0771 already here, sha256 ok"
  else
    curl -fsSL -o "$WORK/$P0771" "$P0771_URL"
    have=$(sha256sum "$WORK/$P0771" | cut -d' ' -f1)
    [[ $have == "$P0771_SHA256" ]] || die "$P0771 sha256 is $have, want $P0771_SHA256"
    say "  $P0771 fetched, sha256 ok"
  fi
  cp "$WORK/$P0771" "$RECIPE/$P0771"
  bash "$HERE/edit-pkgbuild.sh" "$RECIPE/PKGBUILD.orig" "$RECIPE/PKGBUILD"
  say "  the exact edits: diff -u $RECIPE/PKGBUILD.orig $RECIPE/PKGBUILD"
  # build deps: never installed from here (no sudo in a user step); say what is missing
  missing=$(cd "$RECIPE" && makepkg --printsrcinfo 2>/dev/null | awk '$1 == "makedepends" { print $3 }' | xargs pacman -T 2>/dev/null || true)
  if [[ -n $missing ]]; then
    say "  missing build tools; install them, then run build again:"
    say "    sudo pacman -S --needed $(echo "$missing" | tr '\n' ' ')"
    exit 1
  fi
  say "  building $PKG 7.2.5-7 ($(nproc) jobs) - log: $WORK/build.log"
  ( cd "$RECIPE" && BUILDDIR=$WORK/bld SRCDEST=$WORK/srcdest PKGDEST=$WORK/pkgs \
      makepkg --skippgpcheck 2>&1 | tee "$WORK/build.log" )
  [[ -n $(pkg_files "$WORK/pkgs") ]] || die "no packages in $WORK/pkgs (see $WORK/build.log)"
  say "  built:"; pkg_files "$WORK/pkgs" | sed 's/^/    /'
  say "  the build tree $WORK/bld can go now (rm -rf); next: sudo $0 install" ;;

install)
  root_target_user "$@"
  home=$(user_home "$TARGET_USER" 2>/dev/null || true); WORK=$(work_dir "${home:-$HOME}")
  product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)
  case $product in MacBookPro14,*) ;; *) say "  note: this machine is $product; the patches are for MacBookPro14,x (tested 14,2 and 14,3)" ;; esac
  command -v pacman >/dev/null || { say "  pacman not found: this module is for Arch-based Omarchy"; dry || exit 1; }
  files=$(pkg_files "$WORK/pkgs")
  if [[ -z $files ]]; then
    say "  no $PKG packages in $WORK/pkgs: build them first as $TARGET_USER: $HERE/install.sh build"
    dry || exit 1
  fi
  main=$(echo "$files" | grep -v -- "-headers-" | head -1 || true); hdr=$(echo "$files" | grep -- "-headers-" | head -1 || true)
  cmdline="$(drop_args "$(cat /proc/cmdline 2>/dev/null)") $ARGS"
  limine=yes; [[ -d /etc/limine-entry-tool.d ]] || limine=no
  other_dropin=$(grep -ls "KERNEL_CMDLINE\[$PKG\]" /etc/limine-entry-tool.d/*.conf 2>/dev/null | grep -v -F "$DROPIN" || true)
  other_rule=$(grep -ls '05ac.*8600.*power/wakeup' /etc/udev/rules.d/*.rules 2>/dev/null | grep -v -F "$RULE" || true)
  rule_note=""; [[ -n $other_rule ]] && rule_note="
  -> SKIPPED: $other_rule already does this"
  dropin_note=""
  [[ -n $other_dropin ]] && dropin_note="
  -> SKIPPED: $other_dropin already sets it"
  [[ $limine == no ]] && dropin_note="
  -> SKIPPED: no /etc/limine-entry-tool.d here; add the three arguments to the s2idle entry yourself"
  grant_confirm "install $RULE: power/wakeup=disabled for the T1 (usb 05ac:8600) and the Alpine Ridge NHI/xHCI
  (pci 8086:15d2 / 15d4), applied now with udevadm (they wake the Mac the instant it suspends)$rule_note
write $DROPIN: KERNEL_CMDLINE[$PKG] = this boot's cmdline + $ARGS
  (the s2idle entry only; the stock entry's line is untouched)$dropin_note
pacman -U $(basename "${main:-$PKG-<ver>.pkg.tar.zst}") + $(basename "${hdr:-$PKG-headers-<ver>.pkg.tar.zst}") from $WORK/pkgs
  (its hooks build the DKMS modules, the initramfs/UKI and the Limine entry '$PKG'; the stock
  kernel stays the default entry; nothing changes until you pick '$PKG' in the boot menu)"
  dry && exit 0
  # 1. the udev rule, before the kernel: the devices must be quiet at the first suspend
  if [[ -z $other_rule ]]; then
    install_file "$HERE/90-omk-s2idle-wakeup.rules" "$RULE" 0644
    udevadm control --reload
    set_wakeup disabled
    say "  $RULE installed and applied"
  fi
  # 2. the cmdline drop-in, before the kernel: the hooks write the entry from it
  if [[ $limine == yes && -z $other_dropin ]]; then
    printf '# omarchy-mac-kit s2idle: cmdline for the %s entry only (a kernel-specific KERNEL_CMDLINE replaces\n# [default], so the stock line is repeated) + the three arguments of the MacBookPro14,x recipe.\n# Undo: ./install.sh --undo s2idle\nKERNEL_CMDLINE[%s]="%s"\n' "$PKG" "$PKG" "$cmdline" \
      | put "$DROPIN" 0644
    say "  $DROPIN written"
  fi
  # 3. the kernel and headers (dkms needs the headers)
  pacman -U --needed --noconfirm "$main" "$hdr"
  if [[ $limine == yes ]] && command -v limine-update >/dev/null && ! grep -qs "$PKG" /boot/limine.conf; then
    limine-update
  fi
  if grep -qs "$PKG" /boot/limine.conf; then
    say "OK: Limine has the '$PKG' entry; s2idle args present: $(grep -qs 'mem_sleep_default=s2idle' /boot/limine.conf && echo yes || echo NO)"
  else
    warn "no '$PKG' entry in /boot/limine.conf: check limine-entry-tool / limine-update"
  fi
  say "  next: reboot, pick '$PKG' in the boot menu (uname -r ends in -omarchy-s2idle), then test:"
  say "    sudo sh -c 'echo 0 > /sys/power/pm_trace; hwclock --systohc; rtcwake -m freeze -s 25'"
  say "  never suspend while booted on the stock kernel: it hangs (docs/gotchas.md)" ;;

undo)
  root_target_user "$@"
  if on_s2idle_kernel; then
    say "  you are running $(uname -r): reboot into the stock entry first, then undo"
    dry || exit 1
  fi
  have=$(pacman -Q $PKG $PKG-headers 2>/dev/null | awk '{ print $1 }' | tr '\n' ' ' | sed 's/ $//' || true)
  grant_confirm "pacman -R ${have:-(not installed)} (removes the kernel, its modules, its DKMS builds and its Limine entry)
remove $RULE and re-enable the wakeups now
remove $DROPIN and refresh Limine's entries (limine-update)"
  dry && exit 0
  # shellcheck disable=SC2086
  [[ -n $have ]] && pacman -R --noconfirm $have
  if [[ -e $RULE ]]; then remove "$RULE"; udevadm control --reload; set_wakeup enabled; fi
  if [[ -e $DROPIN ]]; then remove "$DROPIN"; command -v limine-update >/dev/null && limine-update; fi
  say "  removed; the stock kernel is the only entry again. Remember: it hangs on suspend" ;;

*)
  say "usage: $0 build   (as you)   |   sudo $0 install|undo"; dry || exit 2 ;;
esac
