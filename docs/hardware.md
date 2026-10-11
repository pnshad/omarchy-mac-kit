# Hardware

| Module | Works on | Tested on |
|---|---|---|
| `hwdeck` | any Linux with a terminal; Mac extras (SMC names, fans, charge limit) with `applesmc` | MacBookPro14,2 |
| `wall` | Hyprland (Lua config: Omarchy 4; a `.conf` twin for classic configs, untested) | Omarchy 4.0.4 |
| `screensaver` | Omarchy (full takeover); plain Hyprland (rain pass + timer); any terminal (`omk-screensaver --demo`) | Omarchy 4.0.4 |
| `lid` | Omarchy laptops; the external-monitor fix only where a `card*-USB-*` connector exists (T1 Macs) | MacBookPro14,2 |
| `touchbar` | T1 MacBook Pros with t1bridge: MacBookPro13,2, 13,3, 14,2, 14,3 | MacBookPro14,2 |
| `fans-ram` | fans: Intel Macs with `applesmc`; RAM trim: any Linux | MacBookPro14,2 |
| `smc-power` | Intel Macs with `applesmc` (keys vary by model) | MacBookPro14,2 |
| `battery-limit` | Intel Macs whose SMC has the `BCLM` key, on the tested kernels only | MacBookPro14,2, kernel 7.2.5 |
| `mic` | Macs with the Cirrus CS8409 codec (most 2016–2019 MacBook Pros) | MacBookPro14,2, kernel 7.2.5 (test load; permanent install not yet run) |
| `lock-fingerprint` | T1 MacBook Pros with t1bridge Touch ID, on Omarchy's lock screen | MacBookPro14,2 |

T2 Macs (2018 and later) have a different Touch Bar and Touch ID path: the Touch Bar and
fingerprint modules do not apply to them.

Install order on a fresh T1 Mac: Omarchy → t1-revive + t1bridge (Touch Bar, Touch ID; its
`appletbdrm` wake fix until it is upstream) → `hwdeck` → `wall` → `screensaver` → `lid` →
`touchbar` → root modules as wanted: `smc-power`, `fans-ram`, `battery-limit`, `mic`,
`lock-fingerprint`.
