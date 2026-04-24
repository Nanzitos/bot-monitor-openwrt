#!/bin/sh

ENV_FILE="/etc/monitor/config.env"
[ -f "$ENV_FILE" ] || exit 1
. "$ENV_FILE"

STATE_DIR="${STATE_DIR:-/tmp/monitor}"
LOG_DIR="${LOG_DIR:-/var/log/monitor}"
ALLOWLIST="${ALLOWLIST:-/etc/monitor/mac_allowlist}"
