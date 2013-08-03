#!/usr/bin/env ruby

module ProgressTracker
  attr_reader :start_time
  attr_writer :start_time, :total_amount
  
  def percent_complete
    self.fraction_complete * 100
  end
  
  def fraction_complete
    self.current_amount.to_f / self.total_amount.to_f
  end
    
  def fraction_complete=(fraction)
    @current_amount = fraction * self.total_amount
  end

  def current_amount
    @current_amount || 0.0
  end

  def current_amount=(amt)
    @start_time || @start_time = Time.new

    # puts "Setting current_amount #{amt}"
    @current_amount = amt
  end
  
  def total_amount
    @total_amount || 1.0
  end
  
  def time_remaining
    (Time.new - @start_time) * (1 - self.fraction_complete) / self.fraction_complete
  end
  
  def time_remaining_s(format = "%dh %02dm %02ds remaining")
    t = self.time_remaining
    h = (t / 3600).to_i
    m = ((t - h * 3600) / 60).to_i
    s = (t % 60).to_i
    sprintf(format, h, m, s)
  end
  
end

