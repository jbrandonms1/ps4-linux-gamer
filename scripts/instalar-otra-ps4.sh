#!/bin/bash
# Sube todo lo necesario a OTRA PS4 (GoldHEN con FTP activo, puerto 2121) para instalar "ps4gamer".
# Uso: bash ~/ps4linux/instalar-otra-ps4.sh IP_DE_LA_OTRA_PS4
IP=${1:?Uso: $0 IP_DE_LA_OTRA_PS4}; F=ftp://$IP:2121; D=~/ps4linux
sube() { echo "-> $2$(basename "$1")"; curl -s --ftp-create-dirs -T "$1" "$F$2$(basename "$1")" || { echo "ERROR subiendo $1"; exit 1; }; }
until timeout 3 curl -s --list-only "$F/" >/dev/null 2>&1; do echo "Esperando FTP en $IP:2121..."; sleep 5; done
sube $D/bzImage            /data/linux/boot/
sube $D/initramfs.cpio.gz  /data/linux/boot/
sube $D/bootargs.txt       /data/linux/boot/
sube $D/linux-2048mb.bin   /data/payloads/
sube $D/pkg/PayloadGuest-v0.98.pkg /data/pkg/
sube $D/ps4-mesa.tar.xz    /user/home/
sube $D/ps4gamer-ps4-rootfs.tar.xz /user/home/
echo; echo "== Comprobación de tamaños"
for p in /data/linux/boot/bzImage /user/home/ps4gamer-ps4-rootfs.tar.xz /user/home/ps4-mesa.tar.xz; do
  r=$(curl -s "$F$(dirname $p)/" | awk -v n="$(basename $p)" '$NF==n{print $5}'); l=$(stat -c %s "$D/$( [ "$(basename $p)" = bzImage ] && echo bzImage || basename $p)")
  [ "$r" = "$l" ] && echo "OK  $p" || echo "MAL $p (remoto $r / local $l)"
done
echo; echo "LISTO. En la otra PS4: GoldHEN > Package Installer > Payload Guest; luego Payload Guest > linux-2048mb.bin > ps4gamer > Install to PS4 (64 GB o más)."
