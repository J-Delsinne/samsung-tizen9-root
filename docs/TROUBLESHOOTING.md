# Troubleshooting

Each failure mode below gives you the diagnostic command, what the output
means, and the fix.

## "ERROR: cannot ping <ip>"

Nothing fancy — the TV isn't reachable.

**Diagnose**: `ping -c 3 <tv-ip>`; `arp -a | grep <tv-mac>`.

**Fix**: check Wi-Fi/Ethernet; set a DHCP reservation for the TV's MAC so its
IP is stable; verify both PC and TV are on the same subnet.

## Step 01 — "pwsh: command not found"

Upstream's `root.ps1` is PowerShell. If you don't have `pwsh` installed,
`01-root-browser.sh` falls back to a manual mode.

**Fix** (preferred): install PowerShell 7+ from https://aka.ms/powershell.
Available on Linux, macOS, and Windows.

**Fix** (manual): follow the `cat` output from `01-root-browser.sh` to run
the upstream server by hand. The hard part is still the TV browser step;
there is no way around it.

## Step 01 — browser hangs on "LOADING…" forever

The WasmGC payload is sensitive to GC pauses in Chromium 120.

**Diagnose**: the upstream server log prints "sweep hit" vs. "sweep miss".

**Fix**: close other browser tabs on the TV, reboot the TV once, retry.
Three attempts in a row usually land one.

## Step 02 — "root channel not responding" after reboot

The boot payload didn't install, or it did install but the `.NET`
`app_onboot` service it replaced isn't being started.

**Diagnose**: re-run step 01 (back to in-memory root), then
`ls -la /opt/usr/apps/<service>/bin/` and check the payload DLL is there.

**Fix**: re-run `02-persist-base.sh`. If it reports success but TCP 31337
still doesn't answer after a reboot, the service it hooked may have been
disabled by a Samsung-side update. Open an issue with your firmware build
number; we'll point you at an alternative service.

## Step 03 — "uep31 INSMOD FAILED (-ENOTSUP)"

Either the kernel symbol lookup failed (unlikely on stock Tizen 9), or the
kernel-text page cannot be flipped R/W.

**Diagnose**: on the TV, `dmesg | tail` right after the `insmod` failure.
`uep31: set_memory_{rw,ro} not resolvable` means symbol lookup failed.

**Fix**: check your kernel build matches what this module targets. Dump the
kernel (see TECHNICAL.md), confirm `set_memory_rw` is exported at a resolvable
address. If not, rebuild the module with a direct-write fallback; or open an
issue with your firmware build.

## Step 03 — "uep31 INSMOD FAILED (-EINVAL)" or wrong offset

The verifier isn't at `0xC02A66E0` on your firmware build. This is the common
case when the firmware is not `1400.x`.

**Fix**: see the "Finding the offset on a different build" section in
`TECHNICAL.md`. Short version: dump RAM, locate the verifier in the dump,
rebuild the module with the new offset.

## Step 04 — "patch.py: Target path too long"

You passed a `--target` longer than 69 UTF-16 LE characters.

**Fix**: keep the path under 69 characters. `/opt/jd/init.sh` is 15; you have
plenty of room. If you really need a longer path, create a symlink
(`ln -s /very/long/real/path /opt/jd/i.sh`) and point the patch at the
shortened form.

## Step 04 — SSH login refused after reboot

`sshd` isn't running, or the host keys / `authorized_keys` aren't in place.

**Diagnose** (via upstream root channel):
```
python3 upstream/samsung_tizen_tv_root/tools/root_shell.py "cat /tmp/jd-init.log" <tv-ip>
```
The log tells you which init.sh step failed.

Common lines:

- `uep31 INSMOD FAILED` — step 03 is broken; SSH will still start but you
  lose any future module features.
- `dropbear MISSING at /opt/ssh/dropbear` — step 04 didn't upload the binary;
  re-run it.
- `dropbear FAILED to start` — `/tmp/dropbear.log` tells you why. Usually a
  port conflict (port 2222 already in use) or missing host keys.

**Fix**: re-run step 04, or manually fix the issue the log points at.

## Step 05 — "boot payload present ❌"

Step 02 didn't persist, or a firmware OTA overwrote it.

**Fix**: start over from step 01.

## OTA firmware update appeared — SSH stopped working

Samsung's OTA replaces the MCS DLL and often other system files. Your
`/opt/jd/backup/MultiControlService.dll.orig` is now stale (it's the
pre-update DLL, not the post-update one you want to be patching against).

**Fix**:

1. Clean up the stale backup: `rm /opt/jd/backup/MultiControlService.dll.orig`
   (via the recovered root channel if you still have it, else start over).
2. Re-run `root-all.sh`.

Watch firmware updates in TV **Settings → Support** and run `root-all.sh`
after each one.

## "I bricked the TV" / no video output

No step in this toolkit should cause that — we only modify things in `/opt/`,
which the TV's init tolerates being absent/broken. If the TV won't boot:

1. **Unplug it for 5 minutes** (full power drain, forces the bootloader to
   re-check).
2. Try the hidden recovery menu (**Mute + 1 + 8 + 2 + Power** on the remote
   for most 2023+ Neo QLEDs).
3. Service centre USB firmware reflash — this is the always-works last
   resort but costs about a service fee.

If `uninstall.sh` runs cleanly, the TV should boot even if every one of our
services is gone.

## Still stuck?

Open an issue at the repo with:

- Firmware build (**Settings → Support → About this TV → Software version**).
- Model number from the sticker.
- Which step failed and the exact error.
- Output of `uname -a` and `cat /proc/version` from the TV (via the root
  channel or SSH, whichever still works).
- `/tmp/jd-init.log` contents if step 04 was reached.
