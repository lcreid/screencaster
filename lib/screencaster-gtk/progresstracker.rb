module ProgressTracker
  attr_writer :start_time, :total_amount
  
  def start_time
    @start_time || @start_time = Time.now
  end

  def percent_complete
    self.fraction_complete * 100
  end
  
  def fraction_complete
    [ self.current_amount.to_f / self.total_amount.to_f, 1.0 ].min
  end
    
  def fraction_complete=(fraction)
    @current_amount = fraction * self.total_amount
  end

  def current_amount
    @current_amount || 0.0
  end

  def current_amount=(amt)
    self.start_time
    @current_amount = amt
  end
  
  def total_amount
    @total_amount || 1.0
  end
  
  def time_remaining
    if self.fraction_complete == 0.0
      1.0
    else
      (Time.new - self.start_time) * (1 - self.fraction_complete) / self.fraction_complete
    end
  end
  
  def time_remaining_s(format = "%dh %02dm %02ds remaining")
    ProgressTracker.format_seconds(self.time_remaining, format)
  end
  
  def self.format_seconds(t, format = "%dh %02dm %02ds")
    h = (t / 3600).to_i
    m = ((t - h * 3600) / 60).to_i
    s = (t % 60).to_i
    sprintf(format, h, m, s)
  end
end

