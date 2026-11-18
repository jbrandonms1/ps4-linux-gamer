#!/bin/bash
# Arreglo + mejoras visuales del escritorio PS4 (fondo, dock, panel, tema, widget) y luego control BT.
# Ejecutar en el escritorio como archlinux:   curl -s IP_DE_TU_PC:8000/escritorio.sh | bash
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
OUT=$HOME/ps4-escritorio.txt
exec > >(tee "$OUT") 2>&1
up() { curl -s -T "$OUT" "http://$HOST/escritorio" >/dev/null 2>&1; }
trap 'echo "== FIN ESCRITORIO $(date)"; up' EXIT
[ -z "$DISPLAY" ] && export DISPLAY=:0
[ "$(id -u)" = 0 ] && { echo "Ejecuta como archlinux, no root."; exit 1; }
captura() {  # captura de pantalla reducida -> se envía a la laptop
  local f=/tmp/captura-$1.png
  ffmpeg -nostdin -loglevel error -y -f x11grab -i "$DISPLAY" -frames:v 1 -vf scale=960:-1 "$f" </dev/null 2>/dev/null \
    || flameshot full -p /tmp >/dev/null 2>&1
  [ -f "$f" ] && curl -s -T "$f" "http://$HOST/$1.png" >/dev/null && echo "(captura '$1' enviada)"
}
estado() {
  echo "-- procesos:"; pgrep -a 'xwinwrap|^mpv$|picom|plank|conky|lxqt-panel|feh' | cut -c1-160
  echo "-- ventanas:"; wmctrl -l -x 2>/dev/null | cut -c1-120
  echo "-- plank:"; gsettings get net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ hide-mode 2>&1
  ls ~/.config/plank/dock1/launchers/ 2>&1 | tr '\n' ' '; echo
}

echo "===== 0. Estado actual ====="
estado; captura antes; up

echo; echo "===== 1. Paquetes (contraseña: archlinux) ====="
sudo pacman -S --noconfirm --needed feh materia-gtk-theme ttf-nerd-fonts-symbols xorg-xset wmctrl ffmpeg conky </dev/null \
  || echo "AVISO: fallo en paquetes"
yay -S --noconfirm --needed --sudoloop --answerdiff None --answerclean None bibata-cursor-theme-bin </dev/null \
  || echo "AVISO: fallo cursor"

echo; echo "===== 2. Sin arranque automático: solo escritorio ====="
[ -x ~/.local/bin/modo-consola ] && ~/.local/bin/modo-consola off
rm -f ~/.config/autostart/modo-consola.desktop

echo; echo "===== 3. Fondo animado nuevo (colores vivos) + fondo fijo de respaldo ====="
VID=$(xdg-user-dir VIDEOS); PIC=$(xdg-user-dir PICTURES); mkdir -p "$VID" "$PIC"
[ -f "$VID/wallpaper.mp4" ] && [ ! -f "$VID/wallpaper-viejo.mp4" ] && mv "$VID/wallpaper.mp4" "$VID/wallpaper-viejo.mp4"
G="gradients=s=1280x720:rate=24:duration=20:speed=0.014:n=5:c0=0x3a0ca3:c1=0x7209b7:c2=0xf72585:c3=0x4361ee:c4=0x4cc9f0"
FX="vignette=PI/5,format=yuv420p,split[a][b];[b]reverse[r];[a][r]concat=n=2:v=1:a=0"
echo "Generando vídeo (1-2 min)..."
ffmpeg -nostdin -loglevel error -y -f lavfi -i "$G:type=radial" -filter_complex "[0]$FX" \
    -c:v libx264 -preset veryfast -crf 22 -pix_fmt yuv420p "$VID/wallpaper.mp4" </dev/null \
 || ffmpeg -nostdin -loglevel error -y -f lavfi -i "$G" -filter_complex "[0]$FX" \
    -c:v libx264 -preset veryfast -crf 22 -pix_fmt yuv420p "$VID/wallpaper.mp4" </dev/null
