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
  attr :pid
  attr :tmp_files

  attr :capture_fps
  attr :encode_fps
  attr :capture_vcodec 
  attr :qscale
  attr :encode_vcodec
  attr :acodec
  attr :audio_sample_frequency
  
  
  def initialize
    @tmp_files = []
    @exit_chain = Signal.trap("EXIT") { 
      self.cleanup
      $logger.debug "In capture about to chain to trap @exit_chain: #{@exit_chain}"
      @exit_chain.call unless @exit_chain.nil? 
    }
    #$logger.debug "@exit_chain: #{@exit_chain.to_s}"
    
    @state = :stopped
    
    @capture_fps = 30
    @encode_fps = 30 # Don't use this. Just copy through
    @capture_vcodec = 'huffyuv' # I used to use ffv1. This is for capture
    @qscale = '4' # Recommended for fast encoding by avconv docs
    @encode_vcodec = 'libx264'
    @acodec = 'aac' # Youtube prefers "AAC-LC" but I don't see one called "-LC"
    @audio_sample_frequency = "48k"
  end
  
  def current_tmp_file
    @tmp_files.last
  end
  
  def new_tmp_file
    @tmp_files << Capture.tmp_file_name(@tmp_files.size)
    self.current_tmp_file
  end
  
  def self.tmp_file_name(index = nil)
    "/tmp/screencaster_#{$$}" + (index.nil? ? "": "_#{"%04d" % index}") + ".mkv"
  end
  
  def self.format_input_files_for_mkvmerge(files)
    files.drop(1).inject("\"#{files.first}\"") {|a, b| "#{a} + \"#{b}\"" }
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
    if @state != :paused
      @tmp_files = [] 
      self.total_amount = 0.0
    end

    output_file = self.new_tmp_file

    @state = :recording
    audio_options="-f alsa -ac 1 -ab #{@audio_sample_frequency} -i pulse -acodec #{acodec}"
    
    # And i should probably popen here, save the pid, then fork and start
    # reading the input, updating the number of frames saved, or the time
    # recorded.
    $logger.debug "Capturing...\n"

    cmd_line = "avconv \
      #{audio_options} \
      -f x11grab \
      -show_region 1 \
      -r #{@capture_fps} \
      -s #{@width}x#{@height} \
      -i :0.0+#{@left},#{@top} \
      -qscale #{@qscale} \
      -vcodec #{@capture_vcodec} \
      -y \
      #{output_file}"
    
    $logger.debug cmd_line

    i, oe, t = Open3.popen2e(cmd_line)
    @pid = t.pid
    Process.detach(@pid)
    
    duration = 0.0
    Thread.new do
      while line = oe.gets("\r")
        $logger.debug "****" + line
        if (line =~ /time=([0-9]*\.[0-9]*)/)
          duration = $1.to_f
          $logger.debug "Recording about to yield #{self.total_amount + duration}"
          yield 0.0, ProgressTracker::format_seconds(self.total_amount + duration)
        end
      end
      self.total_amount += duration
      yield 0.0, ProgressTracker::format_seconds(self.total_amount)
    end
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
    
    $logger.debug "Encoding #{Capture.format_input_files_for_mkvmerge(@tmp_files)}...\n"
    $logger.debug("Total duration #{self.total_amount.to_s}")

    t = self.merge(Capture.tmp_file_name, @tmp_files)
    t.value
    self.final_encode(output_file, Capture.tmp_file_name, feedback)
  end 
  
  # This is ugly.
  # When you open co-processes, they do get stuck together.
  # It seems the if I don't read what's coming out of the co-process, it waits.
  # But if I read it, then it goes right to the end until it returns.
  
  def merge(output_file, input_files, feedback = proc {} )
    $logger.debug("Merging #{input_files.size.to_s} files: #{Capture.format_input_files_for_mkvmerge(input_files)}")
    $logger.debug("Feedback #{feedback}")
    
    # TODO: cp doesn't give feedback like mkvmerge does...
    if input_files.size == 1
      cmd_line = "cp -v #{input_files[0]} #{output_file}"
      #cmd_line = "sleep 5"
    else
      cmd_line = "mkvmerge -v -o #{output_file} #{Capture.format_input_files_for_mkvmerge(input_files)}"
    end
    $logger.debug "Merge command line: #{cmd_line}"
    i, oe, t = Open3.popen2e(cmd_line)
    $logger.debug "Thread from popen2e: #{t}"
    @pid = t.pid
    Process.detach(@pid)
    $logger.debug "@pid: #{@pid.to_s}"
    
    t = Thread.new do
      $logger.debug "Thread from Thread.new: #{t}"
      # $logger.debug "Sleeping..."
      # sleep 2
      # $logger.debug "Awake!"
      while l = oe.gets do
        # TODO: Lots for duplicate code in this line to clean up.
        if block_given? 
          yield 0.5, ""
        else
          feedback.call 0.5, ""
        end
      end
      if block_given?
        yield 1.0, "Done"
      else
        feedback.call 1.0, "Done"
      end
    end
    return t
  end
  
  def final_encode(output_file, input_file, feedback = proc {} )
    # I think I want to popen here, save the pid, then fork and start
    # updating progress based on what I read, which the main body
    # returns and carries on.
    
    cmd_line = "avconv \
      -i #{input_file} \
      -vcodec #{@encode_vcodec} \
      -y \
      '#{output_file}'"
      
    $logger.debug cmd_line
    
    i, oe, t = Open3.popen2e(cmd_line)
    @pid = t.pid
    Process.detach(@pid)
    
    Thread.new do
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
      feedback.call self.fraction_complete = 1, self.time_remaining_s
    end
  end
  
  def stop_encoding
    begin
      Process.kill("INT", @pid)
    rescue SystemCallError
      $logger.error("No encoding to stop.")
    end
  end

  def cleanup
    @tmp_files.each { |f| File.delete(f) if File.exists?(f) }
    File.delete(Capture.tmp_file_name) if File.exists?(Capture.tmp_file_name)
  end
end

