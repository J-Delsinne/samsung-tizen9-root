# Model compatibility

This is a living document. PRs welcome for any additions, confirmations,
or offset probes for new firmware builds.

## Required platform

- **Tizen 9** (TV reports it in Settings → Support → About this TV)
- **QNX1D platform family** (QTV T09)
- **ARMv7 kernel 5.4.x** with soft-float ABI

Tizen 8 and Tizen 10 have different kernel layouts and different UEP offsets;
this toolkit does **not** target them. Tizen 8 has a separate community of
roots; Tizen 10 is too new (at the time of writing) for a stable chain.

## Known-good

| Model | Region | Firmware | Status | Who verified | When |
|-------|--------|----------|--------|--------------|------|
| QE65QN90D | EU | T-PTMDEUC-1400.1 | ✅ full install | J-Delsinne | 2026-11 |

## Expected to work (not yet verified)

Models that share the same chassis and platform code as QE65QN90D. Firmware
build number is what actually matters; model number is a hint about which
build is likely.

- QE55QN90D, QE75QN90D, QE85QN90D (same QN90D series)
- QE43QN90D (same series but different panel size — SoC should match)
- QN90D in US/APAC regions (platform code likely identical, firmware
  build differs)

## Firmware variants in the wild

The firmware name decodes as `T-<platform>-<build>`:

- `T` — Tizen
- `PTM` — platform code (QNX1D family)
- `DEUC` — region (DE=Germany, UC=UK / common European build)
- `1400.1` — build version, minor

The UEP offset (`0xC02A66E0`) and the MCS string offset (`0x83ED`) are
measured against build `1400.x`. On other builds:

- UEP offset may be different — see TECHNICAL.md for the probe.
- MCS string offset may be different — `src/mcs-patch/patch.py --offset 0xNNNN`
  takes an override.

## Reporting a new combination

Open a PR editing this file; please include:

1. Model + region + exact firmware build.
2. Which steps succeeded as-is.
3. For any step that needed an offset override, the offset you used.
4. Output of the first 20 lines of `/tmp/jd-init.log` after a clean install.
5. (Optional) a short note on how you verified SSH login works.

## Explicitly not supported

- Tizen 8.x TVs (different kernel, different verifier)
- TVs from 2022 or earlier (different platform code, pre-UEP in some cases)
- QN900D / QN95D (8K panels, different SoC family — untested, probably
  different offsets)
- Anything with CPU architecture other than ARMv7 soft-float

## About firmware downgrades

If your TV is on a newer `1500.x` or `1600.x` build that this toolkit doesn't
yet target, Samsung TVs do **not** allow downgrading the firmware through the
UI. USB-flash downgrade via service menu is possible but risks bricking.
Recommendation: wait for an offset update in this repo, or help find it
(TECHNICAL.md explains the procedure).
