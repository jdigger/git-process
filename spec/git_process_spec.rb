require File.dirname(__FILE__) + '/../lib/git-process/git_process'
require 'GitRepoHelper'
require 'climate_control'
require 'fileutils'

describe GitProc::Process do
  include GitRepoHelper


  def log_level
    Logger::ERROR
  end


  before(:each) do
    create_files(%w(.gitignore))
    gitlib.commit('initial')
  end


  after(:each) do
    rm_rf(gitlib.workdir)
  end

  around do |example|
    # make sure there aren't side-effects testing from the testing user's .gitconfig
    ClimateControl.modify HOME: '/path_that_does_not_exist' do
      example.run
    end
  end


  describe 'run lifecycle' do

    it 'should call the standard hooks' do
      proc = GitProc::Process.new(gitlib)
      proc.should_receive(:verify_preconditions)
      proc.should_receive(:runner)
      proc.should_receive(:cleanup)
      proc.should_not_receive(:exit)

      proc.run
    end


    it "should call 'cleanup' even if there's an error" do
      proc = GitProc::Process.new(gitlib)
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
      clone_repo('master') do |gl|
        gl.checkout('fb', :new_branch => 'master')

        gp = GitProc::Process.new(gl)
        gp.stub(:ask_about_removing_master).and_return(true)

        gp.verify_preconditions

        gl.branches.include?('master').should be_false
      end
    end


    it "should ask use remove the int-branch if not on it and not blocked" do
      clone_repo('master') do |gl|
        gl.checkout('fb', :new_branch => 'master')

        gp = GitProc::Process.new(gl)
        gp.should_receive(:ask_about_removing_master).and_return(true)

        gp.verify_preconditions

        gl.branches.include?('master').should be_false
      end
    end


    it "should ask use remove the int-branch if not on it and not blocked and not remove if answered no" do
      clone_repo('master') do |gl|
        gl.checkout('fb', :new_branch => 'master')

        gp = GitProc::Process.new(gl)
        gp.should_receive(:ask_about_removing_master).and_return(false)

        gp.verify_preconditions

        gl.branches.include?('master').should be_true
      end
    end


    it "should not remove the int-branch if on it" do
      clone_repo('master') do |gl|
        gp = GitProc::Process.new(gl)
        gp.verify_preconditions

        gl.branches.include?('master').should be_true
      end
    end


    it "should not remove the int-branch if blocked" do
      clone_repo('master') do |gl|
        gl.config['gitProcess.keepLocalIntegrationBranch'] = 'true'
        gl.checkout('fb', :new_branch => 'master')

        gp = GitProc::Process.new(gl)
        gp.verify_preconditions

        gl.branches.include?('master').should be_true
      end
    end


    describe "local vs remote branch status" do

      before(:each) do
        change_file_and_commit('a.txt', 'a content', gitlib)
        change_file_and_commit('b.txt', 'b content', gitlib)
      end


      it "should not remove if both have changes" do
        clone_repo('master') do |gl|
          change_file_and_commit('c.txt', 'c on origin/master', gitlib)
          change_file_and_commit('d.txt', 'd on master', gl)

          gl.checkout('fb', :new_branch => 'master')

          gl.fetch

          gp = GitProc::Process.new(gl)
          gp.verify_preconditions

          gl.branches.include?('master').should be_true
        end
      end


      it "should remove if server changed but not local" do
        clone_repo('master') do |gl|
          gp = GitProc::Process.new(gl)
          gp.stub(:ask_about_removing_master).and_return(true)

          change_file_and_commit('c.txt', 'c on origin/master', gitlib)

          gl.checkout('fb', :new_branch => 'master')

          gl.fetch

          gp.verify_preconditions

          gl.branches.include?('master').should be_false
        end
      end


      it "should not remove if server did not change but local did" do
        clone_repo('master') do |gl|
          change_file_and_commit('c.txt', 'c on master', gl)

          gl.checkout('fb', :new_branch => 'master')

          gl.fetch

          gp = GitProc::Process.new(gl)
          gp.verify_preconditions

          gl.branches.include?('master').should be_true
        end
      end


      it "should remove if server and local are the same" do
        change_file_and_commit('c.txt', 'c on origin/master', gitlib)

        clone_repo('master') do |gl|
          gl.checkout('fb', :new_branch => 'master')
          gp = GitProc::Process.new(gl)
          gp.stub(:ask_about_removing_master).and_return(true)

          gl.fetch
          gp.verify_preconditions

          gl.branches.include?('master').should be_false
        end
      end

    end


    it "should not remove the int-branch if not a clone" do
      gitlib.config['gitProcess.keepLocalIntegrationBranch'] = 'false'
      gitlib.checkout('fb', :new_branch => 'master')

      gitprocess = GitProc::Process.new(gitlib)
      gitprocess.verify_preconditions

      gitlib.branches.include?('master').should be_true
    end

  end

end
