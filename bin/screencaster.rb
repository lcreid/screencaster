#!/usr/bin/env ruby

require "screencaster-gtk"
#require "rdoc/usage"

=begin rdoc
screencaster [OPTION] ... 

-h, --help:
   show help

-s, -p, --start, --pause:
  Pause a running capture, or restart a paused capture
=end

app = ScreencasterGtk.new
app.set_up
app.main
