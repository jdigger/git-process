require 'git-process/git_process'
require 'GitRepoHelper'
require 'fileutils'

describe GitProc::Process do
  include GitRepoHelper


  def log_level
    Logger::ERROR
  end


  before(:each) do
    create_files(%w(.gitignore))
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  describe "workdir" do

    it "should use the passed in directory when the top level is a git workdir" do
      proc = GitProc::Process.new(tmpdir)
      proc.workdir.should == tmpdir
    end


    it "should find the parent git workdir" do
      dir = "#{tmpdir}/a/b/c/d/e/f/g"
      mkdir_p dir
      proc = GitProc::Process.new(dir)
      proc.workdir.should == tmpdir
    end

  end


  describe "run lifecycle" do

    it "should call the standard hooks" do
      proc = GitProc::Process.new(tmpdir)
      proc.should_receive(:verify_preconditions)
      proc.should_receive(:runner)
      proc.should_receive(:cleanup)
      proc.should_not_receive(:exit)

      proc.run
    end


    it "should call 'cleanup' even if there's an error" do
      proc = GitProc::Process.new(tmpdir)
      proc.should_receive(:verify_preconditions)
      proc.should_receive(:runner).and_raise(GitProc::GitProcessError.new("Error!"))
      proc.should_receive(:cleanup)
      proc.should_receive(:exit)
      proc.should_receive(:puts).with("Error!")

      proc.run
    end

  end


  describe "validate local integration branch" do

    it "should use remove the int-branch if not on it and not blocked" do
      gp = clone('master')
      gp.checkout('fb', :new_branch => 'master')

      gp.stub(:ask_about_removing_master).and_return(true)

      gp.verify_preconditions

      gp.branches.include?('master').should be_false
    end


    it "should ask use remove the int-branch if not on it and not blocked" do
      gp = clone('master')
      gp.checkout('fb', :new_branch => 'master')

      gp.should_receive(:ask_about_removing_master).and_return(true)

      gp.verify_preconditions

      gp.branches.include?('master').should be_false
    end


    it "should ask use remove the int-branch if not on it and not blocked and not remove if answered no" do
      gp = clone('master')
      gp.checkout('fb', :new_branch => 'master')

      gp.should_receive(:ask_about_removing_master).and_return(false)

      gp.verify_preconditions

      gp.branches.include?('master').should be_true
    end


    it "should not remove the int-branch if on it" do
      gp = clone('master')

      gp.verify_preconditions

      gp.branches.include?('master').should be_true
    end


    it "should not remove the int-branch if blocked" do
      gp = clone('master')
      gp.config('gitProcess.keepLocalIntegrationBranch', 'true')
      gp.checkout('fb', :new_branch => 'master')

      gp.verify_preconditions

      gp.branches.include?('master').should be_true
    end


    describe "local vs remote branch status" do

      before(:each) do
        change_file_and_commit('a.txt', 'a content', gitprocess)
        change_file_and_commit('b.txt', 'b content', gitprocess)
      end


      it "should not remove if both have changes" do
        gp = clone('master')

        change_file_and_commit('c.txt', 'c on origin/master', gitprocess)
        change_file_and_commit('d.txt', 'd on master', gp)

        gp.checkout('fb', :new_branch => 'master')

        gp.fetch
        gp.verify_preconditions

        gp.branches.include?('master').should be_true
      end


      it "should remove if server changed but not local" do
        gp = clone('master')
        gp.stub(:ask_about_removing_master).and_return(true)

        change_file_and_commit('c.txt', 'c on origin/master', gitprocess)

        gp.checkout('fb', :new_branch => 'master')

        gp.fetch
        gp.verify_preconditions

        gp.branches.include?('master').should be_false
      end


      it "should not remove if server did not change but local did" do
        gp = clone('master')

        change_file_and_commit('c.txt', 'c on master', gp)

        gp.checkout('fb', :new_branch => 'master')

        gp.fetch
        gp.verify_preconditions

        gp.branches.include?('master').should be_true
      end


      it "should remove if server and local are the same" do
        change_file_and_commit('c.txt', 'c on origin/master', gitprocess)

        gp = clone('master')

        gp.checkout('fb', :new_branch => 'master')
        gp.stub(:ask_about_removing_master).and_return(true)

        gp.fetch
        gp.verify_preconditions

        gp.branches.include?('master').should be_false
      end

    end


    it "should not remove the int-branch if not a clone" do
      gitprocess.config('gitProcess.keepLocalIntegrationBranch', 'false')
      gitprocess.checkout('fb', :new_branch => 'master')

      gitprocess.verify_preconditions

      gitprocess.branches.include?('master').should be_true
    end

  end

end