ffprobe -v error -show_entries format=duration -of csv=p=0 "$VID/wallpaper.mp4" </dev/null
ffmpeg -nostdin -loglevel error -y -ss 5 -i "$VID/wallpaper.mp4" -frames:v 1 -vf scale=1920:1080 "$PIC/fondo.png" </dev/null
feh --no-fehbg --bg-fill "$PIC/fondo.png" && echo "Fondo fijo de respaldo OK"
printf '[Desktop Entry]\nType=Application\nName=Fondo fijo\nExec=feh --no-fehbg --bg-fill %s\n' "$PIC/fondo.png" > ~/.config/autostart/fondo-fijo.desktop

# Ventana de fondo como tipo ESCRITORIO (no override): queda debajo de todo, el dock no la "esquiva"
cat > ~/.local/bin/fondo-animado.sh <<'EOF'
#!/bin/sh
# Uso: fondo-animado.sh [video]   |  Para quitarlo: borra ~/.config/autostart/fondo-animado.desktop
V="${1:-$(xdg-user-dir VIDEOS)/wallpaper.mp4}"
SOCK=/tmp/fondo-mpv-$USER
pkill -x xwinwrap 2>/dev/null; sleep 1
command -v xwinwrap >/dev/null || exit 0
xwinwrap -fdt -fs -un -ni -s -st -sp -b -nf -- \
  mpv -wid %WID --loop-file=inf --no-audio --no-osc --no-osd-bar --no-input-default-bindings \
      --hwdec=no --panscan=1.0 --input-ipc-server=$SOCK "$V" >/tmp/fondo.log 2>&1 &
# Pausa mientras hay un juego/emulador o una ventana a pantalla completa (ahorra CPU/GPU)
JUEGOS='^(gamescope|retroarch|dolphin-emu|PPSSPPSDL|PPSSPPQt|es-de|kodi|kodi.bin|kodi-x11|wineserver|reaper)$'
P=0
while sleep 3; do
  FS=0
  W=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $NF}')
  if [ -n "$W" ] && [ "$W" != "0x0" ]; then
    ST=$(xprop -id "$W" _NET_WM_STATE _NET_WM_WINDOW_TYPE 2>/dev/null)
    echo "$ST" | grep -q FULLSCREEN && ! echo "$ST" | grep -q DESKTOP && FS=1
  fi
  if [ $FS = 1 ] || pgrep "$JUEGOS" >/dev/null; then
    [ $P = 0 ] && echo '{"command":["set_property","pause",true]}' | socat - $SOCK >/dev/null 2>&1 && P=1
  else
    [ $P = 1 ] && echo '{"command":["set_property","pause",false]}' | socat - $SOCK >/dev/null 2>&1 && P=0
  fi
done
EOF
chmod +x ~/.local/bin/fondo-animado.sh

echo; echo "===== 4. Compositor: desenfoque, sombras, esquinas, animaciones ====="
cat > ~/.config/picom/picom.conf <<'EOF'
backend = "glx";
vsync = true;
use-damage = true;
unredir-if-possible = true;
unredir-if-possible-exclude = [ "window_type = 'desktop'", "class_g = 'Plank'", "class_g = 'Conky'" ];
shadow = true; shadow-radius = 18; shadow-opacity = 0.5; shadow-offset-x = -14; shadow-offset-y = -12;
shadow-exclude = [ "window_type = 'desktop'", "window_type = 'dock'", "class_g = 'Plank'", "class_g = 'Conky'", "_GTK_FRAME_EXTENTS@" ];
fading = true; fade-in-step = 0.05; fade-out-step = 0.05;
corner-radius = 12;
rounded-corners-exclude = [ "window_type = 'dock'", "window_type = 'desktop'", "class_g = 'Plank'" ];
blur-method = "dual_kawase"; blur-strength = 5;
blur-background-exclude = [ "window_type = 'desktop'", "class_g = 'Plank'", "_GTK_FRAME_EXTENTS@" ];
opacity-rule = [ "90:class_g = 'qterminal'", "94:class_g = 'Rofi'" ];
animations = (
  { triggers = ["open", "show"];  preset = "appear";    duration = 0.18; },
  { triggers = ["close", "hide"]; preset = "disappear"; duration = 0.14; }
);
EOF

