require 'tmpdir'
include FileUtils

module FileHelpers
  TEST_DIR = File.dirname(__FILE__)

  def dir_files(dir)
    Dir.entries(dir).grep(/^[^.]/)
  end


  def compare_files(file1name, file2name)
    str1 = IO.read(file1name)
    str2 = IO.read(file2name)
    str1.should == str2
  end

end
