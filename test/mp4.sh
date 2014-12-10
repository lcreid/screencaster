#!/bin/bash

avconv \
      -f x11grab \
      -show_region 1 \
      -r 30 \
      -s 656x682 \
      -i :0.0+1,60 \
      -qscale 4 \
      -vcodec libx264 \
      -f alsa -ac 1 -ab 48k -i pulse -acodec aac -strict experimental \
      -y \
      libx264.mp4
