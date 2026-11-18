#!/bin/sh
# monitor.sh — TV health monitor, snapshot once per call.
# Called from init.sh's monitor daemon loop (sleep 300 between calls).
# Keeps 7 days of snapshots in /opt/jd/monitor/, plus a compact trend log.
set -u

MON_DIR=/opt/jd/monitor
mkdir -p "$MON_DIR"

TS=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown)
UNIX_TS=$(date +%s 2>/dev/null || echo 0)
SNAPSHOT="$MON_DIR/snap-$TS.txt"

# Rotate: delete older than 7 days
find "$MON_DIR" -name "snap-*.txt" -mtime +7 -delete 2>/dev/null

{
    echo "=== TV HEALTH SNAPSHOT ==="
    echo "timestamp: $TS"
    echo "unix_ts: $UNIX_TS"
    echo "uptime: $(uptime 2>/dev/null)"
    echo ""
    echo "=== LOAD / MEM ==="
    cat /proc/loadavg
    free 2>/dev/null | head -4
    grep -E "^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapFree):" /proc/meminfo
    echo ""
    echo "=== TOP 10 BY RSS ==="
    ps -eo pid,user,rss,comm --sort=-rss 2>/dev/null | head -11
    echo ""
    echo "=== LISTEN PORTS ==="
    netstat -tln 2>/dev/null | awk 'NR>2 {print $4}' | sort -u
    echo ""
    echo "=== DISK ==="
    df -h / /opt /tmp 2>/dev/null
    echo ""
    echo "=== OUR SERVICES ==="
    echo "dropbear pids: $(pidof dropbear 2>/dev/null || echo NONE)"
    echo "uep31 loaded:  $(lsmod 2>/dev/null | grep -c uep31)"
    echo ""
    echo "=== DMESG (latest 10 warn/err) ==="
    dmesg 2>/dev/null | grep -iE 'error|fail|panic|warn' | tail -10
} > "$SNAPSHOT" 2>&1

# Compact one-line trend entry
LOAD1=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo ?)
MEM_FREE_MB=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo ?)
PROCS=$(ps -A --no-headers 2>/dev/null | wc -l)
FDS=$(ls /proc/[0-9]*/fd 2>/dev/null | wc -l)
UP=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo ?)

echo "$UNIX_TS up=$UP load=$LOAD1 memfree=${MEM_FREE_MB}MB procs=$PROCS fds=$FDS" \
    >> "$MON_DIR/trend.log"
