require 'git-process'
require 'GitRepoHelper'

describe Git::Process do
  include GitRepoHelper

  before(:each) do
    create_files(['.gitignore'])
    gitlib.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  describe "rebase to master" do

    def log_level
      Logger::ERROR
    end


    it "should work easily for a simple rebase" do
      gitlib.checkout('fb', :new_branch => 'master')
      change_file_and_commit('a', '')

      commit_count.should == 2

      gitlib.checkout('master')
      change_file_and_commit('b', '')

      gitlib.checkout('fb')

      gitprocess.rebase_to_master

      commit_count.should == 3
    end


    it "should work for a rebase after a rerere merge" do
      # Make sure rerere is enabled
      gitlib.rerere_enabled(true, false)
      gitlib.rerere_autoupdate(false, false)

      # Create the file to conflict on
      change_file_and_commit('a', '')

      # In the new branch, give it a new value
      gitlib.checkout('fb', :new_branch => 'master') do
        change_file_and_commit('a', 'hello')
      end

      # Change the value as well in the origional branch
      gitlib.checkout('master') do
        change_file_and_commit('a', 'goodbye')
      end

      # Merge in the new branch; don't error-out because will auto-fix.
      gitlib.checkout('fb') do
        gitlib.merge('master') rescue
        change_file_and_commit('a', 'merged')
      end

      # Make another change on master
      gitlib.checkout('master') do
        change_file_and_commit('b', '')
      end

      # Go back to the branch and try to rebase
      gitlib.checkout('fb')

      begin
        gitprocess.rebase_to_master
        raise "Should have raised RebaseError"
      rescue Git::Process::RebaseError => exp
        exp.resolved_files.should == ['a']
        exp.unresolved_files.should == []

        exp.commands.length.should == 3
        exp.commands[0].should match /^# Verify/
        exp.commands[1].should == 'git add a'
        exp.commands[2].should == 'git rebase --continue'
      end
    end

  end


  describe "custom integration branch" do

    def log_level
      Logger::ERROR
    end


    it "should use the 'gitProcess.integrationBranch' configuration" do
      gitlib.checkout('int-br', :new_branch => 'master') do
        change_file_and_commit('a', '')
      end
      gitlib.checkout('fb', :new_branch => 'master') do
        change_file_and_commit('b', '')
      end
      gitlib.branches['master'].delete

      clone('int-br') do |gl|
        gl.config('gitProcess.integrationBranch', 'int-br')

        gl.checkout('ab', :new_branch => 'origin/int-br')

        branches = gl.branches
        branches.include?('origin/master').should be_false
        branches['ab'].sha.should == branches['origin/int-br'].sha

        change_file_and_commit('c', '', gl)

        branches = gl.branches
        branches['ab'].sha.should_not == branches['origin/int-br'].sha

        Git::Process.new(nil, gl).rebase_to_master

        branches = gl.branches
        branches['HEAD'].sha.should == branches['origin/int-br'].sha
      end
    end

  end


  describe "remove current feature branch" do

    def log_level
      Logger::ERROR
    end


    describe "when handling the parking branch" do

      it "should create it based on origin/master" do
        gitlib.branch('fb', :base_branch => 'master')
        clone('fb') do |gl|
          gp = Git::Process.new(nil, gl)
          gp.remove_feature_branch
          gl.branches.current.name.should == '_parking_'
        end
      end


      it "should move it to the new origin/master if it already exists and is clean" do
        clone do |gl|
          gl.branch('_parking_', :base_branch => 'origin/master')
          change_file_and_commit('a', '', gl)

          gl.checkout('fb', :new_branch => 'origin/master')

          gp = Git::Process.new(nil, gl)
          gp.remove_feature_branch

          gl.branches.current.name.should == '_parking_'
        end
      end


      it "should move it to the new origin/master if it already exists and changes are part of the current branch" do
        gitlib.checkout('afb', :new_branch => 'master')
        clone do |gl|
          gl.checkout('_parking_', :new_branch => 'origin/master') do
            change_file_and_commit('a', '', gl)
          end

          gl.checkout('fb', :new_branch => '_parking_')
          gl.push('origin', 'fb', 'master')

          gp = Git::Process.new(nil, gl)
          gp.remove_feature_branch
          gl.branches.current.name.should == '_parking_'
        end
      end


      it "should move it out of the way if it has unaccounted changes on it" do
        clone do |gl|
          gl.checkout('_parking_', :new_branch => 'origin/master')
          change_file_and_commit('a', '', gl)
          gl.checkout('fb', :new_branch => 'origin/master')

          gl.branches.include?('_parking_OLD_').should be_false

          gp = Git::Process.new(nil, gl)
          gp.remove_feature_branch

          gl.branches.include?('_parking_OLD_').should be_true
          gl.branches.current.name.should == '_parking_'
        end
      end

    end


    it "should delete the old local branch when it has been merged into origin/master" do
      clone do |gl|
        change_file_and_commit('a', '', gl)

        gl.checkout('fb', :new_branch => 'origin/master')
        gl.branches.include?('fb').should be_true

        gp = Git::Process.new(nil, gl)
        gp.remove_feature_branch

        gl.branches.include?('fb').should be_false
        gl.branches.current.name.should == '_parking_'
      end
    end


    it "should raise an error when the local branch has not been merged into origin/master" do
      clone do |gl|
        gl.checkout('fb', :new_branch => 'origin/master')
        change_file_and_commit('a', '', gl)

        gl.branches.include?('fb').should be_true

        gp = Git::Process.new(nil, gl)
        expect {gp.remove_feature_branch}.should raise_error Git::Process::GitProcessError
      end
    end


    it "should delete the old remote branch" do
      change_file_and_commit('a', '')

      gitlib.branch('fb', :base_branch => 'master')

      clone('fb') do |gl|
        gl.branches.include?('origin/fb').should be_true
        Git::Process.new(nil, gl).remove_feature_branch
        gl.branches.include?('origin/fb').should be_false
        gitlib.branches.include?('fb').should be_false
        gl.branches.current.name.should == '_parking_'
      end
    end


    describe "when used while on _parking_" do

      it 'should fail #rebase_to_master' do
        gitlib.checkout('_parking_', :new_branch => 'master')
        change_file_and_commit('a', '')

        expect {gitprocess.rebase_to_master}.should raise_error Git::Process::ParkedChangesError
      end


      it 'should fail #sync_with_server' do
        gitlib.checkout('_parking_', :new_branch => 'master')
        change_file_and_commit('a', '')

        expect {gitprocess.sync_with_server(false, false)}.should raise_error Git::Process::ParkedChangesError
      end

    end

  end


  describe "#new_feature_branch" do

    def log_level
      Logger::ERROR
    end


    it "should create the named branch against origin/master" do
      clone do |gl|
        new_branch = Git::Process.new(nil, gl).new_feature_branch('test_branch')

        new_branch.name.should == 'test_branch'
        new_branch.sha.should == gl.branches['origin/master'].sha
      end
    end


    it "should bring committed changes on _parking_ over to the new branch" do
      gitlib.branch('origin/master', :base_branch => 'master')
      gitlib.checkout('_parking_', :new_branch => 'master')
      change_file_and_commit('a', '')
      change_file_and_commit('b', '')

      new_branch = gitprocess.new_feature_branch('test_branch')

      new_branch.name.should == 'test_branch'
      Dir.chdir(gitlib.workdir) do |dir|
        File.exists?('a').should be_true
        File.exists?('b').should be_true
      end

      gitlib.branches.parking.should be_nil
    end


    it "should bring new/uncommitted changes on _parking_ over to the new branch" do
      gitlib.branch('origin/master', :base_branch => 'master')
      gitlib.checkout('_parking_', :new_branch => 'master')
      change_file_and_commit('a', '')
      change_file_and_add('b', '')
      change_file('c', '')

      new_branch = gitprocess.new_feature_branch('test_branch')

      new_branch.name.should == 'test_branch'
      Dir.chdir(gitlib.workdir) do |dir|
        File.exists?('a').should be_true
        File.exists?('b').should be_true
        File.exists?('c').should be_true
      end

      gitlib.branches.parking.should be_nil
    end

  end


  describe "#sync_with_server" do

    def log_level
      Logger::ERROR
    end


    it "should work when pushing with fast-forward" do
      change_file_and_commit('a', '')

      gitlib.branch('fb', :base_branch => 'master')

      clone('fb') do |gl|
        change_file_and_commit('a', 'hello', gl)
        gl.branches.include?('origin/fb').should be_true
        Git::Process.new(nil, gl).sync_with_server(false, false)
        gl.branches.include?('origin/fb').should be_true
        gitlib.branches.include?('fb').should be_true
      end
    end


    it "should work with a different remote server name" do
      change_file_and_commit('a', '')

      gitlib.branch('fb', :base_branch => 'master')

      clone('fb', 'a_remote') do |gl|
        change_file_and_commit('a', 'hello', gl)
        gl.branches.include?('a_remote/fb').should be_true
        Git::Process.new(nil, gl).sync_with_server(false, false)
        gl.branches.include?('a_remote/fb').should be_true
        gitlib.branches.include?('fb').should be_true
      end
    end


    it "should fail when pushing with non-fast-forward and no force" do
      change_file_and_commit('a', '')

      gitlib.branch('fb', :base_branch => 'master')

      clone('fb') do |gl|
        gitlib.checkout('fb') do
          change_file_and_commit('a', 'hello', gitlib)
        end

        expect {Git::Process.new(nil, gl).sync_with_server(false, false)}.should raise_error Git::GitExecuteError
      end
    end


    it "should work when pushing with non-fast-forward and force" do
      change_file_and_commit('a', '')

      gitlib.branch('fb', :base_branch => 'master')

      clone('fb') do |gl|
        gitlib.checkout('fb') do
          change_file_and_commit('a', 'hello', gitlib)
        end

        # expect {Git::Process.new(nil, gl).sync_with_server(false, true)}.should_not raise_error Git::GitExecuteError
        Git::Process.new(nil, gl).sync_with_server(false, true)
      end
    end

  end


  describe "sync_with_server with different remote name" do

    def log_level
      Logger::ERROR
    end


    def gitprocess
      @gitprocess ||= Git::Process.new(nil, gitlib, :server_name => 'a_remote')
    end


    it "should work with a different remote server name" do
      change_file_and_commit('a', '')

      gitlib.branch('fb', :base_branch => 'master')

      clone('fb', 'a_remote') do |gl|
        change_file_and_commit('a', 'hello', gl)
        gl.branches.include?('a_remote/fb').should be_true
        Git::Process.new(nil, gl).sync_with_server(false, false)
        gl.branches.include?('a_remote/fb').should be_true
        gitlib.branches.include?('fb').should be_true
      end
    end

  end

end
