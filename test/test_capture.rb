# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# Copyright (c) Jade Systems Inc. 2013, 2014

require 'test/unit'
require 'screencaster-gtk/capture'
require 'logger'
require 'fileutils'
require File.join(File.expand_path(File.dirname(__FILE__)), 'test_utils')
require File.join(File.expand_path(File.dirname(__FILE__)), 'capture')

# TODO: How to test the actual capture?
# There's non-trivial stuff in there, like getting the overall duration.

class TestCapture < Test::Unit::TestCase
  include TestUtils

  def test_merge_two_files
    output = file_name("c-from-two.mkv")
    File.delete(output) if File.exists?(output)
    input = [ "a.mkv", "b.mkv" ].collect { |f| copy_baseline_file_to_test_directory(f) }
    c = Capture.new
    $logger.debug "test_merge_two_files: before merge"
    assert_equal 0, c.merge(output, input) { | pct, msg | puts msg }
    assert File.exists?(output), "Output file #{output} not found."
    assert_equal 1, Thread.list.size
  end

  def test_merge_one_file
    output = file_name("c-from-one.mkv")
    File.delete(output) if File.exists?(output)
    input = [ copy_baseline_file_to_test_directory("a.mkv") ]

    c = Capture.new
    assert_equal 0, c.merge(output, input)
    assert File.exists?(output), "Output file #{output} not found."
    assert File.exists?(input[0]), "Input file #{input[0]} gone."
    # Process should be gone by now
    Thread.list.each { |t| puts t }
    assert_equal 1, Thread.list.size
  end

  def test_block_merge
    output = file_name("c-from-one.mkv")
    File.delete(output) if File.exists?(output)
    input = [ copy_baseline_file_to_test_directory("a.mkv") ]

    amount_done = 0.0
    c = Capture.new
    r = c.merge(output, input) do | fraction, message |
        puts "+++++++++++++++++ #{fraction}, #{message}"
      amount_done = fraction
    end
    assert_equal 0, r
    assert_equal 1.0, amount_done
    assert_equal 1, Thread.list.size
  end

  def test_final_encode
    o = "test-final-encode.mp4"
    i = "c-from-two.mkv"
    baseline = file_name(File.join("baseline", o))
    output = file_name(o)
    File.delete(output) if File.exists?(output)
    input = copy_baseline_file_to_test_directory(i)

    c = Capture.new
    c.total_amount = 1.0
    assert_equal 0, c.final_encode(output, input)
    assert File.exists?(output), "Output file #{output} not found."
    `diff #{baseline} #{output}`
    assert_equal 0, $?.exitstatus, "Output file different from baseline"
    assert_equal 1, Thread.list.size
  end

  def test_record_failure
    # This will fail since the capture area isn't set up
    c = Capture.new
    assert_not_equal 0, c.record
    assert_equal 1, Thread.list.size
  end

  def test_merge_failure
    output = file_name("c-from-one.mkv")
    File.delete(output) if File.exists?(output)
    input = [ file_name("file-does-not-exist.mkv") ]

    c = Capture.new
    assert_not_equal 0, c.merge(output, input)
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
    c.total_amount = 1.0
    assert_not_equal 0, c.final_encode(output, input)
    assert_equal 1, Thread.list.size
  end

  def test_default_total
    c = Capture.new
    assert_equal 0.0, c.total_amount
  end

  def test_total
    c = Capture.new
    c.total_amount = 2.0
    assert_equal 2.0, c.total_amount
  end

  def test_current
    c = Capture.new
    c.total_amount = 1.0
    c.current_amount = 0.25
    assert_equal 0.25, c.current_amount
    assert_equal 0.25, c.fraction_complete
    assert_equal 25, c.percent_complete

    c.total_amount = 0.5
    assert_equal 0.5, c.fraction_complete
  end

  def test_time_remaining
    c = Capture.new
    c.total_amount = 1.0
    c.start_time = Time.new
    c.current_amount = 0.25
    assert_in_delta(0.1, 0.1, c.time_remaining)
    sleep 1
    assert_in_delta(3, 0.1, c.time_remaining)
  end

  def test_time_remaining_none_done_yet
    c = Capture.new
    c.total_amount = 1.0
    c.start_time = Time.new
    assert_in_delta(0.1, 0.1, c.time_remaining)
  end

  def test_time_remaining_s
    c = Capture.new
    c.total_amount = 1.0
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

  def test_record_with_mock
    c = Capture.new
    c.get_window_to_capture
    c.define_mock_capture_success
    assert_equal 0, c.record.exitstatus
    assert File.exists?("/tmp/screencaster_#{$$}_#{"%04d" % 0}.mkv"), "Record didn't create output file"
    assert_equal 1, c.video_segments_size
    assert_equal 0, c.record.exitstatus
    assert File.exists?("/tmp/screencaster_#{$$}_#{"%04d" % 1}.mkv"), "Record didn't create output file"
    assert_equal 2, c.video_segments_size
    c.reset
    assert_equal 0, c.video_segments_size
    assert_equal 0, Dir.glob("/tmp/screencaster_#{$$}*").size
  end
end
