#!/bin/bash
# Diagnóstico de fondo animado y Bluetooth. Ejecutar en el escritorio como archlinux:
#   curl -s IP_DE_TU_PC:8000/diag.sh | bash
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
OUT=$HOME/ps4-diag.txt
exec > >(tee "$OUT") 2>&1
trap 'echo "== FIN DIAG $(date)"; curl -s -T "$OUT" "http://$HOST/diag" >/dev/null' EXIT
[ -z "$DISPLAY" ] && export DISPLAY=:0

echo "===== FONDO ====="
ls -la ~/.config/autostart/ ~/.local/bin/ 2>&1
V="$(xdg-user-dir VIDEOS)/wallpaper.mp4"; ls -la "$V"
ffprobe -v error -show_entries format=duration:stream=codec_name,width,height -of compact "$V" </dev/null 2>&1
which xwinwrap mpv socat xprop
echo "-- procesos:"; pgrep -af 'xwinwrap|mpv|picom|plank|pcmanfm|fondo'
echo "-- sesión:"; echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE DESKTOP=$XDG_CURRENT_DESKTOP DISPLAY=$DISPLAY"
xrandr --current 2>&1 | head -5
echo "-- prueba mpv directa (5 s):"
timeout 5 mpv --no-audio --really-quiet=no --msg-level=all=warn --vo=gpu --length=2 "$V" </dev/null 2>&1 | tail -15
echo "-- prueba xwinwrap+mpv (8 s):"
timeout 8 xwinwrap -ov -fs -ni -s -st -sp -b -nf -- mpv -wid WID --no-audio --msg-level=all=warn --hwdec=no "$V" </dev/null 2>&1 | tail -15
echo "-- prueba script fondo (8 s):"
timeout 8 sh -x ~/.local/bin/fondo-animado.sh </dev/null 2>&1 | head -25
pkill -f fondo-animado.sh; pkill xwinwrap

echo; echo "===== BLUETOOTH ====="
rfkill list 2>&1
systemctl is-enabled bluetooth; systemctl is-active bluetooth
systemctl status bluetooth --no-pager 2>&1 | tail -12
bluetoothctl show 2>&1 | head -20
bluetoothctl devices 2>&1
ls /sys/class/bluetooth/ 2>&1
journalctl -b -k --no-pager 2>/dev/null | grep -iE 'bluetooth|btmrvl|hci|mwifiex|mt76|sdio' | tail -25 || sudo -n dmesg 2>/dev/null | grep -iE 'blue|btmrvl|hci' | tail -25
echo "-- escaneo 15 s (pon el control en modo emparejar: SHARE + PS hasta que parpadee):"
timeout 18 bluetoothctl --timeout 15 scan on 2>&1 | tail -20
bluetoothctl devices 2>&1
groups
