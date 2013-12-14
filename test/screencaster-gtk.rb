class ScreencasterGtk  
  def stop_recording
    @@logger.debug "Stopped in test stub"
    @capture_window.stop_recording
  end
end
