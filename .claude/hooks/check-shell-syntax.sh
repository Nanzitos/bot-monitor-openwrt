#!/bin/sh
# Verifica sintaxe shell após Edit/Write em ficheiros do projecto.
# Recebe JSON no stdin com tool_input.file_path.

FILE=$(python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null)

[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

case "$FILE" in
    *.sh|*/usr/bin/monitor-*|*/usr/lib/monitor/*|*/etc/init.d/*)
        if sh -n "$FILE" 2>&1; then
            printf '[syntax] OK: %s\n' "$(basename "$FILE")"
        else
            printf '[syntax] ERRO em: %s\n' "$FILE"
            exit 1
        fi
        ;;
esac

exit 0
