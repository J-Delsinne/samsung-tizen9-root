# `src/uep/` — UEP verifier bypass as a loadable kernel module

Tizen 9 ships a kernel-side integrity gate called **UEP (Universal Enforcement
Protection)**. It is called by the module loader and by exec paths to verify
signatures over kernel modules and certain binaries. Without bypassing it, we
cannot load `uep31.ko` itself — so the module uses the physmap write primitive
set up by the initial-root chain to flip 8 bytes of kernel text that disable
the check.

## What it does

Writes two ARM instructions at kernel virtual address `0xC02A66E0`:

```
e3a00000  mov r0, #0        ; return 0  (verification OK)
e12fff1e  bx  lr            ; return
```

That is the UEP verifier's entry point on the 2024 Neo QLED Tizen 9 kernel
(1400.x). Once patched, every subsequent call returns "verified OK" without
actually checking anything. The module then becomes idle — it stays loaded
so `lsmod` can prove we're active, but all the real work is done at `insmod`
time.

## What it does NOT do

- Elevate privileges — you need root already (steps 01/02).
- Survive reboot on its own — the file at `/opt/jd/uep31.ko` only reloads
  because `init.sh` calls `insmod` on boot. The MCS DLL hijack of step 04 is
  what wires `init.sh` into the boot flow.
- Modify module signing persistently on-flash — the patch is RAM-only. Reboots
  revert kernel text, which is why we re-apply every boot.

## Checking it is live

```sh
root@tv:~# lsmod | grep uep31
uep31                 12288  0
root@tv:~# dmesg | grep -i uep
[   42.113] uep31: Tizen 9 UEP bypass loading
[   42.118] uep31: UEP_BYPASS_OK
```

## Building

The module targets Linux 5.4.77 ARM32 with soft-float ABI. Easiest path:

```sh
# From repo root:
./build/build-all.sh uep
```

That drops `uep31.ko` in `build/output/`. Step 03 uploads and loads it.

## Finding the offset on a different firmware build

`0xC02A66E0` is specific to the 1400.x kernel we tested. If `insmod` fails
with `-ENOTSUP` or `-EINVAL`, the verifier sits somewhere else in your build.
Use `tools/probe_uep.py` (planned, see `docs/TECHNICAL.md`) to scan RAM for the
verifier's signature and print the right address. Then rebuild with
`-DUEP_VERIFIER_VA=0xXXXXXXXX` in `Makefile`.

## Caveats

- The module uses `kallsyms_lookup_name` to find `set_memory_rw/ro`. On
  kernels where that symbol table is not fully populated (unlikely on Tizen 9
  stock, but possible on stripped builds), the module refuses to patch with
  `-ENOTSUP`. See `docs/TROUBLESHOOTING.md`.
- We do **not** restore kernel text on `rmmod`. Once the bypass is in place
  for a boot, it stays. A reboot wipes it cleanly.

## Authorship

Original research by J-Delsinne. MIT (see repo root `LICENSE`).
