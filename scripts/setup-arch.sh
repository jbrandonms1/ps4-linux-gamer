#!/bin/bash
# PS4 (CUH-2115B Baikal) -> Arch Linux "PC gamer". ps4-multiboot + ps4-mesa.
# Ejecutar como root:  su -c "curl -s IP_DE_TU_PC:8000/s | bash"
# Va subiendo el log al portátil después de cada paso.
HOST=${HOST:-IP_DE_TU_PC:8000}   # IP de tu PC (donde corre serve.py)
LOG=/root/ps4-setup.log
USR=archlinux
HOME_U=/home/$USR
PAC="pacman -S --noconfirm --needed"
[ -f "$LOG" ] && mv "$LOG" "$LOG.old"; exec > >(tee "$LOG") 2>&1
up() { curl -s -m 20 -T "$LOG" "http://$HOST/log" >/dev/null; }
trap 'echo "== FIN (exit $?) $(date)"; up' EXIT
step() { up; echo; echo "===== $* ====="; }
warn() { echo "AVISO: $*"; }
clear

step "1. Hora, zona horaria e idioma"
D=$(curl -sI "http://$HOST/" | sed -n 's/^[Dd]ate: //p' | tr -d '\r')
[ -n "$D" ] && date -s "$D"
ln -sf /usr/share/zoneinfo/America/Mexico_City /etc/localtime
sed -i 's/^#\(es_MX.UTF-8\)/\1/; s/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=es_MX.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
systemctl enable systemd-timesyncd 2>/dev/null
date

# DNS: si resolv.conf apunta a systemd-resolved (apagado), dejar que NetworkManager lo escriba
if ! getent hosts archlinux.org >/dev/null; then
  echo "DNS roto, reparando resolv.conf..."
  rm -f /etc/resolv.conf
  systemctl is-active -q NetworkManager && systemctl restart NetworkManager && sleep 8
  getent hosts archlinux.org >/dev/null || printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
  getent hosts archlinux.org && echo "DNS OK"
fi

step "2. pacman: servidores, multilib, claves"
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
EOF
sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
# El kernel de PS4 no tiene Landlock: desactivar el sandbox de descarga de pacman 7
sed -i 's/^DownloadUser/#DownloadUser/' /etc/pacman.conf
grep -q '^DisableSandbox' /etc/pacman.conf || sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf
grep -nE '^(DisableSandbox|#?DownloadUser)' /etc/pacman.conf
sed -i 's/^#Color/Color/; s/^#\?ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
grep -A1 '^\[multilib\]' /etc/pacman.conf
pacman-key --init && pacman-key --populate archlinux
pacman -Sy --noconfirm archlinux-keyring || { echo "ERROR: pacman no sincroniza"; exit 1; }

step "3. Actualizar sistema completo"
pacman -Su --noconfirm || exit 1

step "4. Base: sudo, herramientas, usuario"
$PAC sudo base-devel git terminus-font htop btop fastfetch unzip 7zip \
     ntfs-3g exfatprogs gvfs xdg-user-dirs zram-generator cpupower || exit 1
usermod -aG wheel,video,audio,input,render "$USR" 2>/dev/null || usermod -aG wheel,video,audio,input "$USR"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel; chmod 440 /etc/sudoers.d/wheel
echo 'FONT=ter-132n' >> /etc/vconsole.conf; setfont ter-132n 2>/dev/null

step "5. Escritorio LXQt, red, audio, bluetooth"
$PAC xorg-server xorg-xinit xorg-xrandr \
     lxqt libsysstat openbox breeze-icons papirus-icon-theme kvantum sddm \
     networkmanager network-manager-applet \
     pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber lib32-pipewire lib32-libpulse pavucontrol-qt \
     bluez bluez-utils blueman \
     noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-dejavu ttf-liberation \
     firefox mpv lxqt-archiver featherpad qterminal pcmanfm-qt || exit 1
