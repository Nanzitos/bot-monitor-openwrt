#!/bin/sh
# Speedtest estilo speedtest-netperf (netperf em paralelo), um teste por WAN com bind no IP da interface.
# OPENWRT_PKG: speedtest-netperf instala sobretudo speedtest-netperf.sh + netperf; não há --json oficial.
# Este módulo gera JSON próprio e mensagem HTML para o Telegram.

SPEEDTEST_HOST="${SPEEDTEST_HOST:-netperf.bufferbloat.net}"
SPEEDTEST_DURATION="${SPEEDTEST_DURATION:-25}"
SPEEDTEST_STREAMS="${SPEEDTEST_STREAMS:-4}"

checks_speed_ipv4_on_dev() {
    ip -4 -o addr show dev "$1" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1
}

# netperf tem de existir no sistema (dependência do pacote monitor ou opkg manual).
checks_speed_netperf_available() {
    command -v netperf >/dev/null 2>&1
}

checks_speed_netperf_sum_file() {
    awk '{s+=$1} END { printf "%.2f", s+0 }' "$1" 2>/dev/null
}

checks_speed_netperf_direction_mbps() {
    _host="$1"
    _lip="$2"
    _dur="$3"
    _streams="$4"
    _test="$5"
    _tmp=$(mktemp /tmp/monitor-netperf.XXXXXX)
    _i=1
    while [ "$_i" -le "$_streams" ]; do
        netperf -4 -L "$_lip" -H "$_host" -t "$_test" -l "$_dur" -v 0 -P 0 >>"$_tmp" 2>/dev/null &
        _i=$((_i + 1))
    done
    wait
    checks_speed_netperf_sum_file "$_tmp"
    rm -f "$_tmp"
}

# Medição por WAN: netperf com -L no IP local (equivalente ao upstream; JSON gerado aqui).
# Se existir um binário speedtest-netperf --json que aceite bind por interface no teu sistema,
# podes estender este script; o pacote OpenWrt usa sobretudo speedtest-netperf.sh (texto).
checks_speed_netperf_measure_json() {
    _uiface="$1"
    _dev="$2"
    _lip="$3"

    _dl=$(checks_speed_netperf_direction_mbps "$SPEEDTEST_HOST" "$_lip" "$SPEEDTEST_DURATION" "$SPEEDTEST_STREAMS" TCP_MAERTS)
    _ul=$(checks_speed_netperf_direction_mbps "$SPEEDTEST_HOST" "$_lip" "$SPEEDTEST_DURATION" "$SPEEDTEST_STREAMS" TCP_STREAM)

    printf '{"iface":"%s","dev":"%s","bind":"%s","mode":"netperf-direct","download_mbps":%s,"upload_mbps":%s,"host":"%s","duration_s":%s,"streams":%s}' \
        "$_uiface" "$_dev" "$_lip" "$_dl" "$_ul" "$SPEEDTEST_HOST" "$SPEEDTEST_DURATION" "$SPEEDTEST_STREAMS"
}

checks_speed_block_html() {
    _title="$1"
    _json="$2"

    _dl=$(echo "$_json" | jsonfilter -e '@.download_mbps' 2>/dev/null)
    _ul=$(echo "$_json" | jsonfilter -e '@.upload_mbps' 2>/dev/null)
    _mode=$(echo "$_json" | jsonfilter -e '@.mode' 2>/dev/null)
    _host=$(echo "$_json" | jsonfilter -e '@.host' 2>/dev/null)
    _bind=$(echo "$_json" | jsonfilter -e '@.bind' 2>/dev/null)
    _dev=$(echo "$_json" | jsonfilter -e '@.dev' 2>/dev/null)
    _dur=$(echo "$_json" | jsonfilter -e '@.duration_s' 2>/dev/null)
    _str=$(echo "$_json" | jsonfilter -e '@.streams' 2>/dev/null)

    [ -z "$_dl" ] && _dl="?"
    [ -z "$_ul" ] && _ul="?"
    [ -z "$_mode" ] && _mode="?"
    [ -z "$_host" ] && _host="$SPEEDTEST_HOST"
    [ -z "$_dur" ] && _dur="$SPEEDTEST_DURATION"
    [ -z "$_str" ] && _str="$SPEEDTEST_STREAMS"

    printf '<b>%s</b> (%s)
↓ Download: <b>%s</b> Mbps
↑ Upload: <b>%s</b> Mbps
<i>%s · bind %s · servidor %s · ~%ss por direção · streams %s</i>' \
        "$_title" "${_dev:-?}" "$_dl" "$_ul" "$_mode" "${_bind:-?}" "$_host" "$_dur" "$_str"
}

check_wan_speed_netperf() {
    checks_ensure_state

    if ! checks_speed_netperf_available; then
        _msg="📶 <b>netperf</b> em falta — o monitor não instala pacotes sozinho.
<pre>opkg update &amp;&amp; opkg install netperf</pre>
Ou reinstala <code>monitor</code> depois de <code>opkg update</code> (dependência do pacote)."
        if [ "$CHECK_SPEED_QUIET" = "1" ]; then
            monitor_log "speed netperf: pacote em falta"
        else
            checks_log_event "WARNING" "$_msg"
        fi
        return 1
    fi

    _body=""
    for _u in wan wan2; do
        _up=$(ubus call "network.interface.${_u}" status 2>/dev/null | jsonfilter -e '@.up')
        [ "$_up" != "true" ] && continue
        _dev=$(checks_iface_dev "$_u")
        [ -z "$_dev" ] && continue
        _lip=$(checks_speed_ipv4_on_dev "$_dev")
        [ -z "$_lip" ] && continue

        _json=$(checks_speed_netperf_measure_json "$_u" "$_dev" "$_lip")
        _blk=$(checks_speed_block_html "$_u" "$_json")
        _body="$_body

${_blk}"
    done

    [ -z "$_body" ] && return 0

    if [ "$CHECK_SPEED_QUIET" = "1" ]; then
        monitor_log "speed netperf:${_body}"
    else
        checks_log_event "INFO" "📶 <b>Speedtest netperf</b> (JSON interno + bind por WAN)${_body}"
    fi
    return 0
}
