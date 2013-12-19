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
  
  def copy_baseline_file_to_test_directory(f)
    target = file_name(f)
    FileUtils.cp(file_name(File.join("baseline", f)), target)
    target
  end
end
