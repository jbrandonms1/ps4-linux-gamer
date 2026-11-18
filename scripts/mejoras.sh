#!/bin/bash
# Mejoras de escritorio: Brave, gráfica de CPU + temperatura junto a la hora, capturas, pantalla siempre encendida.
# Ejecutar en el escritorio como archlinux:   curl -s IP_DE_TU_PC:8000/mejoras.sh | bash
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
OUT=$HOME/ps4-mejoras.txt
exec > >(tee "$OUT") 2>&1
trap 'echo "== FIN MEJORAS $(date)"; curl -s -T "$OUT" "http://$HOST/mejoras" >/dev/null' EXIT
[ -z "$DISPLAY" ] && export DISPLAY=:0
[ "$(id -u)" = 0 ] && { echo "Ejecuta como archlinux, no root."; exit 1; }

echo "===== 1. Paquetes (contraseña: archlinux) ====="
sudo pacman -S --noconfirm --needed flameshot lm_sensors xorg-xset </dev/null
echo "-- Brave (AUR, binario oficial)"
yay -S --noconfirm --needed --sudoloop --answerdiff None --answerclean None brave-bin </dev/null || echo "AVISO: fallo Brave"
command -v brave && brave --version

echo; echo "===== 2. Panel: gráfica de CPU y temperatura junto a la hora ====="
P=$HOME/.config/lxqt/panel.conf
if [ ! -f "$P" ]; then
  for d in /usr/share/lxqt/panel.conf /etc/xdg/lxqt/panel.conf; do [ -f "$d" ] && cp "$d" "$P" && break; done
fi
cp "$P" "$P.bak"
python3 - "$P" <<'EOF'
import configparser, sys
p = sys.argv[1]
c = configparser.ConfigParser(interpolation=None, strict=False)
c.optionxform = str
c.read(p)
panel = next((s for s in c.sections() if c.has_option(s, "plugins")), None)
if not panel:
    sys.exit("No se encontró la lista de plugins del panel")
pl = [x.strip() for x in c.get(panel, "plugins").split(",") if x.strip()]
clock = next((x for x in pl if "clock" in x), None)
pos = pl.index(clock) if clock else len(pl)
for name in ("cpugrafica", "temperatura"):
    if name not in pl:
        pl.insert(pos, name); pos += 1
c.set(panel, "plugins", ", ".join(pl))
if not c.has_section("cpugrafica"):
    c.add_section("cpugrafica")
c["cpugrafica"].update({"type": "sysstat", "data\\source": "cpu", "graph\\updateInterval": "1",
                        "graph\\minimalSize": "40", "title\\label": "CPU", "cpu\\useFrequency": "false"})
if not c.has_section("temperatura"):
    c.add_section("temperatura")
c["temperatura"].update({"type": "sensors", "updateInterval": "2", "tempBarWidth": "8",
                         "useFahrenheitScale": "false", "warningAboutHighTemperature": "true"})
with open(p, "w") as f:
    c.write(f, space_around_delimiters=False)
print("Panel:", panel, "->", c.get(panel, "plugins"))
EOF
# Reiniciar el panel sin que guarde su config vieja encima
pkill -KILL lxqt-panel; sleep 3
pgrep -x lxqt-panel >/dev/null || setsid -f lxqt-panel </dev/null >/dev/null 2>&1
sleep 2; pgrep -x lxqt-panel >/dev/null && echo "PANEL OK"

echo; echo "===== 3. Tecla Impr Pant = captura de pantalla (flameshot) ====="
K=$HOME/.config/lxqt/globalkeyshortcuts.conf
grep -q 'flameshot' "$K" 2>/dev/null || cat >> "$K" <<'EOF'

[Print.10]
Comment=Captura de pantalla
Enabled=true
Exec=flameshot, gui
EOF
mkdir -p "$(xdg-user-dir PICTURES)/Capturas"
mkdir -p ~/.config/flameshot
printf '[General]\nsavePath=%s/Capturas\nshowStartupLaunchMessage=false\ndisabledTrayIcon=false\n' "$(xdg-user-dir PICTURES)" > ~/.config/flameshot/flameshot.ini
printf '[Desktop Entry]\nType=Application\nName=Flameshot\nExec=flameshot\n' > ~/.config/autostart/flameshot.desktop
pkill -f lxqt-globalkeysd; sleep 1; pgrep -f lxqt-globalkeysd >/dev/null || setsid -f lxqt-globalkeysd </dev/null >/dev/null 2>&1
setsid -f flameshot </dev/null >/dev/null 2>&1