echo; echo "===== 5. Barra de tareas arriba: translúcida, más grande, gráfica CPU + temperatura ====="
P=$HOME/.config/lxqt/panel.conf; cp "$P" "$P.bak4" 2>/dev/null
DEF=$(ls /usr/share/lxqt/panel.conf /etc/xdg/lxqt/panel.conf 2>/dev/null | head -1)
python3 - "$P" "$DEF" <<'EOF'
import configparser, sys
def load(*ps):
    c = configparser.ConfigParser(interpolation=None, strict=False); c.optionxform = str
    for p in ps:
        if p:
            try: c.read_string("[General]\n" + open(p).read())
            except Exception as e: print("ignorado", p, e)
    return c
p, d = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "")
c = load(d, p)
panel = next((s for s in c.sections() if c.has_option(s, "plugins")), None) or "panel1"
if not c.has_section(panel): c.add_section(panel)
if not c.has_option(panel, "plugins"):
    c.set(panel, "plugins", "fancymenu, taskbar, statusnotifier, tray, mount, volume, worldclock, showdesktop")
pl = [x.strip() for x in c.get(panel, "plugins").split(",") if x.strip()]
clock = next((x for x in pl if "clock" in x), None)
pos = pl.index(clock) if clock else len(pl)
for n in ("cpugrafica", "temperatura"):
    if n not in pl: pl.insert(pos, n); pos += 1
c.set(panel, "plugins", ", ".join(pl))
for s in ("cpugrafica", "temperatura"):
    if not c.has_section(s): c.add_section(s)
c["cpugrafica"].update({"type": "sysstat", "data\\source": "cpu", "graph\\updateInterval": "1",
    "graph\\minimalSize": "48", "title\\label": "CPU", "cpu\\useFrequency": "false",
    "grid\\lines": "1", "cpu\\systemColor": "#ff4fd8", "cpu\\userColor": "#9d7bff", "cpu\\niceColor": "#4cc9f0"})
c["temperatura"].update({"type": "sensors", "updateInterval": "2", "tempBarWidth": "8",
    "useFahrenheitScale": "false", "warningAboutHighTemperature": "true"})
c[panel].update({"position": "Top", "panelSize": "44", "iconSize": "28", "lineCount": "1",
    "background-color": "#16132e", "opacity": "82", "font-color": "#e8e6ff", "reserve-space": "true"})
with open(p, "w") as f: c.write(f, space_around_delimiters=False)
print("OK:", c.get(panel, "plugins"))
EOF

echo; echo "===== 6. Tema oscuro para todo: ventanas, apps GTK (Brave/Steam/Firefox), cursor ====="
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0 ~/.icons/default ~/.themes/PS4Dark/openbox-3 ~/.config/openbox
CUR=Bibata-Modern-Ice; [ -d /usr/share/icons/$CUR ] || CUR=Adwaita
for g in gtk-3.0 gtk-4.0; do
  printf '[Settings]\ngtk-theme-name=Materia-dark\ngtk-icon-theme-name=Papirus-Dark\ngtk-cursor-theme-name=%s\ngtk-cursor-theme-size=28\ngtk-font-name=Noto Sans 11\ngtk-application-prefer-dark-theme=1\n' "$CUR" > ~/.config/$g/settings.ini
done
printf 'gtk-theme-name="Materia-dark"\ngtk-icon-theme-name="Papirus-Dark"\ngtk-cursor-theme-name="%s"\ngtk-font-name="Noto Sans 11"\n' "$CUR" > ~/.gtkrc-2.0
printf '[Icon Theme]\nInherits=%s\n' "$CUR" > ~/.icons/default/index.theme
grep -q '^Xcursor.theme' ~/.Xresources 2>/dev/null || printf 'Xcursor.theme: %s\nXcursor.size: 28\n' "$CUR" >> ~/.Xresources
xrdb -merge ~/.Xresources
S=$HOME/.config/lxqt/session.conf
if [ -f "$S" ]; then
  grep -q '^\[Mouse\]' "$S" || printf '\n[Mouse]\n' >> "$S"
  sed -i "/^\[Mouse\]/a cursor_theme=$CUR\ncursor_size=28" "$S"
