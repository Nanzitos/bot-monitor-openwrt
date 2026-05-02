#!/bin/sh
# Funções de monitorização partilhadas (ash / OpenWrt).
# Requer: configs.sh, utils.sh, telegram.sh antes de source.

# Limiares (sobrescrever em config.env se existir)
DDOS_MAX_PER_IP="${DDOS_MAX_PER_IP:-200}"
PORT_SPIKE_MIN="${PORT_SPIKE_MIN:-15}"

############################
# Cache de log (um ciclo)
############################

checks_refresh_log_cache() {
    LOG_CACHE="$(logread)"
    CURRENT_MIN="$(date '+%b %d %H:%M')"
    CURRENT_HOUR="$(date '+%b %d %H')"
}

############################
# Caminhos de estado
############################

checks_ensure_state() {
    mkdir -p "$STATE_DIR" "$LOG_DIR" 2>/dev/null || true
    WAN_STATE="$STATE_DIR/wan_state"
    FAILOVER_STATE="$STATE_DIR/failover_state"
    IP_STATE_WAN="$STATE_DIR/public_ip_wan"
    IP_STATE_WAN2="$STATE_DIR/public_ip_wan2"
    SSH_STATE="$STATE_DIR/ssh_alert"
    DAILY_STATE="$STATE_DIR/daily_sent"
    SCAN_STATE="$STATE_DIR/scan_alert"
    WIFI_CACHE="$STATE_DIR/wifi_stations.cache"
    DDOS_STATE="$STATE_DIR/ddos_alert"
    PORTSPIKE_STATE="$STATE_DIR/port_spike_alert"
}

############################
# Telegram (HTML)
############################

checks_log_event() {
    LEVEL="$1"
    MESSAGE="$2"
    FINAL_MESSAGE="📡 <b>MONITOR</b> | <b>$LEVEL</b>

$MESSAGE"
    send_message_html "$FINAL_MESSAGE" || monitor_log "telegram: log_event falhou ($LEVEL)"
}

############################
# WiFi: cache por ciclo
############################

checks_build_wifi_cache() {
    _tmp="${WIFI_CACHE}.tmp"
    : > "$_tmp"
    for iface in $(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}'); do
        SSID_JSON=$(ubus call "hostapd.$iface" get_status 2>/dev/null)
        WIFI_SSID=$(echo "$SSID_JSON" | jsonfilter -e '@.ssid' 2>/dev/null)
        [ -z "$WIFI_SSID" ] && WIFI_SSID="unknown"
        iw dev "$iface" station dump 2>/dev/null | awk -v ifc="$iface" -v ssid="$WIFI_SSID" \
            '$1=="Station"{print tolower($2)"|"ifc"|"ssid}' >> "$_tmp"
    done
    mv "$_tmp" "$WIFI_CACHE" 2>/dev/null || rm -f "$_tmp"
}

############################
# ubus: device L3 da interface
############################

checks_iface_dev() {
    _iface="$1"
    _d=$(ubus call "network.interface.${_iface}" status 2>/dev/null | jsonfilter -e '@.l3_device' 2>/dev/null)
    [ -n "$_d" ] && echo "$_d" && return 0
    ubus call "network.interface.${_iface}" status 2>/dev/null | jsonfilter -e '@.device' 2>/dev/null
}

############################
# WAN STATUS
############################

check_wan() {
    WAN1=$(ubus call network.interface.wan status 2>/dev/null | jsonfilter -e '@.up')
    WAN2=$(ubus call network.interface.wan2 status 2>/dev/null | jsonfilter -e '@.up')

    WAN1=${WAN1:-false}
    WAN2=${WAN2:-false}

    [ -f "$WAN_STATE" ] || echo "WAN1_OLD=unknown WAN2_OLD=unknown" > "$WAN_STATE"
    . "$WAN_STATE"

    CURRENT_WAN1=$([ "$WAN1" = "true" ] && echo "online" || echo "offline")
    CURRENT_WAN2=$([ "$WAN2" = "true" ] && echo "online" || echo "offline")

    [ "$CURRENT_WAN1" != "$WAN1_OLD" ] && checks_log_event "INFO" "WAN1 $CURRENT_WAN1"
    [ "$CURRENT_WAN2" != "$WAN2_OLD" ] && checks_log_event "INFO" "WAN2 $CURRENT_WAN2"

    echo "WAN1_OLD=$CURRENT_WAN1 WAN2_OLD=$CURRENT_WAN2" > "$WAN_STATE"
}

