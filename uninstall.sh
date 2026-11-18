#!/usr/bin/env bash
# uninstall.sh — Restore all modified files from backups on the TV.
# After this: TV is back to stock, dropbear gone, UEP unloaded, MCS restored.
# A factory reset is NOT performed; your settings stay.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="${SCRIPT_DIR}/upstream/samsung_tizen_tv_root"

TV_IP=""
usage() {
    cat <<EOF
Usage: $0 --tv-ip <ip> [--keep-ssh-keys]

  --tv-ip <ip>          TV IP (required)
  --keep-ssh-keys       Leave authorized_keys and dropbear binary in place,
                        only restore MCS DLL. (default: wipe everything)

Restores:
  - /opt/usr/apps/com.samsung.tv.MultiControl-Service/bin/MultiControlService.dll
    from /opt/jd/backup/MultiControlService.dll.orig
  - Unloads uep31.ko
  - Kills dropbear
  - Removes /opt/jd/ and /opt/ssh/ (unless --keep-ssh-keys)

Does NOT:
  - Factory reset the TV
  - Remove upstream's boot payload (use upstream/samsung_tizen_tv_root/uninstall.ps1)
EOF
    exit "${1:-0}"
}

KEEP_KEYS=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tv-ip) TV_IP="$2"; shift 2 ;;
        --keep-ssh-keys) KEEP_KEYS=1; shift ;;
        -h|--help) usage 0 ;;
        *) usage 1 ;;
    esac
done
[[ -z "$TV_IP" ]] && usage 1

echo "[uninstall] Restoring TV to pre-install state — TV=${TV_IP}"

RS="python3 ${UPSTREAM}/tools/root_shell.py"

# If we can SSH in, prefer that over the root channel (it's cleaner)
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes \
       -p 2222 "root@${TV_IP}" "echo UP" 2>/dev/null | grep -q UP; then
    RUN() { ssh -o StrictHostKeyChecking=no -p 2222 "root@${TV_IP}" "$*"; }
    echo "[uninstall] Using SSH (dropbear) as control channel."
else
    RUN() { $RS "$*" "$TV_IP"; }
    echo "[uninstall] Using upstream root channel (TCP 31337)."
fi

MCS_PATH="/opt/usr/apps/com.samsung.tv.MultiControl-Service/bin/MultiControlService.dll"

# Restore MCS from backup
RUN "if [ -f /opt/jd/backup/MultiControlService.dll.orig ]; then \
         cp /opt/jd/backup/MultiControlService.dll.orig ${MCS_PATH} && \
         echo RESTORED_MCS; \
     else echo NO_BACKUP; fi"

# Unload UEP
RUN "lsmod | grep -q uep31 && rmmod uep31 && echo UNLOADED_UEP || echo UEP_NOT_LOADED"

# Kill dropbear
RUN "pidof dropbear | xargs -r kill && echo KILLED_DROPBEAR || echo NO_DROPBEAR"

# Wipe install directories
if [[ "$KEEP_KEYS" -eq 0 ]]; then
    RUN "rm -rf /opt/jd /opt/ssh && echo WIPED_INSTALL_DIRS"
else
    RUN "rm -f /opt/jd/init.sh /opt/jd/uep31.ko && echo REMOVED_INIT_AND_UEP_KEPT_KEYS"
fi

echo ""
echo "[uninstall] ✅ Our additions removed."
echo ""
echo "  To also remove upstream's boot payload (step 02) and go fully stock:"
echo "    cd upstream/samsung_tizen_tv_root && pwsh -File ./uninstall.ps1 -TvIp ${TV_IP}"
echo ""
echo "  Then power-cycle the TV once."
