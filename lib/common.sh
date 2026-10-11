# omarchy-mac-kit: shared helpers for every module installer. Sourced, not run.
#
# Dry run: OMK_DRY_RUN=1 (install.sh --dry-run) prints every change instead of making it and
# touches nothing: no files, no units, no sudo.

OMK_ROOT=${OMK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
OMK_DRY_RUN=${OMK_DRY_RUN:-0}
OMK_PREFIX=omk
OMK_BIN=${OMK_BIN:-$HOME/.local/bin}
OMK_OVERRIDE_DIR=${OMK_OVERRIDE_DIR:-$HOME/.local/share/omk/bin}
OMK_CONFIG=${OMK_CONFIG:-$HOME/.config/omk}
OMK_STATE=${OMK_STATE:-$HOME/.local/state/omk}
HYPR_DIR=${HYPR_DIR:-$HOME/.config/hypr}
OMARCHY_PATH=${OMARCHY_PATH:-/usr/share/omarchy}

say()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'stop: %s\n' "$*" >&2; exit 1; }
dry()  { [[ $OMK_DRY_RUN == 1 ]]; }

# act CMD...: run a command, or print it in a dry run
act() {
  if dry; then printf '  would run: %s\n' "$*"; else "$@"; fi
}

# put DEST MODE: write stdin to DEST with MODE (atomically), or show it in a dry run
put() {
  local dest=$1 mode=$2 tmp
  if dry; then
    printf '  would write %s (mode %s, %s lines)\n' "$dest" "$mode" "$(wc -l | tr -d ' ')"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  tmp=$(mktemp "$(dirname "$dest")/.omk.XXXXXX")
  cat > "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$dest"
}

# install_file SRC DEST MODE: copy one shipped file into place
install_file() {
  put "$2" "$3" < "$1"
}

# remove PATH...: delete files the kit installed
remove() {
  local f
  for f in "$@"; do
    [[ -e $f || -L $f ]] || continue
    if dry; then say "  would remove $f"; else rm -f -- "$f"; say "  removed $f"; fi
  done
}

# ---- blocks in Hyprland config files: marker-delimited, so undo removes exactly ours ---------
# block_add FILE NAME COMMENT_PREFIX < content
block_add() {
  local file=$1 name=$2 c=${3:---} body
  body=$(cat)
  if [[ -f $file ]] && grep -qF -e "$c >>> omk:$name" "$file"; then
    say "  $file already has the omk:$name block (left as is; --undo then install to refresh)"
    return 0
  fi
  if dry; then
    say "  would append the omk:$name block to $file ($(printf '%s\n' "$body" | wc -l | tr -d ' ') lines)"
    return 0
  fi
  [[ -f $file ]] || die "$file not found"
  [[ -e $file.omk-backup ]] || cp -p "$file" "$file.omk-backup"
  printf '\n%s >>> omk:%s (omarchy-mac-kit; remove with ./install.sh --undo)\n%s\n%s <<< omk:%s\n' \
    "$c" "$name" "$body" "$c" "$name" >> "$file"
  say "  added the omk:$name block to $file (backup: $file.omk-backup)"
}

# block_remove FILE NAME COMMENT_PREFIX
block_remove() {
  local file=$1 name=$2 c=${3:---}
  [[ -f $file ]] && grep -qF -e "$c >>> omk:$name" "$file" || return 0
  if dry; then say "  would remove the omk:$name block from $file"; return 0; fi
  awk -v start="$c >>> omk:$name" -v stop="$c <<< omk:$name" '
    index($0, start) == 1 { skip = 1; next }
    skip && index($0, stop) == 1 { skip = 0; next }
    !skip' "$file" > "$file.omk-tmp" && mv "$file.omk-tmp" "$file"
  say "  removed the omk:$name block from $file"
}

# hypr_flavour: "lua" (Omarchy 4 / Hyprland Lua config), "conf" (classic hyprland.conf) or ""
hypr_flavour() {
  if [[ -f $HYPR_DIR/hyprland.lua ]]; then echo lua
  elif [[ -f $HYPR_DIR/hyprland.conf ]]; then echo conf
  fi
}

is_omarchy() { [[ -d $OMARCHY_PATH/bin ]]; }

# The user override dir must be the user's own and not writable by anyone else: everything in it
# runs ahead of Omarchy's own commands.
ensure_override_dir() {
  if dry; then say "  would create $OMK_OVERRIDE_DIR (mode 0755, yours)"; return 0; fi
  install -d -m 0755 "$OMK_OVERRIDE_DIR"
  [[ $(stat -c %u "$OMK_OVERRIDE_DIR") == "$(id -u)" ]] || die "$OMK_OVERRIDE_DIR is not yours"
  chmod go-w "$OMK_OVERRIDE_DIR"
}

# path_override_add: the Lua block that puts the override dir first in Hyprland's PATH
path_override_add() {
  [[ $(hypr_flavour) == lua ]] || { warn "no hyprland.lua: add $OMK_OVERRIDE_DIR to the front of PATH yourself"; return 0; }
  block_add "$HYPR_DIR/hyprland.lua" path-override -- < "$OMK_ROOT/lib/path-override.lua"
  say "  restart the shell to apply: omarchy-restart-shell (or log out and in)"
}

# path_override_remove: only when no override is left in the dir
path_override_remove() {
  if compgen -G "$OMK_OVERRIDE_DIR/*" > /dev/null; then
    say "  keeping the PATH override: $OMK_OVERRIDE_DIR still has files"
    return 0
  fi
  block_remove "$HYPR_DIR/hyprland.lua" path-override --
}

# ---- root modules ----------------------------------------------------------------------------
# root_target_user: the user a root module is installed for. Refuses to guess: it must be run
# with sudo by that user (SUDO_USER set, and not root).
root_target_user() {
  if dry; then
    TARGET_USER=${SUDO_USER:-${USER:-you}}
    return 0
  fi
  [[ $(id -u) == 0 ]] || die "run it with sudo: sudo $0 $*"
  [[ -n ${SUDO_USER:-} ]] || die "SUDO_USER is empty: run it as your own user with sudo, not from a root shell"
  [[ $SUDO_USER != root ]] || die "SUDO_USER is root: run it as your own user with sudo"
  id -u "$SUDO_USER" >/dev/null 2>&1 || die "no such user: $SUDO_USER"
  TARGET_USER=$SUDO_USER
}

# grant_confirm TEXT: print what will be granted and wait for y (default no)
grant_confirm() {
  say ""
  say "This module will, as root:"
  printf '%s\n' "$1" | sed 's/^/  - /'
  say ""
  if dry; then say "  (dry run: not asking, nothing changes)"; return 0; fi
  local a
  read -r -p "Go ahead? [y/N] " a
  [[ $a == y || $a == Y ]] || die "nothing changed"
}

# user_home USER
user_home() { getent passwd "$1" | cut -d: -f6; }
