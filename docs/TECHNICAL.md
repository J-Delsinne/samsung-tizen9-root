# Technical details — how each step works

For people who want to understand the chain, port it to a new firmware build,
or write the next persistence trick.

## Step 1 — Initial root (upstream)

Code: `upstream/samsung_tizen_tv_root/`. Four stages, every one with a public
writeup linked below.

1. **Browser RCE**: CVE-2024-2887 (WasmGC type confusion in Chromium 120)
   triggered from the TV's built-in `SamsungBrowser/7.0`. Gives shellcode
   execution inside the renderer (`uid=5001`, group `video`).
2. **Physmap**: `/dev/video40` (and `/30`, `/60` as fallbacks) accept an
   attacker-chosen `vm_pgoff` in `mmap()` and pass it to `remap_pfn_range()`
   unvalidated. Result: arbitrary physical-memory read/write from the
   renderer process. Per-instance `EBUSY` behavior — retry the same node, do
   not round-robin busy nodes.
3. **Cred patch**: walk `init_task` → find our own task through a forked
   child's `real_parent`, zero `cred->uid/gid/euid/egid/fsuid/fsgid` and set
   `cap_effective = 0x3fffffffff`. We now have `uid=0, CapEff=full`.
4. **Service hop**: the renderer is sandboxed by Smack; we hop to a stock
   service with a looser label by overwriting its credentials the same way,
   then talk to the world through TCP 31337 (upstream's "root channel").

The physmap technique is the interesting part; see
`upstream/samsung_tizen_tv_root/docs/EXPLOIT.md` for the measured constants.

**Result**: `uid=0` on the TV, in-memory only. Any reboot wipes it.

## Step 2 — Boot-time persistence (.NET payload) — upstream

Code: `upstream/samsung_tizen_tv_root/payload/`.

The TV runs several `app_onboot` .NET services as root at every boot. Upstream
replaces the IL assembly of one of them with a payload that:

1. Re-applies the physmap cred patch on boot.
2. Closes its own `/dev/video40` fd so the kernel node is free for subsequent
   use.
3. Listens on TCP 31337 and runs commands the install scripts send.

Deployed to a specific path inside `/opt/usr/apps/*`. Same permissions as the
stock service.

**Result**: boot survives, TCP 31337 answers. SSH not yet available.

## Step 3 — UEP bypass kernel module

Code: `src/uep/`. Full writeup: [`../src/uep/README.md`](../src/uep/README.md).

The Tizen 9 kernel has an **in-kernel verifier** we call UEP (Universal
Enforcement Protection). It gates module signature verification and certain
exec paths. If we don't flip it, `insmod` on anything unsigned fails.

The verifier's entry point on the 1400.x kernel is at virtual address
**`0xC02A66E0`**. `uep31.ko` writes

```
e3a00000  mov r0, #0
e12fff1e  bx  lr
```

there — 8 bytes. After that every call returns "verified OK" and the rest of
our modules load freely.

### Writable kernel text

ARM32 Tizen 9 maps kernel text R-X with `CONFIG_STRICT_KERNEL_RWX=y` enforced.
`uep31.ko` calls `kallsyms_lookup_name("set_memory_rw")` to get a writable
alias for one page, writes the two instructions, calls
`flush_icache_range()`, and sets the page back to R-X. The whole patch is
done with `local_irq_save` to keep from racing another CPU.

### Finding the offset on a different build

Build-specific. If `insmod uep31.ko` reports `-ENOTSUP`:

1. Dump kernel RAM with `upstream/samsung_tizen_tv_root/tools/dump_kernel_ram.py`.
2. Load the dump into Ghidra / IDA / radare2 with base address `0xC0008000`.
3. Search strings for `"module signature"`. The verifier sits near the only
   function that reads them and returns an int. Its address is your new UEP
   entry.
4. Rebuild `uep31.ko` with `-DUEP_VERIFIER_VA=0xXXXXXXXX`.

A `probe_uep.py` helper that does this automatically is on the roadmap; PRs
welcome.

## Step 4 — MCS DLL string hijack (dropbear SSH persistence)

Code: `src/mcs-patch/`.

The TV runs `MultiControlService.dll` (a C# / IL binary) as root at boot. Deep
in that DLL's string table, at file offset **`0x83ED`**, sits a 138-byte
UTF-16 LE field: a path string that MCS reads during startup and invokes
through `Process.Start()` without further sandboxing.

We overwrite those 138 bytes with the UTF-16 encoding of our own path
(`/opt/jd/init.sh`, padded with zeros).

`init.sh` then:

1. `insmod /opt/jd/uep31.ko` — UEP bypass loaded for this boot.
2. `mount -t tmpfs tmpfs /root; echo <key> > /root/.ssh/authorized_keys`.
   Tmpfs because `/root` on stock Tizen 9 is read-only; tmpfs gives us a
   writable per-boot overlay.
3. `nohup /opt/ssh/dropbear -p 2222 …` — SSH daemon up.
4. Spawn the health monitor loop.

The original DLL is backed up to `/opt/jd/backup/MultiControlService.dll.orig`
on first install, so `uninstall.sh` can restore it byte-for-byte.

### Why a string hijack and not a code patch?

String patches are robust against IL layout drift — the string table's shape
is the same across firmware revisions, only the specific path moves. A code
patch would need recompiling the whole DLL and re-signing it (Tizen 9 does
check CRC of .NET DLLs on some paths). This keeps the DLL's code unchanged
and only redirects one data field.

### Finding the offset on another firmware

The string at `0x83ED` on `T-PTMDEUC-1400.x` was found by:

1. Pull the DLL off a rooted TV: `scp -P 2222 root@tv:/opt/usr/apps/.../MultiControlService.dll .`
2. Open in a .NET decompiler (`ilspycmd`, dotPeek) and look at its boot
   method's string literals.
3. Verify the offset by scanning for the UTF-16 encoding of the string in
   the raw bytes.

On other firmware the offset may move; `src/mcs-patch/patch.py --offset 0xNNNN`
takes an override.

## Step 5 — Verify

Code: `05-verify.sh`. Nothing clever — just a checklist. Each check is a
small command that either succeeds or fails. Red ❌ tells you which step to
re-run.

## Uninstall

Code: `uninstall.sh`. Restores from backups kept on the TV itself under
`/opt/jd/backup/`. Does NOT perform a factory reset; your settings and
accounts stay. Does NOT remove upstream's step-2 payload — that has its own
uninstall.ps1 in `upstream/`.

## Why it's safe to leave `uep31.ko` resident

Once UEP returns "OK" for the rest of the boot, the module itself is idle. It
could unload itself at the end of `init()` but we leave it resident so `lsmod`
can prove it's active — useful for the health monitor and verify step.

## What we deliberately did NOT publish

See `NOTICE.md`:

- No extracted HDCP keys.
- No extracted DRM/device-bound TEE keys.
- No redistributed Samsung firmware binaries.

Methodology is enough to reproduce on your own TV; publishing the keys would
cross a legal line we don't want anywhere near this repo.
