#!/bin/sh

# Uso de RAM aproximado (0–100) via /proc/meminfo (BusyBox/OpenWrt).

mem_usage_percent() {
    MemTotal=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    MemAvail=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    if [ -z "$MemAvail" ] || [ "$MemAvail" = "0" ]; then
        MemAvail=$(awk '/^MemFree:/ {print $2}' /proc/meminfo)
    fi
    if [ -z "$MemTotal" ] || [ "$MemTotal" = "0" ]; then
        echo "?"
        return
    fi
    echo $(( (MemTotal - MemAvail) * 100 / MemTotal ))
}

# Log local (falhas Telegram, eventos); não falha se disco cheio.

monitor_log() {
    _msg="$1"
    _d="${LOG_DIR:-/var/log/monitor}"
    mkdir -p "$_d" 2>/dev/null || return 0
    _ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
    echo "$_ts $_msg" >> "$_d/monitor.log" 2>/dev/null || true
}
