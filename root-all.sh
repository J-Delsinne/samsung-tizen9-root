#!/usr/bin/env bash
# root-all.sh — Convenience wrapper that runs steps 01-05 in order.
# Any step failure stops and tells you which command to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TV_IP=""
SSH_KEY=""
SSH_PORT=2222
usage() {
    cat <<EOF
Usage: $0 --tv-ip <ip> --ssh-key <pub-key-file> [--ssh-port <port>]

Runs 01-root-browser, 02-persist-base, 03-uep-setup, 04-mcs-ssh-hijack, 05-verify
in order. Stops at first failure with an "re-run step N" hint.
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
[[ -z "$TV_IP" || -z "$SSH_KEY" ]] && usage 1

run_step() {
    local n="$1"; shift
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  STEP ${n}"
    echo "════════════════════════════════════════════════════════════════"
    if ! bash "${SCRIPT_DIR}/$@"; then
        echo ""
        echo "✗ Step ${n} FAILED."
        echo "  Fix the issue reported above, then re-run:"
        echo "    bash $*"
        exit 1
    fi
}

run_step 1 01-root-browser.sh      --tv-ip "$TV_IP"
run_step 2 02-persist-base.sh      --tv-ip "$TV_IP"

echo ""
echo "⚠️  Power-cycle the TV now so the boot payload takes effect."
read -r -p "Press Enter when the TV has booted back up (or Ctrl+C to pause)."

run_step 3 03-uep-setup.sh         --tv-ip "$TV_IP"
run_step 4 04-mcs-ssh-hijack.sh    --tv-ip "$TV_IP" --ssh-key "$SSH_KEY" --ssh-port "$SSH_PORT"

echo ""
echo "⚠️  Power-cycle the TV one more time so MCS hijack takes effect."
read -r -p "Press Enter when the TV has booted back up: "

# Resolve the matching private key for verification.
PRIV_KEY="${SSH_KEY%.pub}"
[[ -f "$PRIV_KEY" ]] && SSH_VERIFY_ARG=(--ssh-key "$PRIV_KEY") || SSH_VERIFY_ARG=()

run_step 5 05-verify.sh --tv-ip "$TV_IP" --ssh-port "$SSH_PORT" "${SSH_VERIFY_ARG[@]}"

echo ""
echo "✅ All steps complete. You can SSH as root:"
echo "    ssh -i ${PRIV_KEY} -p ${SSH_PORT} root@${TV_IP}"
