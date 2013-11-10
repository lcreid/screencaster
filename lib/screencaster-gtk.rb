require 'gtk2'
require 'logger'
require 'fileutils'
require "screencaster-gtk/capture"

##########################

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
        LOGGER.error("Can't happen #{__FILE__} line: #{__LINE__}")
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

class ScreencasterGtk
  attr_reader :capture_window, :window
  attr_writer :status_icon
    
  # Set up logging. Keep 5 log files of a 100K each
  log_dir = File.expand_path('~/.screencaster/log/')
  FileUtils.mkpath log_dir
  LOGGER = Logger.new(File.join(log_dir, 'screencaster.log'), 5, 100000)
  LOGGER.level = Logger::DEBUG
  
  DEFAULT_SPACE = 10

  def initialize
    #### Create Main Window
    
    LOGGER.info "Started"

    @window = Gtk::Window.new
    @window.signal_connect("delete_event") {
      LOGGER.debug "delete event occurred"
      #true
      self.quit
      false
    }
    
    @window.signal_connect("destroy") {
      LOGGER.debug "destroy event occurred"
    }
    
    # The following gets minimize and restore events, but not iconify and de-iconify 
    @window.signal_connect("window_state_event") { |w, e|
      puts ("window_state_event #{e.to_s}")
    }
    
    @window.border_width = DEFAULT_SPACE
    
    bottom_columns = Gtk::HBox.new(false, ScreencasterGtk::DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
    
    @select_button = Gtk::Button.new("Select Window to Record")
    @select_button.signal_connect("clicked") {
      self.select
    }
    bottom_columns.pack_start(@select_button, true, false)
    
    button = Gtk::Button.new("Quit")
    button.signal_connect("clicked") {
      self.quit
    }
    bottom_columns.pack_end(button, true, false)
    
    bottom_row = Gtk::VBox.new(false, ScreencasterGtk::DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
    bottom_row.pack_end(bottom_columns, false)
    
    control_columns = Gtk::HBox.new(false, ScreencasterGtk::DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
    
    @record_button = Gtk::Button.new("Record")
    @record_button.sensitive = false
    @record_button.signal_connect("clicked") {
      self.record
    }
    control_columns.pack_start(@record_button, true, false)
    
    @pause_button = Gtk::Button.new("Pause")
    @pause_button.sensitive = false
    @pause_button.signal_connect("clicked") {
      self.pause
    }
    control_columns.pack_start(@pause_button, true, false)
    
    @stop_button = Gtk::Button.new("Stop")
    @stop_button.sensitive = false
    @stop_button.signal_connect("clicked") {
      self.stop_recording
    }
    control_columns.pack_start(@stop_button, true, false)
    
    control_row = Gtk::VBox.new(false, ScreencasterGtk::DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
    control_row.pack_start(control_columns, true, false)
    
    columns = Gtk::HBox.new(false, ScreencasterGtk::DEFAULT_SPACE)
    @progress_bar = Gtk::ProgressBar.new
    columns.pack_start(@progress_bar, true, false)
    
    @cancel_button = Gtk::Button.new("Cancel")
    @cancel_button.sensitive = false
    @cancel_button.signal_connect("clicked") {
      self.stop_encoding
    }
    columns.pack_start(@cancel_button, true, false)
    
    progress_row = Gtk::VBox.new(false, ScreencasterGtk::DEFAULT_SPACE) # children have different sizes, spaced by DEFAULT_SPACE
    progress_row.pack_start(columns, true, false)
    
    the_box = Gtk::VBox.new(false, ScreencasterGtk::DEFAULT_SPACE)
    the_box.pack_end(bottom_row, false, false)
    the_box.pack_end(progress_row, false, false)
    the_box.pack_end(control_row, false, false)
    
    @window.add(the_box)

    ##### Done Creating Main Window
    
    #### Accelerator Group
    group = Gtk::AccelGroup.new
    group.connect(Gdk::Keyval::GDK_N, Gdk::Window::CONTROL_MASK|Gdk::Window::MOD1_MASK, Gtk::ACCEL_VISIBLE) do
      #puts "You pressed 'Ctrl+Alt+n'"
    end

    #### Pop up menu on right click

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

    #### Done Menus
    
    #### Attach accelerators to window
    #root = Gdk::Window.default_root_window
    @window.add_accel_group(group)
  end
  
  #### Status Icon
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
  
  #### Done Status Icon
  
  def quit
    LOGGER.debug "Quitting"
    # self.status_icon.destroy
    # LOGGER.debug "After status icon destroy."
    # @window.destroy
    # LOGGER.debug "After window destroy."
    # We don't want to destroy here because the object continues to exist
    # Just hide everything
    self.hide_all_including_status
    # self.status_icon.hide doesn't work/exist
    Gtk.main_quit 
    LOGGER.debug "After main_quit."
  end
  
  def select
    LOGGER.debug "Selecting Window"
    @capture_window = Capture.new
    @capture_window.get_window_to_capture
    @record_button.sensitive = true
  end
  
  def record
    LOGGER.debug "Recording"
    recording
    @capture_window.record
  end
  
  def pause
    LOGGER.debug "Pausing"
    paused
    @capture_window.pause_recording
  end
  
  def stop_recording
    LOGGER.debug "Stopped"
    not_recording
    @capture_window.stop_recording
    
    SaveFile.get_file_to_save { |filename|
      encoding
      @capture_window.encode(filename) { |percent, time_remaining| 
        @progress_bar.fraction = percent 
        @progress_bar.text = time_remaining
        LOGGER.debug "Did progress #{percent.to_s} time remaining: #{time_remaining}"
        percent < 1 || stop_encoding
      }
      LOGGER.debug "Back from encode"
    }
  end
  
  def stop_encoding
    LOGGER.debug "Cancelled encoding"
    not_recording
    @capture_window.stop_encoding
  end
  
  def stop
    case @capture_window.state
    when :recording || :paused
      stop_recording
    when :encoding
      stop_encoding
    when :stopped
      # Do nothing
    else
      LOGGER.error "#{__FILE__} #{__LINE__}: Can't happen."
    end
  end
  
  def recording
    self.status_icon.stock = Gtk::Stock::MEDIA_STOP
    @select.sensitive = @select_button.sensitive = false
    @pause.sensitive = @pause_button.sensitive = true
    @stop.sensitive = @stop_button.sensitive = true
    @record.sensitive = @record_button.sensitive = false
    @cancel_button.sensitive = false
  end
  
  def not_recording
    self.status_icon.stock = Gtk::Stock::MEDIA_RECORD
    @select.sensitive = @select_button.sensitive = true
    @pause.sensitive = @pause_button.sensitive = false
    @stop.sensitive = @stop_button.sensitive = false
    @record.sensitive = @record_button.sensitive = ! @capture_window.nil?
    @cancel_button.sensitive = false
  end
  
  def paused
    self.status_icon.stock = Gtk::Stock::MEDIA_RECORD
    @select.sensitive = @select_button.sensitive = false
    @pause.sensitive = @pause_button.sensitive = false
    @stop.sensitive = @stop_button.sensitive = true
    @record.sensitive = @record_button.sensitive = ! @capture_window.nil?
    @cancel_button.sensitive = true
  end
  
  def encoding
    self.status_icon.stock = Gtk::Stock::MEDIA_STOP
    @pause.sensitive = @pause_button.sensitive = false
    @stop.sensitive = @stop_button.sensitive = false
    @record.sensitive = @record_button.sensitive = false
    @cancel_button.sensitive = true
  end
  
  def not_encoding
    not_recording
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
  
  def main
    LOGGER.info "Starting"
    self.not_recording
    self.show_all_including_status
    Gtk.main
    LOGGER.info "Finished"
  end
end

#puts "Loaded #{__FILE__}"

