#!/bin/sh
# Reempacota um .ipk OpenWrt para tar internos em formato ustar (sem typeflag PAX 'x'),
# compatível com o extrator tar do opkg/libbb do router.
# Requer GNU tar (--format=ustar). Uso: repack-ipk-opkg-compat.sh /entrada.ipk [/saida.ipk]
set -e
IPK="${1:?caminho do .ipk de entrada}"
OUT="${2:-$IPK}"
[ -f "$IPK" ]
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
(
	cd "$d"
	gzip -dc "$IPK" | tar -xf -
	for inner in control.tar.gz data.tar.gz; do
		mkdir -p "_u/$inner"
		tar -xzf "$inner" -C "_u/$inner"
		(
			cd "_u/$inner"
			tar --format=ustar --numeric-owner --owner=0 --group=0 -cf - .
		) | gzip -n - >"$inner.new"
		cp -f "$inner.new" "$inner"
		rm -f "$inner.new"
		rm -rf "_u/$inner"
	done
	tar --format=ustar --numeric-owner --owner=0 --group=0 -cf - \
		debian-binary data.tar.gz control.tar.gz | gzip -n - >"$d/ipk.new"
)
cp -f "$d/ipk.new" "$OUT"
rm -f "$d/ipk.new"
gzip -t "$OUT"
