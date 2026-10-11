# battery-limit

Licence: **GPL-2.0-only** (this folder only; see [LICENSE](LICENSE)). The rest of
omarchy-mac-kit is MIT.

- `applesmc.c` — the Linux kernel's `drivers/hwmon/applesmc.c` as of kernel 7.2.5 with
  `applesmc-bclm.patch` applied (`MODULE_VERSION("7.2.5-bclm1")`). Upstream copyright: the
  applesmc authors (Nicolas Boichat, Henrik Rydberg and others, see the file header).
- `applesmc-bclm.patch` — the change: a `charge_control_end_threshold` attribute on the applesmc
  platform device backed by the SMC's `BCLM` key (stop charging at this %, minimum 20).
- `Makefile`, `dkms.conf` — out-of-tree build with DKMS. `AUTOINSTALL="no"`: a kernel update
  does not rebuild this source for a kernel it was not tested on.

Tested kernels: 7.2.5 (Omarchy `7.2.5-3-omarchy`) on a MacBookPro14,2. `install.sh` refuses
others; to add one, diff this `applesmc.c` against that kernel's, re-apply the patch, test, and
add the version to `TESTED_KERNELS`.
