#!/usr/bin/env bash
# 03-uep-setup.sh — Build uep31.ko and install it on the TV so it loads at boot.
# UEP = Tizen 9's in-kernel module-signature verifier at kernel va c02a66e0.
# We patch its entry to `mov r0, #0; bx lr` so unsigned modules load.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="${SCRIPT_DIR}/upstream/samsung_tizen_tv_root"

TV_IP=""
usage() {
    cat <<EOF
Usage: $0 --tv-ip <ip>

  --tv-ip <ip>    TV IP (required)

Prerequisites: step 02 complete (root channel on TCP 31337 reachable).
Result: /opt/jd/uep31.ko installed, autoloads at boot via init.sh.
EOF
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tv-ip) TV_IP="$2"; shift 2 ;;
        -h|--help) usage 0 ;;
        *) usage 1 ;;
    esac
done
[[ -z "$TV_IP" ]] && usage 1

echo "[03] UEP kernel-module build and install — TV=${TV_IP}"

# 1. Build uep31.ko if not already built
if [[ ! -f "${SCRIPT_DIR}/build/output/uep31.ko" ]]; then
    echo "[03] Building uep31.ko via dockcross..."
    bash "${SCRIPT_DIR}/build/build-all.sh" uep
fi

KO="${SCRIPT_DIR}/build/output/uep31.ko"
if [[ ! -f "$KO" ]]; then
    echo "ERROR: build failed — ${KO} not produced." >&2
    exit 4
fi

# 2. Verify we have working root channel
RS="python3 ${UPSTREAM}/tools/root_shell.py"
if ! $RS "id" "$TV_IP" | grep -q 'uid=0'; then
    echo "ERROR: root channel not returning uid=0. Re-run 01/02." >&2
    exit 2
fi

# 3. Upload uep31.ko via root channel
echo "[03] Uploading uep31.ko..."
# Upstream's root channel supports `b64put <path>` for binary upload; wrap it.
B64=$(base64 -w0 < "$KO")
$RS "mkdir -p /opt/jd && echo $B64 | base64 -d > /opt/jd/uep31.ko && chmod 644 /opt/jd/uep31.ko && ls -la /opt/jd/uep31.ko" "$TV_IP"

# 4. Try loading it right now (sanity)
echo "[03] Loading uep31.ko now..."
$RS "insmod /opt/jd/uep31.ko && lsmod | grep uep31 && echo OK_UEP_LOADED" "$TV_IP"

# 5. Install init.sh (if step 04 hasn't already); it'll handle boot-time load
if ! $RS "test -f /opt/jd/init.sh && echo EXISTS" "$TV_IP" | grep -q EXISTS; then
    echo "[03] Installing /opt/jd/init.sh (includes UEP autoload)..."
    INIT_SH_B64=$(base64 -w0 < "${SCRIPT_DIR}/src/mcs-patch/init.sh")
    $RS "echo $INIT_SH_B64 | base64 -d > /opt/jd/init.sh && chmod 755 /opt/jd/init.sh" "$TV_IP"
fi

echo "[03] ✅ UEP module installed and loaded."
echo "    To make it survive reboot, run ./04-mcs-ssh-hijack.sh (that wires MCS to call init.sh)."
