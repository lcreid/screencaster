# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# Copyright (c) Jade Systems Inc. 2013, 2014

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
  
  def define_mock_capture_success
    def self.record_command_line(output_file)
      "touch '#{output_file}'"
    end
  end
end

