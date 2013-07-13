module ProgressTracker
  attr_reader :start_time
  attr_writer :start_time, :total_amount
  
  def percent_complete
    fraction_complete * 100
  end
  
  def fraction_complete
    current_amount.to_f / total_amount.to_f
  end
    
  def fraction_complete=(fraction)
    @current_amount = fraction * total_amount
  end

  def current_amount
    @current_amount || 0.0
  end

  def current_amount=(amt)
    @start_time || @start_time = Time.new

    puts "Setting current_amount #{amt}"
    @current_amount = amt
  end
  
  def total_amount
    @total_amount || 1.0
  end
  
  def time_remaining
    (Time.new - @start_time) / fraction_complete
  end
  
  def time_remaining_s(s = "%s remaining")
    sprintf(s, time_remaining)
  end
  
end

