# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# Copyright (c) Jade Systems Inc. 2013, 2014

require 'gtk2'
require 'logger'
require 'fileutils'
require 'getoptlong'
require "screencaster-gtk/capture"
require "screencaster-gtk/savefile"
require "screencaster-gtk/dbus_app.rb"
require "screencaster-gtk/version"

##########################

=begin rdoc
A program to capture screencasts -- video from monitor and sound from microphone
=end
class ScreencasterGtk
  attr_reader :capture_window
  
  protected
  attr_reader :window
#  atr_writer :status_icon
    
  SCREENCASTER_DIR = File.join(Dir.home, ".screencaster")
  # Set up logging. Keep 5 log files of 100K each
  log_dir = File.join(SCREENCASTER_DIR, 'log')
  FileUtils.mkpath log_dir
  LOGFILE = File.join(log_dir, 'screencaster.log')
  @@logger = Logger.new(LOGFILE, 5, 100000)
  @@logger.level = Logger::DEBUG
  
  PIDFILE = File.join(SCREENCASTER_DIR, "run", "screencaster.pid")
  
  SOUND_SETTINGS = "/usr/bin/gnome-control-center"

  DEFAULT_SPACE = 10
  RECORD_IMAGE = Gtk::Image.new(Gtk::Stock::MEDIA_RECORD, Gtk::IconSize::SMALL_TOOLBAR)
  PAUSE_IMAGE = Gtk::Image.new(Gtk::Stock::MEDIA_PAUSE, Gtk::IconSize::SMALL_TOOLBAR)
  STOP_IMAGE = Gtk::Image.new(Gtk::Stock::MEDIA_STOP, Gtk::IconSize::SMALL_TOOLBAR)
  CANCEL_IMAGE = Gtk::Image.new(Gtk::Stock::CANCEL, Gtk::IconSize::SMALL_TOOLBAR)
  QUIT_IMAGE = Gtk::Image.new(Gtk::Stock::QUIT, Gtk::IconSize::SMALL_TOOLBAR)

  public
  def self.logger
    @@logger
  end
  
  def self.logger=(log_file)
    @@logger = Logger.new(log_file, 5, 100000)
  end
      

  def initialize
    ###### Create Main Window ######
    
    @@logger.info "Started"
    
    @window = Gtk::Window.new("Screencaster")
    @window.signal_connect("delete_event") {
      @@logger.debug "delete event occurred"
      #true
      self.quit
      false
    }
    
    @window.signal_connect("destroy") {
      @@logger.debug "destroy event occurred"
    }
    
    # The following gets minimize and restore events, but not iconify and de-iconify 
    @window.signal_connect("window_state_event") { |w, e|
      @@logger.debug "window_state_event #{e.to_s}"
    }
    
    @window.border_width = DEFAULT_SPACE
   
    control_bar = Gtk::HBox.new(false, ScreencasterGtk::DEFAULT_SPACE)
    
    @select_button = add_button("Select Window", 
      control_bar, 
      "Select a window from which to record video") { self.select }
    @record_pause_button = add_button(RECORD_IMAGE, 
      control_bar,
      "Record") { self.record_pause }
    @stop_button = add_button(STOP_IMAGE, 
      control_bar,
      "Stop recording and save video") { self.stop_recording }
    @cancel_button = add_button(CANCEL_IMAGE, 
      control_bar,
      "Cancel saving") { self.stop_encoding }
    if File.executable? SOUND_SETTINGS
      # There appears to be no stock icon for someting like a volume control.
      #@sound_settings_button.image = AUDIO_VOLUME_MEDIUM
      @sound_settings_button = add_button("Sound", 
        control_bar, 
        "Show the sound input/output controls", 
        true) {
        Thread.new { `#{SOUND_SETTINGS} sound` }
      }
    end
    add_button("About", control_bar, "", true) { about }
    add_button(QUIT_IMAGE, control_bar, "Quit the program", true) { self.quit }
    
    columns = Gtk::HBox.new(false, ScreencasterGtk::DEFAULT_SPACE)
    @progress_bar = Gtk::ProgressBar.new
    @progress_bar.text = "Select Window to Record"
    columns.pack_start(@progress_bar, true, true)
    
    progress_row = Gtk::VBox.new(false, ScreencasterGtk::DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
    progress_row.pack_start(columns, true, false)
    
    the_box = Gtk::VBox.new(false, ScreencasterGtk::DEFAULT_SPACE)
    the_box.pack_end(progress_row, false, false)
    the_box.pack_end(control_bar, false, false)
    
    @window.add(the_box)

    ###### Done Creating Main Window ######
    
    ###### Pop up menu on right click ######
    group = Gtk::AccelGroup.new
    
    @select = Gtk::ImageMenuItem.new("Select Window")
    @select.signal_connect('activate'){self.select}

    @record = Gtk::ImageMenuItem.new(Gtk::Stock::MEDIA_RECORD)
    @record.signal_connect('activate'){self.record}
    @record.add_accelerator('activate', 
      group, Gdk::Keyval::GDK_R,
      Gdk::Window::CONTROL_MASK | Gdk::Window::MOD1_MASK, 
      Gtk::ACCEL_VISIBLE)
    @pause = Gtk::ImageMenuItem.new(Gtk::Stock::MEDIA_PAUSE)
    @pause.signal_connect('activate'){self.pause}
    @pause.add_accelerator('activate', 
      group, Gdk::Keyval::GDK_P,
      Gdk::Window::CONTROL_MASK | Gdk::Window::MOD1_MASK, 
      Gtk::ACCEL_VISIBLE)
    @stop = Gtk::ImageMenuItem.new(Gtk::Stock::MEDIA_STOP)
    @stop.signal_connect('activate'){self.stop}
    @stop.add_accelerator('activate', 
      group, Gdk::Keyval::GDK_S,
      Gdk::Window::CONTROL_MASK | Gdk::Window::MOD1_MASK, 
      Gtk::ACCEL_VISIBLE)
    @show_hide = Gtk::MenuItem.new("Hide")
    @show_hide.signal_connect('activate'){self.show_hide_all}

    quit = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
    quit.signal_connect('activate'){self.quit}

    @menu = Gtk::Menu.new
    @menu.append(@select)
    
    @menu.append(Gtk::SeparatorMenuItem.new)
    @menu.append(@record)
    @menu.append(@pause)
    @menu.append(@stop)
    
    @menu.append(Gtk::SeparatorMenuItem.new)
    @menu.append(@show_hide)
    
    @menu.append(Gtk::SeparatorMenuItem.new)
    @menu.append(quit)
    
    @menu.show_all

    ###### Done Menus ######
    
    ###### Attach accelerators to window ######
    #root = Gdk::Window.default_root_window
    @window.add_accel_group(group)
  end
  
  ###### Status Icon ######
  def status_icon
    return @status_icon unless @status_icon.nil?
    
    @status_icon = Gtk::StatusIcon.new
    # Some space appears in the tray immediately, so hide it.
    # The icon doesn't actually appear until you start Gtk.main
    @status_icon.visible = false
    @status_icon.stock = Gtk::Stock::MEDIA_RECORD
    @status_icon.tooltip = 'Screencaster'

    ##Show menu on right click
    @status_icon.signal_connect('popup-menu'){|tray, button, time| @menu.popup(nil, nil, button, time)}
    
    @status_icon
  end
  
  ###### Done Status Icon ######
  
  def quit
    if @capture_window.nil? ||
      @capture_window.raw_files.nil? ||
      0 == @capture_window.raw_files.size || 
      SaveFile.are_you_sure?(@window)
      @@logger.debug "Quitting"
      # We don't want to destroy here because the object continues to exist
      # Just hide everything
      self.hide_all_including_status
      # self.status_icon.hide doesn't work/exist
      Gtk.main_quit 
      @@logger.debug "After main_quit."
    end
  end
  
  public
  def select
    @@logger.debug "Selecting Window"
    @capture_window = Capture.new
    @capture_window.get_window_to_capture
    record_pause_button_set_record(true)
  end
  
  protected
  def record_pause
    @@logger.debug "Record/Pause state: #{@capture_window.state}"
    case @capture_window.state
    when :recording
      @@logger.debug "Record/Pause -- pause"
      pause
    when :paused, :stopped
      @@logger.debug "Record/Pause -- record"
      record
    else
      @@logger.error "#{__FILE__} #{__LINE__}: Can't happen (state #{@capture_window.state})."
    end
  end
  
  def record
    @@logger.debug "Recording"
    recording
    spawn_record
  end
  
  def pause
    @@logger.debug "Pausing"
    paused
    @capture_window.pause_recording
  end
  
  public
  def stop_recording
    @@logger.debug "Stopped"
    not_recording
    @capture_window.stop_recording
    
    SaveFile.get_file_to_save { |filename|
      encoding
      spawn_encode(filename)
      @@logger.debug "Encode spawned"
    }
  end
  
=begin rdoc
Encode in the background. If the background process fails, be able to pop
up a window. Give feedback by calling the optional block with | fraction, message |.
=end
  def spawn_record
    @background = Thread.new do
      @capture_window.record do |percent, time_elapsed| 
        @progress_bar.text = time_elapsed
        @progress_bar.pulse
        @@logger.debug "Did elapsed time: #{time_elapsed}"
      end
    end
    @background
  end
  
=begin rdoc
Encode in the background. If the background process fails, be able to pop
up a window. Give feedback by calling the optional block with | fraction, message |.
=end
  def spawn_encode(filename)
    @background = Thread.new do
      @capture_window.encode(filename) do |fraction, time_remaining| 
        @progress_bar.pulse if fraction == 0
        @progress_bar.fraction = fraction 
        @progress_bar.text = time_remaining
        @@logger.debug "Did progress #{fraction.to_s} time remaining: #{time_remaining}"
        not_encoding if fraction >= 1
      end
    end
    @background
  end
  
=begin rdoc
Check how the background process is doing.
If there is none, or it's running fine, return true.
If there was a background process but it failed, return false and
ensure that the user doesn't get another 
message about the same condition.
=end
  def check_background
    return true if @background.nil? 
    return true if @background.status
    if ! background_exitstatus
      @background = nil
      return false
    end
    true 
  end
  
  def background_exitstatus
    return true if @background.nil?
    @@logger.debug "background_exitstatus: #{@background.value.exitstatus}"
    [0, 255].any? { | x | x == @background.value.exitstatus }
  end
  
  def idle
    error_dialog_tell_about_log unless check_background
  end
  
  protected
  def stop_encoding
    @@logger.debug "Cancelled encoding"
    not_recording
    @capture_window.stop_encoding
  end
  
  def stop
    case @capture_window.state
    when :recording, :paused
      stop_recording
    when :encoding
      stop_encoding
    when :stopped
      # Do nothing
    else
      @@logger.error "#{__FILE__} #{__LINE__}: Can't happen (state #{@capture_window.state})."
    end
  end
  
  public
  def toggle_recording
    @@logger.debug "Toggle recording"
    return if @capture_window.nil?
    case @capture_window.state
    when :recording
      pause
    when :paused, :stopped
      record
    when :encoding
      stop_encoding
    else
      @@logger.error "#{__FILE__} #{__LINE__}: Can't happen (state #{@capture_window.state})."
    end
  end
  
  ###### Methods to set sensitivity of controls ######
  protected
  def recording
    self.status_icon.stock = Gtk::Stock::MEDIA_PAUSE
    record_pause_button_set_pause
    @select.sensitive = @select_button.sensitive = false
#    @pause.sensitive = @pause_button.sensitive = true
    @stop.sensitive = @stop_button.sensitive = true
    @cancel_button.sensitive = false
  end
  
  def not_recording
    self.status_icon.stock = Gtk::Stock::MEDIA_RECORD
    record_pause_button_set_record
    @select.sensitive = @select_button.sensitive = true
#    @pause.sensitive = @pause_button.sensitive = false
    @stop.sensitive = @stop_button.sensitive = false
    @cancel_button.sensitive = false
  end
  
  def paused
    self.status_icon.stock = Gtk::Stock::MEDIA_RECORD
    record_pause_button_set_record
    @select.sensitive = @select_button.sensitive = false
#    @pause.sensitive = @pause_button.sensitive = false
    @stop.sensitive = @stop_button.sensitive = true
    @cancel_button.sensitive = true
  end
  
  def encoding
    self.status_icon.stock = Gtk::Stock::MEDIA_STOP
    record_pause_button_set_record(false)
#    @pause.sensitive = @pause_button.sensitive = false
    @stop.sensitive = @stop_button.sensitive = false
    @cancel_button.sensitive = true
  end
  
  def not_encoding
    not_recording
  end
  
  def record_pause_button_set_pause
    @record_pause_button.image = PAUSE_IMAGE
    @record_pause_button.tooltip_text = "Pause"
    @record_pause_button.sensitive = true
    @record.sensitive = false
    @pause.sensitive = true
  end
  
  def record_pause_button_set_record(sensitivity = ! @capture_window.nil?)
    @record_pause_button.image = RECORD_IMAGE
    @record_pause_button.tooltip_text = "Record"
    @record.sensitive = @record_pause_button.sensitive = sensitivity
    @pause.sensitive = @capture_window.nil? ? false: ! sensitivity
  end
  
  def show_all
    @show_hide.label = "Hide"
    @show_hide_state = :show
    @window.show_all
  end
  
  def hide_all
    @show_hide.label = "Show"
    @show_hide_state = :hide
    @window.hide_all
  end
  
  def show_hide_all
    case @show_hide_state
    when :show
      self.hide_all
    when :hide
      self.show_all
    else
      logger.error("#{__FILE__} (#{__LINE__} @show_hide_state: #{@show_hide_state.to_s}")
    end
  end
  
  def show_all_including_status
    self.show_all
    self.status_icon.visible = true
  end
  
  def hide_all_including_status
    self.hide_all
    self.status_icon.visible = false
  end
  
  public
  
  # Shows the screencaster window and starts processing events from the user.
  #
  # The hot key toggles between capture and pause. 
  # The default hot key is Ctrl+Alt+S.
  def main
    @@logger.info "Starting event loop"
    self.not_recording
    self.show_all_including_status
    GLib::Idle.add { idle }
    Gtk.main
    @@logger.info "Finished"
  end
  
  # Process command line arguments, set up the log file, and set up hot keys.
  # *   The default hot key is Ctrl+Alt+S.
  def set_up
    opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT ]
    )
    
    opts.each do |opt, arg|
      case opt
      when '--help'
          puts <<-EOF
