# omarchy-mac-kit

Parts for running [Omarchy](https://github.com/basecamp/omarchy) on an Intel MacBook, most of
all a 2016–2017 MacBook Pro with the T1 Touch Bar — and a few that suit any Omarchy machine.
Install all of it or one module; every module undoes cleanly.

| Module | What you get | Root |
|---|---|---|
| `hwdeck` (optional) | [hwdeck](https://github.com/pnshad/hwdeck): full-screen terminal views of CPU, memory, thermal, network, power, battery; the Touch Bar's slots open them | no |
| `lid` | lid close locks, freezes GUI apps, turns the panel off and saves power, without suspend; a sleep/awake mode; two Omarchy fixes for Macs | no |
| `touchbar` | [touchbar-strip](https://github.com/pnshad/touchbar-strip) as the Touch Bar: clock, agent status, machine slots with tap/hold actions, dials, Touch ID key | no |
| `fans-ram` | fans to max / auto and a RAM trim, for the strip's holds (an exact-argument sudo rule) | yes |
| `smc-power` | whole-system watts from the Apple SMC, published for hwdeck and the strip | yes |
| `battery-limit` | hold the battery at 80 % (patched applesmc, GPL-2.0, tested kernels only) | yes |
| `mic` | the built-in microphone on Cirrus CS8409 Macs (builds snd_hda_macbookpro) | yes |
| `lock-fingerprint` | Touch ID on Omarchy's lock screen without wedging the T1 | yes |

Core = `touchbar`, `lid` and, if you want them, `hwdeck` and the root modules. Nothing
decorative is installed or switched on by default.

What runs where: [docs/hardware.md](docs/hardware.md). Why things are done the way they are:
[docs/gotchas.md](docs/gotchas.md).

## Install

```bash
git clone https://github.com/pnshad/omarchy-mac-kit
cd omarchy-mac-kit
less install.sh modules/*/install.sh      # they are short; read before you run
./install.sh --dry-run                     # what every module would do here; changes nothing
./install.sh                               # detects the machine, suggests modules, asks
./install.sh hwdeck lid touchbar           # or name them
./install.sh --undo lid                    # reverse one
```

Root modules run with `sudo`, one at a time, only when you pick them. Each prints exactly what
it will grant (files, units, sudo rules) and waits for `y`. They refuse to run from a root shell
(they install for the user who ran `sudo`) and never pick a default user.

The `mic` module is three separate steps you run yourself:
`sudo modules/mic/install.sh build`, then `test` (this boot only), then `install`.

`hwdeck` and `touchbar` clone their repos and check out a pinned commit, verified after the
clone (the maintainer tags releases; `OMK_HWDECK_TAG` / `OMK_STRIP_TAG` pick a tag, which must
point at the pinned commit). If a checkout of either sits next to this one, the installer asks
whether to use it instead (default No: that copy is not checked against the pin).

## Compatible extras

Not part of the kit, and not needed by it; each is its own repo:

- [**omarchy-mac-kit-extras**](https://github.com/pnshad/omarchy-mac-kit-extras): the hwdeck views
  as a 3×2 floating wall, a digital-rain screensaver that hands over to the live wall, and an
  hourly rain pass over the screen (a pixel refresh for OLED / LCD panels). With it installed,
  the strip's `"refresh_sign": true` shows PROCESSING → REFRESHED after each pass, and the
  `lock-rain` action plays a short rain before locking.
- [**hwdeck**](https://github.com/pnshad/hwdeck): the dashboards themselves, usable on any Linux
  terminal without either repo (one Python file).

The `wall` and `screensaver` modules used to live here. If an older version of this kit installed
them, `./install.sh --undo wall` / `--undo screensaver` still removes them (the extras' installer
owns them now and its `--undo` does the same; both use the same `omk` files and blocks).

## Where things go

- programs: `~/.local/bin/omk-*`, `~/.local/bin/hwdeck`, `~/.local/lib/touchbar-strip/`
- Omarchy overrides: `~/.local/share/omk/bin/` (first in Hyprland's PATH via a marked block)
- Hyprland: marked blocks (`-- >>> omk:<name>` … `-- <<< omk:<name>`) appended to
  `~/.config/hypr/hyprland.lua` / `bindings.lua`; a backup is kept as `*.omk-backup`
- settings: `~/.config/omk/`, state `~/.local/state/omk/`
- root: `/usr/local/bin/omk-hw`, `/etc/sudoers.d/omk-hw`, `omk-smc-power.service`,
  `omk-battery-limit.service` + DKMS `omk-applesmc-bclm`, `/var/lib/omk-mic`,
  `/etc/pam.d/omarchy-lock-fingerprint`

## Not here

- **Suspend.** Real suspend hangs T1 MacBook Pros; the `lid` module freezes instead.
- **t1bridge / t1-revive** (Touch Bar, Touch ID, camera): install them from
  [standardagents/t1bridge](https://github.com/standardagents/t1bridge) first.

## Licence

MIT, except `modules/battery-limit/` (GPL-2.0, a patched Linux driver). See
[CREDITS.md](CREDITS.md).