systemctl enable sddm NetworkManager bluetooth
systemctl disable systemd-networkd systemd-resolved 2>/dev/null   # NetworkManager toma la red desde el próximo arranque
[ -L /etc/resolv.conf ] && [ -s /run/systemd/resolve/resolv.conf ] && cp --remove-destination /run/systemd/resolve/resolv.conf /etc/resolv.conf
mkdir -p /etc/NetworkManager/conf.d
printf '[device]\nwifi.scan-rand-mac-address=no\n[connection]\nwifi.cloned-mac-address=permanent\n' \
  > /etc/NetworkManager/conf.d/ps4-wifi.conf

step "6. Gráficos y juegos (repos oficiales)"
$PAC mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader \
     mesa-utils vulkan-tools \
     steam gamescope mangohud lib32-mangohud gamemode lib32-gamemode goverlay \
     lutris wine-staging winetricks wine-mono wine-gecko \
     antimicrox discord steam-devices evtest || warn "fallo en paquetes de juego"

step "6b. Multimedia (centro de medios y códecs)"
$PAC kodi kodi-addon-inputstream-adaptive kodi-addon-peripheral-joystick \
     vlc vlc-plugins-all ffmpeg ffmpegthumbnailer yt-dlp \
     gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav \
     libdvdcss libbluray spotify-launcher || warn "fallo en multimedia"

step "7. Emuladores"
$PAC retroarch retroarch-assets-xmb libretro-core-info \
     libretro-snes9x libretro-mgba libretro-genesis-plus-gx libretro-nestopia \
     libretro-beetle-psx libretro-mupen64plus-next libretro-flycast \
     dolphin-emu ppsspp || warn "fallo en emuladores"

step "8. AUR: yay, Heroic, ProtonUp-Qt, reglas de mandos"
echo "$USR ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/zz-tmp-aur; chmod 440 /etc/sudoers.d/zz-tmp-aur
sudo -u "$USR" bash -c '
  set -e; cd /tmp; rm -rf yay-bin
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm
' || warn "no se pudo instalar yay"
if command -v yay >/dev/null; then
  sudo -u "$USR" yay -S --noconfirm --needed --answerdiff None --answerclean None \
       heroic-games-launcher-bin protonup-qt game-devices-udev || warn "fallo en paquetes AUR"
  up; echo "Compilando EmulationStation-DE (menú de emuladores). En la PS4 tarda ~30-60 min..."
  sudo -u "$USR" yay -S --noconfirm --needed --answerdiff None --answerclean None \
       emulationstation-de || warn "fallo compilando EmulationStation-DE"
fi
rm -f /etc/sudoers.d/zz-tmp-aur

step "9. Drivers 3D de PS4 (ps4-mesa)"
if [ ! -x /opt/ps4-mesa/bin/ps4-mesa-enable ]; then
  echo "ps4-mesa no estaba, instalando..."
  curl -fL -o /root/ps4-mesa.tar.xz "http://$HOST/ps4-mesa.tar.xz" \
   || curl -fL -o /root/ps4-mesa.tar.xz https://github.com/blue0x1/ps4-multiboot/releases/download/v1.5.0-beta.5/ps4-mesa.tar.xz
  tar -xJf /root/ps4-mesa.tar.xz -C /
fi
/opt/ps4-mesa/bin/ps4-mesa-enable   # se re-aplica tras instalar el Mesa del sistema
ls /opt/ps4-mesa/bin

step "10. Rendimiento"
printf '[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd\n' > /etc/systemd/zram-generator.conf
printf 'vm.swappiness = 100\nvm.page-cluster = 0\n' > /etc/sysctl.d/90-zram.conf
sed -i "s/^#\?governor=.*/governor='performance'/" /etc/default/cpupower 2>/dev/null
systemctl enable cpupower 2>/dev/null
gpasswd -a "$USR" gamemode 2>/dev/null

