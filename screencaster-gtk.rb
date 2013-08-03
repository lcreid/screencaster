#!/usr/bin/env ruby
=begin
=end

require 'gtk2'
require 'logger'
require 'fileutils'
require './capture'

##########################

# Set up logging. Keep 5 log files of a 100K each
log_dir = File.expand_path('~/.screencaster/log/')
FileUtils.mkpath log_dir
$logger = Logger.new(File.join(log_dir, 'screencaster.log'), 5, 100000)
$logger.level = Logger::DEBUG

$logger.info "Started"

class SaveFile
  def self.set_up_dialog(file_name = "output.mp4")
    @dialog = Gtk::FileChooserDialog.new(
        "Save File As ...",
        $window,
        Gtk::FileChooser::ACTION_SAVE,
        nil,
        [ Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL ],
        [ Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT ]
    )
    # dialog.signal_connect('response') do |w, r|
      # odg = case r
        # when Gtk::Dialog::RESPONSE_ACCEPT
          # filename = dialog.filename
          # "'ACCEPT' (#{r}) button pressed -- filename is {{ #{filename} }}"
        # when Gtk::Dialog::RESPONSE_CANCEL;   "'CANCEL' (#{r}) button pressed"
        # else; "Undefined response ID; perhaps Close-x? (#{r})"
      # end
      # puts odg
      # dialog.destroy 
    # end
    @dialog.current_name = GLib.filename_to_utf8(file_name)
    @dialog.current_folder = GLib.filename_to_utf8(Dir.getwd)
    @dialog.do_overwrite_confirmation = true
  end
  
  def self.get_file_to_save
    @dialog || SaveFile.set_up_dialog
    result = @dialog.run
    file_name = @dialog.filename
    case result
      when Gtk::Dialog::RESPONSE_ACCEPT
        @dialog.hide
        yield file_name
      when Gtk::Dialog::RESPONSE_CANCEL
        self.confirm_cancel(@dialog)
        @dialog.hide
      else
        $logger.error("Can't happen #{__FILE__} line: #{__LINE__}")
        @dialog.hide
    end
  end
  
  def self.confirm_cancel(parent)
    dialog = Gtk::Dialog.new(
      "Confirm Cancel",
      parent,
      Gtk::Dialog::MODAL,
      [ "Discard Recording", Gtk::Dialog::RESPONSE_CANCEL ],
      [ "Save Recording As...", Gtk::Dialog::RESPONSE_OK ]
    )
    dialog.has_separator = false
    label = Gtk::Label.new("Your recording has not been saved.")
    image = Gtk::Image.new(Gtk::Stock::DIALOG_WARNING, Gtk::IconSize::DIALOG)
  
    hbox = Gtk::HBox.new(false, 5)
    hbox.border_width = 10
    hbox.pack_start_defaults(image);
    hbox.pack_start_defaults(label);
  
    dialog.vbox.add(hbox)
    dialog.show_all
    result = dialog.run
    dialog.destroy
    
    case result
      when Gtk::Dialog::RESPONSE_OK
        self.get_file_to_save
      else
    end
  end
end

