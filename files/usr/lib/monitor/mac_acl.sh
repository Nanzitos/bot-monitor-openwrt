#!/bin/sh
# Regras nftables (família bridge) para blocklist e opcionalmente só permitir MAC da allowlist.
# OpenWrt com nft + bridge (fw4). Se nft falhar, regista em monitor.log e sai sem erro.

. /usr/lib/monitor/configs.sh || exit 1
. /usr/lib/monitor/utils.sh

monitor_mac_normalize() {
    echo "$1" | tr 'A-Z' 'a-z'
}

# Remove uma linha (MAC) de um ficheiro texto (match exact, sem distinguir maiúsculas).
monitor_mac_file_remove_line() {
    _file="$1"
    _mac="$2"
    [ -f "$_file" ] || return 0
    grep -vxFi "$_mac" "$_file" > "${_file}.new" 2>/dev/null && mv "${_file}.new" "$_file"
}

monitor_apply_mac_acl() {
    LAN_BRIDGE="${LAN_BRIDGE:-br-lan}"
    MAC_ENFORCE="${MAC_ENFORCE:-0}"
    BLOCKLIST="${BLOCKLIST:-/etc/monitor/mac_blocklist}"
    ALLOWLIST="${ALLOWLIST:-/etc/monitor/mac_allowlist}"

    [ -f "$BLOCKLIST" ] || touch "$BLOCKLIST"
    [ -f "$ALLOWLIST" ] || touch "$ALLOWLIST"

    command -v nft >/dev/null 2>&1 || {
        monitor_log "mac_acl: nft indisponivel — instale nftables"
        return 0
    }

    nft delete table bridge monitor_acl 2>/dev/null || true

    if ! nft add table bridge monitor_acl 2>/dev/null; then
        monitor_log "mac_acl: nao foi possivel criar table bridge monitor_acl (kernel/modulos?)"
        return 0
    fi

    if ! nft add chain bridge monitor_acl forward '{ type filter hook forward priority -150; policy accept; }' 2>/dev/null; then
        monitor_log "mac_acl: hook forward bridge falhou"
        nft delete table bridge monitor_acl 2>/dev/null || true
        return 0
    fi

    # 1) Blocklist explícita (DROP)
    while read -r _line; do
        [ -z "$_line" ] && continue
        echo "$_line" | grep -q '^#' && continue
        _m=$(monitor_mac_normalize "$_line")
        echo "$_m" | grep -qE '^([0-9a-f]{2}:){5}[0-9a-f]{2}$' || continue
        nft add rule bridge monitor_acl forward iifname "$LAN_BRIDGE" ether saddr "$_m" drop 2>/dev/null || \
            monitor_log "mac_acl: regra drop falhou para $_m"
    done < "$BLOCKLIST"

    # 2) Só MAC na allowlist (opcional)
    if [ "$MAC_ENFORCE" = "1" ]; then
        if [ ! -s "$ALLOWLIST" ]; then
            monitor_log "mac_acl: MAC_ENFORCE=1 mas allowlist vazia — enforce ignorado"
        else
            if ! nft add set bridge monitor_acl allow_m '{ type ether_addr; flags interval; }' 2>/dev/null; then
                monitor_log "mac_acl: criacao set allow_m falhou"
            else
                while read -r _line; do
                    [ -z "$_line" ] && continue
                    echo "$_line" | grep -q '^#' && continue
                    _m=$(monitor_mac_normalize "$_line")
                    echo "$_m" | grep -qE '^([0-9a-f]{2}:){5}[0-9a-f]{2}$' || continue
                    nft add element bridge monitor_acl allow_m "{ $_m }" 2>/dev/null || true
                done < "$ALLOWLIST"

                nft add rule bridge monitor_acl forward iifname "$LAN_BRIDGE" ether saddr @allow_m accept 2>/dev/null || true
                nft add rule bridge monitor_acl forward iifname "$LAN_BRIDGE" drop 2>/dev/null || true
            fi
        fi
    fi

    monitor_log "mac_acl: regras aplicadas (bridge $LAN_BRIDGE enforce=$MAC_ENFORCE)"
    return 0
}
