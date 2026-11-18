#!/usr/bin/env bash
# 04-mcs-ssh-hijack.sh — Patch MultiControlService.dll to run /opt/jd/init.sh
# on every boot. init.sh brings up UEP, tmpfs /root, authorized_keys, dropbear
# SSH on :2222, and the health monitor.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="${SCRIPT_DIR}/upstream/samsung_tizen_tv_root"

TV_IP=""
SSH_KEY=""
SSH_PORT=2222

usage() {
    cat <<EOF
Usage: $0 --tv-ip <ip> --ssh-key <public-key-file> [--ssh-port <port>]

  --tv-ip <ip>              TV IP (required)
  --ssh-key <path>          Path to the PUBLIC key to install (required)
                            e.g. ~/.ssh/id_ed25519.pub
  --ssh-port <port>         Dropbear listen port on the TV (default: 2222)

Prerequisites: step 03 complete (uep31.ko uploaded).
Result: MCS DLL hijacked. After reboot, TV runs init.sh → loads UEP,
        mounts tmpfs /root with authorized_keys, starts dropbear on
        TCP <ssh-port>. You can SSH as root with your key.
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
[[ ! -f "$SSH_KEY" ]] && { echo "ERROR: SSH key file not found: $SSH_KEY" >&2; exit 1; }

echo "[04] MCS DLL hijack + dropbear SSH install — TV=${TV_IP}  port=${SSH_PORT}"

# 1. Build dropbear if not already built
if [[ ! -f "${SCRIPT_DIR}/build/output/dropbear" ]]; then
    echo "[04] Building dropbear via dockcross..."
    bash "${SCRIPT_DIR}/build/build-all.sh" dropbear
fi
DROPBEAR="${SCRIPT_DIR}/build/output/dropbear"
[[ ! -f "$DROPBEAR" ]] && { echo "ERROR: dropbear build failed." >&2; exit 4; }

RS="python3 ${UPSTREAM}/tools/root_shell.py"
if ! $RS "id" "$TV_IP" | grep -q 'uid=0'; then
    echo "ERROR: root channel not responding. Re-run 01/02." >&2
    exit 2
fi

# 2. Download MCS DLL from TV so we can patch it
MCS_PATH="/opt/usr/apps/com.samsung.tv.MultiControl-Service/bin/MultiControlService.dll"
LOCAL_MCS="${SCRIPT_DIR}/build/output/MultiControlService.dll"
LOCAL_MCS_BAK="${SCRIPT_DIR}/build/output/MultiControlService.dll.bak"

echo "[04] Fetching ${MCS_PATH}..."
$RS "base64 -w0 ${MCS_PATH}" "$TV_IP" > "${LOCAL_MCS}.b64"
base64 -d < "${LOCAL_MCS}.b64" > "$LOCAL_MCS"
rm "${LOCAL_MCS}.b64"
cp "$LOCAL_MCS" "$LOCAL_MCS_BAK"

# 3. Apply the string hijack patch
echo "[04] Applying 138-byte patch at offset 0x83ed..."
python3 "${SCRIPT_DIR}/src/mcs-patch/patch.py" \
    --input "$LOCAL_MCS_BAK" \
    --output "$LOCAL_MCS" \
    --target "/opt/jd/init.sh"

# 4. Prepare init.sh with the right SSH port and authorized_keys
AK_CONTENTS=$(cat "$SSH_KEY")
TMP_INIT=$(mktemp)
sed \
    -e "s|@@SSH_PORT@@|${SSH_PORT}|g" \
    -e "s|@@AUTHORIZED_KEY@@|${AK_CONTENTS}|g" \
    "${SCRIPT_DIR}/src/mcs-patch/init.sh" > "$TMP_INIT"
chmod 755 "$TMP_INIT"

# 5. Backup original MCS on TV (if not already), upload patched version
echo "[04] Backing up original MCS DLL on TV..."
$RS "mkdir -p /opt/jd/backup && [ -f /opt/jd/backup/MultiControlService.dll.orig ] || cp ${MCS_PATH} /opt/jd/backup/MultiControlService.dll.orig" "$TV_IP"

echo "[04] Uploading patched MCS DLL..."
PATCHED_B64=$(base64 -w0 < "$LOCAL_MCS")
$RS "echo $PATCHED_B64 | base64 -d > ${MCS_PATH} && ls -la ${MCS_PATH}" "$TV_IP"

# 6. Upload the templated init.sh and dropbear binary
echo "[04] Uploading init.sh (SSH port ${SSH_PORT}, key installed)..."
INIT_B64=$(base64 -w0 < "$TMP_INIT")
$RS "echo $INIT_B64 | base64 -d > /opt/jd/init.sh && chmod 755 /opt/jd/init.sh" "$TV_IP"
rm "$TMP_INIT"

echo "[04] Uploading dropbear binary..."
DB_B64=$(base64 -w0 < "$DROPBEAR")
$RS "mkdir -p /opt/ssh && echo $DB_B64 | base64 -d > /opt/ssh/dropbear && chmod 755 /opt/ssh/dropbear" "$TV_IP"

echo "[04] ✅ MCS hijack installed, init.sh + dropbear deployed."
echo "    Reboot the TV once; then test with:"
echo "        ssh -i <your-private-key> -p ${SSH_PORT} root@${TV_IP}"
echo ""
echo "    ./05-verify.sh will do that check automatically after reboot."
