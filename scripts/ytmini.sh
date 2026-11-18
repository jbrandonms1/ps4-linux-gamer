#!/bin/bash
# Mini reproductor flotante de YouTube (mpv). Instalar:  curl -s IP_DE_TU_PC:8000/ytmini.sh | bash
# Uso: copia el enlace del video en Brave (Ctrl+L, Ctrl+C) y pulsa Super+Y (tecla Windows + Y).
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
OUT=$HOME/ps4-ytmini.txt
exec > >(tee "$OUT") 2>&1
trap 'echo "== FIN YTMINI $(date)"; curl -s -T "$OUT" "http://$HOST/ytmini" >/dev/null' EXIT
[ -z "$DISPLAY" ] && export DISPLAY=:0

sudo pacman -S --noconfirm --needed mpv yt-dlp xclip libnotify </dev/null

mkdir -p ~/.local/bin ~/.local/share/applications
cat > ~/.local/bin/yt-mini <<'EOF'
#!/bin/sh
# yt-mini [url]  -> sin url usa el portapapeles
URL="${1:-$(xclip -o -selection clipboard 2>/dev/null)}"
case "$URL" in
  http*://*) ;;
  *) notify-send "Mini YouTube" "Copia primero el enlace del video (Ctrl+L, Ctrl+C en Brave)"; exit 1 ;;
esac
notify-send "Mini YouTube" "Abriendo video..."
exec mpv --ontop --no-border --title="Mini YouTube" --x11-name=yt-mini \
  --geometry=480x270-40-120 --autofit-larger=60%x60% --keepaspect-window=yes \
  --ytdl-format='bv*[height<=720][vcodec^=avc1]+ba[acodec^=mp4a]/b[height<=720]/b' \
  --hwdec=no --force-window=immediate --snap-window=yes --cache=yes \
  --script-opts=osc-visibility=auto "$URL"
EOF
chmod +x ~/.local/bin/yt-mini

printf '[Desktop Entry]\nType=Application\nName=Mini YouTube\nComment=Video flotante del enlace copiado\nExec=%s/.local/bin/yt-mini\nIcon=youtube\nTerminal=false\nCategories=AudioVideo;\n' "$HOME" \
  > ~/.local/share/applications/yt-mini.desktop

# Atajo Super+Y
K=$HOME/.config/lxqt/globalkeyshortcuts.conf
grep -q 'yt-mini' "$K" 2>/dev/null || printf '\n[Meta%%2BY.30]\nComment=Mini YouTube\nEnabled=true\nExec=%s/.local/bin/yt-mini\n' "$HOME" >> "$K"
pkill -f lxqt-globalkeysd; sleep 2
pgrep -f lxqt-globalkeysd >/dev/null || setsid -f lxqt-globalkeysd </dev/null >/dev/null 2>&1

# Openbox: la ventana mini en todos los escritorios y sin decoración
RC=~/.config/openbox/lxqt-rc.xml
if [ -f "$RC" ] && ! grep -q 'yt-mini' "$RC"; then
  python3 - "$RC" <<'PYEOF'
import sys
p = sys.argv[1]; s = open(p).read()
rule = '''<application name="yt-mini"><decor>no</decor><layer>above</layer><desktop>all</desktop><skip_taskbar>no</skip_taskbar></application>
'''
if "<applications>" in s: s = s.replace("<applications>", "<applications>\n" + rule, 1)
elif "<applications/>" in s: s = s.replace("<applications/>", "<applications>\n" + rule + "</applications>", 1)
else: s = s.replace("</openbox_config>", "<applications>\n" + rule + "</applications>\n</openbox_config>", 1)
open(p, "w").write(s); print("Regla Openbox añadida")
PYEOF
  openbox --reconfigure 2>/dev/null
fi
yt-dlp --version
echo "LISTO: copia un enlace de YouTube y pulsa Super+Y, o abre 'Mini YouTube' desde el menú."
