require File.expand_path('../../lib/git-process', __FILE__)
require File.expand_path('../FileHelpers', __FILE__)

describe Git::Process do

  before(:each) do
    @tmpdir = Dir.mktmpdir
  end

  after(:each) do
    rm_rf(@tmpdir)
  end


  def commit_count(gp)
    gp.lib.log_count
  end


  describe "rebase to master" do

    it "should work easily for a simple rebase" do
      tgz_file = File.expand_path('../files/simple-rebase.tgz', __FILE__)
      Dir.chdir(@tmpdir) { `tar xfz #{tgz_file}` }
      gp = Git::Process.new(@tmpdir, :log_level => Logger::ERROR)

      commit_count(gp).should == 2

      gp.rebase_to_master(false)

      commit_count(gp).should == 3
    end

    it "should work for a rebase after a rerere merge" do
      tgz_file = File.expand_path('../files/merge-conflict-rerere.tgz', __FILE__)
      Dir.chdir(@tmpdir) { `tar xfz #{tgz_file}` }
      gp = Git::Process.new(@tmpdir, :log_level => Logger::ERROR)

      commit_count(gp).should == 4

      gp.rebase_to_master(false)

      commit_count(gp).should == 3  # the merge commit is removed
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
