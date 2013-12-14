module TestUtils
  Thread.abort_on_exception = true
  TEST_FILE_PATH = File.dirname(__FILE__)
  
  $logger = Logger.new(STDOUT)
  $logger.formatter = proc do |severity, datetime, progname, msg|
    "#{msg}\n"
  end
  
  def file_name(f)
    File.join(TEST_FILE_PATH, f)
  end

  def baseline_file_name(f)
    file_name(File.join('baseline', f))
  end
end
