require 'gtk2'

=begin rdoc
Run the standard save file dialog for screencaster
=end
class SaveFile
  
=begin rdoc
Create the file chooser dialogue with a default file name.
=end
  def self.set_up_dialog(file_name = "output.mp4")
    @dialog = Gtk::FileChooserDialog.new(
        "Save File As ...",
        nil,
        Gtk::FileChooser::ACTION_SAVE,
        nil,
        [ Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL ],
        [ Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT ]
    )
    @dialog.current_name = GLib.filename_to_utf8(file_name)
    @dialog.current_folder = GLib.filename_to_utf8(Dir.getwd)
    @dialog.do_overwrite_confirmation = true
  end
  
=begin rdoc
Do the workflow around saving a file, warning the user before allow
them to abandon their capture.
=end
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
  
=begin rdoc
Confirm cancellation when the user has captured something but not
saved it.
=end
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

