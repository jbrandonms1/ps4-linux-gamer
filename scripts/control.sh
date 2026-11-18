#!/bin/bash
# Empareja el DualShock 4 por cable USB (método más fiable). Ejecutar como archlinux:
#   curl -s IP_DE_TU_PC:8000/control.sh | bash
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
OUT=$HOME/ps4-control.txt
exec > >(tee "$OUT") 2>&1
trap 'echo "== FIN CONTROL $(date)"; curl -s -T "$OUT" "http://$HOST/control" >/dev/null' EXIT

echo "===== 1. Ajustes de BlueZ (contraseña: archlinux) ====="
sudo sed -i 's/^#\?ClassicBondedOnly=.*/ClassicBondedOnly=false/' /etc/bluetooth/input.conf
sudo sed -i 's/^#\? *JustWorksRepairing *=.*/JustWorksRepairing = always/; s/^#\? *FastConnectable *=.*/FastConnectable = true/' /etc/bluetooth/main.conf
grep -E '^(JustWorksRepairing|FastConnectable)' /etc/bluetooth/main.conf
grep -E '^ClassicBondedOnly' /etc/bluetooth/input.conf
sudo systemctl restart bluetooth; sleep 3
bluetoothctl power on >/dev/null

echo; echo "===== 2. Borrar emparejamiento anterior ====="
for m in $(bluetoothctl devices | grep -i 'Wireless Controller' | awk '{print $2}'); do bluetoothctl remove $m; done

echo; echo "===== 3. Emparejar por cable ====="
echo ">>> CONECTA AHORA EL CONTROL CON EL CABLE USB a la PS4 (tienes 60 segundos)."
USB=0
for i in $(seq 60); do
  grep -q 'Sony Interactive Entertainment Wireless Controller' /proc/bus/input/devices && lsusb 2>/dev/null | grep -qi '054c:' && { USB=1; break; }
  sleep 1
done
if [ $USB = 1 ]; then
  echo "Control detectado por USB. Grabando la llave de Linux en el control..."
  # El plugin 'sixaxis' de BlueZ pide autorización: se responde 'yes' automáticamente
  { echo "agent on"; echo "default-agent"; for i in $(seq 25); do sleep 1; echo "yes"; done; echo "quit"; } \
    | bluetoothctl 2>&1 | grep -viE 'invalid command|^\s*$' | tail -15
  MAC=$(bluetoothctl devices | grep -i 'Wireless Controller' | awk '{print $2}' | head -1)
  if [ -n "$MAC" ]; then
    bluetoothctl trust $MAC
    echo
    echo ">>> AHORA: DESCONECTA EL CABLE y presiona el botón PS (esperando 60 s)..."
    for i in $(seq 60); do
      bluetoothctl info $MAC | grep -q 'Connected: yes' && ! lsusb | grep -qi '054c:' && { echo "CONECTADO POR BLUETOOTH ✔"; break; }
      sleep 1
    done
    bluetoothctl info $MAC | grep -E 'Name|Paired|Trusted|Connected'
    exit 0
  fi
  echo "El emparejamiento por cable no funcionó; probando por Bluetooth..."
fi

echo; echo "===== 4. Emparejar por Bluetooth (sin conectar desde Linux) ====="
echo ">>> Desconecta el cable. Con el control APAGADO mantén SHARE + PS hasta el doble destello rápido."
bluetoothctl --timeout 60 scan on >/dev/null 2>&1 &
SCAN=$!; MAC=""
for i in $(seq 60); do
  MAC=$(bluetoothctl devices | grep -i 'Wireless Controller' | awk '{print $2}' | head -1)
  [ -n "$MAC" ] && break; sleep 1
done
kill $SCAN 2>/dev/null
[ -z "$MAC" ] && { echo "No se encontró el control."; exit 1; }
bluetoothctl pair $MAC; bluetoothctl trust $MAC
echo ">>> NO toques nada 5 s; luego presiona PS una vez (esperando 45 s)..."
for i in $(seq 45); do bluetoothctl info $MAC | grep -q 'Connected: yes' && { echo "CONECTADO ✔"; break; }; sleep 1; done
bluetoothctl info $MAC | grep -E 'Name|Paired|Trusted|Connected'