step "11. Personalización (tema oscuro, autologin, ajuste de bordes)"
mkdir -p /etc/sddm.conf.d
printf '[Autologin]\nUser=%s\nSession=lxqt.desktop\n' "$USR" > /etc/sddm.conf.d/autologin.conf
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<'EOF'
Section "InputClass"
    Identifier "teclado"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us"
EndSection
EOF
sudo -u "$USR" xdg-user-dirs-update 2>/dev/null
mkdir -p $HOME_U/.config/lxqt $HOME_U/.config/autostart $HOME_U/.local/bin $HOME_U/.config/MangoHud
cat > $HOME_U/.config/lxqt/lxqt.conf <<'EOF'
[General]
theme=dark
icon_theme=Papirus-Dark
[Qt]
style=Fusion
EOF
# Corrige el recorte de la tele (overscan): overscan.sh <horizontal> <vertical>; borra el autostart si sobra.
cat > $HOME_U/.local/bin/overscan.sh <<'EOF'
#!/bin/sh
H=${1:-48}; V=${2:-27}
for o in $(xrandr | awk '/ connected/{print $1}'); do
  xrandr --output "$o" --set underscan on --set "underscan hborder" "$H" --set "underscan vborder" "$V" 2>/dev/null
done
EOF
chmod +x $HOME_U/.local/bin/overscan.sh
printf '[Desktop Entry]\nType=Application\nName=Overscan\nExec=%s/.local/bin/overscan.sh\n' "$HOME_U" > $HOME_U/.config/autostart/overscan.desktop
printf 'fps\ngpu_stats\ncpu_stats\nram\nvram\nposition=top-left\n' > $HOME_U/.config/MangoHud/MangoHud.conf
# Accesos directos en el escritorio (centro gamer/multimedia)
DESK=$(sudo -u "$USR" xdg-user-dir DESKTOP 2>/dev/null); DESK=${DESK:-$HOME_U/Desktop}; mkdir -p "$DESK"
for app in steam emulationstation-de org.libretro.RetroArch heroic net.davidotek.pupgui2 lutris kodi vlc spotify-launcher firefox discord; do
  f=$(ls /usr/share/applications/$app*.desktop 2>/dev/null | head -1)
  [ -n "$f" ] && cp "$f" "$DESK/" && chmod +x "$DESK/$(basename "$f")"
done
chown -R "$USR:$USR" $HOME_U/.config $HOME_U/.local "$DESK"

step "11b. Fondo animado, dock, menú de apps, efectos y tema"
$PAC picom rofi plank xdotool socat wmctrl xorg-xprop xorg-xwininfo kvantum-theme-materia mpv ffmpeg \
  || warn "fallo en paquetes de escritorio"
command -v yay >/dev/null && {
  echo "$USR ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/zz-tmp-aur; chmod 440 /etc/sudoers.d/zz-tmp-aur
  sudo -u "$USR" yay -S --noconfirm --needed --answerdiff None --answerclean None xwinwrap-git || warn "fallo xwinwrap"
  rm -f /etc/sudoers.d/zz-tmp-aur; }

# Vídeo de fondo generado localmente (degradado animado, bucle sin cortes). Reemplazable por ~/Videos/wallpaper.mp4
VID=$(sudo -u "$USR" xdg-user-dir VIDEOS 2>/dev/null); VID=${VID:-$HOME_U/Videos}; mkdir -p "$VID"
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VID/wallpaper.mp4" 2>/dev/null </dev/null | cut -d. -f1); if [ "${D:-0}" -lt 29 ]; then
  echo "Generando fondo animado..."
  ffmpeg -nostdin -loglevel error -y -f lavfi \
    -i "gradients=s=960x540:rate=24:duration=15:speed=0.012:n=4:c0=0x0f0c29:c1=0x302b63:c2=0x1a1a40:c3=0x7b2ff7" \
    -filter_complex "[0]format=yuv420p,split[a][b];[b]reverse[r];[a][r]concat=n=2:v=1:a=0" \
    -c:v libx264 -preset veryfast -crf 24 -pix_fmt yuv420p "$VID/wallpaper.mp4" </dev/null || warn "no se pudo generar el fondo"
