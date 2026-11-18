#!/bin/bash
# Diagnóstico Bluetooth del control.   curl -s IP_DE_TU_PC:8000/btdiag.sh | bash
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
OUT=$HOME/ps4-btdiag.txt
exec > >(tee "$OUT") 2>&1
trap 'echo "== FIN BTDIAG $(date)"; curl -s -T "$OUT" "http://$HOST/btdiag" >/dev/null' EXIT
echo "===== Adaptador (contraseña: archlinux) ====="
sudo btmgmt info 2>&1 | head -20
bluetoothctl show | grep -E 'Powered|Discoverable|Pairable|Connectable'
echo; echo "===== Control guardado ====="
bluetoothctl devices
for m in $(bluetoothctl devices | grep -i 'Wireless Controller' | awk '{print $2}'); do bluetoothctl info $m; done
sudo ls -la /var/lib/bluetooth/*/ 2>&1
for m in $(bluetoothctl devices | grep -i 'Wireless Controller' | awk '{print $2}'); do sudo cat /var/lib/bluetooth/*/$m/info 2>&1 | grep -vE '^Key=' ; done
lsmod | grep -iE 'hid_playstation|hid_sony|hidp|btmrvl'
echo; echo "===== Captura de 40 s ====="
echo ">>> DESCONECTA el cable. Cuando veas 'GRABANDO', presiona el botón PS del control UNA vez y espera."
sleep 3
sudo timeout 40 btmon > /tmp/btmon.txt 2>&1 &
sleep 1; echo ">>> GRABANDO... presiona PS ahora"
sudo journalctl -f -u bluetooth --no-pager -n 0 > /tmp/bluez.txt 2>&1 &
J=$!
wait %1 2>/dev/null; sleep 40; sudo kill $J 2>/dev/null
echo; echo "-- bluetoothd:"; cat /tmp/bluez.txt | tail -30
echo; echo "-- btmon (eventos clave):"
grep -E 'Connect Request|Connection Complete|Disconn|Link Key|PIN Code|IO Capability|Auth|Encrypt|Status|Reason|Address:' /tmp/btmon.txt | head -80
echo; echo "-- btmon líneas: $(wc -l < /tmp/btmon.txt)"
