# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# Copyright (c) Jade Systems Inc. 2013, 2014

class ScreencasterGtk  
  def stop_recording
    @@logger.debug "Stopped in test stub"
    @capture_window.stop_recording
  end
end
