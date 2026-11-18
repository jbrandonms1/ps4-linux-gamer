#!/bin/bash
# Comparte ~/Videos, ~/Music y ~/Pictures de la laptop para Kodi en la PS4 (solo lectura, puerto 8090).
# Ejecuta:  bash ~/ps4linux/compartir-medios.sh   (Ctrl+C para dejar de compartir)
cd ~/ps4linux/medios || exit 1
echo "Compartiendo Videos/Music/Pictures en http://$(hostname -I | awk '{print $1}'):8090  (Ctrl+C para parar)"
exec python3 -m http.server 8090 --bind 0.0.0.0
