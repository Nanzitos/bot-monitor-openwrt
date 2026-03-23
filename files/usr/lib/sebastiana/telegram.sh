#!/bin/sh

send_message() {
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$1" > /dev/null
}

get_updates() {
    LAST_ID=$(cat /tmp/telegram_last 2>/dev/null)

    if [ -z "$LAST_ID" ]; then
        curl -s "https://api.telegram.org/bot$TOKEN/getUpdates"
    else
        curl -s "https://api.telegram.org/bot$TOKEN/getUpdates?offset=$((LAST_ID+1))"
    fi
}