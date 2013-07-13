#!/bin/bash

# ffmpeg -f x11grab -r 25 -s 1024x768 -i :0.0+100,200 -f alsa -ac 2 -i pulse output.flv
# 
# # Grab first, then encode:
# ffmpeg -f x11grab -r 25 -s 1024x768 -i :0.0+100,200 -f alsa -ac 2 -i pulse -vcodec libx264 -crf 0 -preset ultrafast -acodec pcm_s16le output.flv
# ffmpeg -i output.flv -acodec ... -vcodec ... final.flv

echo "*** Click on the window to be recorded ***"
INFO=$(xwininfo)

WIN_GEO=$(echo "$INFO" | 
  grep -oEe 'geometry [0-9]+x[0-9]+' | 
  grep -oEe '[0-9]+x[0-9]+')
WIN_XY=$(echo "$INFO" | 
  grep -oEe 'Corners:\s+\+[0-9]+\+[0-9]+' | 
  grep -oEe '[0-9]+\+[0-9]+' | 
  sed -e 's/+/,/' )

IFS="," read -ra ORIGINS <<< "$WIN_XY"
X_ORIGIN=${ORIGINS[0]}
Y_ORIGIN=${ORIGINS[1]}
    
WIDTH=`echo "$INFO" | 
  grep -oEe 'Width:\s+[0-9]+' |
  grep -oEe '[0-9]+'`

HEIGHT=`echo "$INFO" | 
  grep -oEe 'Height:\s+[0-9]+' |
  grep -oEe '[0-9]+'`

# Make the width even, since many codecs seem to want it this way
WIDTH=$(( $WIDTH + $WIDTH % 2 ))
HEIGHT=$(( $HEIGHT + $HEIGHT % 2 ))
echo mine: geo: ${WIDTH}x${HEIGHT} theirs: geo: $WIN_GEO xy: $WIN_XY

# For the capture phase I tried -vcodec huffyuv but I got background showing through.
# Trying ffv1. Still get background showing through
FPS=60
ENCODE_FPS=30
VIDEO_OPTIONS="-vcodec libx264 -pre:v ultrafast"
AUDIO_OPTIONS="-f alsa -ac 1 -ab 192k -i pulse -acodec pcm_s16le"
TMP_FILE=/tmp/screencaster_$$.mkv
avconv \
  ${AUDIO_OPTIONS} \
  -f x11grab \
  -show_region 1 \
  -r ${FPS} \
  -s ${WIDTH}x${HEIGHT} \
  -i :0.0+${WIN_XY} \
  -qscale 0 -vcodec ffv1 \
  -y \
  $TMP_FILE
  
echo "*** Encoding ***"
avconv \
  -i $TMP_FILE \
  ${VIDEO_OPTIONS} \
  -r ${ENCODE_FPS} \
  -s ${WIDTH}x${HEIGHT} \
  -threads 0 \
  -y \
  ${1:-output}.mp4

#rm $TMP_FILE

