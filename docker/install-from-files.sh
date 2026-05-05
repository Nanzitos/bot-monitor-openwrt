#!/bin/sh
# Instala o conteúdo de files/ num root (igual ao Makefile do pacote OpenWrt).
# Uso: install-from-files.sh <dir-files> [destino=/]

set -e
SRC="${1:?uso: install-from-files.sh <path-to-files> [dest-root]}"
ROOT="${2:-/}"

mkdir -p "$ROOT/etc/monitor" "$ROOT/usr/bin" "$ROOT/usr/lib/monitor" \
    "$ROOT/var/log/monitor" "$ROOT/etc/init.d"

cp -a "$SRC/etc/monitor/config.env" "$ROOT/etc/monitor/"
cp -a "$SRC/etc/monitor/mac_allowlist" "$ROOT/etc/monitor/"
cp -a "$SRC/etc/monitor/mac_blocklist" "$ROOT/etc/monitor/"

# cp+chmod (BusyBox/OpenWrt rootfs pode não ter o binário `install`)
cp -a "$SRC/usr/bin/monitor-network" "$ROOT/usr/bin/monitor-network"
ln -sf monitor-network "$ROOT/usr/bin/network-monitor"
cp -a "$SRC/usr/bin/monitor-bot" "$ROOT/usr/bin/monitor-bot"
cp -a "$SRC/usr/bin/monitor-clear-logs" "$ROOT/usr/bin/monitor-clear-logs"
cp -a "$SRC/usr/bin/monitor-apply-mac-acl" "$ROOT/usr/bin/monitor-apply-mac-acl"
chmod 755 "$ROOT/usr/bin/monitor-network" "$ROOT/usr/bin/monitor-bot" "$ROOT/usr/bin/monitor-clear-logs" "$ROOT/usr/bin/monitor-apply-mac-acl"

for f in "$SRC/usr/lib/monitor"/*.sh; do
    [ -f "$f" ] || continue
    cp -a "$f" "$ROOT/usr/lib/monitor/$(basename "$f")"
    chmod 644 "$ROOT/usr/lib/monitor/$(basename "$f")"
done

cp -a "$SRC/etc/init.d/monitor" "$ROOT/etc/init.d/monitor"
chmod 755 "$ROOT/etc/init.d/monitor"
