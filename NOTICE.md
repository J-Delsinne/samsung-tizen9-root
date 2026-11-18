# Third-party notices and attribution

This project builds on prior work. Credit where due.

## Upstream initial-root chain

The `upstream/` directory is a vendored copy of
**[commit-regrets/samsung_tizen_tv_root](https://github.com/commit-regrets/samsung_tizen_tv_root)**,
licensed MIT, copyright (c) 2026 the Samsung Tizen 9 TV Root authors. It
provides the browser-RCE → physmap → root chain used by step 01 and 02.

Their work in turn vendored and credited:

- **Browser RCE chain** (CVE-2024-2887, WasmGC type confusion in Chromium 120)
  — derived from the public `samsung-smarttv-tizen-9-chromium-120-v8-rce`
  project by **hdbreaker**. Upstream had no LICENSE file at the time of
  writing; attribute and link to the upstream project if you redistribute
  these files.
- **V4L2 physmap technique** — the `/dev/video40` mapping primitive and
  `physrpc` stub layout build on the same research.
- **Debloat package classification** — vendored from
  [andrearicci93/vetro](https://github.com/andrearicci93/vetro) 0.2.3, MIT,
  copyright (c) 2026 Vetro contributors.
- **cleanyourtv** — [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv)
  as a reference for package-per-TV classification.

## New work in this repository

Everything OUTSIDE `upstream/` is original work added by J-Delsinne and
contributors to this repository. That includes:

- **UEP (Universal Enforcement Protection) bypass** — identification of the
  Tizen 9 verifier at kernel address `c02a66e0`, loadable kernel module
  (`uep31.ko`) that patches it to `mov r0, #0; bx lr`, and the install path
  that survives reboot.
- **MCS DLL string hijack** — boot-time persistence that modifies 138 bytes
  (69 UTF-16 LE characters) at file offset `0x83ed` inside
  `MultiControlService.dll` so that stock MCS execution kicks off
  `/opt/jd/init.sh` on every boot.
- **Dropbear 2026.94 build** — minimal cross-compile configuration for
  ARMv7 soft-float, deployed as the persistent SSH server on TCP port 2222.
- **Deployment orchestration** — the five step scripts, the health monitor,
  the uninstall path, and the documentation that ties it all together.

This repository is licensed MIT; see [`LICENSE`](LICENSE). The MIT license
covers the original work in this repository; it does not relicense the
vendored `upstream/` tree, which keeps its own `LICENSE` file.

## Trademarks

**Samsung** and **Tizen** are trademarks of Samsung Electronics Co., Ltd.
This project is unofficial, not affiliated with or endorsed by Samsung.

## Legal and ethical

This toolkit is intended for **security research on your own device**, for
debloating and restoring control over hardware you own. Do not use it on
devices you do not own or do not have explicit authorization to modify.

The authors deliberately **do not publish** any extracted cryptographic key
material (HDCP keys, device-bound TEE keys, DRM content keys) — these keys
raise circumvention-device concerns under DMCA § 1201 and the EU InfoSoc
Directive Article 6. Methodology is published; keys are not.
