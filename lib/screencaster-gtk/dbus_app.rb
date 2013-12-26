require 'dbus'
require 'screencaster-gtk/screencaster_dbus_object'

class DBusApp
  # Make the attribute accessible so we can observe how it works.
  attr_reader :service_name, :object_name, :interface_name
  
  def initialize(service, object, interface, app, window)
    @service_name = service
    @object_name = object
    @interface_name = interface
    @app = app
    @window = window
  end
  
  def bus
    return @bus if @bus
    @bus = DBus::SessionBus.instance
  end
  
  def service
    return @service if @service
    if application_exists? 
      #puts "Service already defined"
      @service = bus.service(@service_name) 
    else 
      @service = bus.request_service(@service_name) 
    end
    @service
  end

  def object
    return @exported if @exported
    @exported = ScreencasterDBusObject.new(@object_name, @app, @window)
    service.export(@exported)
    @exported
  end
  
  def interface
    object[@interface_name]
  end
  
  # Check if the service exists
  def application_exists?
    bus.service(@service_name).exists?
  end
  
  # Bring the existing window to the front by sending the 'present' message
  # to the running application
  def bring_to_front
    o = service.object(@object_name)
    o.introspect
    o[@interface_name].present
  end
  
  def glibize
    bus.glibize unless @glibized
    @glibized = true
  end
end

