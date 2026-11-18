#!/usr/bin/env bash
# 01-root-browser.sh — Initial (in-memory) root via CVE-2024-2887 browser chain.
# Thin wrapper around upstream's root.ps1; falls back to printing manual
# instructions if PowerShell 7+ (pwsh) isn't available.
#
# Result on success: uid=0 on the TV, in-memory only. Does NOT survive reboot.
# Run 02-persist-base.sh next.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="${SCRIPT_DIR}/upstream/samsung_tizen_tv_root"

TV_IP=""
usage() {
    cat <<EOF
Usage: $0 --tv-ip <ip>

  --tv-ip <ip>    TV IP address on your LAN (required)
  -h, --help      Show this help

Prerequisites:
  - TV reachable (ping first)
  - TV's built-in browser accessible via TV remote
  - PowerShell 7+ (pwsh) OR a willingness to run the manual fallback

Result: in-memory root. NOT persistent. Run 02-persist-base.sh next.
EOF
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tv-ip) TV_IP="$2"; shift 2 ;;
        -h|--help) usage 0 ;;
        *) echo "Unknown arg: $1" >&2; usage 1 ;;
    esac
done
[[ -z "$TV_IP" ]] && { echo "ERROR: --tv-ip is required" >&2; usage 1; }

echo "[01] Initial root via CVE-2024-2887 — TV=${TV_IP}"

# Sanity: can we reach the TV?
if ! ping -c 1 -W 2 "$TV_IP" >/dev/null 2>&1; then
    echo "ERROR: cannot ping ${TV_IP}. Is the TV on and on the same network?" >&2
    exit 2
fi

# Sanity: upstream present?
if [[ ! -d "$UPSTREAM" ]]; then
    echo "ERROR: upstream/ is empty." >&2
    echo "       Run: ./build/init-upstream.sh    to vendor the chain." >&2
    exit 3
fi

# Does pwsh exist?
if command -v pwsh >/dev/null 2>&1; then
    echo "[01] Found pwsh → running upstream root.ps1"
    cd "$UPSTREAM"
    pwsh -File ./root.ps1 -TvIp "$TV_IP" -SkipPersistence
    echo "[01] ✅ Initial root done."
    exit 0
fi

# Fallback — manual instructions
cat <<EOF

[01] ⚠️  PowerShell 7+ (pwsh) not installed. Manual steps:

  1. Install pwsh from https://aka.ms/powershell (works on Linux/macOS/Windows).
     OR run the upstream chain's Python port if one exists.

  2. Alternatively run the manual browser payload server from upstream:
       cd upstream/samsung_tizen_tv_root
       python3 server/serve.py --listen 0.0.0.0:80
     then on the TV browser, open: http://<your-pc-ip>/index.html
     and wait for "RUNNING".

  3. When done, press Enter here.

See upstream/samsung_tizen_tv_root/docs/USAGE.md for the full manual procedure.

EOF
read -r -p "Press Enter when the TV browser shows RUNNING (or Ctrl+C to abort): "
echo "[01] ⚠️  Assuming initial root succeeded. Run ./05-verify.sh to confirm before step 02."
