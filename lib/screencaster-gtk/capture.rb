# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# Copyright (c) Jade Systems Inc. 2013, 2014

require 'open3'
require 'logger'
require "screencaster-gtk/progresstracker"

=begin rdoc
Select a window or area of the screen to capture, capture it, and encode it.
=end
class Capture
  include ProgressTracker

  attr_writer :left, :top, :right, :bottom
  attr_reader :state
  attr_accessor :pid
  attr_accessor :raw_files

  attr_accessor :capture_fps
  attr_accessor :encode_fps
  attr_accessor :capture_vcodec
  attr_accessor :qscale
  attr_accessor :encode_vcodec
  attr_accessor :acodec
  attr_accessor :audio_sample_frequency
  attr_accessor :audio_input


  def initialize
    @exit_chain = Signal.trap("EXIT") {
      self.cleanup
      $logger.debug "In capture about to chain to trap @exit_chain: #{@exit_chain}"
      @exit_chain.call unless @exit_chain.nil?
    }
    #$logger.debug "@exit_chain: #{@exit_chain.to_s}"

    self.reset_without_cleanup

    @state = :stopped
    @coprocess = nil

    @capture_fps = 30
    @encode_fps = 30 # Don't use this. Just copy through
    @capture_vcodec = 'huffyuv' # I used to use ffv1. This is for capture
    @qscale = '4' # Recommended for fast encoding by avconv docs
    @encode_vcodec = 'libx264'
    @acodec = 'aac -strict experimental' # Youtube prefers "AAC-LC" but I don't see one called "-LC"
    @audio_sample_frequency = "48k"
    @audio_input = "pulse"
  end

  def wait
    $logger.debug "wait: Current thread #{Thread.current}"
    @coprocess.value
  end

  def status
    $logger.debug "status: Current thread #{Thread.current}"
    return false if @coprocess.nil?
    @coprocess.status
  end

  def current_tmp_file
    @raw_files.last
  end

  def new_tmp_file
    @raw_files << Capture.tmp_file_name(@raw_files.size)
    self.current_tmp_file
  end

  def self.tmp_file_name(index = nil)
    "/tmp/screencaster_#{$$}" + (index.nil? ? "": "_#{"%04d" % index}") + ".mkv"
  end

  def self.format_input_files_for_mkvmerge(files)
    files.drop(1).inject("'#{files.first}'") {|a, b| "#{a} + '#{b}'" }
  end

  def video_segments_size
    @raw_files.size
  end

  def width
    @right - @left
  end

  def height=(h)
    @bottom = @top + h
    h
  end

  def height
    @bottom - @top
  end

  def width=(w)
    @right = @left + w
    w
  end

  # I have to refactor this to make it more testable.
  # As a general approach, I want to factor out the parts that have human input
  # so that whatever I have to do for that is as small as possible.

  def get_window_to_capture
    print "Click in the window you want to capture.\n"
    info = `xwininfo`

    info =~ /Window id: (0x[[:xdigit:]]+)/
    window_id = $1

    info =~ /geometry\s+([[:digit:]])+x([[:digit:]]+)\+([[:digit:]]+)-([[:digit:]]+)/

    info =~ /Absolute upper-left X:\s+([[:digit:]]+)/
    @left = $1.to_i
    info =~ /Absolute upper-left Y:\s+([[:digit:]]+)/
    @top = $1.to_i

    info =~ /Width:\s+([[:digit:]]+)/
    @width = $1.to_i
    info =~ /Height:\s+([[:digit:]]+)/
    @height = $1.to_i

    @height +=  @height % 2
    @width += @width % 2

    $logger.debug "Capturing #{@left},#{@top} to #{@left+@width},#{@top+@height}. Dimensions #{@width},#{@height}.\n"
  end

  def record
    output_file = self.new_tmp_file

    @state = :recording

    # And i should probably popen here, save the pid, then fork and start
    # reading the input, updating the number of frames saved, or the time
    # recorded.
    $logger.debug "Capturing...\n"

    cmd_line = record_command_line(output_file)

    $logger.debug cmd_line

    duration = 0.0
    i, oe, @coprocess = Open3.popen2e(cmd_line)
    $logger.debug "record: co-process started #{@coprocess}"
    @pid = @coprocess.pid

    while line = oe.gets("\r")
      $logger.debug "****" + line
      if (line =~ /time=([0-9]*\.[0-9]*)/)
        duration = $1.to_f
        $logger.debug "Recording about to yield #{self.total_amount + duration}"
        yield 0.0, ProgressTracker::format_seconds(self.total_amount + duration) if block_given?
      end
    end
    self.total_amount += duration
    yield 1.0, ProgressTracker::format_seconds(self.total_amount) if block_given?
    $logger.debug "Leaving record"
    @coprocess.value
  end

  def stop_recording
    begin
      Process.kill("INT", @pid)
    rescue SystemCallError
      $logger.error("No recording to stop.") unless @state == :paused
    end
    @state = :stopped
  end

  def pause_recording
    begin
      Process.kill("INT", @pid)
    rescue SystemCallError
      $logger.error("No recording to pause.")
    end
    @state = :paused
  end

  # Refactoring this to make it more testable and so it works:
  # Encoding now has two steps: Merge the files (if more than one)
  # and then encode
  # Encode takes an optional block that updates a progress bar or other type
  # of status
  # I believe I have to split it out so that variables are in scope when I
  # need them to be, but mainly I need to make this testable, and now is the time.

  def encode(output_file = "output.mp4", &feedback)
    state = :encoding
    output_file =~ /.mp4$/ || output_file += ".mp4"

    $logger.debug "Encoding #{Capture.format_input_files_for_mkvmerge(@raw_files)}...\n"
    $logger.debug("Total duration #{self.total_amount.to_s}")

    merge(Capture.tmp_file_name, @raw_files, feedback)
    final_encode(output_file, Capture.tmp_file_name, feedback)
  end

  def merge(output_file, input_files, feedback = proc {} )
    $logger.debug("Merging #{input_files.size.to_s} files: #{Capture.format_input_files_for_mkvmerge(input_files)}")
    $logger.debug("Feedback #{feedback}")

    cmd_line = merge_command_line(output_file, input_files)

    $logger.debug "merge: command line: #{cmd_line}"
    i, oe, @coprocess = Open3.popen2e(cmd_line)
    $logger.debug "merge: Thread from popen2e: #{@coprocess}"
    @pid = @coprocess.pid
    $logger.debug "@pid: #{@pid.to_s}"
    while l = oe.gets do
      # TODO: Lots of duplicate code in this line to clean up.
      if block_given?
        yield 0.5, "Merging..."
      else
        feedback.call 0.5, "Merging..."
      end
    end
    if block_given?
      yield 1.0, "Done"
    else
      feedback.call 1.0, "Done"
    end
    @coprocess.value
  end

  def final_encode(output_file, input_file, feedback = proc {} )
    # I think I want to popen here, save the pid, then fork and start
    # updating progress based on what I read, while the main body
    # returns and carries on.

    cmd_line = encode_command_line(output_file, input_file)

    $logger.debug cmd_line

    i, oe, @coprocess = Open3.popen2e(cmd_line)
    @pid = @coprocess.pid

    while (line = oe.gets("\r"))
      $logger.debug "****" + line
      if (line =~ /time=([0-9]*\.[0-9]*)/)
        $logger.debug '******' + $1
        self.current_amount = $1.to_f
      end
      $logger.debug "******** #{self.current_amount} #{self.fraction_complete}"
      feedback.call self.fraction_complete, self.time_remaining_s
    end
    $logger.debug "reached end of file"
    @state = :stopped
    self.fraction_complete = 1
    feedback.call self.fraction_complete, "Done"
    reset
    @coprocess.value # A little bit of a head game here. Either return this, or maybe have to do t.value.value in caller
  end

  def stop_encoding
    begin
      Process.kill("INT", @pid)
    rescue SystemCallError
      $logger.error("No encoding to stop.")
    end
  end

  def reset
    cleanup
    reset_without_cleanup
  end

  def reset_without_cleanup
    @raw_files = []
    self.total_amount = 0.0
  end

  def cleanup
    @raw_files.each { |f| File.delete(f) if File.exists?(f) }
    File.delete(Capture.tmp_file_name) if File.exists?(Capture.tmp_file_name)
  end

  def record_command_line(output_file)
    audio_options="-f alsa -ac 1 -ab #{@audio_sample_frequency} -i #{@audio_input} -acodec #{@acodec}"
    "avconv \
      -f x11grab \
      -show_region 1 \
      -r #{@capture_fps} \
      -s #{@width}x#{@height} \
      -i :0.0+#{@left},#{@top} \
      -qscale #{@qscale} \
      -vcodec #{@capture_vcodec} \
      #{audio_options} \
      -y \
      #{output_file}"
  end

  def merge_command_line(output_file, input_files)
    # TODO: cp doesn't give feedback like mkvmerge does...
    if input_files.size == 1
      "cp -v #{input_files[0]} #{output_file}"
      #cmd_line = "sleep 5"
    else
      "mkvmerge -v -o '#{output_file}' #{Capture.format_input_files_for_mkvmerge(input_files)}"
    end
  end

  def encode_command_line(output_file, input_file)
    "avconv \
      -i '#{input_file}' \
      -vcodec #{@encode_vcodec} \
      -strict experimental \
      -y \
      '#{output_file}'"
  end
end