fi

mkdir -p $HOME_U/.local/bin $HOME_U/.config/autostart $HOME_U/.config/picom $HOME_U/.config/rofi \
         $HOME_U/.config/Kvantum $HOME_U/.config/plank/dock1/launchers $HOME_U/.local/share/applications

# Fondo animado: mpv dentro de xwinwrap, se pausa con juegos/emuladores a pantalla completa
cat > $HOME_U/.local/bin/fondo-animado.sh <<'EOF'
#!/bin/sh
# Uso: fondo-animado.sh [video]   |  Para quitarlo: borra ~/.config/autostart/fondo-animado.desktop
V="${1:-$(xdg-user-dir VIDEOS)/wallpaper.mp4}"
SOCK=/tmp/fondo-mpv-$USER
pkill -f "xwinwrap.*fondo-mpv" 2>/dev/null; sleep 1
command -v xwinwrap >/dev/null || exit 0
xwinwrap -ov -fs -ni -s -st -sp -b -nf -- \
  mpv -wid %WID --loop-file=inf --no-audio --no-osc --no-osd-bar --no-input-default-bindings \
      --hwdec=no --panscan=1.0 --profile=fast --input-ipc-server=$SOCK "$V" &
# Pausa mientras hay un juego o emulador abierto (ahorra CPU/GPU)
JUEGOS='gamescope|steamapps|reaper|wine|proton|retroarch|dolphin-emu|PPSSPP|es-de|emulationstation|kodi|heroic.*game'
P=0
while sleep 3; do
  if pgrep -f "$JUEGOS" >/dev/null || xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $NF}' \
       | xargs -r -I{} xprop -id {} _NET_WM_STATE 2>/dev/null | grep -q FULLSCREEN; then
    [ $P = 0 ] && echo '{"command":["set_property","pause",true]}' | socat - $SOCK >/dev/null 2>&1 && P=1
  else
    [ $P = 1 ] && echo '{"command":["set_property","pause",false]}' | socat - $SOCK >/dev/null 2>&1 && P=0
  fi
done
EOF
chmod +x $HOME_U/.local/bin/fondo-animado.sh
printf '[Desktop Entry]\nType=Application\nName=Fondo animado\nExec=%s/.local/bin/fondo-animado.sh\nX-LXQt-Need-Tray=false\n' "$HOME_U" \
  > $HOME_U/.config/autostart/fondo-animado.desktop
# El escritorio de pcmanfm-qt taparía el vídeo: se desactiva y los accesos pasan al dock
printf '[Desktop Entry]\nType=Application\nName=Desktop\nHidden=true\n' > $HOME_U/.config/autostart/lxqt-desktop.desktop

# Compositor con animaciones (se desactiva solo en juegos a pantalla completa)
cat > $HOME_U/.config/picom/picom.conf <<'EOF'
backend = "glx";
vsync = true;
unredir-if-possible = true;
shadow = true; shadow-radius = 14; shadow-opacity = 0.45; shadow-offset-x = -10; shadow-offset-y = -10;
shadow-exclude = [ "class_g = 'Plank'", "_NET_WM_WINDOW_TYPE@:a *= 'DESKTOP'" ];
fading = true; fade-in-step = 0.06; fade-out-step = 0.06;
corner-radius = 10;
rounded-corners-exclude = [ "window_type = 'dock'", "window_type = 'desktop'" ];
animations = (
  { triggers = ["open", "show"];  preset = "appear";    duration = 0.18; },
  { triggers = ["close", "hide"]; preset = "disappear"; duration = 0.14; }
);
EOF
printf '[Desktop Entry]\nType=Application\nName=Picom\nExec=picom --config %s/.config/picom/picom.conf\n' "$HOME_U" \
  > $HOME_U/.config/autostart/picom.desktop

