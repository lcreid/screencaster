#!/bin/bash

# ffmpeg -f x11grab -r 25 -s 1024x768 -i :0.0+100,200 -f alsa -ac 2 -i pulse output.flv
# 
# # Grab first, then encode:
# ffmpeg -f x11grab -r 25 -s 1024x768 -i :0.0+100,200 -f alsa -ac 2 -i pulse -vcodec libx264 -crf 0 -preset ultrafast -acodec pcm_s16le output.flv
# ffmpeg -i output.flv -acodec ... -vcodec ... final.flv

echo "*** Click on the window to be recorded ***"
INFO=$(xwininfo -frame)
WIN_GEO=$(echo $INFO | 
  grep -oEe 'geometry [0-9]+x[0-9]+' | 
  grep -oEe '[0-9]+x[0-9]+')
WIN_XY=$(echo $INFO | 
  grep -oEe 'Corners:\s+\+[0-9]+\+[0-9]+' | 
  grep -oEe '[0-9]+\+[0-9]+' | 
  sed -e 's/+/,/' )
FPS="25"
VIDEO_OPTIONS="-vcodec theora"
AUDIO_OPTIONS="-f alsa -i pulse"
avconv -f x11grab \
  -s ${WIN_GEO} \
  -r ${FPS} \
  -i :0.0+${WIN_XY} \
  -threads 2 \
  -y \
  ${VIDEO_OPTIONS} \
  ${AUDIO_OPTIONS} \
  ${1:-output}.ogv

