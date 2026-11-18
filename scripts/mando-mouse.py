#!/usr/bin/env python3
"""Control como mouse/teclado en el escritorio (DualShock 4 y cualquier gamepad).

  Stick izq.  -> mover puntero (R2 = rápido, L2 = preciso)
  Stick der.  -> desplazar (scroll)
  X           -> clic izquierdo        O -> clic derecho      Cuadrado -> clic central
  Triángulo   -> menú de apps (Super)  Cruceta -> flechas
  L1 / R1     -> pestaña anterior / siguiente (Ctrl+Shift+Tab / Ctrl+Tab)
  Share       -> Esc                   Options -> Enter
  L3          -> Alt+Izquierda (atrás) R3 -> F11 (pantalla completa)
  PS          -> activar / desactivar el modo mouse

Se pausa solo cuando hay un juego, emulador, Kodi o Steam abierto (ellos manejan el control).
"""
import os, re, select, subprocess, time
from evdev import InputDevice, UInput, ecodes as e, list_devices

PAUSA = re.compile(r'^(steam|gamescope|retroarch|dolphin-emu|PPSSPPSDL|PPSSPPQt|es-de|kodi|kodi\.bin|kodi-x11|'
                   r'wineserver|reaper|antimicrox|heroic|lutris)$')
DEAD, VEL, VEL_RAPIDO, VEL_LENTO = 0.12, 14.0, 32.0, 4.0

BOTONES = {e.BTN_SOUTH: [e.BTN_LEFT], e.BTN_EAST: [e.BTN_RIGHT], e.BTN_WEST: [e.BTN_MIDDLE],
           e.BTN_NORTH: [e.KEY_LEFTMETA], e.BTN_SELECT: [e.KEY_ESC], e.BTN_START: [e.KEY_ENTER],
           e.BTN_TL: [e.KEY_LEFTCTRL, e.KEY_LEFTSHIFT, e.KEY_TAB], e.BTN_TR: [e.KEY_LEFTCTRL, e.KEY_TAB],
           e.BTN_THUMBL: [e.KEY_LEFTALT, e.KEY_LEFT], e.BTN_THUMBR: [e.KEY_F11]}

def aviso(t):
    subprocess.Popen(['notify-send', '-t', '1500', 'Control', t], stderr=subprocess.DEVNULL)

import signal
signal.signal(signal.SIGCHLD, signal.SIG_IGN)   # no dejar procesos zombis de kodi-pip

def kodi_pantalla_completa():
    try:
        out = subprocess.run(['sh', '-c', "W=$(wmctrl -l -x | awk 'tolower($3) ~ /kodi/ {print $1; exit}'); "
                              "[ -n \"$W\" ] && xprop -id \"$W\" _NET_WM_STATE"],
                             capture_output=True, text=True, timeout=2).stdout
        return 'FULLSCREEN' in out
    except Exception:
        return True

def juego_abierto():
    for pid in os.listdir('/proc'):
        if pid.isdigit():
            try:
                with open(f'/proc/{pid}/comm') as f:
                    n = f.read().strip()
                    if n.startswith('kodi'):
                        if kodi_pantalla_completa(): return True
                        continue
                    if PAUSA.match(n): return True
            except OSError: pass
    return False

def buscar_mando():
    for path in list_devices():
        try:
            d = InputDevice(path)
            caps = d.capabilities()
            if e.BTN_SOUTH in caps.get(e.EV_KEY, []) and any(a[0] == e.ABS_X for a in caps.get(e.EV_ABS, [])):
                return d
        except OSError: pass
    return None

def norm(d, code, v):
    info = d.absinfo(code); mid = (info.max + info.min) / 2; half = (info.max - info.min) / 2 or 1
    x = (v - mid) / half
    return 0.0 if abs(x) < DEAD else (x - DEAD * (1 if x > 0 else -1)) / (1 - DEAD)

teclas = {k for v in BOTONES.values() for k in v} | {e.KEY_UP, e.KEY_DOWN, e.KEY_LEFT, e.KEY_RIGHT}
ui = UInput({e.EV_KEY: list(teclas), e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL, e.REL_HWHEEL,
             e.REL_WHEEL_HI_RES, e.REL_HWHEEL_HI_RES]}, name='Control-Mouse PS4')

