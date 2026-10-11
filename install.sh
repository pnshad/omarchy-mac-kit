#!/usr/bin/env bash
# omarchy-mac-kit installer: pick modules; each one installs (or undoes) on its own.
#
#   ./install.sh                     menu: what this machine has, then pick modules
#   ./install.sh MODULE...           install those modules
#   ./install.sh --dry-run [MODULE...]   show what would happen (all modules when none given);
#                                    changes nothing, asks for nothing, runs no sudo
#   ./install.sh --undo MODULE       reverse one module
#   ./install.sh --list              the modules and what they need
#
# User modules run as you. Root modules run with sudo, one at a time, only when picked; each
# prints exactly what it will grant and waits for "y". Read a module's install.sh before running
# it: they are short. No curl | bash anywhere.
set -euo pipefail
KIT=$(cd "$(dirname "$0")" && pwd)
. "$KIT/lib/common.sh"

USER_MODULES="hwdeck lid touchbar"
# Moved to omarchy-mac-kit-extras; only their --undo stays here, for older installs.
MOVED_MODULES="wall screensaver"
ROOT_MODULES="fans-ram smc-power battery-limit mic lock-fingerprint"
what() {
  case $1 in
  hwdeck) echo "terminal hardware dashboards (any Linux)" ;;
  lid) echo "lid close: lock, freeze GUI apps, panel off, no suspend; sleep/awake mode (Omarchy laptops)" ;;
  touchbar) echo "touchbar-strip as the Touch Bar renderer (T1 MacBook Pro + t1bridge)" ;;
  fans-ram) echo "root helper + exact-argument sudo rule: fans max/auto, RAM trim (Intel Macs)" ;;
  smc-power) echo "root service publishing SMC whole-system watts (Intel Macs)" ;;
  battery-limit) echo "patched applesmc (GPL-2.0, DKMS): battery charge limit (Intel Macs, tested kernels only)" ;;
  mic) echo "build snd_hda_macbookpro for the built-in mic (Cirrus CS8409 Macs)" ;;
  lock-fingerprint) echo "Touch ID on Omarchy's lock without wedging the T1 (PAM)" ;;
  esac
}

is_root_module() { [[ " $ROOT_MODULES " == *" $1 "* ]]; }
known() { [[ " $USER_MODULES $ROOT_MODULES " == *" $1 "* ]]; }

detect() {
  local product cs t1=no smc=no omarchy=no flavour
  product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown ($(uname -s))")
  case $product in MacBookPro13,2|MacBookPro13,3|MacBookPro14,2|MacBookPro14,3) t1=yes ;; esac
  compgen -G "/sys/devices/platform/applesmc.*" > /dev/null && smc=yes
  cs=no; grep -qs CS8409 /proc/asound/card*/codec#* && cs=yes
  is_omarchy && omarchy=yes
  flavour=$(hypr_flavour); flavour=${flavour:-none}
  say "This machine: $product"
  say "  Omarchy: $omarchy · Hyprland config: $flavour · T1 Touch Bar: $t1 · applesmc: $smc · CS8409 codec: $cs"
  if [[ $t1 == yes ]] && ! systemctl --user cat t1-touchbar.service > /dev/null 2>&1; then
    say "  t1bridge: not found (the touchbar module needs it)"
  fi
  SUGGEST=""
  SUGGEST+=" hwdeck"
  [[ $omarchy == yes && -d /proc/acpi/button/lid ]] && SUGGEST+=" lid"
  [[ $t1 == yes ]] && SUGGEST+=" touchbar"
  SUGGEST_ROOT=""
  [[ $smc == yes ]] && SUGGEST_ROOT+=" fans-ram smc-power battery-limit"
  [[ $cs == yes ]] && SUGGEST_ROOT+=" mic"
  [[ $t1 == yes && $omarchy == yes ]] && SUGGEST_ROOT+=" lock-fingerprint"
  return 0
}

list() {
  local m
  say "User modules (run as you):"
  for m in $USER_MODULES; do printf '  %-17s %s\n' "$m" "$(what "$m")"; done
  say "Root modules (sudo; each asks before it grants anything):"
  for m in $ROOT_MODULES; do printf '  %-17s %s\n' "$m" "$(what "$m")"; done
  say "Extras (deck wall, rain screensaver, pixel refresh): https://github.com/pnshad/omarchy-mac-kit-extras"
}

moved() { [[ " $MOVED_MODULES " == *" $1 "* ]]; }

run_module() {   # run_module MODULE [args...]
  local m=$1; shift
  moved "$m" && die "$m moved to omarchy-mac-kit-extras (https://github.com/pnshad/omarchy-mac-kit-extras)"
  known "$m" || die "unknown module: $m (./install.sh --list)"
  say ""
  say "== $m: $(what "$m")"
  if is_root_module "$m"; then
    if dry; then
      OMK_DRY_RUN=1 bash "$KIT/modules/$m/install.sh" "$@"
    else
      sudo OMK_ROOT="$KIT" bash "$KIT/modules/$m/install.sh" "$@"
    fi
  else
    OMK_DRY_RUN=$OMK_DRY_RUN bash "$KIT/modules/$m/install.sh" "$@"
  fi
}

undo=""; picks=()
while (( $# )); do
  case $1 in
  --dry-run) OMK_DRY_RUN=1; export OMK_DRY_RUN ;;
  --undo) undo=${2:-}; [[ -n $undo ]] || die "--undo needs a module"; shift ;;
  --list) list; exit 0 ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -*) die "unknown option $1" ;;
  *) picks+=("$1") ;;
  esac
  shift
done

if [[ -n $undo ]]; then
  if moved "$undo"; then
    say "$undo now belongs to omarchy-mac-kit-extras; undoing what an older omarchy-mac-kit installed:"
    OMK_DRY_RUN=$OMK_DRY_RUN bash "$KIT/lib/legacy-undo.sh" "$undo"
  elif [[ $undo == mic ]]; then run_module mic undo; else run_module "$undo" --undo; fi
  exit 0
fi

detect
if (( ${#picks[@]} == 0 )); then
  if dry; then
    say "Dry run of every module (nothing changes):"
    # shellcheck disable=SC2206
    picks=($USER_MODULES $ROOT_MODULES)
  else
    say ""
    list
    say ""
    say "Suggested for this machine:${SUGGEST:- none}${SUGGEST_ROOT:+   root:$SUGGEST_ROOT}"
    read -r -p "Modules to install (space-separated, empty = suggested user modules): " line
    # shellcheck disable=SC2206
    picks=(${line:-$SUGGEST})
  fi
fi
[[ " ${picks[*]} " == *" touchbar "* && " ${picks[*]} " != *" hwdeck "* ]] \
  && say "note: the Touch Bar's slots open hwdeck views; add the hwdeck module too"
for m in "${picks[@]}"; do
  if [[ $m == mic ]]; then
    if dry; then run_module mic build; else
      say ""; say "== mic: three steps, run them yourself in order:"
      say "   sudo $KIT/modules/mic/install.sh build   then   test   then   install"
    fi
  else
    run_module "$m"
  fi
done
say ""
dry && say "Dry run: nothing was changed." || say "Done. Undo any module with: ./install.sh --undo <module>"