echo; echo "===== 4. Pantalla siempre encendida (centro multimedia en TV) ====="
printf '[Desktop Entry]\nType=Application\nName=Sin apagado de pantalla\nExec=xset s off -dpms s noblank\n' > ~/.config/autostart/no-blank.desktop
xset s off -dpms s noblank && echo "OK"

echo; echo "===== 5. Brave en el dock ====="
f=$(ls /usr/share/applications/brave*.desktop 2>/dev/null | head -1)
D=$HOME/.config/plank/dock1/launchers
if [ -n "$f" ] && [ -d "$D" ] && ! ls $D/*brave* >/dev/null 2>&1; then
  printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$f" > "$D/07b-brave.dockitem"
  echo "Brave añadido al dock"
fi
DESK=$(xdg-user-dir DESKTOP); [ -n "$f" ] && cp "$f" "$DESK/" && chmod +x "$DESK/$(basename "$f")"

echo; echo "===== 6. Letras y barra más grandes (para TV) ====="
# DPI 120 = todo 25% más grande (Qt y GTK: Brave, Firefox, Steam). SDDM carga ~/.Xresources al iniciar sesión.
grep -q '^Xft.dpi' ~/.Xresources 2>/dev/null && sed -i 's/^Xft.dpi:.*/Xft.dpi: 120/' ~/.Xresources || echo 'Xft.dpi: 120' >> ~/.Xresources
xrdb -merge ~/.Xresources
python3 - "$HOME/.config/lxqt/panel.conf" "$HOME/.config/lxqt/lxqt.conf" <<'EOF'
import configparser, sys
def load(p):
    c = configparser.ConfigParser(interpolation=None, strict=False); c.optionxform = str; c.read(p); return c
p, l = sys.argv[1], sys.argv[2]
c = load(p)
panel = next((s for s in c.sections() if c.has_option(s, "plugins")), None)
if panel:
    c.set(panel, "panelSize", "44"); c.set(panel, "iconSize", "30"); c.set(panel, "lineCount", "1")
    with open(p, "w") as f: c.write(f, space_around_delimiters=False)
c = load(l)
if not c.has_section("Qt"): c.add_section("Qt")
c.set("Qt", "font", '"Noto Sans,12,-1,5,50,0,0,0,0,0"')
with open(l, "w") as f: c.write(f, space_around_delimiters=False)
print("Panel 44px, iconos 30px, fuente Noto Sans 12, DPI 120")
EOF
pkill -KILL lxqt-panel; sleep 3
pgrep -x lxqt-panel >/dev/null || setsid -f lxqt-panel </dev/null >/dev/null 2>&1