class ScreencasterGTK
  attr_reader :capture_window
  
  def initialize
    @status_icon = Gtk::StatusIcon.new
    @status_icon.stock = Gtk::Stock::MEDIA_RECORD
    @status_icon.tooltip = 'Screencaster'

    ###**************************###
    ## Pop up menu on right click
    ###**************************###
    ##Build a menu
    @select = Gtk::ImageMenuItem.new("Select Window")
    @select.signal_connect('activate'){self.select}

    @record = Gtk::ImageMenuItem.new(Gtk::Stock::MEDIA_RECORD)
    @record.signal_connect('activate'){self.record}
    @pause = Gtk::ImageMenuItem.new(Gtk::Stock::MEDIA_PAUSE)
    @pause.signal_connect('activate'){self.pause}
    @stop = Gtk::ImageMenuItem.new(Gtk::Stock::MEDIA_STOP)
    @stop.signal_connect('activate'){self.stop_recording}

    quit = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
    quit.signal_connect('activate'){self.quit}

    @menu = Gtk::Menu.new
    @menu.append(@select)
    
    @menu.append(Gtk::SeparatorMenuItem.new)
    @menu.append(@record)
    @menu.append(@pause)
    @menu.append(@stop)
    
    @menu.append(Gtk::SeparatorMenuItem.new)
    @menu.append(quit)
    
    @menu.show_all
    ##Show menu on right click
    @status_icon.signal_connect('popup-menu'){|tray, button, time| @menu.popup(nil, nil, button, time)}
  end
  
  def quit
    $logger.debug "Quitting"
    Gtk.main_quit 
  end
  
  def select
    $logger.debug "Selecting Window"
    @capture_window = Capture.new
    @capture_window.get_window_to_capture
    $record_button.sensitive = true
  end
  
  def record
    $logger.debug "Recording"
    recording
    @capture_window.record
  end
  
  def pause
    $logger.debug "Pause not implemented"
    not_recording
  end
  
  def stop_recording
    $logger.debug "Stopped"
    not_recording
    @capture_window.stop_recording
    
    SaveFile.get_file_to_save { |filename|
      encoding
      @capture_window.encode(filename) { |percent, time_remaining| 
        $progress_bar.fraction = percent 
        $progress_bar.text = time_remaining
        $logger.debug "Did progress #{percent.to_s} time remaining: #{time_remaining}"
        percent < 1 || stop_encoding
      }
      $logger.debug "Back from encode"
    }
  end
  
  def stop_encoding
    $logger.debug "Cancelled encoding"
    not_recording
    @capture_window.stop_encoding
  end
  
  def recording
    @select.sensitive = $select_button.sensitive = false
    @pause.sensitive = $pause_button.sensitive = true
    @stop.sensitive = $stop_button.sensitive = true
    @record.sensitive = $record_button.sensitive = false
    $cancel_button.sensitive = false
  end
  
  def not_recording
    @select.sensitive = $select_button.sensitive = true
    @pause.sensitive = $pause_button.sensitive = false
    @stop.sensitive = $stop_button.sensitive = false
    @record.sensitive = $record_button.sensitive = ! @capture_window.nil?
    $cancel_button.sensitive = false
  end
  
  def encoding
    @pause.sensitive = $pause_button.sensitive = false
    @stop.sensitive = $stop_button.sensitive = false
    @record.sensitive = $record_button.sensitive = false
    $cancel_button.sensitive = true
  end
  
  def not_encoding
    not_recording
  end
end

app = ScreencasterGTK.new

DEFAULT_SPACE = 10

bottom_columns = Gtk::HBox.new(false, DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE

$select_button = Gtk::Button.new("Select Window to Record")
$select_button.signal_connect("clicked") {
  app.select
}
bottom_columns.pack_start($select_button, true, false)

button = Gtk::Button.new("Quit")
button.signal_connect("clicked") {
  app.quit
}
bottom_columns.pack_end(button, true, false)

bottom_row = Gtk::VBox.new(false, DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
bottom_row.pack_end(bottom_columns, false)

control_columns = Gtk::HBox.new(false, DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE

$record_button = Gtk::Button.new("Record")
$record_button.sensitive = false
$record_button.signal_connect("clicked") {
  app.record
}
control_columns.pack_start($record_button, true, false)

$pause_button = Gtk::Button.new("Pause")
$pause_button.sensitive = false
$pause_button.signal_connect("clicked") {
  app.pause
}
control_columns.pack_start($pause_button, true, false)

$stop_button = Gtk::Button.new("Stop")
$stop_button.sensitive = false
$stop_button.signal_connect("clicked") {
  app.stop_recording
}
control_columns.pack_start($stop_button, true, false)

control_row = Gtk::VBox.new(false, DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
control_row.pack_start(control_columns, true, false)

columns = Gtk::HBox.new(false, DEFAULT_SPACE)
$progress_bar = Gtk::ProgressBar.new
columns.pack_start($progress_bar, true, false)

$cancel_button = Gtk::Button.new("Cancel")
$cancel_button.sensitive = false
$cancel_button.signal_connect("clicked") {
  app.stop_encoding
}
columns.pack_start($cancel_button, true, false)

progress_row = Gtk::VBox.new(false, DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
progress_row.pack_start(columns, true, false)

the_box = Gtk::VBox.new(false, DEFAULT_SPACE)
the_box.pack_end(bottom_row, false, false)
the_box.pack_end(progress_row, false, false)
the_box.pack_end(control_row, false, false)

$window = Gtk::Window.new
$window.signal_connect("delete_event") {
  $logger.debug "delete event occurred"
  #true
  false
}

$window.signal_connect("destroy") {
  $logger.debug "destroy event occurred"
  app.quit
}

$window.border_width = DEFAULT_SPACE
$window.add(the_box)
$window.show_all


Gtk.main

$logger.info "Finished"
