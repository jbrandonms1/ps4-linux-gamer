#!/bin/bash
# Fondo animado v2: 5 escenas (gradientes de distintas formas/paletas + patrones) con transiciones,
# variación de tono suave y bucle sin cortes. Uso: fondo-v2.sh [salida] [ancho] [alto] [seg_por_escena]
OUT=${1:-$HOME/Videos/wallpaper-v2.mp4}; W=${2:-1280}; H=${3:-720}; D=${4:-30}; T=3; R=24
L=$((D+T))                       # cada escena dura D+T para solapar la transición
G="s=${W}x${H}:rate=$R:duration=$L:seed=7"
PW=$((W/4)); PH=$((H/4))

ffmpeg -nostdin -loglevel error -y \
 -f lavfi -i "gradients=$G:type=radial:speed=0.012:n=5:c0=0x3a0ca3:c1=0x7209b7:c2=0xf72585:c3=0x4361ee:c4=0x4cc9f0" \
 -f lavfi -i "gradients=$G:type=linear:speed=0.008:n=4:c0=0x00241b:c1=0x0b6e4f:c2=0x08a4bd:c3=0x7400b8" \
 -f lavfi -i "gradients=$G:type=spiral:speed=0.010:n=5:c0=0x240046:c1=0x9d0208:c2=0xf48c06:c3=0xff006e:c4=0x3c096c" \
 -f lavfi -i "gradients=$G:type=circular:speed=0.009:n=4:c0=0x03045e:c1=0x0077b6:c2=0x00b4d8:c3=0x90e0ef" \
 -f lavfi -i "gradients=$G:type=square:speed=0.007:n=4:c0=0x10002b:c1=0x240046:c2=0x5a189a:c3=0x9d4edd" \
 -f lavfi -i "life=s=${PW}x${PH}:rate=$R:mold=12:ratio=0.08:seed=3:life_color=#c77dff:death_color=#10002b:mold_color=#3c096c" \
 -f lavfi -i "cellauto=s=${PW}x${PH}:rate=$R:rule=110:scroll=1:full=1:seed=5" \
 -filter_complex "
  [0]format=yuv420p,split[s1a][s1b];
  [s1a]trim=start=$T:end=$L,setpts=PTS-STARTPTS[s1];
  [s1b]trim=start=0:end=$T,setpts=PTS-STARTPTS[s1h];
  [1]format=yuv420p[s2];
  [2]format=yuv420p[s3];
  [5]trim=duration=$L,scale=${W}x${H}:flags=bicubic,gblur=sigma=3,format=yuv420p[life];
  [3]format=yuv420p[g4];
  [g4][life]blend=all_mode=screen:all_opacity=0.55,format=yuv420p[s4];
  [6]trim=duration=$L,scale=${W}x${H}:flags=bicubic,gblur=sigma=3,negate,format=yuv420p[ca];
  [4]format=yuv420p[g5];
  [g5][ca]blend=all_mode=softlight:all_opacity=0.30,format=yuv420p[s5];
  [s1][s2]xfade=transition=fade:duration=$T:offset=$((D-T))[x1];
  [x1][s3]xfade=transition=smoothleft:duration=$T:offset=$((2*D-T))[x2];
  [x2][s4]xfade=transition=circleopen:duration=$T:offset=$((3*D-T))[x3];
  [x3][s5]xfade=transition=dissolve:duration=$T:offset=$((4*D-T))[x4];
  [x4][s1h]xfade=transition=fade:duration=$T:offset=$((5*D-T)),
    hue=h='18*sin(2*PI*t/$((5*D)))',vignette=PI/5,format=yuv420p[v]" \
 -map "[v]" -c:v libx264 -preset veryfast -crf 22 -pix_fmt yuv420p -movflags +faststart "$OUT"
