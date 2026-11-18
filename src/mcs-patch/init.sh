#!/bin/sh
# /opt/jd/init.sh — Boot-time init invoked by the patched MCS DLL.
# Loads UEP bypass, installs authorized_keys on a tmpfs /root, starts dropbear,
# and spawns the health monitor.
#
# Placeholders replaced by 04-mcs-ssh-hijack.sh:
#   @@SSH_PORT@@         Port dropbear listens on (default 2222)
#   @@AUTHORIZED_KEY@@   Single-line OpenSSH public key for root
#
# This file is deployed to /opt/jd/init.sh on the TV. The patched MCS DLL
# invokes it at every boot as uid=0 (root).

set -u

LOG=/tmp/jd-init.log
: > "$LOG"
echo "=== JD boot init at $(date 2>/dev/null || echo unknown-date) ===" >> "$LOG"

# 1. Load UEP bypass kernel module
if ! lsmod 2>/dev/null | grep -q uep31; then
    if [ -f /opt/jd/uep31.ko ]; then
        insmod /opt/jd/uep31.ko 2>>"$LOG"
        if [ $? -eq 0 ]; then
            echo "uep31 LOADED" >> "$LOG"
        else
            echo "uep31 INSMOD FAILED (bypass offset wrong?)" >> "$LOG"
        fi
    else
        echo "uep31.ko MISSING at /opt/jd/uep31.ko" >> "$LOG"
    fi
else
    echo "uep31 already loaded" >> "$LOG"
fi

# 2. tmpfs /root with authorized_keys (so SSH key auth works)
if ! mountpoint -q /root 2>/dev/null; then
    mount -t tmpfs tmpfs /root 2>>"$LOG"
    echo "tmpfs mounted on /root" >> "$LOG"
fi
chmod 755 /root 2>/dev/null
mkdir -p /root/.ssh 2>/dev/null
cat > /root/.ssh/authorized_keys <<'EOF_KEY'
@@AUTHORIZED_KEY@@
EOF_KEY
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
# Avoid the Tizen stock login banner for interactive SSH:
touch /root/.hushlogin

# 3. Start dropbear SSH on configured port
if ! pgrep -x dropbear > /dev/null 2>&1; then
    if [ -x /opt/ssh/dropbear ]; then
        mkdir -p /opt/ssh/keys
        # Generate host keys on first boot if missing
        [ -f /opt/ssh/keys/rsa_host_key ] || \
            /opt/ssh/dropbear -A -r /opt/ssh/keys/rsa_host_key 2>>"$LOG" || true
        [ -f /opt/ssh/keys/ecdsa_host_key ] || \
            /opt/ssh/dropbear -A -r /opt/ssh/keys/ecdsa_host_key 2>>"$LOG" || true
        [ -f /opt/ssh/keys/ed25519_host_key ] || \
            /opt/ssh/dropbear -A -r /opt/ssh/keys/ed25519_host_key 2>>"$LOG" || true

        nohup /opt/ssh/dropbear \
            -r /opt/ssh/keys/rsa_host_key \
            -r /opt/ssh/keys/ecdsa_host_key \
            -r /opt/ssh/keys/ed25519_host_key \
            -p @@SSH_PORT@@ -P /tmp/dropbear.pid -E \
            > /tmp/dropbear.log 2>&1 < /dev/null &
        disown 2>/dev/null || true
        sleep 1
        pgrep -x dropbear > /dev/null && echo "dropbear STARTED on :@@SSH_PORT@@" >> "$LOG" \
                                     || echo "dropbear FAILED to start" >> "$LOG"
    else
        echo "dropbear MISSING at /opt/ssh/dropbear" >> "$LOG"
    fi
else
    echo "dropbear already running" >> "$LOG"
fi

# 4. Health monitor (runs forever, logs every 5 min to /opt/jd/monitor/)
if [ -x /opt/jd/monitor.sh ] && ! pgrep -f "jd-monitor-daemon" > /dev/null 2>&1; then
    nohup sh -c '
        exec -a jd-monitor-daemon sh -c "
            while true; do
                . /opt/jd/monitor.sh
                sleep 300
            done
        "
    ' > /tmp/jd-monitor.log 2>&1 < /dev/null &
    disown 2>/dev/null || true
    echo "monitor daemon STARTED" >> "$LOG"
fi

echo "=== JD init complete ===" >> "$LOG"

# Return 0 so MCS continues its own startup.
exit 0
