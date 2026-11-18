#!/bin/bash
# Arreglo: gráfica CPU + temperatura en el panel, barra grande, pantalla siempre encendida.
#   curl -s IP_DE_TU_PC:8000/mejoras2.sh | bash
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
OUT=$HOME/ps4-mejoras2.txt
exec > >(tee "$OUT") 2>&1
trap 'echo "== FIN MEJORAS2 $(date)"; curl -s -T "$OUT" "http://$HOST/mejoras2" >/dev/null' EXIT
[ -z "$DISPLAY" ] && export DISPLAY=:0

echo "===== 1. xset (contraseña: archlinux) ====="
sudo pacman -S --noconfirm --needed xorg-xset </dev/null
xset s off -dpms s noblank && echo "Pantalla siempre encendida OK"

echo; echo "===== 2. Panel ====="
P=$HOME/.config/lxqt/panel.conf
DEF=$(ls /usr/share/lxqt/panel.conf /etc/xdg/lxqt/panel.conf 2>/dev/null | head -1)
echo "Por defecto: $DEF"; echo "-- panel.conf actual:"; cat "$P" 2>/dev/null
cp "$P" "$P.bak2" 2>/dev/null
python3 - "$P" "$DEF" <<'EOF'
import configparser, sys
def load(*ps):
    c = configparser.ConfigParser(interpolation=None, strict=False); c.optionxform = str
    for p in ps:
        if p:
            try: c.read_string("[General]\n" + open(p).read())
            except Exception as e: print("ignorado", p, e)
    return c
p, d = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ""
c = load(d, p)          # valores por defecto + los del usuario encima
panel = next((s for s in c.sections() if c.has_option(s, "plugins")), None)
if not panel:
    panel = "panel1"
    if not c.has_section(panel): c.add_section(panel)
    c.set(panel, "plugins", "mainmenu, desktopswitch, quicklaunch, taskbar, tray, statusnotifier, volume, worldclock, showdesktop")
    for s, t in [("mainmenu","mainmenu"),("desktopswitch","desktopswitch"),("quicklaunch","quicklaunch"),("taskbar","taskbar"),
                 ("tray","tray"),("statusnotifier","statusnotifier"),("volume","volume"),("worldclock","worldclock"),("showdesktop","showdesktop")]:
        if not c.has_section(s): c.add_section(s); c.set(s, "type", t)
pl = [x.strip() for x in c.get(panel, "plugins").split(",") if x.strip()]
clock = next((x for x in pl if "clock" in x), None)
pos = pl.index(clock) if clock else len(pl)
for n in ("cpugrafica", "temperatura"):
    if n not in pl: pl.insert(pos, n); pos += 1
c.set(panel, "plugins", ", ".join(pl))
for s in ("cpugrafica", "temperatura"):
    if not c.has_section(s): c.add_section(s)
c["cpugrafica"].update({"type": "sysstat", "data\\source": "cpu", "graph\\updateInterval": "1",
                        "graph\\minimalSize": "40", "title\\label": "CPU", "cpu\\useFrequency": "false"})
c["temperatura"].update({"type": "sensors", "updateInterval": "2", "tempBarWidth": "8",
                         "useFahrenheitScale": "false", "warningAboutHighTemperature": "true"})
c.set(panel, "panelSize", "44"); c.set(panel, "iconSize", "30")
with open(p, "w") as f: c.write(f, space_around_delimiters=False)
print("OK:", panel, "->", c.get(panel, "plugins"))
EOF
pkill -KILL -x lxqt-panel; sleep 3
pgrep -x lxqt-panel >/dev/null || setsid -f lxqt-panel </dev/null >/dev/null 2>&1
sleep 3; pgrep -x lxqt-panel >/dev/null && echo "PANEL OK" || echo "PANEL NO ARRANCÓ"

echo; echo "===== 3. Atajo Impr Pant ====="
pkill -f lxqt-globalkeysd; sleep 2
pgrep -f lxqt-globalkeysd >/dev/null || setsid -f lxqt-globalkeysd </dev/null >/dev/null 2>&1
sleep 1; pgrep -f lxqt-globalkeysd >/dev/null && echo "ATAJOS OK"
