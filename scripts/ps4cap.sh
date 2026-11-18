#!/bin/bash
# Uso: ps4cap.sh salida.png [filtro-ffmpeg]   -> captura la pantalla de la PS4 por SSH
ssh ps4 "export DISPLAY=:0 XAUTHORITY=\$(ls -t /tmp/xauth_* | head -1); ffmpeg -nostdin -loglevel error -f x11grab -i :0 -frames:v 1 ${2:+-vf $2} -f image2 -c:v png -" > "$1"
