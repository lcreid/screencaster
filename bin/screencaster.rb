#!/usr/bin/env ruby

require 'getoptlong'
require 'fileutils'
require 'logger'
require "screencaster-gtk"

# Don't run the program if there's another instance running for the user.
# If there's another instance running for the user and the --pause or --start 
# flags are present, send the USR1 signal to the running instance
# and exit.
# If there's no other instance running for the user, and the --pause or --start 
# flags are not present, start normally.

screencaster_dir = File.join(Dir.home, ".screencaster")
pidfile = File.join(screencaster_dir, "run", "screencaster.pid")
output_file = "/home/reid/test-key.log"

existing_pid = nil
begin
  ScreencasterGtk::LOGGER.debug("pid_file is #{pidfile}")
  f = File.new(pidfile)
  ScreencasterGtk::LOGGER.debug("Opened pidfile")
  existing_pid = f.gets
  existing_pid = existing_pid.to_i
  f.close
  ScreencasterGtk::LOGGER.debug("existing_pid = #{existing_pid.to_s}")
rescue StandardError
  FileUtils.mkpath(File.dirname(pidfile))
  f = File.new(pidfile, "w")
  f.close
end

opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--pause', GetoptLong::NO_ARGUMENT ],
  [ '--start', GetoptLong::NO_ARGUMENT ]
)

opts.each do |opt, arg|
  case opt
    when '--help'
      puts <<-EOF
screencaster [OPTION] ... 

-h, --help:
   show help

-s, -p, --start, --pause:
  Pause a running capture, or restart a paused capture
      EOF
      exit 0
    when '--pause' || '--start'
      if existing_pid then
        ScreencasterGtk::LOGGER.debug("Got a pause for PID #{existing_pid}")
        Process.kill "USR1", existing_pid
        exit 0
      else
        ScreencasterGtk::LOGGER.debug("Got a pause but no pid")
        exit 1
      end 
  end
end

# TODO: Check for running process and if not, ignore pidfile.
(ScreencasterGtk::LOGGER.debug("Can't run two instances at once."); exit 1) if ! existing_pid.nil?

chain = Signal.trap("EXIT") { 
  ScreencasterGtk::LOGGER.debug("Exiting")
  ScreencasterGtk::LOGGER.debug("unlinking") if File.file?(pidfile)
  File.unlink(pidfile) if File.file?(pidfile)
  `gconftool-2 --unset /apps/metacity/keybinding_commands/screencaster_pause`
  `gconftool-2 --unset /apps/metacity/global_keybindings/run_screencaster_pause`
  chain.call unless chain == "DEFAULT"
}

`gconftool-2 --set /apps/metacity/keybinding_commands/screencaster_pause --type string "/home/reid/Documents/Computers/screencaster/test-key.rb --pause"`
`gconftool-2 --set /apps/metacity/global_keybindings/run_screencaster_pause --type string "<Control><Alt>S"`

Signal.trap("USR1") { ScreencasterGtk::LOGGER.debug("Pause/Resume") }

app = ScreencasterGtk.new
$logger = ScreencasterGtk::LOGGER # TODO: Fix logging
app.main
