# Ajustes de RetroArch que marcan la diferencia en la PS4

Edita **con RetroArch cerrado** (al salir reescribe `retroarch.cfg` y los `.opt`).

## ~/.config/retroarch/retroarch.cfg
```
input_driver = "x"          # ¡clave! con "udev" llama a XGetInputFocus en cada lectura y los juegos van a ~30 FPS
input_joypad_driver = "udev"
```

## PS1 (PCSX ReARMed) — ~/.config/retroarch/config/PCSX-ReARMed/PCSX-ReARMed.cfg
```
video_driver = "glcore"
video_fullscreen = "true"
video_windowed_fullscreen = "false"
input_driver = "x"
```
Control con sticks: el tipo de mando va en el remap, no en el .cfg:
`~/.config/retroarch/config/remaps/PCSX-ReARMed/PCSX-ReARMed.rmp` → `input_libretro_device_p1 = "517"` (DualShock).
L3+R3 alterna el modo analógico. Juegos sin soporte analógico (p. ej. GTA 2) llevan su propio remap con
`input_libretro_device_p1 = "1"` y `input_player1_analog_dpad_mode = "1"`.

## Dreamcast (Flycast) — ~/.config/retroarch/config/Flycast/Flycast.opt
```
reicast_internal_resolution = "1280x960"
```
