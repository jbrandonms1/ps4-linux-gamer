#!/bin/bash
# Sube Payload Guest a la PS4 (GoldHEN FTP, puerto 2121) para instalarlo desde GoldHEN > Package Installer.
PS4=${PS4_IP:?Indica la IP de la PS4, ej.: PS4_IP=192.168.1.50 bash $0}
PKG=~/ps4linux/pkg/PayloadGuest-v0.98.pkg
echo "Esperando FTP de GoldHEN en $PS4:2121 (Ctrl+C para cancelar)..."
until timeout 3 curl -s --list-only "ftp://$PS4:2121/" >/dev/null 2>&1; do sleep 3; done
curl -s --ftp-create-dirs -T "$PKG" "ftp://$PS4:2121/data/pkg/PayloadGuest-v0.98.pkg" && echo "SUBIDO a /data/pkg"
curl -s --list-only "ftp://$PS4:2121/data/pkg/"
curl -s --list-only "ftp://$PS4:2121/data/payloads/"
