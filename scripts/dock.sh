#!/bin/bash
# Barra de tareas arriba, dock abajo (sin encimarse).   curl -s IP_DE_TU_PC:8000/dock.sh | bash
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
OUT=$HOME/ps4-dock.txt
exec > >(tee "$OUT") 2>&1
trap 'echo "== FIN DOCK $(date)"; curl -s -T "$OUT" "http://$HOST/dock" >/dev/null' EXIT
[ -z "$DISPLAY" ] && export DISPLAY=:0
P=$HOME/.config/lxqt/panel.conf
cp "$P" "$P.bak3"
python3 - "$P" <<'EOF'
import configparser, sys
p = sys.argv[1]
c = configparser.ConfigParser(interpolation=None, strict=False); c.optionxform = str
c.read_string("[General]\n" + open(p).read())
panel = next((s for s in c.sections() if c.has_option(s, "plugins")), "panel1")
if not c.has_section(panel): c.add_section(panel)
c.set(panel, "position", "Top")
with open(p, "w") as f: c.write(f, space_around_delimiters=False)
print("Barra de tareas:", panel, "-> arriba")
EOF
pkill -KILL -x lxqt-panel; sleep 3
pgrep -x lxqt-panel >/dev/null || setsid -f lxqt-panel </dev/null >/dev/null 2>&1
# Dock abajo, centrado, que se oculte solo si una ventana lo tapa
S=net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/
gsettings set $S position 'bottom'
gsettings set $S alignment 'center'
gsettings set $S hide-mode 'window-dodge'
gsettings set $S zoom-enabled true
gsettings set $S zoom-percent 130
# Widget un poco más abajo para no quedar pegado a la barra de arriba
sed -i 's/gap_y = 60/gap_y = 80/' ~/.config/conky/conky.conf 2>/dev/null
pkill -x plank; sleep 1; setsid -f plank </dev/null >/dev/null 2>&1
pkill -x conky; sleep 1; conky -d -q
sleep 2; pgrep -x lxqt-panel >/dev/null && pgrep -x plank >/dev/null && echo "LISTO: barra arriba, dock abajo"
