# Credits

omarchy-mac-kit's own code is MIT (see [LICENSE](LICENSE)), copyright pnshad.
`modules/battery-limit/` is GPL-2.0-only (see its LICENSE and README).

| Project | Licence | How the kit uses it | Shipped here? |
|---|---|---|---|
| [t1bridge](https://github.com/standardagents/t1bridge) + t1-revive | MIT | Touch Bar and Touch ID on T1 Macs; the renderer hook; its `contrib/omarchy` desktop provider, which the `touchbar` module wires in with a systemd drop-in | no: install it first |
| [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) | GPL-2.0 | the CS8409 codec driver the `mic` module builds, at a pinned commit | no: cloned at build time |
| Linux kernel `applesmc` driver (Boichat, Rydberg, Love, Juhl, Holtmann and others) | GPL-2.0-only | `battery-limit` ships applesmc.c from kernel 7.2.5 with a BCLM patch | yes, under GPL-2.0 in its own folder |
| Linux kernel sources (kernel.org) | GPL-2.0 | the `mic` build uses the matching `sound/hda` tree, sha256-checked | no: downloaded at build time |
| [Omarchy](https://github.com/basecamp/omarchy) | MIT | user overrides for two of its commands (`omarchy-brightness-keyboard` wrapped, handing every other case to Omarchy's own; `omarchy-hw-external-monitors` re-implemented with one change); calls its lock, shell, launch and lid commands and uses its Lua config API | no Omarchy code is copied |
| [hwdeck](https://github.com/pnshad/hwdeck), [touchbar-strip](https://github.com/pnshad/touchbar-strip) | MIT | installed by the `hwdeck` and `touchbar` modules | no: cloned at a tag |
| [btop](https://github.com/aristocratos/btop) by Aristocratos | Apache-2.0 | hwdeck's `btop` style borrows its look; no code | no |
| [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono) + [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) | OFL-1.1 / MIT | icons and digits in the strip and hwdeck views | no |
| Hyprland · foot · uwsm · PipeWire / WirePlumber · brightnessctl · NetworkManager · power-profiles-daemon · systemd · DKMS · fprintd / PAM | BSD-3 · MIT · MIT · MIT · MIT · GPL-2.0 · GPL-3.0 · LGPL-2.1 · GPL-2.0 · GPL-2.0 / BSD | runtime tools, called by name | no |

The strip's LOCKED sign decodes out of katakana, after the digital rain of *The Matrix* (1999);
no assets are used. The rain screensaver and pixel refresh live in
[omarchy-mac-kit-extras](https://github.com/pnshad/omarchy-mac-kit-extras).
