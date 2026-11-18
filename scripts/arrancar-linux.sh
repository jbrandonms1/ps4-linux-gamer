#!/bin/bash
# Envía el payload de Linux a la PS4 por la red (GoldHEN BinLoader, puerto 9090).
# En la PS4: activa GoldHEN y en su menú "BinLoader Server" = ON. Luego en la laptop:
#   bash ~/ps4linux/arrancar-linux.sh
PS4=${PS4_IP:?Indica la IP de la PS4, ej.: PS4_IP=192.168.1.50 bash $0}
PAY=~/ps4linux/linux-2048mb.bin
echo "Esperando GoldHEN BinLoader en $PS4:9090 (Ctrl+C para cancelar)..."
until timeout 2 bash -c "</dev/tcp/$PS4/9090" 2>/dev/null; do sleep 3; done
echo "Enviando payload..."
python3 - "$PS4" "$PAY" <<'PY'
import socket, sys
s = socket.create_connection((sys.argv[1], 9090), timeout=10)
s.sendall(open(sys.argv[2], 'rb').read()); s.close()
print("Payload enviado. En la TV: elige archlinux -> Boot (tarda 1-2 min).")
PY
