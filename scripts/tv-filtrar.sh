#!/bin/bash
# Descarga listas legales de iptv-org, prueba cada canal y guarda solo los que responden.
# Resultado: ~/Videos/TV por internet/*(funcionando).m3u  (Kodi y VLC los usan)
T="$(xdg-user-dir VIDEOS)/TV por internet"; mkdir -p "$T"
B=https://iptv-org.github.io/iptv
UA="VLC/3.0.24 LibVLC/3.0.24"
probar() {  # lee pares EXTINF/URL y escribe solo los vivos
  local src="$1" out="$2" tmp; tmp=$(mktemp -d)
  curl -sL -m 60 "$src" | tr -d '\r' > "$tmp/lista.m3u" || return 1
  awk '/^#EXTINF/{inf=$0; next} /^https?:\/\//{n++; printf "%d\t%s\t%s\n", n, inf, $0}' "$tmp/lista.m3u" > "$tmp/pares.tsv"
  cut -f1,3 "$tmp/pares.tsv" | xargs -P 24 -L 1 sh -c \
    'c=$(curl -s -o /dev/null -m 6 -A "'"$UA"'" -w "%{http_code}" "$1"); [ "$c" = 200 ] && echo "$0"' > "$tmp/vivos.txt"
  { echo "#EXTM3U"; sort -n "$tmp/vivos.txt" | while read -r i; do awk -F'\t' -v i="$i" '$1==i{print $2; print $3}' "$tmp/pares.tsv"; done; } > "$out.tmp"
  mv "$out.tmp" "$out"
  echo "$(basename "$out"): $(wc -l < "$tmp/vivos.txt") de $(wc -l < "$tmp/pares.tsv") funcionan"
  rm -rf "$tmp"
}
probar "$B/countries/mx.m3u"    "$T/México (funcionando).m3u"
probar "$B/languages/spa.m3u"   "$T/En español (funcionando).m3u"
date > "$T/.ultima-revision"
