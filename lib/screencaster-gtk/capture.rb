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
    @exit_chain = trap("EXIT") { self.cleanup; @exit_chain.call unless @exit_chain == "DEFAULT" }
    state = :stopped
  end
  
  def current_tmp_file
    @tmp_files.last
  end
  
  def new_tmp_file
    @tmp_files << self.tmp_file_name(@tmp_files.size)
  end
  
  def tmp_file_name(index = nil)
    "/tmp/screencaster_#{$$}" + (index.nil? ? "": "_#{"%04d" % index}") + ".mkv"
  end
  
  def input_files
    @tmp_files.inject {|a, b| "#{a} +#{b}" }
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
    @tmp_files = [] if @state != :paused
    @state = :recording
    capture_fps=24
    audio_options="-f alsa -ac 1 -ab 192k -i pulse -acodec pcm_s16le"
    self.new_tmp_file
    
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
    i, oe, t = Open3.popen2e("avconv \
        #{audio_options} \
        -f x11grab \
        -show_region 1 \
        -r #{capture_fps} \
        -s #{@width}x#{@height} \
        -i :0.0+#{@left},#{@top} \
        -qscale 0 -vcodec #{vcodec} \
        -y \
        #{self.current_tmp_file}")
    @pid = t.pid
    Process.detach(@pid)
    
    Thread.new do
      while line = oe.gets("\r")
        $logger.debug "****" + line
        (line =~ /time=([0-9]*\.[0-9]*)/) && (self.total_amount = $1.to_f)
      end
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

  def encode(output_file = "output.mp4")
    state = :encoding
    encode_fps=24
    video_encoding_options="-vcodec libx264 -pre:v ultrafast"

    output_file =~ /.mp4$/ || output_file += ".mp4"
    
    # I think I want to popen here, save the pid, then fork and start
    # updating progress based on what I read, which the main body
    # returns and carries on.
    $logger.debug "Encoding #{self.input_files}...\n"
    
    cmd_line = "mkvmerge -o #{self.tmp_file_name} #{self.input_files}"
    $logger.debug cmd_line
    $logger.debug(`#{cmd_line}`)
    $logger.debug "mkvmerge return value #{$?}"
    
    cmd_line = "avconv \
        -i #{tmp_file_name} \
        #{video_encoding_options} \
        -r #{encode_fps} \
        -s #{@width}x#{@height} \
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
        (line =~ /time=([0-9]*\.[0-9]*)/) && (self.current_amount = $1.to_f)
        # $logger.debug '****' + $1
        # $logger.debug "******** #{self.current_amount} #{self.fraction_complete}"
        yield self.fraction_complete, self.time_remaining_s
      end
      $logger.debug "reached end of file"
      @state = :stopped
      yield self.fraction_complete = 1, self.time_remaining_s
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
    @tmp_files.each { |f| File.delete(f) }
  end
end

