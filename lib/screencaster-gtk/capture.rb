require 'open3'
require 'logger'
require "screencaster-gtk/progresstracker"

class Capture
  include ProgressTracker
  
  attr_writer :left, :top, :right, :bottom
  attr_reader :state
  attr :pid
  attr :tmp_files
  
  def initialize
    @tmp_files = []
    @exit_chain = Signal.trap("EXIT") { 
      self.cleanup
      $logger.debug "In capture about to chain to trap @exit_chain: #{@exit_chain}"
      @exit_chain.call unless @exit_chain.nil? 
    }
    $logger.debug "@exit_chain: #{@exit_chain.to_s}"
    @state = :stopped
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
    
    $logger.debug "Before xprop: Capturing #{@left.to_s},#{@top.to_s} to #{(@left+@width).to_s},#{(@top+@height).to_s}. Dimensions #{@width.to_s},#{@height.to_s}.\n"
    
    # Use xprop on the window to figure out decorations? Maybe...
    # $logger.debug "Window ID: #{window_id}"
    # info = `xprop -id #{window_id}`
    # info =~ /_NET_FRAME_EXTENTS\(CARDINAL\) = ([[:digit:]]+), ([[:digit:]]+), ([[:digit:]]+), ([[:digit:]]+)/
    # border_left = $1.to_i
    # border_right = $2.to_i
    # border_top = $3.to_i
    # border_bottom = $4.to_i
    # 
    # $logger.debug "Borders: #{border_left.to_s},#{border_top.to_s},#{border_right.to_s},#{border_bottom.to_s}.\n"
    # 
    # top += border_top
    # left += border_left
    # height -= border_top + border_bottom
    # width -= border_left + border_right
    
    @height +=  @height % 2
    @width += @width % 2

    $logger.debug "Capturing #{@left},#{@top} to #{@left+@width},#{@top+@height}. Dimensions #{@width},#{@height}.\n"
  end
  
  def record
    if @state != :paused
      @tmp_files = [] 
      self.total_amount = 0.0
    end
    record_one_file(self.new_tmp_file)
  end
  
  def record_one_file(output_file)
    @state = :recording
    capture_fps=24
    audio_options="-f alsa -ac 1 -ab 192k -i pulse -acodec pcm_s16le"
    
    # And i should probably popen here, save the pid, then fork and start
    # reading the input, updating the number of frames saved, or the time
    # recorded.
    $logger.debug "Capturing...\n"
    # @pid = Process.spawn("avconv \
        # #{audio_options} \
        # -f x11grab \
        # -show_region 1 \
        # -r #{capture_fps} \
        # -s #{@width}x#{@height} \
        # -i :0.0+#{@left},#{@top} \
        # -qscale 0 -vcodec ffv1 \
        # -y \
        # #{TMP_FILE}")
    # Process.detach(@pid)
    # avconv writes output to stderr, why?
    # writes with CR and not LF, so it's hard to read
    # with popen and 2>&1, an extra shell gets created that messed things up.
    # popen2e helps.
    vcodec = 'huffyuv' # I used to use ffv1
    
    cmd_line = "avconv \
      #{audio_options} \
      -f x11grab \
      -show_region 1 \
      -r #{capture_fps} \
      -s #{@width}x#{@height} \
      -i :0.0+#{@left},#{@top} \
      -qscale 0 -vcodec #{vcodec} \
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
        end
      end
      self.total_amount += duration
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
    
    if input_files.size == 1
      cmd_line = "cp #{input_files[0]} #{output_file}"
      #cmd_line = "sleep 5"
    else
      cmd_line = "mkvmerge -v -o #{output_file} #{Capture.format_input_files_for_mkvmerge(input_files)}"
    end
    $logger.debug "Merge command line: #{cmd_line}"
    i, oe, t = Open3.popen2e(cmd_line)
    @pid = t.pid
    Process.detach(@pid)
    $logger.debug "@pid: #{@pid.to_s}"
    
    t = Thread.new do
      # $logger.debug "Sleeping..."
      # sleep 2
      # $logger.debug "Awake!"
      while oe.gets do
        # $logger.debug "Line"
      end
      feedback.call 1.0, "Done"
    end
    return t
  end
  
  def final_encode(output_file, input_file, feedback = proc {} )
    encode_fps=24
    video_encoding_options="-vcodec libx264 -pre:v ultrafast"
    
    # I think I want to popen here, save the pid, then fork and start
    # updating progress based on what I read, which the main body
    # returns and carries on.
    
    # The following doesn't seem to be necessary
#      -s #{@width}x#{@height} \
    cmd_line = "avconv \
      -i #{input_file} \
      #{video_encoding_options} \
      -r #{encode_fps} \
      -threads 0 \
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

