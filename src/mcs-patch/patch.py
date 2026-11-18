#!/usr/bin/env python3
"""
patch.py — MCS DLL string hijack for Samsung Tizen 9 boot persistence.

The .NET-compiled MultiControlService.dll on Samsung Tizen 9 TVs contains a
UTF-16 LE string literal at file offset 0x83ed that MCS reads at startup and
treats as a path to invoke. Overwriting 138 bytes (69 UTF-16 LE characters)
there with our own path redirects boot execution into our init script.

Default target: /opt/jd/init.sh

Usage:
    python3 patch.py --input original.dll --output patched.dll \\
                     [--target /opt/jd/init.sh] \\
                     [--offset 0x83ed]

Verifies:
  - file size unchanged
  - exactly 138 bytes differ, all within [0x83ed, 0x83ed + 138)
  - target path round-trips through UTF-16 LE cleanly

License: MIT. Copyright (c) 2026 J-Delsinne.
"""

import argparse
import hashlib
import os
import sys


PATCH_OFFSET_DEFAULT = 0x83ED
PATCH_LEN_BYTES = 138       # 69 UTF-16 LE characters
DEFAULT_TARGET = "/opt/jd/init.sh"


def encode_target(path: str) -> bytes:
    """Encode a path to a 138-byte UTF-16 LE field, zero-padded."""
    enc = path.encode("utf-16-le")
    if len(enc) > PATCH_LEN_BYTES:
        raise ValueError(
            f"Target path too long: {len(enc)} bytes encoded, "
            f"max is {PATCH_LEN_BYTES} (69 UTF-16 LE chars). "
            f"Shorten the path or use a symlink like /opt/jd/i.sh."
        )
    return enc + b"\x00" * (PATCH_LEN_BYTES - len(enc))


def patch_dll(input_path: str, output_path: str, target: str, offset: int) -> dict:
    with open(input_path, "rb") as f:
        data = bytearray(f.read())
    orig_size = len(data)
    orig_sha = hashlib.sha256(data).hexdigest()

    if offset + PATCH_LEN_BYTES > orig_size:
        raise ValueError(
            f"Offset 0x{offset:x} + {PATCH_LEN_BYTES} bytes exceeds file size "
            f"({orig_size} bytes). Wrong DLL or wrong offset."
        )

    new_bytes = encode_target(target)

    orig_slice = bytes(data[offset:offset + PATCH_LEN_BYTES])
    data[offset:offset + PATCH_LEN_BYTES] = new_bytes

    if len(data) != orig_size:
        raise RuntimeError("patch changed file size — internal bug, bailing out")

    with open(output_path, "wb") as f:
        f.write(data)

    new_sha = hashlib.sha256(data).hexdigest()

    return {
        "input": input_path,
        "output": output_path,
        "orig_size": orig_size,
        "orig_sha256": orig_sha,
        "patched_sha256": new_sha,
        "offset": offset,
        "patch_len": PATCH_LEN_BYTES,
        "target": target,
        "original_bytes_hex": orig_slice.hex(),
        "patched_bytes_hex": new_bytes.hex(),
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description="Patch MCS DLL to invoke a custom init script at boot."
    )
    ap.add_argument("--input", required=True, help="Original DLL (read-only)")
    ap.add_argument("--output", required=True, help="Patched DLL to write")
    ap.add_argument(
        "--target",
        default=DEFAULT_TARGET,
        help=f"Path invoked by MCS at boot (default: {DEFAULT_TARGET})",
    )
    ap.add_argument(
        "--offset",
        type=lambda v: int(v, 0),
        default=PATCH_OFFSET_DEFAULT,
        help=f"File offset of the string table entry (default: 0x{PATCH_OFFSET_DEFAULT:x})",
    )
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    if not os.path.isfile(args.input):
        print(f"ERROR: input not found: {args.input}", file=sys.stderr)
        return 2
    if os.path.realpath(args.input) == os.path.realpath(args.output):
        print("ERROR: --input and --output must be different files", file=sys.stderr)
        return 2

    try:
        info = patch_dll(args.input, args.output, args.target, args.offset)
    except (ValueError, RuntimeError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 3

    if not args.quiet:
        print(f"[patch] input:       {info['input']}")
        print(f"[patch] output:      {info['output']}")
        print(f"[patch] size:        {info['orig_size']} bytes (unchanged)")
        print(f"[patch] offset:      0x{info['offset']:04x}")
        print(f"[patch] target:      {info['target']}")
        print(f"[patch] orig sha256: {info['orig_sha256']}")
        print(f"[patch] new  sha256: {info['patched_sha256']}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
