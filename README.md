# samsung-tizen9-root

**Persistent root for 2024+ Samsung Neo QLED TVs running Tizen 9**, via the
public CVE-2024-2887 browser chain plus our own boot-time persistence layer
(MCS DLL string hijack + UEP kernel-module autostart + dropbear SSH).

| | |
|---|---|
| **Target** | Samsung Neo QLED, Tizen 9, QNX1D platform (QTV T09), kernel 5.4.77 ARM32 |
| **Tested on** | QE65QN90D (EU), firmware `T-PTMDEUC-1400.x` |
| **Entry point** | CVE-2024-2887 (Chromium 120 WasmGC) via built-in browser |
| **Persistence** | Boot-time `.NET` payload + MCS DLL hijack + `uep31.ko` + dropbear SSH :2222 |
| **No** | firmware flashing, dev-mode, sdb, remote unlock codes, signed modules |

> ⚠️ **Security research use only.** Only run this on a TV you own. The chain
> modifies stock system files; a failed install can require a factory reset or
> (worst case) a service-centre firmware reflash. The `uninstall.sh` script
> restores all modified files from backups. Read [`docs/TECHNICAL.md`](docs/TECHNICAL.md)
> before running anything.

---

## Prerequisites

- **Linux, macOS, or Windows with WSL2** (for Docker + cross-compile)
- **Docker** (uses `dockcross/linux-armv7-lts`)
- **Python 3.9+**
- **An SSH keypair** you want to install for root access
- **The TV's IP address** on your LAN (DHCP reservation recommended)
- The TV must be reachable: ping it before you start.

## Quick start — one command

```bash
./root-all.sh --tv-ip 192.168.0.74 --ssh-key ~/.ssh/id_ed25519.pub
```

That runs all five steps in order. If any step fails it stops and tells you
exactly which script to re-run.

## Step-by-step (what `root-all.sh` does internally)

The install is split into five independent commands. Run them in order — each
can be re-run safely if it fails. Each step is documented in detail in
[`docs/TECHNICAL.md`](docs/TECHNICAL.md).

### Step 1 — Initial root (in-memory)

```bash
./01-root-browser.sh --tv-ip 192.168.0.74
```

Drives the upstream CVE-2024-2887 browser exploit. You will be told to open a
URL on the TV's built-in browser once. On success you have **in-memory root**
on the TV — no reboot survival yet. This is `upstream/samsung_tizen_tv_root/`'s
`root.ps1`, wrapped so bash/zsh users don't need PowerShell.

### Step 2 — Persistent root base (.NET boot payload)

```bash
./02-persist-base.sh --tv-ip 192.168.0.74
```

Installs the upstream's boot-time `.NET` payload that replays the physmap root
on every boot. After this step the TV survives a power-cycle with a root
channel on TCP **31337**. Still upstream's work — we don't touch the payload
itself.

### Step 3 — UEP bypass (kernel module)

```bash
./03-uep-setup.sh --tv-ip 192.168.0.74
```

Builds `uep31.ko` from source using dockcross, uploads it to `/opt/jd/`, and
wires it into the boot flow so it loads before our later services. UEP
(Universal Enforcement Protection) is Tizen 9's in-kernel module-signature
verifier; patching it to `mov r0, #0; bx lr` is what lets subsequent steps
load their own code. See [`src/uep/README.md`](src/uep/README.md).

### Step 4 — MCS DLL hijack for dropbear SSH

```bash
./04-mcs-ssh-hijack.sh --tv-ip 192.168.0.74 --ssh-key ~/.ssh/id_ed25519.pub
```

This is **our main contribution** on top of upstream. Patches a 138-byte
UTF-16 LE string in `MultiControlService.dll` at file offset `0x83ed` so the
stock MCS service, running as root at boot, invokes our `init.sh`. `init.sh`:

1. Loads `uep31.ko`
2. Mounts tmpfs on `/root` and installs your public key in `authorized_keys`
3. Starts dropbear on TCP **2222**
4. Starts the health monitor

