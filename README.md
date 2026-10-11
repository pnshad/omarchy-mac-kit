# omarchy-mac-kit

Parts for running [Omarchy](https://github.com/basecamp/omarchy) on an Intel MacBook, most of
all a 2016–2017 MacBook Pro with the T1 Touch Bar — and a few that suit any Omarchy machine.
Install all of it or one module; every module undoes cleanly.

| Module | What you get | Root |
|---|---|---|
| `hwdeck` | [hwdeck](https://github.com/pnshad/hwdeck): full-screen terminal views of CPU, memory, thermal, network, power, battery | no |
| `wall` | those six views as a 3×2 floating grid | no |
| `screensaver` | idle → digital rain that drains away to reveal a live hwdeck wall; an hourly rain pass over the wall (pixel refresh) that ends on a red column | no |
| `lid` | lid close locks, freezes GUI apps, turns the panel off and saves power, without suspend; a sleep/awake mode; two Omarchy fixes for Macs | no |
| `touchbar` | [touchbar-strip](https://github.com/pnshad/touchbar-strip) as the Touch Bar: clock, agent status, machine slots with tap/hold actions, dials, Touch ID key | no |
| `fans-ram` | fans to max / auto and a RAM trim, for the strip's holds (an exact-argument sudo rule) | yes |
| `smc-power` | whole-system watts from the Apple SMC, published for hwdeck and the strip | yes |
| `battery-limit` | hold the battery at 80 % (patched applesmc, GPL-2.0, tested kernels only) | yes |
| `mic` | the built-in microphone on Cirrus CS8409 Macs (builds snd_hda_macbookpro) | yes |
| `lock-fingerprint` | Touch ID on Omarchy's lock screen without wedging the T1 | yes |

What runs where: [docs/hardware.md](docs/hardware.md). Why things are done the way they are:
[docs/gotchas.md](docs/gotchas.md).

## Install

```bash
git clone https://github.com/pnshad/omarchy-mac-kit
cd omarchy-mac-kit
less install.sh modules/*/install.sh      # they are short; read before you run
./install.sh --dry-run                     # what every module would do here; changes nothing
./install.sh                               # detects the machine, suggests modules, asks
./install.sh hwdeck wall screensaver       # or name them
./install.sh --undo screensaver            # reverse one
```

Root modules run with `sudo`, one at a time, only when you pick them. Each prints exactly what
it will grant (files, units, sudo rules) and waits for `y`. They refuse to run from a root shell
(they install for the user who ran `sudo`) and never pick a default user.

The `mic` module is three separate steps you run yourself:
`sudo modules/mic/install.sh build`, then `test` (this boot only), then `install`.

`hwdeck` and `touchbar` clone their repos at a pinned tag (or use a checkout next to this one).

## Where things go

- programs: `~/.local/bin/omk-*`, `~/.local/bin/hwdeck`, `~/.local/lib/touchbar-strip/`
- Omarchy overrides: `~/.local/share/omk/bin/` (first in Hyprland's PATH via a marked block)
- Hyprland: marked blocks (`-- >>> omk:<name>` … `-- <<< omk:<name>`) appended to
  `~/.config/hypr/hyprland.lua` / `bindings.lua`; a backup is kept as `*.omk-backup`
- user units: `omk-rainpass.timer`; settings: `~/.config/omk/`, state `~/.local/state/omk/`
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