# Dock con los programas principales
printf '[Desktop Entry]\nType=Application\nName=Plank\nExec=plank\n' > $HOME_U/.config/autostart/plank.desktop
i=0
for app in menu-juegos steam emulationstation-de org.libretro.RetroArch heroic lutris kodi spotify-launcher vlc firefox discord pcmanfm-qt qterminal; do
  f=$(ls /usr/share/applications/$app*.desktop $HOME_U/.local/share/applications/$app*.desktop 2>/dev/null | head -1)
  [ -z "$f" ] && [ "$app" = menu-juegos ] && f=$HOME_U/.local/share/applications/menu-juegos.desktop
  [ -n "$f" ] || continue
  i=$((i+1)); printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$f" \
    > "$HOME_U/.config/plank/dock1/launchers/$(printf %02d $i)-$app.dockitem"
done

# Menú de aplicaciones a pantalla completa (rofi), tema oscuro con iconos
cat > $HOME_U/.config/rofi/config.rasi <<'EOF'
configuration { modi: "drun,window"; show-icons: true; icon-theme: "Papirus-Dark"; display-drun: "Apps"; drun-display-format: "{name}"; }
* { bg: #12101fdd; fg: #e6e1ff; acc: #7b2ff7; background-color: transparent; text-color: @fg; font: "Noto Sans 14"; }
window { fullscreen: true; background-color: @bg; padding: 8% 12%; }
mainbox { spacing: 24px; }
inputbar { padding: 14px 20px; border-radius: 14px; background-color: #ffffff14; children: [prompt, entry]; spacing: 12px; }
prompt { text-color: @acc; }
listview { columns: 6; lines: 3; spacing: 18px; fixed-columns: true; }
element { orientation: vertical; padding: 18px; border-radius: 16px; spacing: 10px; }
element selected { background-color: @acc; }
element-icon { size: 72px; horizontal-align: 0.5; }
element-text { horizontal-align: 0.5; }
EOF
cat > $HOME_U/.local/share/applications/menu-juegos.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Menú
Comment=Todas las aplicaciones
Icon=applications-games
Exec=rofi -show drun
EOF
# Tecla Super (Windows) abre el menú
cat > $HOME_U/.config/lxqt/globalkeyshortcuts.conf <<'EOF'
[General]
version=1.0

[Super_L.1]
Comment=Menu rofi
Enabled=true
Exec=rofi, -show, drun
EOF

# Tema: Kvantum Materia oscuro
printf '[General]\ntheme=MateriaDark\n' > $HOME_U/.config/Kvantum/kvantum.kvconfig
sed -i 's/^style=.*/style=kvantum/' $HOME_U/.config/lxqt/lxqt.conf
chown -R "$USR:$USR" $HOME_U/.config $HOME_U/.local "$VID"

step "12. Diagnóstico"
uname -r
grep -m1 'model name' /proc/cpuinfo; grep -qw avx2 /proc/cpuinfo && echo "AVX2: sí" || echo "AVX2: no"
free -h; df -h /
lspci -nn | grep -iE 'vga|display|audio|network|ethernet'
cat /etc/environment
dmesg | grep -iE 'ps4-linux|3D graphics|amdgpu.*(error|fail)' | tail -30
vulkaninfo --summary 2>&1 | tail -30
echo "-- Bluetooth:"; ls /sys/class/bluetooth 2>&1; dmesg | grep -iE 'bluetooth|btmtk|btmrvl|hci0' | tail -8
echo "-- Mandos/entrada:"; ls /dev/input/js* 2>&1; grep -E 'Name=' /proc/bus/input/devices | head -15
echo "-- Paquetes:"; pacman -Q steam lutris retroarch dolphin-emu ppsspp kodi vlc yay heroic-games-launcher-bin emulationstation-de 2>&1

step "LISTO. Reinicia con: reboot   (menu: archlinux -> Boot). Arrancará directo al escritorio."
