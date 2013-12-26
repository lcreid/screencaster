require 'dbus'

class ScreencasterDBusObject < DBus::Object
  def initialize(object_name, app, window)
    super(object_name)
    @app = app
    @window = window
  end

  dbus_interface "ca.jadesystems.screencaster" do
    dbus_method :pause_record do 
      #puts "Pause/Record."
      #puts @app.inspect
      @app.toggle_recording
    end
    dbus_method :present do
      #puts "Present."
      @window.present
    end
    dbus_signal :paused do end
  end
end