After this step you get SSH-with-key-auth that survives reboots.

### Step 5 — Verify

```bash
./05-verify.sh --tv-ip 192.168.0.74
```

Health check:
- Root channel on TCP 31337 responds?
- UEP module loaded (`lsmod | grep uep31`)?
- Dropbear listening on 2222?
- SSH key auth works end-to-end?
- `init.sh` log clean?

Any failure gives a clear "re-run step X" hint.

## Uninstall

```bash
./uninstall.sh --tv-ip 192.168.0.74
```

Restores every modified file from backups kept under `/opt/jd/backup/` on the
TV, unloads modules, removes services, and power-cycles the TV once. After
this the TV is back to the same firmware state you started with.

## Repository layout

```
samsung-tizen9-root/
├── 01-root-browser.sh      # Thin wrapper → upstream root.ps1 (or pwsh fallback)
├── 02-persist-base.sh      # Upstream's boot payload install
├── 03-uep-setup.sh         # Our UEP kernel-module build + install
├── 04-mcs-ssh-hijack.sh    # Our MCS DLL hijack + dropbear install
├── 05-verify.sh            # Health check
├── root-all.sh             # Runs 01-05 in sequence
├── uninstall.sh            # Full restore from backups
│
├── upstream/
│   └── samsung_tizen_tv_root/   # Vendored (see NOTICE.md)
│
├── src/
│   ├── uep/                # uep31.c + Makefile — in-kernel verifier patch
│   ├── mcs-patch/          # patch.py (binary patch) + init.sh (boot script)
│   ├── dropbear/           # Cross-compile config for dropbear 2026.94
│   └── monitor/            # Health monitor daemon
│
├── build/
│   ├── Dockerfile          # dockcross-based ARM build environment
│   └── build-all.sh        # Build uep31.ko + dropbear
│
├── docs/
│   ├── GETTING-STARTED.md  # Overview + prereqs + first-run walkthrough
│   ├── TECHNICAL.md        # How each step works, offsets, references
│   ├── TROUBLESHOOTING.md  # Common failures and recovery
│   └── MODEL-COMPATIBILITY.md
│
├── tests/
│   ├── test-ssh.sh         # SSH key auth end-to-end
│   └── test-uep.sh         # UEP bypass liveness check
│
├── LICENSE                 # MIT
├── NOTICE.md               # Attribution to commit-regrets, hdbreaker, Vetro
└── .gitignore              # Blocks keys, firmware binaries, HDCP blobs
```

## Known-good TVs

See [`docs/MODEL-COMPATIBILITY.md`](docs/MODEL-COMPATIBILITY.md) for the full
list. Report additions as issues or PRs.

| Model | Region | Firmware | Status |
|---|---|---|---|
| QE65QN90D | EU | T-PTMDEUC-1400.1 | ✅ Fully working |

## Known limitations

- **Tizen 9 only** — Tizen 8 uses a different kernel layout; the `uep31.ko`
  offset is wrong. We do not plan to backport.
- **No HDCP capture bypass** — a separate research track (see
  `docs/HDCP-RESEARCH.md`) looks at the TA-level HDCP enforcement for
  ambient-color use cases. The patches in that doc are **not** included in the
  install flow because the resulting frames are still blanked at kernel level
  on this firmware.
- **Firmware updates will reset it** — a stock OTA will overwrite the
  MCS DLL. Re-run `root-all.sh` after any OTA.

## Contributing

PRs welcome for:
- Additional model/firmware combinations in `docs/MODEL-COMPATIBILITY.md`
- UEP offset probes for new kernel builds
- Debloat lists for region-specific apps (goes into `upstream/`'s debloat
  directory, PR upstream too)

Please do **not** submit PRs containing extracted keys, firmware binaries, or
DRM material. See [`.gitignore`](.gitignore) and [`NOTICE.md`](NOTICE.md).

## License

MIT — see [`LICENSE`](LICENSE). Third-party components retain their own
licenses as documented in [`NOTICE.md`](NOTICE.md).