activo, pausado, ultimo_chequeo = True, False, 0
presionados = set()

def kodi_abierto():
    for pid in os.listdir('/proc'):
        if pid.isdigit():
            try:
                with open(f'/proc/{pid}/comm') as f:
                    n = f.read().strip()
                if n.startswith('kodi'): return True
                if n == 'retroarch': return False
            except OSError: pass
    return False

while True:
    d = buscar_mando()
    if not d: time.sleep(2); continue
    aviso(f'{d.name} listo: modo mouse {"activo" if activo else "apagado"} (PS = cambiar)')
    ejes = {}; acum = {'x': 0.0, 'y': 0.0, 'w': 0.0, 'h': 0.0}
    try:
        while True:
            r, _, _ = select.select([d.fd], [], [], 1 / 90)
            if time.time() - ultimo_chequeo > 1:
                ultimo_chequeo = time.time(); p = juego_abierto()
                if p != pausado: pausado = p
            for ev in (d.read() if r else []):
                if ev.type == e.EV_ABS:
                    ejes[ev.code] = ev.value
                    if activo and not pausado and ev.code in (e.ABS_HAT0X, e.ABS_HAT0Y):
                        k = {(e.ABS_HAT0X, -1): e.KEY_LEFT, (e.ABS_HAT0X, 1): e.KEY_RIGHT,
                             (e.ABS_HAT0Y, -1): e.KEY_UP, (e.ABS_HAT0Y, 1): e.KEY_DOWN}.get((ev.code, ev.value))
                        if k: ui.write(e.EV_KEY, k, 1); ui.write(e.EV_KEY, k, 0); ui.syn()
                elif ev.type == e.EV_KEY:
                    if ev.value == 1: presionados.add(ev.code)
                    elif ev.value == 0: presionados.discard(ev.code)
                    # Share + Options: Kodi mini <-> pantalla completa
                    if ev.value == 1 and {e.BTN_SELECT, e.BTN_START} <= presionados and kodi_abierto():
                        subprocess.Popen([os.path.expanduser('~/.local/bin/kodi-pip')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        continue
                    if ev.code == e.BTN_MODE and ev.value == 1 and not pausado:
                        activo = not activo; aviso('Modo mouse ' + ('ACTIVO' if activo else 'APAGADO'))
                    elif activo and not pausado and ev.code in BOTONES and ev.value in (0, 1):
                        ks = BOTONES[ev.code]
                        for k in (ks if ev.value else reversed(ks)): ui.write(e.EV_KEY, k, ev.value)
                        ui.syn()
            if not activo or pausado: continue
            g = lambda c: norm(d, c, ejes[c]) if c in ejes else 0.0
            r2 = ejes.get(e.ABS_RZ, 0) > 60; l2 = ejes.get(e.ABS_Z, 0) > 60
            vel = VEL_RAPIDO if r2 else VEL_LENTO if l2 else VEL
            x, y = g(e.ABS_X), g(e.ABS_Y)
            acum['x'] += x * abs(x) * vel; acum['y'] += y * abs(y) * vel
            acum['w'] += -g(e.ABS_RY) * 0.35; acum['h'] += g(e.ABS_RX) * 0.35
            mx, my = int(acum['x']), int(acum['y']); w, h = int(acum['w'] * 120), int(acum['h'] * 120)
            if mx or my:
                ui.write(e.EV_REL, e.REL_X, mx); ui.write(e.EV_REL, e.REL_Y, my); acum['x'] -= mx; acum['y'] -= my
            if w:
                ui.write(e.EV_REL, e.REL_WHEEL_HI_RES, w)
                if abs(acum['w']) >= 1: ui.write(e.EV_REL, e.REL_WHEEL, int(acum['w']))
                acum['w'] -= w / 120
            if h:
                ui.write(e.EV_REL, e.REL_HWHEEL_HI_RES, h)
                if abs(acum['h']) >= 1: ui.write(e.EV_REL, e.REL_HWHEEL, int(acum['h']))
                acum['h'] -= h / 120
            if mx or my or w or h: ui.syn()
    except OSError:
        aviso('Control desconectado'); time.sleep(1)
