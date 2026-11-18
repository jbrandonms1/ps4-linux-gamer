#!/bin/bash
# SSH con llave (solo red local) + cambio de contraseñas. Ejecutar como ROOT:
#   su -c "curl -s IP_DE_TU_PC:8000/ssh.sh | bash"
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
USR=archlinux
OUT=/root/ps4-ssh.txt
exec > >(tee "$OUT") 2>&1
trap 'echo "== FIN SSH $(date)"; curl -s -T "$OUT" "http://$HOST/ssh" >/dev/null' EXIT
[ "$(id -u)" = 0 ] || { echo "Ejecuta con: su -c \"curl -s $HOST/ssh.sh | bash\""; exit 1; }

echo "===== 1. OpenSSH + nombre en la red (archlinux-ps4.local) ====="
pacman -S --noconfirm --needed openssh avahi nss-mdns </dev/null
sed -i 's/^hosts:.*mymachines/& mdns_minimal [NOTFOUND=return]/' /etc/nsswitch.conf
grep -q mdns_minimal /etc/nsswitch.conf || sed -i 's/^hosts: /hosts: mdns_minimal [NOTFOUND=return] /' /etc/nsswitch.conf
systemctl enable --now avahi-daemon

echo; echo "===== 2. Llave de la laptop (solo esa llave puede entrar) ====="
KEY=$(curl -s "http://$HOST/laptop.pub")
case "$KEY" in ssh-ed25519\ *) ;; *) echo "ERROR: no se pudo bajar la llave"; exit 1;; esac
for H in /home/$USR /root; do
  mkdir -p $H/.ssh; chmod 700 $H/.ssh
  grep -qF "$KEY" $H/.ssh/authorized_keys 2>/dev/null || echo "$KEY" >> $H/.ssh/authorized_keys
  chmod 600 $H/.ssh/authorized_keys
done
chown -R $USR:$USR /home/$USR/.ssh

cat > /etc/ssh/sshd_config.d/10-ps4.conf <<'EOF'
# Solo llaves, nada de contraseñas por red. Root solo con llave.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
EOF
ssh-keygen -A
sshd -t && systemctl enable --now sshd && systemctl restart sshd
systemctl is-active sshd
ip -4 -o addr show | awk '!/ lo /{print "IP:", $2, $4}'
hostnamectl hostname 2>/dev/null

echo; echo "===== 3. Cambio de contraseñas ====="
echo "Escribe la NUEVA contraseña para el usuario '$USR' (no se ve al escribir; dos veces)."
until passwd $USR </dev/tty; do echo "Inténtalo otra vez."; done
echo
echo "Ahora la NUEVA contraseña para 'root' (puede ser distinta; dos veces)."
until passwd root </dev/tty; do echo "Inténtalo otra vez."; done
echo
echo "LISTO: contraseñas cambiadas y SSH activo (solo con la llave de la laptop)."
