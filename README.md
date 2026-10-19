# omarchy-mac-kit

Parts for running [Omarchy](https://github.com/basecamp/omarchy) on an Intel MacBook, most of
all a 2016–2017 MacBook Pro with the T1 Touch Bar — and a few that suit any Omarchy machine.
Install all of it or one module; every module undoes cleanly.

| Module | What you get | Root |
|---|---|---|
| `hwdeck` (optional) | [hwdeck](https://github.com/pnshad/hwdeck): full-screen terminal views of CPU, memory, thermal, network, power, battery; the Touch Bar's slots open them | no |
| `lid` | lid close locks, freezes GUI apps, turns the panel off and saves power, without suspend; a sleep/awake mode; two Omarchy fixes for Macs | no |
| `touchbar` | [touchbar-strip](https://github.com/pnshad/touchbar-strip) as the Touch Bar: clock, agent status or an Omarchy dock (open apps with their own icons, workspaces), machine slots with tap/hold actions, battery time left, dials, Touch ID key | no |
| `fans-ram` | fans to max / auto and a RAM trim, for the strip's holds (an exact-argument sudo rule) | yes |
| `smc-power` | whole-system watts from the Apple SMC, published for hwdeck and the strip | yes |
| `battery-limit` | hold the battery at 80 % (patched applesmc, GPL-2.0, tested kernels only) | yes |
| `mic` | the built-in microphone on Cirrus CS8409 Macs (builds snd_hda_macbookpro) | yes |
| `lock-fingerprint` | Touch ID on Omarchy's lock screen without wedging the T1 | yes |
| `s2idle` | a side kernel that suspends: `linux-omarchy-s2idle` (omarchy-pkgs PR 596 + 544, MacBookPro14,x), a wakeup rule for the T1 and Thunderbolt, the Limine cmdline for its entry only; the stock entry stays default and fallback | build: no · install: yes |

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

The `s2idle` module is two: `modules/s2idle/install.sh build` as you (a kernel build, 2–3 hours
and about 25 GB under `~/.cache/omk/s2idle`; `OMK_S2IDLE_WORK` moves it), then
`sudo modules/s2idle/install.sh install`. It builds omarchy-pkgs' `linux-omarchy` 7.2.5 at a
pinned commit of [PR 596](https://github.com/omacom/omarchy-pkgs/pull/596) plus
[PR 544](https://github.com/omacom/omarchy-pkgs/pull/544)'s ACPICA patch (sha256-checked) under
its own package name, so it sits beside the stock kernel with its own boot entry and
`omarchy-update` never touches it; the exact PKGBUILD edits are
[modules/s2idle/edit-pkgbuild.sh](modules/s2idle/edit-pkgbuild.sh). After a reboot pick
`linux-omarchy-s2idle` in the boot menu and test with `rtcwake` before trusting it
(docs/gotchas.md 18–21). To boot it by default put `linux-omarchy-s2idle` first in `BOOT_ORDER`
in `/etc/default/limine`; the stock kernel stays in the menu as the fallback. The module does not
change what the lid does.

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
  `/etc/pam.d/omarchy-lock-fingerprint`, packages `linux-omarchy-s2idle` + `-headers`,
  `/etc/udev/rules.d/90-omk-s2idle-wakeup.rules`, `/etc/limine-entry-tool.d/omk-s2idle.conf`

## Not here

- **Suspend on the stock kernel.** It hangs T1 MacBook Pros; the `lid` module freezes instead.
  The `s2idle` module's side kernel suspends and resumes on MacBookPro14,x, but only when you
  booted it: never suspend while on the stock entry.
- **t1bridge / t1-revive** (Touch Bar, Touch ID, camera): install them from
  [standardagents/t1bridge](https://github.com/standardagents/t1bridge) first.

## Licence

MIT, except `modules/battery-limit/` (GPL-2.0, a patched Linux driver). See
[CREDITS.md](CREDITS.md).
