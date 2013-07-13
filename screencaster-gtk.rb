#!/usr/bin/env ruby
=begin
=end

require 'gtk2'
require './capture'

DEFAULT_SPACE = 10

def recording
  $pause_button.sensitive = true
  $stop_button.sensitive = true
  $record_button.sensitive = false
  $cancel_button.sensitive = false
end

def not_recording
  $pause_button.sensitive = false
  $stop_button.sensitive = false
  $record_button.sensitive = true
  $cancel_button.sensitive = false
end

def encoding
  $pause_button.sensitive = false
  $stop_button.sensitive = false
  $record_button.sensitive = false
  $cancel_button.sensitive = true
end

def not_encoding
  not_recording
end

bottom_columns = Gtk::HBox.new(false, DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE

button = Gtk::Button.new("Select Window to Record")
button.signal_connect("clicked") {
  puts "Selecting Window"
  $capture_window = Capture.new
  $capture_window.get_window_to_capture
  $record_button.sensitive = true
}
bottom_columns.pack_start(button, true, false)

button = Gtk::Button.new("Quit")
button.signal_connect("clicked") {
  puts "Quitting"
  Gtk.main_quit
}
bottom_columns.pack_end(button, true, false)

bottom_row = Gtk::VBox.new(false, DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
bottom_row.pack_end(bottom_columns, false)

control_columns = Gtk::HBox.new(false, DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE

$record_button = Gtk::Button.new("Record")
$record_button.sensitive = false
$record_button.signal_connect("clicked") {
  puts "Recording"
  recording
  $capture_window.record
}
control_columns.pack_start($record_button, true, false)

$pause_button = Gtk::Button.new("Pause")
$pause_button.sensitive = false
$pause_button.signal_connect("clicked") {
  puts "Paused"
  not_recording
}
control_columns.pack_start($pause_button, true, false)

$stop_button = Gtk::Button.new("Stop")
$stop_button.sensitive = false
$stop_button.signal_connect("clicked") {
  puts "Stopped"
  not_recording
  $capture_window.stop_recording
  encoding
  $capture_window.encode { |percent| 
    $progress_bar.fraction = percent 
    puts "Did progress #{percent.to_s}"
    percent < 1 || stop_encoding
  }
  puts "Back from encode"
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
  puts "Cancelled"
  not_recording
  $capture_window.stop_encoding
}
columns.pack_start($cancel_button, true, false)

progress_row = Gtk::VBox.new(false, DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
progress_row.pack_start(columns, true, false)

the_box = Gtk::VBox.new(false, DEFAULT_SPACE)
the_box.pack_end(bottom_row, false, false)
the_box.pack_end(progress_row, false, false)
the_box.pack_end(control_row, false, false)

window = Gtk::Window.new
window.signal_connect("delete_event") {
  puts "delete event occurred"
  #true
  false
}

window.signal_connect("destroy") {
  puts "destroy event occurred"
  Gtk.main_quit
}

window.border_width = DEFAULT_SPACE
window.add(the_box)
window.show_all

Gtk.main
