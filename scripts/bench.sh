#!/bin/bash
# Prueba de rendimiento PS4 Linux. Ejecutar en el ESCRITORIO como usuario normal (no root):
#   curl -s IP_DE_TU_PC:8000/bench.sh | bash
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
OUT=$HOME/ps4-bench.txt
exec > >(tee "$OUT") 2>&1
up() { curl -s -T "$OUT" "http://$HOST/bench" >/dev/null 2>&1; }
sec() { up; echo; echo "===== $* ====="; }
trap 'echo "== FIN BENCH $(date)"; up' EXIT

if [ "$(id -u)" = 0 ]; then echo "Ejecuta esto como usuario normal (archlinux), no como root."; exit 1; fi
[ -z "$DISPLAY" ] && export DISPLAY=:0

sec "0. Herramientas (pide la contraseña de archlinux)"
sudo pacman -S --noconfirm --needed mesa-utils vulkan-tools glmark2 7zip lm_sensors </dev/null || echo "AVISO: no se pudieron instalar herramientas"

sec "1. Sistema"
uname -r; grep -m1 'model name' /proc/cpuinfo; nproc; free -h; df -h /
cat /etc/environment
/opt/ps4-mesa/bin/ps4-mesa-check 2>&1 | head -30

sec "2. GPU OpenGL"
glxinfo -B 2>&1 | grep -E 'OpenGL renderer|OpenGL core profile version|OpenGL version|direct rendering|Accelerated|Video memory'

sec "3. GPU Vulkan"
vulkaninfo --summary 2>&1 | grep -E 'apiVersion|driverName|deviceName|deviceType|driverInfo' | head -12

sec "4. CPU (7-Zip, 1 núcleo y todos)"
7z b -mmt1 2>&1 | tail -4
7z b 2>&1 | tail -4

sec "5. Memoria (copia 16 GB en RAM)"
dd if=/dev/zero of=/dev/null bs=1M count=16384 2>&1 | tail -1

sec "6. Disco (imagen de Linux en el HDD de la PS4)"
F=$HOME/.bench.tmp
dd if=/dev/zero of=$F bs=1M count=1024 conv=fdatasync 2>&1 | tail -1
dd if=$F of=/dev/null bs=1M iflag=direct 2>&1 | tail -1
rm -f $F

sec "7. GPU glmark2 (1280x720, ~3 min, no toques nada)"
glmark2 -s 1280x720 \
  -b build:use-vbo=true -b texture:texture-filter=linear -b shading:shading=phong \
  -b bump:bump-render=normals -b effect2d:kernel=0,1,0\;1,-4,1\;0,1,0\; \
  -b pulsar:light=false:quads=5:texture=false -b desktop:blur-radius=5:effect=blur:passes=1:separable=true:windows=4 \
  -b refract -b terrain -b jellyfish 2>&1 | grep -E 'GL_RENDERER|GL_VERSION|FPS:|Score'

sec "8. Temperaturas"
sensors 2>/dev/null | grep -vE '^$' | head -20
cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null
