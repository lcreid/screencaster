require 'test/unit'
require 'screencaster-gtk'
require File.join(File.expand_path(File.dirname(__FILE__)), 'test_utils')
require File.join(File.expand_path(File.dirname(__FILE__)), 'capture')
require File.join(File.expand_path(File.dirname(__FILE__)), 'screencaster-gtk')

class TestScreencasterGtk < Test::Unit::TestCase
  include TestUtils
  
  ScreencasterGtk.logger = STDOUT
  ScreencasterGtk.logger.formatter = proc do |severity, datetime, progname, msg|
    "#{msg}\n"
  end
  
  def setup
    @sc = ScreencasterGtk.new
  end
  
  def test_record
    ScreencasterGtk.logger.debug("Thread exception: #{Thread.abort_on_exception}")
    ScreencasterGtk.logger.debug("test_record")
    # Uses the test definition of select defined in the local version of capture.rb
    @sc.select
    ScreencasterGtk.logger.debug("selected")
    @sc.spawn_record
    ScreencasterGtk.logger.debug("about to sleep")
    sleep 2
    ScreencasterGtk.logger.debug("woke up")
    assert @sc.check_background, "check_background 1 failed"
    ScreencasterGtk.logger.debug("About to stop")
    @sc.stop_recording
    ScreencasterGtk.logger.debug("Stopped (in test_record)")
    assert @sc.check_background, "check_background 2 failed"
    assert @sc.background_exitstatus, "Unexpected background failure"
    assert @sc.check_background, "check_background 3 failed"
  end
  
  def test_encode
    output = file_name("c.mkv")
    File.delete output if File.exists? output
    # Uses the test definition of select defined in the local version of capture.rb
    @sc.select
    @sc.capture_window.tmp_files = [file_name("a.mkv")]
    @sc.capture_window.total_amount = 1
    assert @sc.spawn_encode(output), "spawn_encode failed"
    assert @sc.check_background, "check_background failed"
    assert @sc.background_exitstatus, "Unexpected background failure"
  end
  
  def test_no_background_process
    assert @sc.check_background, "check_background failed when no background process"
    assert @sc.background_exitstatus, "Unexpected background failure"
  end
  
  def test_background_fails
    # Uses the test definition of select defined in the local version of capture.rb
    @sc.select
    # Force a failure by giving a bogus sound device
    @sc.capture_window.audio_input = 'bogus_audio'
    @sc.spawn_record
    sleep 1
    assert ! @sc.check_background, "check_background should have returned false"
    assert @sc.check_background, "check_background should not have returned false"
  end
end
