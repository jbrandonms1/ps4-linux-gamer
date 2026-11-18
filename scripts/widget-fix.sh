#!/bin/bash
# Ajustes del widget conky.   curl -s IP_DE_TU_PC:8000/widget-fix.sh | bash
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
OUT=$HOME/ps4-widget.txt
exec > >(tee "$OUT") 2>&1
trap 'echo "== FIN WIDGET $(date)"; curl -s -T "$OUT" "http://$HOST/widget" >/dev/null' EXIT
[ -z "$DISPLAY" ] && export DISPLAY=:0
C=~/.config/conky/conky.conf; cp "$C" "$C.bak"
echo "-- sensores GPU disponibles:"; ls /sys/class/drm/card*/device/ 2>/dev/null | grep -E 'busy|vram|pp_dpm' | head
python3 - "$C" <<'PYEOF'
import sys, re
p = sys.argv[1]; s = open(p).read()
F = "${font Symbols Nerd Font:size=12}"
out = []
for line in s.split("\n"):
    if "vram.sh" in line or "gpu_busy_percent" in line:
        if "GPU" in line:   # cabecera GPU: info fija (el kernel PS4 no expone el uso)
            ico = re.search(r"\$\{color1\}(.)\$\{font\}", line)
            i = ico.group(1) if ico else ""
            out.append("${voffset 4}" + F + "${color1}" + i + "${font}${color}  ${font Noto Sans:bold:size=10}GPU${font} ${color3}Liverpool 18 CU${color}${alignr}${color5}Vulkan 1.3 · GL 4.6${color}")
        continue
    if "VRAM" in line: continue
    line = line.replace("↓", F + "\U000f0045${font}").replace("↑", F + "\U000f005d${font}")
    line = line.replace("ff4fd8 -t}", "ff4fd8}")
    line = re.sub(r"\$\{cpugraph cpu0 34,330 [0-9a-f]+ [0-9a-f]+\}", "${cpugraph cpu0 40,330 7b2ff7 ff4fd8}", line)
    out.append(line)
s = "\n".join(out)
s = s.replace("draw_graph_borders = false", "draw_graph_borders = true")
s = s.replace("default_color = 'e8e6ff',", "default_color = 'e8e6ff', default_outline_color = '2e2a58',")
open(p, "w").write(s)
print("widget actualizado")
PYEOF
grep -n 'GPU\|cpugraph\|downspeed' "$C" | cut -c1-140
pkill -x conky; sleep 1; conky -d -q 2>/tmp/conky.log && echo "WIDGET OK"
sleep 5
ffmpeg -nostdin -loglevel error -y -f x11grab -i "$DISPLAY" -frames:v 1 -vf scale=960:-1 /tmp/captura-widget.png </dev/null \
  && curl -s -T /tmp/captura-widget.png "http://$HOST/widget.png" >/dev/null && echo "(captura enviada)"