fi
# Tema de ventanas Openbox a juego (morado oscuro)
cat > ~/.themes/PS4Dark/openbox-3/themerc <<'EOF'
border.width: 0
padding.width: 8
padding.height: 5
window.handle.width: 0
window.client.padding.width: 0
window.client.padding.height: 0
window.label.text.justify: center
window.active.border.color: #7b2ff7
window.inactive.border.color: #13112a
window.active.title.bg: flat solid
window.active.title.bg.color: #1d1940
window.inactive.title.bg: flat solid
window.inactive.title.bg.color: #13112a
window.active.label.bg: parentrelative
window.inactive.label.bg: parentrelative
window.active.label.text.color: #f0eeff
window.inactive.label.text.color: #7d79a3
window.active.button.unpressed.bg: parentrelative
window.active.button.unpressed.image.color: #c9b8ff
window.active.button.hover.bg: flat solid
window.active.button.hover.bg.color: #7b2ff7
window.active.button.hover.image.color: #ffffff
window.active.button.pressed.bg: flat solid
window.active.button.pressed.bg.color: #5a1fd0
window.active.button.pressed.image.color: #ffffff
window.active.button.disabled.bg: parentrelative
window.active.button.disabled.image.color: #4a4670
window.active.button.toggled.bg: parentrelative
window.active.button.toggled.image.color: #ff4fd8
window.inactive.button.unpressed.bg: parentrelative
window.inactive.button.unpressed.image.color: #625e88
window.inactive.button.hover.bg: flat solid
window.inactive.button.hover.bg.color: #2a2650
window.inactive.button.hover.image.color: #ffffff
window.inactive.button.pressed.bg: flat solid
window.inactive.button.pressed.bg.color: #2a2650
window.inactive.button.pressed.image.color: #ffffff
window.inactive.button.disabled.bg: parentrelative
window.inactive.button.disabled.image.color: #3a3660
window.inactive.button.toggled.bg: parentrelative
window.inactive.button.toggled.image.color: #9d7bff
menu.border.width: 0
menu.items.bg: flat solid
menu.items.bg.color: #1d1940
menu.items.text.color: #e8e6ff
menu.items.disabled.text.color: #5a5680
menu.items.active.bg: flat solid
menu.items.active.bg.color: #7b2ff7
menu.items.active.text.color: #ffffff
menu.title.bg: flat solid
menu.title.bg.color: #13112a
menu.title.text.color: #c9b8ff
menu.title.text.justify: center
menu.separator.color: #2e2a58
osd.border.width: 0
osd.bg: flat solid
osd.bg.color: #1d1940
osd.label.text.color: #e8e6ff
osd.hilight.bg: flat solid
osd.hilight.bg.color: #7b2ff7
osd.unhilight.bg: flat solid
osd.unhilight.bg.color: #2e2a58
EOF
RC=~/.config/openbox/lxqt-rc.xml
if [ ! -f "$RC" ]; then
  for d in /usr/share/lxqt/openbox/lxqt-rc.xml /usr/share/lxqt/openbox/rc.xml /etc/xdg/openbox/lxqt-rc.xml /etc/xdg/openbox/rc.xml; do
    [ -f "$d" ] && cp "$d" "$RC" && break
  done
fi
[ -f "$RC" ] && python3 - "$RC" <<'EOF'
import re, sys
p = sys.argv[1]; s = open(p).read()
s2 = re.sub(r'(<theme>\s*<name>)[^<]*(</name>)', r'\1PS4Dark\2', s, count=1)
open(p, "w").write(s2); print("Openbox tema:", "PS4Dark" if s2 != s or "PS4Dark" in s else "sin cambio")
EOF

echo; echo "===== 7. Dock: siempre visible abajo, transparente, iconos grandes con zoom ====="
S=net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/
gsettings set $S position 'bottom'
gsettings set $S alignment 'center'
gsettings set $S hide-mode 'none'
gsettings set $S theme 'Transparent'
gsettings set $S icon-size 52
gsettings set $S zoom-enabled true
gsettings set $S zoom-percent 140
gsettings set $S offset 0