echo; echo "===== 7. Widget de sistema en el escritorio (conky) ====="
sudo pacman -S --noconfirm --needed conky </dev/null
NET=$(ip route show default | awk '{print $5; exit}'); NET=${NET:-eth0}
HW=$(for h in /sys/class/hwmon/hwmon*; do [ "$(cat $h/name)" = k10temp ] && basename $h; done | head -1)
HWN=${HW#hwmon}; HWN=${HWN:-0}
GPUB=$(ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
mkdir -p ~/.config/conky
cat > ~/.config/conky/conky.conf <<EOF
conky.config = {
  alignment = 'top_right', gap_x = 40, gap_y = 60, minimum_width = 300, maximum_width = 300,
  background = true, double_buffer = true, update_interval = 2,
  own_window = true, own_window_type = 'normal', own_window_class = 'Conky',
  own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
  own_window_argb_visual = true, own_window_argb_value = 150, own_window_colour = '0f0c29',
  border_inner_margin = 14, use_xft = true, font = 'Noto Sans:size=11',
  default_color = 'e8e6ff', color1 = '9d7bff', color2 = '7b2ff7',
  draw_shades = false, draw_outline = false, draw_borders = false, draw_graph_borders = false,
  default_bar_height = 6, cpu_avg_samples = 2, net_avg_samples = 2, no_buffers = true,
};
conky.text = [[
\${color1}\${font Noto Sans:bold:size=18}\${time %H:%M}\${font}\${color}  \${time %A %d %B}
\${color1}PS4 \${color}\${alignr}up \${uptime_short}
\${color2}\${hr 1}\${color}
\${color1}CPU\${color} \${alignr}\${cpu cpu0}%  ·  \${hwmon $HWN temp 1}°C
\${color2}\${cpugraph cpu0 30,300 7b2ff7 9d7bff}\${color}
\${cpubar cpu1 4,140}\${alignr}\${cpubar cpu2 4,140}
\${cpubar cpu3 4,140}\${alignr}\${cpubar cpu4 4,140}
\${cpubar cpu5 4,140}\${alignr}\${cpubar cpu6 4,140}
\${cpubar cpu7 4,140}\${alignr}\${cpubar cpu8 4,140}
EOF
[ -n "$GPUB" ] && echo "\${color1}GPU\${color} \${alignr}\${cat $GPUB}%" >> ~/.config/conky/conky.conf
cat >> ~/.config/conky/conky.conf <<EOF
\${color1}RAM\${color} \${alignr}\$mem / \$memmax
\${color2}\${membar}\${color}
\${color1}Disco\${color} \${alignr}\${fs_used /} / \${fs_size /}
\${color2}\${fs_bar /}\${color}
\${color1}Red\${color} \${alignr}↓ \${downspeed $NET}   ↑ \${upspeed $NET}
\${color2}\${downspeedgraph $NET 24,145 7b2ff7 9d7bff}\${alignr}\${upspeedgraph $NET 24,145 7b2ff7 9d7bff}\${color}
\${color1}Procesos\${color} \${alignr}\${top name 1} \${top cpu 1}%
]];
EOF
printf '[Desktop Entry]\nType=Application\nName=Widget conky\nExec=sh -c "sleep 6; conky -d"\n' > ~/.config/autostart/conky.desktop
# que picom no le ponga sombra ni esquinas al widget
grep -q "Conky" ~/.config/picom/picom.conf || sed -i "s/shadow-exclude = \[ /shadow-exclude = [ \"class_g = 'Conky'\", /" ~/.config/picom/picom.conf
pkill -x conky; sleep 1; conky -d -q && echo "WIDGET OK"

echo; echo "===== 8. Modo consola (todo con el control, sin teclado) ====="
cat > ~/.local/bin/modo-consola <<'EOF'
#!/bin/sh
# modo-consola steam   -> al encender entra a Steam Big Picture
# modo-consola es-de   -> al encender entra a EmulationStation (emuladores + accesos a Steam)
# modo-consola off     -> al encender queda en el escritorio normal
# modo-consola         -> abre ahora el modo elegido
A=$HOME/.config/autostart/modo-consola.desktop
C=$HOME/.config/modo-consola
case "$1" in
  steam|es-de)
    echo "$1" > "$C"
    printf '[Desktop Entry]\nType=Application\nName=Modo consola\nExec=sh -c "sleep 8; %s"\n' "$HOME/.local/bin/modo-consola" > "$A"
    echo "Modo consola ACTIVADO al encender: $1" ;;
  off) rm -f "$A"; echo "Modo consola DESACTIVADO (arranca en escritorio)" ;;
  *)
    M=$(cat "$C" 2>/dev/null || echo es-de)
    if [ "$M" = steam ]; then exec steam -gamepadui
    else ES=$(command -v es-de || command -v emulationstation-de || command -v emulationstation); exec "$ES"; fi ;;
esac
EOF
chmod +x ~/.local/bin/modo-consola
# Iconos para cambiar de modo desde el escritorio
mk() { printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nIcon=%s\nTerminal=false\n' "$1" "$2" "$3" > "$HOME/.local/share/applications/$4.desktop"; }
mk "Modo Consola" "$HOME/.local/bin/modo-consola" input-gaming modo-consola
mk "Consola al encender: Steam" "sh -c '$HOME/.local/bin/modo-consola steam; notify-send \"Modo consola\" \"Al encender: Steam Big Picture\"'" steam modo-consola-steam
mk "Consola al encender: EmulationStation" "sh -c '$HOME/.local/bin/modo-consola es-de; notify-send \"Modo consola\" \"Al encender: EmulationStation\"'" input-gaming modo-consola-esde
mk "Consola al encender: Desactivar" "sh -c '$HOME/.local/bin/modo-consola off; notify-send \"Modo consola\" \"Al encender: escritorio\"'" user-desktop modo-consola-off
DESK=$(xdg-user-dir DESKTOP)
cp ~/.local/share/applications/modo-consola*.desktop "$DESK/"; chmod +x "$DESK"/modo-consola*.desktop
D=$HOME/.config/plank/dock1/launchers
[ -d "$D" ] && printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$HOME/.local/share/applications/modo-consola.desktop" > "$D/00-modo-consola.dockitem"
# Activado por defecto con EmulationStation (desde ahí también se abren los juegos de Steam)
~/.local/bin/modo-consola es-de

echo
echo "Listo:"
echo " - Impr Pant = captura | gráfica de CPU y temperatura junto a la hora | Brave en el dock"
echo " - Letras más grandes: se ven completas al reiniciar"
echo " - Widget arriba a la derecha"
echo " - Modo consola: al encender entra a EmulationStation. Cambia con los iconos 'Consola al encender: ...'"
