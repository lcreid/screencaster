# Redefine some methods in Capture for testing purposes.

class Capture
  def get_window_to_capture
    @left   = 100
    @top    = 100
    @width  = 100
    @height = 100
    @height += @height % 2
    @width  += @width % 2

    $logger.debug "Capturing #{@left},#{@top} to #{@left+@width},#{@top+@height}. Dimensions #{@width},#{@height}.\n"
  end
end

