#!/usr/bin/env bash
# 02-persist-base.sh — Install upstream's boot-time .NET payload.
# After this step: reboot survives, TV answers on TCP 31337 (root channel).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="${SCRIPT_DIR}/upstream/samsung_tizen_tv_root"

TV_IP=""
usage() {
    cat <<EOF
Usage: $0 --tv-ip <ip>

  --tv-ip <ip>    TV IP address (required)

Prerequisites: step 01 complete (in-memory root).
Result: boot-time .NET payload installed. TV survives reboot with
        root channel on TCP 31337.
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

echo "[02] Installing boot payload — TV=${TV_IP}"

# Can we reach the root channel from step 01?
if ! python3 "${UPSTREAM}/tools/root_shell.py" "id" "$TV_IP" >/dev/null 2>&1; then
    echo "ERROR: TV root channel not responding." >&2
    echo "       Run ./01-root-browser.sh first (or re-run if it was lost by reboot)." >&2
    exit 2
fi

if command -v pwsh >/dev/null 2>&1; then
    cd "$UPSTREAM"
    pwsh -File ./root.ps1 -TvIp "$TV_IP" -SkipInitialRoot -InstallPersistence
    echo "[02] ✅ Boot payload installed. Reboot the TV once, then re-check with:"
    echo "        python3 upstream/samsung_tizen_tv_root/tools/root_shell.py \"id\" ${TV_IP}"
else
    echo "ERROR: pwsh not available. See upstream docs/USAGE.md for manual payload install." >&2
    exit 3
fi