screencaster [OPTION] ... 

-h, --help:
   show help
          EOF
          exit 0
      end
    end
    
    ###### If already running, bring to front ######
    
    @dbus_app = DBusApp.new("ca.jadesystems.screencaster", 
      "/ca/jadesystems/screencaster", 
      "ca.jadesystems.screencaster",
      self,
      @window)
    
    if @dbus_app.application_exists?
      @@logger.debug("Already running. Bringing window to front")
      @dbus_app.bring_to_front
      exit 0
    else # get ready to receive DBus messages
      @@logger.debug("Own the DBus service. Prep it")
      @dbus_app.glibize
      @dbus_app.object
    end

    # Add application properties for PulseAudio
    # See: http://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/Developer/Clients/ApplicationProperties/
    # Unfortunately, this doesn't seem to help
    # Perhaps because avconv is a separate program and is setting its own values
    GLib::application_name = "Screencaster"
    Gtk::Window.default_icon_name = "screencaster"
    GLib::setenv("PULSE_PROP_media.role", "video")

    set_up_keybindings

    $logger = @@logger # TODO: Fix logging
  end
  
  # Helper functions
  private
  def add_button(label, box, tooltip, sensitive = false, &callback)
    b = Gtk::Button.new
    b.image = label if label.is_a? Gtk::Image
    b.label = label if label.is_a? String
    b.tooltip_text = tooltip
    b.sensitive = sensitive
    b.signal_connect("clicked") { callback.call }
    box.pack_start(b, true, false)
    b
  end
  
  public
  def error_dialog_tell_about_log(msg = "", file = nil, line = nil)
    d = Gtk::MessageDialog.new(@window, 
      Gtk::Dialog::DESTROY_WITH_PARENT, 
      Gtk::MessageDialog::WARNING, 
      Gtk::MessageDialog::BUTTONS_CLOSE, 
      "Internal Error")
    
    d.secondary_text = msg
    d.secondary_text += " in #{file}" unless file.nil?
    d.secondary_text += ", line: #{line}" unless line.nil?
    d.secondary_text.strip!

    @@logger.warn(d.secondary_text)

    d.secondary_text += "\nLook in #{LOGFILE} for further information"
    d.secondary_text.strip!
    
    d.run
    d.destroy
  end
  
  def about
    about = Gtk::AboutDialog.new
    about.version = VERSION
    about.website = HOMEPAGE
    about.authors = AUTHORS
    about.copyright = COPYRIGHT
    
    begin
      about.license = IO.read(File.join(File.dirname(__FILE__), "../MPL2.0"))
    rescue SystemCallError
      @@logger.warn("Try 'gem uninstall screencaster-gtk; gem install screencaster-gtk' (#{$!})")
      about.license = LICENSE
    end

    #about.show
    about.run
    about.destroy
  end
  
  ###### Set up keybindings ######
  #require 'gconf2'
  
  def set_up_keybindings
    command = "command_1"
    wm = "/apps/metacity"
    keybinding_commands = "#{wm}/keybinding_commands/#{command}"
    global_keybindings = "#{wm}/global_keybindings/run_#{command}"
    
    #client = GConf::Client.new
      
    @chain = Signal.trap("EXIT") { 
      @@logger.debug "In ScreencasterGtk exit handler @chain: #{@chain}"
      `gconftool-2 --unset #{keybinding_commands}`
      `gconftool-2 --unset #{global_keybindings}`
      # client[keybinding_commands] = nil
      # client[global_keybindings] = nil
      @@logger.debug "About to call next trap with @chain: #{@chain}"
      @chain.call unless @chain.nil?
    }
    @@logger.debug "ScreencasterGtk after setting @chain: #{@chain}"

    pause_command = "dbus-send --dest=#{@dbus_app.service_name} --type=method_call #{@dbus_app.object_name} #{@dbus_app.interface_name}.pause_record"
    `gconftool-2 --set #{keybinding_commands} --type string "#{pause_command}"`
    `gconftool-2 --set #{global_keybindings} --type string "<Control><Alt>S"`
    # client.unset(keybinding_commands) = pause_command
    # client.unset(global_keybindings) = "<Control><Alt>S"
  end
end

#puts "Loaded #{__FILE__}"

