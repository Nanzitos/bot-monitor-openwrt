#!/bin/sh

# Requer: configs.sh antes (TELEGRAM_TOKEN, TELEGRAM_CHAT_ID, STATE_DIR, LOG_DIR)

STATE_DIR="${STATE_DIR:-/tmp/monitor}"
LAST_UPDATE_FILE="${STATE_DIR}/telegram_last_update"

TG_CURL_OPTS="-sS --connect-timeout 10 --max-time 35"

send_message() {
    _text="$1"
    [ -z "$TELEGRAM_TOKEN" ] && return 1
    curl $TG_CURL_OPTS -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${_text}" >/dev/null 2>&1
}

send_message_html() {
    _text="$1"
    [ -z "$TELEGRAM_TOKEN" ] && return 1
    if ! curl $TG_CURL_OPTS -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${_text}" \
        --data-urlencode "parse_mode=HTML" >/dev/null 2>&1
    then
        mkdir -p "${LOG_DIR:-/var/log/monitor}" 2>/dev/null || true
        _ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)
        echo "$_ts send_message_html failed" >> "${LOG_DIR:-/var/log/monitor}/telegram_send_errors.log" 2>/dev/null || true
        return 1
    fi
    return 0
}

get_updates() {
    [ -z "$TELEGRAM_TOKEN" ] && printf '%s\n' '{"ok":false,"result":[]}' && return
    LAST_ID=$(cat "$LAST_UPDATE_FILE" 2>/dev/null)
    if [ -z "$LAST_ID" ]; then
        curl $TG_CURL_OPTS "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates?timeout=25"
    else
        curl $TG_CURL_OPTS "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates?offset=$((LAST_ID + 1))&timeout=25"
    fi
}