echo; echo "===== 8. Panel de monitor (widget) renovado ====="
NET=$(ip route show default | awk '{print $5; exit}'); NET=${NET:-eth0}
HWN=""; FANN=""
for h in /sys/class/hwmon/hwmon*; do
  case "$(cat $h/name 2>/dev/null)" in k10temp) HWN=${h##*hwmon};; ps4_fan) FANN=${h##*hwmon};; esac
done
G=$(ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1); DEV=${G:+$(dirname "$G")}
cat > ~/.local/bin/vram.sh <<EOF
#!/bin/sh
U=\$(cat $DEV/mem_info_vram_used 2>/dev/null || echo 0); T=\$(cat $DEV/mem_info_vram_total 2>/dev/null || echo 1)
[ "\$1" = pct ] && echo \$((U*100/T)) || echo "\$((U/1048576)) / \$((T/1048576)) MiB"
EOF
chmod +x ~/.local/bin/vram.sh
IF="Symbols Nerd Font:size=12"
I_CPU=$''; I_TEMP=$''; I_GPU=$'\U000f08ae'; I_RAM=$'\U000f035b'; I_DISK=$'\U000f02ca'
I_NET=$'\U000f0200'; I_FAN=$'\U000f0210'; I_TOP=$'\U000f0279'; I_UP=$'\U000f0150'
{
cat <<EOF
conky.config = {
  alignment = 'top_right', gap_x = 36, gap_y = 64, minimum_width = 330, maximum_width = 330,
  background = true, double_buffer = true, update_interval = 1.5,
  own_window = true, own_window_type = 'normal', own_window_class = 'Conky',
  own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
  own_window_argb_visual = true, own_window_argb_value = 165, own_window_colour = '120f28',
  border_inner_margin = 16, use_xft = true, font = 'Noto Sans:size=10', override_utf8_locale = true,
  default_color = 'e8e6ff', color1 = 'c9a7ff', color2 = '7b2ff7', color3 = '8f8ab8', color4 = 'ff4fd8', color5 = '4cc9f0',
  draw_shades = false, draw_outline = false, draw_borders = false, draw_graph_borders = false,
  cpu_avg_samples = 2, net_avg_samples = 2, no_buffers = true, text_buffer_size = 2048,
};
conky.text = [[
\${font Noto Sans:bold:size=30}\${color1}\${time %H:%M}\${font}\${voffset -22}\${goto 150}\${color}\${time %A}
\${goto 150}\${color3}\${time %d %B %Y}\${color}
\${voffset 4}\${color3}archlinux-ps4\${alignr}\${font $IF}$I_UP\${font} \${uptime_short}\${color}
\${color2}\${hr 1}\${color}
\${font $IF}\${color1}$I_CPU\${font}\${color}  \${font Noto Sans:bold:size=10}CPU\${font} \${color3}Jaguar 8 núcleos\${color}\${alignr}\${color4}\${font Noto Sans:bold:size=11}\${cpu cpu0}%\${font}\${color}
\${color3}Frecuencia\${color} \${freq_g} GHz\${alignr}\${font $IF}\${color1}$I_TEMP\${font}\${color} \${hwmon $HWN temp 1}°C
\${cpugraph cpu0 34,330 4a2bd0 ff4fd8 -t}
\${color3}1\${color} \${cpubar cpu1 6,140}\${goto 178}\${color3}2\${color} \${cpubar cpu2 6,140}
\${color3}3\${color} \${cpubar cpu3 6,140}\${goto 178}\${color3}4\${color} \${cpubar cpu4 6,140}
\${color3}5\${color} \${cpubar cpu5 6,140}\${goto 178}\${color3}6\${color} \${cpubar cpu6 6,140}
\${color3}7\${color} \${cpubar cpu7 6,140}\${goto 178}\${color3}8\${color} \${cpubar cpu8 6,140}
EOF
if [ -n "$DEV" ]; then
cat <<EOF
\${voffset 4}\${font $IF}\${color1}$I_GPU\${font}\${color}  \${font Noto Sans:bold:size=10}GPU\${font} \${color3}Liverpool\${color}\${alignr}\${color4}\${font Noto Sans:bold:size=11}\${cat $DEV/gpu_busy_percent}%\${font}\${color}
\${color3}VRAM\${color}\${alignr}\${execi 3 ~/.local/bin/vram.sh texto}
\${color2}\${execibar 3 ~/.local/bin/vram.sh pct}\${color}
EOF
fi
[ -n "$FANN" ] && echo "\${color3}SoC (sensor del ventilador)\${color}\${alignr}\${font $IF}\${color1}$I_FAN\${font}\${color} \${hwmon $FANN temp 1}°C"
cat <<EOF
\${voffset 4}\${font $IF}\${color1}$I_RAM\${font}\${color}  \${font Noto Sans:bold:size=10}RAM\${font}\${alignr}\$mem / \$memmax
\${color2}\${membar 7}\${color}
\${color3}zram (swap)\${color}\${alignr}\$swap / \$swapmax
\${voffset 4}\${font $IF}\${color1}$I_DISK\${font}\${color}  \${font Noto Sans:bold:size=10}Disco\${font}\${alignr}\${fs_used /} / \${fs_size /}
\${color2}\${fs_bar 7 /}\${color}
\${color3}Lectura\${color} \${diskio_read}\${alignr}\${color3}Escritura\${color} \${diskio_write}
\${voffset 4}\${font $IF}\${color1}$I_NET\${font}\${color}  \${font Noto Sans:bold:size=10}Red\${font} \${color3}\${addr $NET}\${color}\${alignr}\${color5}↓ \${downspeed $NET}\${color}  \${color4}↑ \${upspeed $NET}\${color}
\${downspeedgraph $NET 26,160 2b1d6e 4cc9f0}\${alignr}\${upspeedgraph $NET 26,160 2b1d6e ff4fd8}
\${voffset 4}\${font $IF}\${color1}$I_TOP\${font}\${color}  \${font Noto Sans:bold:size=10}Procesos\${font}\${alignr}\${color3}CPU    RAM\${color}
\${top name 1}\${alignr}\${top cpu 1}%  \${top mem 1}%
\${color3}\${top name 2}\${alignr}\${top cpu 2}%  \${top mem 2}%
\${top name 3}\${alignr}\${top cpu 3}%  \${top mem 3}%\${color}
]];
EOF
} > ~/.config/conky/conky.conf
printf '[Desktop Entry]\nType=Application\nName=Widget conky\nExec=sh -c "sleep 6; conky -d"\n' > ~/.config/autostart/conky.desktop
echo "Widget: red=$NET k10temp=hwmon$HWN ventilador=hwmon$FANN gpu=$DEV"

echo; echo "===== 9. Aplicar todo ahora ====="
openbox --reconfigure 2>/dev/null
pkill -x picom; sleep 1; setsid -f picom --config ~/.config/picom/picom.conf </dev/null >/tmp/picom.log 2>&1
pkill -KILL -x lxqt-panel; sleep 3
pgrep -x lxqt-panel >/dev/null || setsid -f lxqt-panel </dev/null >/dev/null 2>&1
pkill -f fondo-animado.sh; pkill -x xwinwrap; sleep 1
setsid -f ~/.local/bin/fondo-animado.sh </dev/null >/dev/null 2>&1
sleep 4
pkill -x plank; sleep 1; setsid -f plank </dev/null >/dev/null 2>&1
pkill -x conky; sleep 1; conky -d -q 2>/tmp/conky.log
sleep 8
echo; echo "-- picom:"; tail -5 /tmp/picom.log
echo "-- mpv/fondo:"; tail -8 /tmp/fondo.log
echo "-- conky:"; tail -5 /tmp/conky.log
estado; captura despues; up

echo
echo "LISTO. Arranca directo al escritorio (modo consola apagado)."
echo "Si algo se ve raro, avisa: la captura ya me llegó."
echo
echo "===== 10. Control por Bluetooth (ten el cable USB a la mano) ====="
up
curl -s "http://$HOST/control.sh" | bash
