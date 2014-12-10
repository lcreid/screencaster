#!/bin/bash

avconv \
      -f alsa -ac 1 -ab 48k -i pulse -acodec aac \
      -f x11grab \
      -show_region 1 \
      -r 30 \
      -s 656x682 \
      -i :0.0+1,60 \
      -qscale 4 \
      -vcodec huffyuv \
      -y \
      huffy.mkv
