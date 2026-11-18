#!/usr/bin/env bash
# build-all.sh — Build everything we deploy to the TV.
#
#   ./build-all.sh              # build both (uep + dropbear)
#   ./build-all.sh uep          # uep31.ko only
#   ./build-all.sh dropbear     # dropbear only
#
# Needs: Docker. First call pulls dockcross/linux-armv7-lts (~800MB).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUT="${REPO_ROOT}/build/output"
mkdir -p "$OUT"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is required for the cross-build." >&2
    exit 1
fi

TARGETS=("${@:-uep dropbear}")

build_uep() {
    echo "[build] uep31.ko"
    local src="${REPO_ROOT}/src/uep"

    # UEP needs matching Tizen 9 kernel headers. If the user has extracted them
    # already, we expect them at $KDIR; else we tell them where to drop them.
    local kdir="${KDIR:-${REPO_ROOT}/build/workdir/tizen9-kernel}"
    if [[ ! -d "$kdir/include" ]]; then
        cat >&2 <<EOF
ERROR: Tizen 9 kernel headers not found at:
    ${kdir}

Extract them from the OTA firmware package (see docs/TECHNICAL.md),
then re-run:
    KDIR=/absolute/path/to/kernel-headers ./build/build-all.sh uep
EOF
        exit 2
    fi

    docker run --rm \
        -v "$src":/src \
        -v "$kdir":/kernel \
        -v "$OUT":/out \
        dockcross/linux-armv7-lts bash -c '
            cd /src
            make KDIR=/kernel ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-
            cp uep31.ko /out/
            arm-linux-gnueabi-strip --strip-debug /out/uep31.ko
        '
    echo "[build] ✅ ${OUT}/uep31.ko"
}

build_dropbear() {
    echo "[build] dropbear"
    bash "${REPO_ROOT}/src/dropbear/build-dropbear.sh"
}

for t in "${TARGETS[@]}"; do
    case "$t" in
        uep)      build_uep ;;
        dropbear) build_dropbear ;;
        *) echo "unknown target: $t (want: uep | dropbear)" >&2; exit 1 ;;
    esac
done

echo ""
echo "[build] done."
ls -la "$OUT"
