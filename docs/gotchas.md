# Gotchas

Each of these cost real time to find on a 2017 MacBook Pro (MacBookPro14,2) running Omarchy 4.
The kit's modules already handle them; they are here so you know why the modules look the way
they do, and for anyone building something similar.

## Omarchy and Hyprland

1. **Omarchy forces its own bin dir first in Hyprland's PATH** (`default/hypr/envs.lua`), so
   overrides in `/usr/local/bin` never win; only a user dir prepended at the end of
   `~/.config/hypr/hyprland.lua` does (the kit's `path-override` block, `~/.local/share/omk/bin`).
   Restart the shell (`omarchy-restart-shell`) to apply. Keep that dir yours and not writable by
   anyone else: everything in it runs ahead of Omarchy's own commands.
2. **The T1 Touch Bar is a DRM connector `card*-USB-*`, always connected**, so Omarchy's
   `omarchy-hw-external-monitors` says "external screen" and every lid close becomes clamshell
   mode (no lock). The `lid` module's override skips `USB` connectors.
3. **Omarchy's lock blank saves the keyboard light level with `brightnessctl -s` on every
   blank**, so a second blank saves 0 and 0 comes back. The `lid` module's override saves only
   levels above 0.
4. **Real suspend hangs a T1 MacBook Pro** (deep S3 and s2idle both, even with NVMe D3cold off).
   The kit never enables suspend; the `lid` module freezes GUI apps instead.
5. **t1bridge's `t1-touchbar.service` runs with `NoNewPrivileges=yes`**, so `sudo` inside the
   renderer fails. The strip calls its root helper through `systemd-run --user`, which starts
   outside that limit.
6. **The Touch Bar renderer starts before uwsm exports `WAYLAND_DISPLAY` and friends**, so
   anything it launches has no display. Merge `systemctl --user show-environment` into the
   environment of whatever you start.
7. **`pkill -f <pattern>` / `pgrep -f` over ssh match their own command line.** Use the bracket
   trick: `pkill -f '[o]rg.omarchy.screensaver'`.
8. **Hyprland Lua dispatch:** `hl.dsp.window.close({ window = "address:0x…" })` works,
   `class:` selectors did not; `hl.dsp.dpms({ action = "off" })`; `hl.dsp.exec_cmd("…")`.
9. **`brightnessctl` and `powerprofilesctl` work from the user's session services (logind), not
   from an ssh shell.** Test them from the desktop.
10. **Omarchy's default window opacity (0.985 / 0.96) makes black look dark grey.** The rain
    windows get an `opacity = "1.0 override 1.0 override"` rule. In foot, true black needs
    24-bit colour (`\e[48;2;0;0;0m`); ANSI background 40 is the theme's dark grey, and foot 1.28
    rejects a `[colors]` section on the command line (`-o colors-dark.background=000000` works).

## Mac hardware

11. **Touch ID on the T1: never a Cancel button, never extra verifies.** Every fingerprint verify
    is a Secure Enclave keybag handoff; about 60 of them in a row wedge the keybag until a full
    power cycle. Omarchy's lock screen restarts a failed verify every 250 ms, and an idle lock
    screen alone made ~120 handoffs an hour. The `lock-fingerprint` module waits while the lid is
    closed or the panel is off and keeps one verify open for the whole lock; the strip's Touch ID
    overlay is cosmetic only and never cancels or starts a verify.
    **Clamshell / external monitor:** with the lid closed the fingerprint step waits (up to 12 h,
    then falls through), so with the lid shut on an external monitor unlock with the password.
    **Test password unlock before relying on the module** (lock, type the password, get in).
12. **Two applesmc replacements fight.** With `applesmc-next-dkms` installed alongside the
    `battery-limit` module the battery vanished (`BAT0` missing) until a full power-off. The
    module refuses to install while applesmc-next is there.
13. **The built-in mic records silence on the stock CS8409 codec driver** (about −93 dBFS); the
    patched `snd_hda_macbookpro` module brings it to −30…−55 dBFS in a quiet room.
14. **SMC power keys (MacBookPro14,2):** `PSTR` whole system, `PD0R` / `PDTR` from the adapter,
    `PCPT` CPU package, `PCPC` cores, `PCPG` graphics, `PPBR` battery/platform (a guess); `PZ*`
    are limits. Reading any key needs root (the `key_at_index` write), hence the `smc-power`
    service that publishes them as JSON.
15. **Fans:** `fan*_manual` / `fan*_output` are root-only; writing `fan*_safe` gives EINVAL.
16. **Ambient light:** `/sys/bus/iio/devices/iio:device0/in_illuminance_raw` (~13 at night
    under a lamp).
17. **NetworkManager allows Wi-Fi radio toggles from the session; `iw dev <if> link` works
    without root.**