############################
# FAILOVER
############################

check_failover() {
    ROUTE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5}')

    if [ "$ROUTE" = "wan2" ]; then
        [ ! -f "$FAILOVER_STATE" ] && \
        checks_log_event "WARNING" "Failover ativo (WAN2 em uso)." && \
        touch "$FAILOVER_STATE"
    else
        [ -f "$FAILOVER_STATE" ] && \
        checks_log_event "INFO" "WAN primária restaurada." && \
        rm -f "$FAILOVER_STATE"
    fi
}

############################
# IP público por WAN (ipify via interface)
############################

check_public_ip_one() {
    _uiface="$1"
    _statefile="$2"
    _label="$3"

    _up=$(ubus call "network.interface.${_uiface}" status 2>/dev/null | jsonfilter -e '@.up')
    [ "$_up" != "true" ] && return 0

    _dev=$(checks_iface_dev "$_uiface")
    [ -z "$_dev" ] && return 0

    CURRENT_IP=$(curl -sS --connect-timeout 8 --max-time 15 --interface "$_dev" "https://api.ipify.org" 2>/dev/null) || return 0
    [ -z "$CURRENT_IP" ] && return 0
    echo "$CURRENT_IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || return 0

    if [ ! -f "$_statefile" ]; then
        echo "$CURRENT_IP" > "$_statefile"
    else
        OLD_IP=$(cat "$_statefile")
        if [ "$CURRENT_IP" != "$OLD_IP" ]; then
            checks_log_event "WARNING" "IP público ($_label) alterado

Antigo: $OLD_IP
Novo: $CURRENT_IP"
            echo "$CURRENT_IP" > "$_statefile"
        fi
    fi
}

check_public_ip_all_wans() {
    check_public_ip_one wan "$IP_STATE_WAN" "WAN"
    check_public_ip_one wan2 "$IP_STATE_WAN2" "WAN2"
}

############################
# SSH BRUTE FORCE (TEMPORAL)
############################

check_ssh() {
    COUNT=$(echo "$LOG_CACHE" | \
        grep "$CURRENT_HOUR" | \
        grep "Failed password" | wc -l)

    if [ "$COUNT" -gt 10 ]; then
        [ ! -f "$SSH_STATE" ] && \
        checks_log_event "CRITICAL" "$COUNT tentativas SSH na última hora." && \
        touch "$SSH_STATE"
    else
        rm -f "$SSH_STATE"
    fi
}

############################
# NAC / allowlist
############################

check_mac() {
    [ -f "$ALLOWLIST" ] || touch "$ALLOWLIST"

    checks_build_wifi_cache

    ip neigh show | while read -r IP _ DEV _ MAC STATE _; do
        echo "$IP" | grep -qE '^[0-9]+\.' || continue
        echo "$MAC" | grep -q ":" || continue
        [ "$STATE" = "FAILED" ] && continue

        MAC=$(echo "$MAC" | tr 'A-Z' 'a-z')

        VLAN_NAME="UNKNOWN"
        case "$DEV" in
            br-lan.30) VLAN_NAME="USERS" ;;
            br-lan.40) VLAN_NAME="IOT" ;;
            br-lan.50) VLAN_NAME="GUEST" ;;
            br-lan.20) VLAN_NAME="LAB" ;;
            br-lan.1)  VLAN_NAME="LAN" ;;
        esac

        HOSTNAME=$(awk -v mac="$MAC" 'tolower($2)==mac {print $4}' /tmp/dhcp.leases 2>/dev/null)
        [ -z "$HOSTNAME" ] && HOSTNAME="desconhecido"

        CONNECTION_TYPE="Cabo"
        WIFI_SSID="N/A"
        _wline=$(grep -F "${MAC}|" "$WIFI_CACHE" 2>/dev/null | head -n1)
        if [ -n "$_wline" ]; then
            CONNECTION_TYPE="WiFi"
            WIFI_SSID=$(echo "$_wline" | cut -d'|' -f3)
            [ -z "$WIFI_SSID" ] && WIFI_SSID="SSID_desconhecido"
        fi

        if ! grep -iq "^$MAC$" "$ALLOWLIST"; then
            checks_log_event "CRITICAL" "Novo dispositivo detectado

