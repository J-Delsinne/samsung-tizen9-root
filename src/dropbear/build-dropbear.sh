#!/usr/bin/env bash
# build-dropbear.sh — Cross-compile dropbear 2026.94 for Samsung Tizen 9 ABI.
# ABI: ARMv7, soft-float EABI, glibc 2.30+. Dynamic linker /lib/ld-linux.so.3.
# Produces a single statically-linked dropbear binary in build/output/dropbear.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DROPBEAR_VERSION="${DROPBEAR_VERSION:-2026.94}"
DROPBEAR_URL="${DROPBEAR_URL:-https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2}"
WORKDIR="${WORKDIR:-${REPO_ROOT}/build/workdir/dropbear}"
OUT="${REPO_ROOT}/build/output/dropbear"

mkdir -p "$WORKDIR" "$(dirname "$OUT")"

TAR="${WORKDIR}/dropbear-${DROPBEAR_VERSION}.tar.bz2"
SRC="${WORKDIR}/dropbear-${DROPBEAR_VERSION}"

if [[ ! -f "$TAR" ]]; then
    echo "[dropbear] fetching ${DROPBEAR_URL}"
    curl -L --fail -o "$TAR" "$DROPBEAR_URL"
fi

if [[ ! -d "$SRC" ]]; then
    tar -xjf "$TAR" -C "$WORKDIR"
fi

# Apply minimal config — key features only, static link.
cp "${SCRIPT_DIR}/localoptions.h" "${SRC}/localoptions.h"

# Build under dockcross (same image we use for uep31.ko).
# Use arm-linux-gnueabi (NOT gnueabihf) because Tizen 9 is soft-float ABI.
docker run --rm -v "${SRC}":/work -w /work dockcross/linux-armv7-lts bash -c '
    ./configure \
        --host=arm-linux-gnueabi \
        --disable-wtmp \
        --disable-lastlog \
        --disable-syslog \
        CFLAGS="-Os" \
        LDFLAGS="-static"
    make clean
    make -j"$(nproc)" PROGRAMS="dropbear"
    arm-linux-gnueabi-strip dropbear
    file dropbear
'

cp "${SRC}/dropbear" "$OUT"
echo "[dropbear] ✅ ${OUT}"
ls -la "$OUT"
