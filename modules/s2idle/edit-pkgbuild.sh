#!/usr/bin/env bash
# s2idle: turn omarchy-pkgs' linux-omarchy PKGBUILD (pinned commit) into linux-omarchy-s2idle.
# The edits are exactly the ones made by hand on the first machine (2026-10-19):
#   1. pkgbase linux-omarchy -> linux-omarchy-s2idle, so it installs BESIDE the stock kernel
#      (own Limine entry, own modules dir, omarchy-update never touches it)
#   2. pkgdesc says what it is
#   3. rust, rust-bindgen, rust-src dropped from makedepends, and prepare() disables CONFIG_RUST
#      (no Rust toolchain needed; no Apple driver is Rust)
#   4. PR 544's 0771-acpica-preserve-parent-derived-pci-bus.patch added to source=() after the
#      0770 patch, with its b2sum and sha256 at the same index in b2sums=() and sha256sums=()
#   edit-pkgbuild.sh ORIG OUT      (reads ORIG, writes OUT; nothing else is touched)
set -euo pipefail
orig=$1 out=$2
P0771=0771-acpica-preserve-parent-derived-pci-bus.patch
P0771_B2=ed4a4031b35dd9413510862c0ea06c1cd42839b622a7ef5e05ff432a2096a29dfbe77d0ef6db2481f6eb2f1bf59d0974a0ae28dd2c911282b61273dbc02e88a9
P0771_SHA256=5894f4b9e312d310f74b7465b953f1ecfa58328cc18b303614a2d2d4d7b8a067
ANCHOR='0770-acpi-pm-acer-swift3-sf314-56g-power-resource.patch{,.sig}'

die() { printf 'stop: %s\n' "$*" >&2; exit 1; }
[[ -f $orig ]] || die "$orig not found"
grep -q '^pkgbase=linux-omarchy$' "$orig" || die "$orig is not the linux-omarchy PKGBUILD (pkgbase)"
grep -qF "  $ANCHOR" "$orig" || die "$orig has no $ANCHOR line (recipe changed; refusing to guess)"
grep -q "$P0771" "$orig" && die "$orig already lists $P0771"
grep -q '^  cp \.\./config\.\$CARCH \.config$' "$orig" || die "prepare() in $orig does not copy the config the known way"

# Index (1-based) of the anchor's .sig in source=(): each line is one entry, `{,.sig}` and
# `{xz,sign}` are two, `${_rcpatch:+…}` is none (no -rc here). Must equal the number of entries
# before it in both checksum arrays, which the awk below checks.
idx=$(awk -v anchor="  $ANCHOR" '
  /^source=\(/ { in_src = 1; n = 0; next }
  in_src && /^\)/ { exit }
  in_src {
    if ($0 ~ /\$\{_rcpatch:\+/) next
    n += ($0 ~ /\{,\.sig\}|\{xz,sign\}/) ? 2 : 1
    if ($0 == anchor) { print n; exit }
  }' "$orig")
[[ -n $idx ]] || die "could not place $P0771 in source=()"

awk -v idx="$idx" -v p="$P0771" -v b2="$P0771_B2" -v sha="$P0771_SHA256" -v anchor="  $ANCHOR" '
  function fail(msg) { print "stop: " msg > "/dev/stderr"; exit 1 }
  # 1 + 2: names
  $0 == "pkgbase=linux-omarchy" { print "pkgbase=linux-omarchy-s2idle"; next }
  $0 == "pkgdesc='"'"'Omarchy Linux'"'"'" {
    print "pkgdesc='"'"'Omarchy Linux + MacBookPro14,x s2idle patches (omarchy-pkgs PR 596 + 544; omarchy-mac-kit)'"'"'"; next }
  # 3: makedepends without rust
  /^makedepends=\(/ { in_md = 1 }
  in_md && /^\)/ { in_md = 0 }
  in_md && ($0 == "  rust" || $0 == "  rust-bindgen" || $0 == "  rust-src") { next }
  # 4: the patch after the anchor in source=(), its sums at the same index
  /^source=\(/ { in_src = 1 }
  in_src && /^\)/ { in_src = 0 }
  in_src && $0 == anchor { print; print "  " p; next }
  /^b2sums=\(/ { arr = "b2"; n = 0 }
  /^sha256sums=\(/ { arr = "sha"; n = 0 }
  arr != "" {
    line = $0
    if (line ~ /\)$/) closing = 1
    if (line ~ /'"'"'[0-9a-fA-F]+'"'"'|'"'"'SKIP'"'"'/) {
      n++
      print line
      if (n == idx) print "        " (arr == "b2" ? "'"'"'" b2 "'"'"'" : "    '"'"'" sha "'"'"'")
      if (closing) { if (n < idx) fail(arr "sums has only " n " entries, fewer than the patch index " idx); arr = ""; closing = 0 }
      next
    }
    if (closing) { arr = ""; closing = 0 }
  }
  # 3: CONFIG_RUST off, right after the config is copied in prepare()
  $0 == "  cp ../config.$CARCH .config" {
    print; print "  # omarchy-mac-kit s2idle: no Rust toolchain on the builder; no Apple driver is Rust."
    print "  scripts/config --disable CONFIG_RUST"; next }
  { print }
' "$orig" > "$out.tmp"
grep -q "^pkgbase=linux-omarchy-s2idle$" "$out.tmp" || die "edit failed (pkgbase)"
grep -qF "  $P0771" "$out.tmp" || die "edit failed (source)"
[[ $(grep -c "$P0771_B2" "$out.tmp") == 1 && $(grep -c "$P0771_SHA256" "$out.tmp") == 1 ]] || die "edit failed (sums)"
grep -q 'scripts/config --disable CONFIG_RUST' "$out.tmp" || die "edit failed (CONFIG_RUST)"
grep -q '^  rust' "$out.tmp" && die "edit failed (rust still in makedepends)"
mv -f "$out.tmp" "$out"
printf 'edited %s -> %s (%s at source index %s)\n' "$orig" "$out" "$P0771" "$idx"