IP: $IP
MAC: $MAC
Hostname: $HOSTNAME
VLAN: $VLAN_NAME
Conexao: $CONNECTION_TYPE
WiFi Rede: $WIFI_SSID
Estado ARP: $STATE"
        fi
    done
}

############################
# INTERNAL SCAN (TEMPORAL)
############################

check_internal_scan() {
    COUNT=$(echo "$LOG_CACHE" | \
        grep "$CURRENT_MIN" | \
        grep "MONITOR_DROP" | wc -l)

    if [ "$COUNT" -gt 20 ]; then
        if [ ! -f "$SCAN_STATE" ]; then
            ATTACKER=$(echo "$LOG_CACHE" | \
                grep "$CURRENT_MIN" | \
                grep "MONITOR_DROP" | \
                awk '{for(i=1;i<=NF;i++) if($i ~ /SRC=/){split($i,a,"="); print a[2]}}' | \
                sort | uniq -c | sort -nr | head -n1)

            checks_log_event "CRITICAL" "Possível scan interno detectado.

Eventos no último minuto: $COUNT
Principal origem: $ATTACKER"

            touch "$SCAN_STATE"
        fi
    else
        rm -f "$SCAN_STATE"
    fi
}

############################
# Heurística DDoS: muitas entradas nf_conntrack por IP de origem
############################

check_ddos_light() {
    [ -r /proc/net/nf_conntrack ] || return 0

    TOP=$(awk '
    BEGIN { max = 0 }
    {
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^src=/) {
                split($i, a, "=")
                if (a[2] ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                    c[a[2]]++
                    if (c[a[2]] > max) { max = c[a[2]]; top = a[2] }
                }
            }
        }
    }
    END { if (max > 0) print max " " top }
    ' /proc/net/nf_conntrack 2>/dev/null)

    [ -z "$TOP" ] && return 0
    MAX_CNT=$(echo "$TOP" | awk '{print $1}')
    TOP_IP=$(echo "$TOP" | awk '{print $2}')

    if [ "$MAX_CNT" -gt "$DDOS_MAX_PER_IP" ] 2>/dev/null; then
        if [ ! -f "$DDOS_STATE" ]; then
            checks_log_event "WARNING" "Possível saturação de conexões (conntrack).

IP com mais entradas: $TOP_IP (~$MAX_CNT). Limiar: $DDOS_MAX_PER_IP.

Se for falso positivo, aumente DDOS_MAX_PER_IP em config.env."
            touch "$DDOS_STATE"
        fi
    else
        rm -f "$DDOS_STATE"
    fi
}

############################
# Muitas quedas MONITOR_DROP no mesmo DPT (último minuto)
############################

check_port_spike() {
    SPIKE=$(echo "$LOG_CACHE" | grep "$CURRENT_MIN" | grep "MONITOR_DROP" | \
        awk '
        BEGIN { max = 0 }
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^DPT=/ || $i ~ /^dpt=/) {
                    split($i, a, "=")
                    p = a[2]
                    gsub(/[^0-9]/, "", p)
                    if (p != "") c[p]++
                }
            }
        }
        END {
            for (p in c) {
                if (c[p] > max) { max = c[p]; top = p }
            }
            if (max > 0) print max " " top
        }')

    [ -z "$SPIKE" ] && return 0
    N=$(echo "$SPIKE" | awk '{print $1}')
    P=$(echo "$SPIKE" | awk '{print $2}')

    if [ "$N" -ge "$PORT_SPIKE_MIN" ] 2>/dev/null; then
        if [ ! -f "$PORTSPIKE_STATE" ]; then
            checks_log_event "WARNING" "Pico de eventos MONITOR_DROP na porta $P no último minuto ($N). Verificar regras de firewall / scan."
            touch "$PORTSPIKE_STATE"
        fi
    else
        rm -f "$PORTSPIKE_STATE"
    fi
}

