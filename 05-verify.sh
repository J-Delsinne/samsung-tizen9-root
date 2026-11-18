#!/usr/bin/env bash
# 05-verify.sh — Health check all install steps.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="${SCRIPT_DIR}/upstream/samsung_tizen_tv_root"

TV_IP=""
SSH_KEY=""
SSH_PORT=2222

usage() {
    cat <<EOF
Usage: $0 --tv-ip <ip> [--ssh-key <private-key>] [--ssh-port <port>]

Runs 5 checks and reports PASS/FAIL per step:
  1. Root channel on TCP 31337
  2. Boot payload installed (/opt/jd/payload.dll present)
  3. uep31.ko loaded (lsmod)
  4. Dropbear listening on configured port
  5. SSH key auth works (requires --ssh-key = PRIVATE key)
EOF
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tv-ip) TV_IP="$2"; shift 2 ;;
        --ssh-key) SSH_KEY="$2"; shift 2 ;;
        --ssh-port) SSH_PORT="$2"; shift 2 ;;
        -h|--help) usage 0 ;;
        *) usage 1 ;;
    esac
done
[[ -z "$TV_IP" ]] && usage 1

PASS=0; FAIL=0
check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✅  ${name}"
        PASS=$((PASS+1))
    else
        echo "  ❌  ${name}"
        FAIL=$((FAIL+1))
    fi
}

RS="python3 ${UPSTREAM}/tools/root_shell.py"

echo "[05] Health check — TV=${TV_IP}"
echo ""
echo "  Step 1-2 (root channel + boot payload):"
check "TV pingable"                 ping -c 1 -W 2 "$TV_IP"
check "root channel responds"       bash -c "$RS 'echo ALIVE' $TV_IP | grep -q ALIVE"
check "uid=0 on root channel"       bash -c "$RS 'id' $TV_IP | grep -q 'uid=0'"
check "boot payload present"        bash -c "$RS 'ls /opt/usr/apps/*/bin/payload*.dll 2>/dev/null' $TV_IP | grep -q payload"

echo ""
echo "  Step 3 (UEP):"
check "uep31.ko loaded"             bash -c "$RS 'lsmod' $TV_IP | grep -q uep31"
check "uep31.ko file persisted"     bash -c "$RS 'ls /opt/jd/uep31.ko' $TV_IP | grep -q uep31.ko"

echo ""
echo "  Step 4 (SSH):"
check "init.sh installed"           bash -c "$RS 'ls /opt/jd/init.sh' $TV_IP | grep -q init.sh"
check "MCS DLL backup exists"       bash -c "$RS 'ls /opt/jd/backup/MultiControlService.dll.orig' $TV_IP | grep -q orig"
check "dropbear binary installed"   bash -c "$RS 'ls /opt/ssh/dropbear' $TV_IP | grep -q dropbear"
check "dropbear process running"    bash -c "$RS 'pidof dropbear' $TV_IP | grep -qE '[0-9]+'"
check "port ${SSH_PORT} listening"  bash -c "$RS \"netstat -tln | grep ':${SSH_PORT}'\" $TV_IP | grep -q LISTEN"

if [[ -n "$SSH_KEY" ]]; then
    echo ""
    echo "  Step 5 (end-to-end SSH):"
    check "SSH key auth succeeds"   ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
                                        -o BatchMode=yes -i "$SSH_KEY" -p "$SSH_PORT" \
                                        "root@${TV_IP}" "id"
fi

echo ""
echo "  Summary: ${PASS} pass, ${FAIL} fail"
if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "  See docs/TROUBLESHOOTING.md for recovery steps."
    exit 1
fi
echo "  🎉  All checks passed. Enjoy your rooted TV."
