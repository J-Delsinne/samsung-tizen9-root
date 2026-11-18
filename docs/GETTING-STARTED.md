# Getting started

## What you need

| Item | Why | How to get it |
|------|-----|---------------|
| A supported Tizen 9 TV | the target | See [MODEL-COMPATIBILITY.md](MODEL-COMPATIBILITY.md) |
| Linux, macOS, or WSL2 | runs the install scripts | native |
| Docker | cross-compiles ARM binaries | https://docs.docker.com/get-docker/ |
| Python 3.9+ | patch.py, upstream helpers | native |
| An SSH keypair | will become your root auth | `ssh-keygen -t ed25519` |
| TV + PC on same LAN | TCP 31337 + :2222 need to reach | wire or Wi-Fi, same subnet |

Optional:

| Item | Why |
|------|-----|
| PowerShell 7+ (`pwsh`) | lets steps 01/02 call upstream `root.ps1` directly |
| `jq`, `ripgrep` | nicer debugging of the trend log and dmesg |

## 15-minute walkthrough

```bash
# 1. Clone and vendor upstream
git clone https://github.com/J-Delsinne/samsung-tizen9-root.git
cd samsung-tizen9-root
./build/init-upstream.sh

# 2. Generate an SSH key if you don't have one
ssh-keygen -t ed25519 -f ~/.ssh/tv_tizen9

# 3. Run the full install (five steps, pauses for two reboots)
./root-all.sh --tv-ip 192.168.0.74 --ssh-key ~/.ssh/tv_tizen9.pub

# 4. SSH into your TV as root
ssh -i ~/.ssh/tv_tizen9 -p 2222 root@192.168.0.74
```

## If something goes wrong

Each step is independent and re-runnable. `root-all.sh` tells you which one
failed; you re-run **only** that one.

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common failures. The
`uninstall.sh` script restores every modified file from backups kept on the
TV itself, so you can always get back to a stock state without a factory reset.

## What to do next

- **Debloat**: `upstream/samsung_tizen_tv_root/debloat/` has a tested disable
  list for the QNX1D platform. Follow the README there.
- **Keep it up**: a stock OTA update will overwrite the patched MCS DLL. Watch
  the TV for firmware updates in Settings → Support, and re-run `root-all.sh`
  after each one.
- **Explore**: the TV is now a normal ARM Linux box. `/usr/lib/` has 1,500+
  shared libraries; many are interesting. Report findings as issues.

## What NOT to do

- **Do not publish extracted keys** (HDCP, DRM, device TEE keys) — see the
  legal notice in `NOTICE.md`.
- **Do not run on a TV you do not own.**
- **Do not share your private SSH key.** If you're writing it into a tutorial,
  generate a fresh pair for the walkthrough.
