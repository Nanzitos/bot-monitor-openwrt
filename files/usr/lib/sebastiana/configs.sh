#!/bin/sh

ENV_FILE="/etc/sebastiana/config.env"
[ -f "$ENV_FILE" ] || exit 1
. "$ENV_FILE"
