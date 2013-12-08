require 'test/unit'
require 'screencaster-gtk/capture'
require 'logger'
require 'fileutils'

# TODO: How to test the actual capture?
# There's non-trivial stuff in there, like getting the overall duration.

class TestCapture < Test::Unit::TestCase
  TEST_FILE_PATH = File.dirname(__FILE__)
  
  $logger = Logger.new(STDOUT)
  $logger.formatter = proc do |severity, datetime, progname, msg|
    "#{msg}\n"
  end
  
  def file_name(f)
    File.join(TEST_FILE_PATH, f)
  end
  
  def test_merge_two_files
    output = file_name("c-from-two.mkv")
    File.delete(output) if File.exists?(output)
    input = [ file_name("a.mkv"), file_name("b.mkv") ]
    
    c = Capture.new
    t = c.merge(output, input)
    # Should have something going in the background here.
    assert_equal "run", t.status
    assert_equal 0, t.value.exitstatus
    assert File.exists?(output), "Output file #{output} not found."
    assert_equal 1, Thread.list.size
  end
  
  def test_merge_one_file
    output = file_name("c-from-one.mkv")
    File.delete(output) if File.exists?(output)
    input = [ file_name("a.mkv") ]
    
    c = Capture.new
    t = c.merge(output, input)
    assert_equal 0, t.value.exitstatus
    # Should have something going in the background here, but it happens
    # so fast that it's hard to catch it. Since the two file case checks,
    # I won't bother here.
    assert File.exists?(output), "Output file #{output} not found."
    assert File.exists?(input[0]), "Input file #{input[0]} gone."
    # Process should be gone by now
    assert_equal 1, Thread.list.size
  end
  
  def test_block_merge
    output = file_name("c-from-one.mkv")
    File.delete(output) if File.exists?(output)
    input = [ file_name("a.mkv") ]
    
    amount_done = 0.0
    c = Capture.new
    t = c.merge(output, input) do | fraction, message |
        puts "+++++++++++++++++ #{fraction}, #{message}"
      amount_done = fraction
    end
    $logger.debug "Thread from c.merge: #{t}"
    assert_equal 0, t.value.exitstatus
    assert_equal 1.0, amount_done
    assert_equal 1, Thread.list.size
  end
  
  def test_final_encode
    o = "test-final-encode.mp4"
    i = "c-from-two.mkv"
    baseline = file_name(File.join("baseline", o))
    output = file_name(o)
    File.delete(output) if File.exists?(output)
    input = file_name(i)
    FileUtils.cp(file_name(File.join("baseline", i)), input)
    
    c = Capture.new
    t = c.final_encode(output, input)
    assert_equal "run", t.status
    assert_equal 0, t.value.exitstatus
    assert File.exists?(output), "Output file #{output} not found."
    assert_raise Errno::ECHILD do
      Process.wait(c.pid)
    end
    `diff #{baseline} #{output}`
    assert_equal 0, $?.exitstatus, "Output file different from baseline"
    assert_equal 1, Thread.list.size
  end
  
  def test_record_failure
    # This will fail since the capture area isn't set up
    c = Capture.new
    t = c.record
    assert_equal "run", t.status
    assert_not_equal 0, t.value.exitstatus
    assert_equal 1, Thread.list.size
  end
  
  def test_merge_failure
    output = file_name("c-from-one.mkv")
    File.delete(output) if File.exists?(output)
    input = [ file_name("file-does-not-exist.mkv") ]
    
    c = Capture.new
    t = c.merge(output, input)
    assert_equal "run", t.status
    assert_not_equal 0, t.value.exitstatus
    assert_equal 1, Thread.list.size
  end
  
  def test_final_encode_failure
    o = "test-final-encode.mp4"
    i = "file-does-not-exist.mkv"
    baseline = file_name(File.join("baseline", o))
    output = file_name(o)
    File.delete(output) if File.exists?(output)
    input = file_name(i)
    
    c = Capture.new
    t = c.final_encode(output, input)
    assert_equal "run", t.status
    assert_not_equal 0, t.value.exitstatus
    assert_equal 1, Thread.list.size
  end
  
  def test_default_total
    c = Capture.new
    assert_equal 1.0, c.total_amount
  end
  
  def test_total
    c = Capture.new
    c.total_amount = 2.0
    assert_equal 2.0, c.total_amount
  end
  
  def test_current
    c = Capture.new
    c.current_amount = 0.25
    assert_equal 0.25, c.current_amount
    assert_equal 0.25, c.fraction_complete
    assert_equal 25, c.percent_complete
    
    c.total_amount = 0.5
    assert_equal 0.5, c.fraction_complete
  end
  
  def test_time_remaining
    c = Capture.new
    c.start_time = Time.new
    c.current_amount = 0.25
    assert_in_delta(0.1, 0.1, c.time_remaining)
    sleep 1
    assert_in_delta(3, 0.1, c.time_remaining)
  end
  
  def test_time_remaining_none_done_yet
    c = Capture.new
    c.start_time = Time.new
    assert_in_delta(0.1, 0.1, c.time_remaining)
  end
  
  def test_time_remaining_s
    c = Capture.new
    c.current_amount = 0.5
    c.start_time = Time.new - 3661
    assert_equal("1h 01m 01s remaining", c.time_remaining_s)
  end
  
  def test_set_fraction_complete
    c = Capture.new
    c.total_amount = 4
    c.fraction_complete = 1
    assert_not_nil c.current_amount
    assert_equal 4, c.current_amount
  end
  
  def test_format_seconds
    assert_equal "1h 01m 01s", Capture::ProgressTracker.format_seconds(3661) 
  end
end