############################
# Taxa aproximada RX/TX em Mbps (delta /proc/net/dev)
############################

checks_dev_counters() {
    _dev="$1"
    grep -F "${_dev}:" /proc/net/dev 2>/dev/null | head -n1 | awk '{print $2, $10}'
}

check_wan_speed() {
    _sec=2
    _body=""
    for _u in wan wan2; do
        _up=$(ubus call "network.interface.${_u}" status 2>/dev/null | jsonfilter -e '@.up')
        [ "$_up" != "true" ] && continue
        _dev=$(checks_iface_dev "$_u")
        [ -z "$_dev" ] && continue
        C1=$(checks_dev_counters "$_dev")
        [ -z "$C1" ] && continue
        RX1=$(echo "$C1" | awk '{print $1}')
        TX1=$(echo "$C1" | awk '{print $2}')
        sleep "$_sec"
        C2=$(checks_dev_counters "$_dev")
        RX2=$(echo "$C2" | awk '{print $1}')
        TX2=$(echo "$C2" | awk '{print $2}')
        [ -z "$RX2" ] && continue
        DRX=$((RX2 - RX1))
        DTX=$((TX2 - TX1))
        [ "$DRX" -lt 0 ] && DRX=0
        [ "$DTX" -lt 0 ] && DTX=0
        _mbps_rx=$(( DRX * 8 / _sec / 1000000 ))
        _mbps_tx=$(( DTX * 8 / _sec / 1000000 ))
        _body="$_body

$_u ($_dev): ↓ ~${_mbps_rx} Mbps  ↑ ~${_mbps_tx} Mbps"
    done
    [ -z "$_body" ] && return 0
    if [ "$CHECK_SPEED_QUIET" = "1" ]; then
        monitor_log "speed (amostra ${_sec}s):$_body"
    else
        checks_log_event "INFO" "Velocidade aproximada (amostra ${_sec}s):${_body}"
    fi
}

############################
# Relatório diário (disparado pelo cron às 08:00)
############################

daily_report() {
    TODAY=$(date +%Y-%m-%d)
    if [ -f "$DAILY_STATE" ]; then
        _last=$(cat "$DAILY_STATE" 2>/dev/null)
        [ "$_last" = "$TODAY" ] && return 0
    fi

    LOAD=$(uptime | awk -F'load average:' '{ print $2 }')
    MEM=$(mem_usage_percent)

    checks_log_event "INFO" "Daily Report

CPU Load:$LOAD
RAM:${MEM}%"

    echo "$TODAY" > "$DAILY_STATE"
}

############################
# Agregadores (monitor-network / Telegram)
############################

checks_tick() {
    checks_ensure_state
    checks_refresh_log_cache
    check_wan
    check_failover
    check_public_ip_all_wans
    check_mac
}

checks_ssh_only() {
    checks_ensure_state
    checks_refresh_log_cache
    check_ssh
}

checks_scan_only() {
    checks_ensure_state
    checks_refresh_log_cache
    check_internal_scan
}

checks_daily_only() {
    checks_ensure_state
    daily_report
}

checks_ddos_only() {
    checks_ensure_state
    checks_refresh_log_cache
    check_ddos_light
}

checks_portscan_only() {
    checks_ensure_state
    checks_refresh_log_cache
    check_port_spike
}

checks_speed_only() {
    checks_ensure_state
    check_wan_speed
}

checks_all() {
    checks_tick
    checks_ssh_only
    checks_scan_only
    checks_ddos_only
    checks_portscan_only
    checks_speed_only
}
