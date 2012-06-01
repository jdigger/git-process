require File.expand_path('../../lib/git-process', __FILE__)
require File.expand_path('../FileHelpers', __FILE__)

describe Git::Process do
  @@logger = Logger.new(STDOUT)
  @@logger.level = Logger::WARN
  @@logger.datetime_format = "%Y-%m-%d %H:%M:%S"
  f = Logger::Formatter.new
  @@logger.formatter = proc do |severity, datetime, progname, msg|
    "#{severity[0..0]}: Git::Process #{datetime.strftime(@@logger.datetime_format)}: #{msg}\n"
  end


  before(:each) do
    @tmpdir = Dir.mktmpdir
  end

  after(:each) do
    rm_rf(@tmpdir)
  end


  describe "when creating" do

    before(:each) do
      @gp = Git::Process.new(@tmpdir, @@logger)
      files = [File.join(@gp.workdir, 'a')]
      FileUtils.touch files
      files.each {|f| @gp.add(f)}
      
      @gp.commit("initial commit")
    end

    it "should hand over a valid repo" do
#      
    end

  end

end
