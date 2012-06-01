require File.expand_path('../../lib/git-process', __FILE__)
require File.expand_path('../FileHelpers', __FILE__)

describe Git::Process do
  @@logger = Logger.new(STDOUT)
  @@logger.level = Logger::INFO
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


  def commit_count(gp)
    gp.git.log.count
  end


  describe "rebase to master" do

    it "should should work easily for a simple rebase" do
      tgz_file = File.expand_path('../files/simple-rebase.tgz', __FILE__)
      Dir.chdir(@tmpdir) { `tar xfz #{tgz_file}` }
      gp = Git::Process.new(@tmpdir, @@logger)

      commit_count(gp).should == 2

      gp.rebase_to_master(false)

      commit_count(gp).should == 3
    end

  end


  # describe "when creating" do
  # 
  #   before(:each) do
  #     @gp = Git::Process.new(@tmpdir, @@logger)
  #     files = [File.join(@gp.workdir, 'a')]
  #     FileUtils.touch files
  #     files.each {|f| @gp.add(f)}
  #     
  #     @gp.commit("initial commit")
  #   end
  # 
  #   it "should be clonable" do
  #     puts "clone_dir: #{@gp.clone(@gp.workdir, Dir.mktmpdir.to_s).workdir}"
  #   end
  # 
  #   it "should rebase to master" do
  #     @gp.rebase_to_master(false)
  #   end
  # 
  # end

end
