require 'git-process/rebase_to_master'
require 'GitRepoHelper'
require 'webmock/rspec'
require 'json'

describe GitProc::RebaseToMaster do
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


  def create_process(dir, opts)
    GitProc::RebaseToMaster.new(dir, opts)
  end


  describe "rebase to master" do

    it "should work easily for a simple rebase" do
      gitprocess.checkout('fb', :new_branch => 'master')
      change_file_and_commit('a', '')

      commit_count.should == 2

      gitprocess.checkout('master')
      change_file_and_commit('b', '')

      gitprocess.checkout('fb')

      gitprocess.run

      commit_count.should == 3
    end


    it "should work for a rebase after a rerere merge" do
      # Make sure rerere is enabled
      gitprocess.rerere_enabled(true, false)
      gitprocess.rerere_autoupdate(false, false)

      # Create the file to conflict on
      change_file_and_commit('a', '')

      # In the new branch, give it a new value
      gitprocess.checkout('fb', :new_branch => 'master') do
        change_file_and_commit('a', 'hello')
      end

      # Change the value as well in the origional branch
      gitprocess.checkout('master') do
        change_file_and_commit('a', 'goodbye')
      end

      # Merge in the new branch; don't error-out because will auto-fix.
      gitprocess.checkout('fb') do
        gitprocess.merge('master') rescue
            change_file_and_commit('a', 'merged')
      end

      # Make another change on master
      gitprocess.checkout('master') do
        change_file_and_commit('b', '')
      end

      # Go back to the branch and try to rebase
      gitprocess.checkout('fb')

      begin
        gitprocess.runner
        raise "Should have raised RebaseError"
      rescue GitProc::RebaseError => exp
        exp.resolved_files.should == %w(a)
        exp.unresolved_files.should == []

        exp.commands.length.should == 3
        exp.commands[0].should match /^# Verify/
        exp.commands[1].should == 'git add a'
        exp.commands[2].should == 'git rebase --continue'
      end
    end


    describe "when used on _parking_" do
      it 'should fail #rebase_to_master' do
        gitprocess.checkout('_parking_', :new_branch => 'master')
        change_file_and_commit('a', '')

        expect { gitprocess.verify_preconditions }.should raise_error GitProc::ParkedChangesError
      end
    end


    describe "closing the pull request" do

      it "should work for an existing pull request" do
        stub_request(:get, /test_repo\/pulls\?access_token=/).
            to_return(:status => 200, :body => JSON([{:number => 987, :state => 'open', :html_url => 'test_url', :head => {:ref => 'fb'}, :base => {:ref => 'master'}}]))
        stub_request(:patch, /test_repo\/pulls\/987\?access_token=/).
            with(:body => JSON({:state => 'closed'})).
            to_return(:status => 200, :body => JSON([{:number => 987, :state => 'closed', :html_url => 'test_url', :head => {:ref => 'fb'}, :base => {:ref => 'master'}}]))

        gitprocess.branch('fb', :base_branch => 'master')

        gp = clone('fb')
        gp.config('gitProcess.github.authToken', 'test-token')
        gp.config('remote.origin.url', 'git@github.com:test_repo.git')
        gp.config('github.user', 'test_user')

        rtm = GitProc::RebaseToMaster.new(gp.workdir, {:log_level => log_level})
        rtm.stub(:fetch)
        rtm.stub(:push)
        rtm.runner
      end


      it "should not try when there is no auth token" do
        gitprocess.branch('fb', :base_branch => 'master')
        gp = clone('fb')
        gp.config('gitProcess.github.authToken', '')
        gp.config('remote.origin.url', 'git@github.com:test_repo.git')
        gp.config('github.user', 'test_user')

        rtm = GitProc::RebaseToMaster.new(gp.workdir, {:log_level => log_level})
        rtm.stub(:fetch)
        rtm.stub(:push)
        rtm.runner
      end


      it "should not try when there is a file:// origin url" do
        gitprocess.branch('fb', :base_branch => 'master')
        gp = clone('fb')
        gp.config('gitProcess.github.authToken', 'test-token')
        gp.config('github.user', 'test_user')

        rtm = GitProc::RebaseToMaster.new(gp.workdir, {:log_level => log_level})
        rtm.stub(:fetch)
        rtm.stub(:push)
        rtm.runner
      end

    end

  end


  describe "custom integration branch" do

    it "should use the 'gitProcess.integrationBranch' configuration" do
      gitprocess.checkout('int-br', :new_branch => 'master')
      change_file_and_commit('a', '')

      gitprocess.checkout('fb', :new_branch => 'master')
      change_file_and_commit('b', '')

      gitprocess.branches['master'].delete!

      gl = clone('int-br')
      gl.config('gitProcess.integrationBranch', 'int-br')

      gl.checkout('ab', :new_branch => 'origin/int-br')

      my_branches = gl.branches
      my_branches.include?('origin/master').should be_false
      my_branches['ab'].sha.should == my_branches['origin/int-br'].sha

      gl.stub(:repo_name).and_return('test_repo')

      change_file_and_commit('c', '', gl)

      my_branches = gl.branches
      my_branches['ab'].sha.should_not == my_branches['origin/int-br'].sha

      GitProc::RebaseToMaster.new(gl.workdir, {:log_level => log_level}).runner

      my_branches = gl.branches
      my_branches['HEAD'].sha.should == my_branches['origin/int-br'].sha
    end

  end


  describe "remove current feature branch" do

    describe "when handling the parking branch" do

      it "should create it based on origin/master" do
        gitprocess.branch('fb', :base_branch => 'master')
        clone('fb') do |gp|
          gp.remove_feature_branch
          gp.branches.current.name.should == '_parking_'
        end
      end


      it "should move it to the new origin/master if it already exists and is clean" do
        clone do |gp|
          gp.branch('_parking_', :base_branch => 'origin/master')
          change_file_and_commit('a', '', gp)

          gp.checkout('fb', :new_branch => 'origin/master')

          gp.remove_feature_branch

          gp.branches.current.name.should == '_parking_'
        end
      end


      it "should move it to the new origin/master if it already exists and changes are part of the current branch" do
        gitprocess.checkout('afb', :new_branch => 'master')
        clone do |gp|
          gp.checkout('_parking_', :new_branch => 'origin/master') do
            change_file_and_commit('a', '', gp)
          end

          gp.checkout('fb', :new_branch => '_parking_')
          gp.push('origin', 'fb', 'master')

          gp.remove_feature_branch
          gp.branches.current.name.should == '_parking_'
        end
      end


      it "should move it out of the way if it has unaccounted changes on it" do
        clone do |gp|
          gp.checkout('_parking_', :new_branch => 'origin/master')
          change_file_and_commit('a', '', gp)
          gp.checkout('fb', :new_branch => 'origin/master')

          gp.branches.include?('_parking_OLD_').should be_false

          gp.remove_feature_branch

          gp.branches.include?('_parking_OLD_').should be_true
          gp.branches.current.name.should == '_parking_'
        end
      end

    end


    it "should delete the old local branch when it has been merged into origin/master" do
      clone do |gp|
        change_file_and_commit('a', '', gp)

        gp.checkout('fb', :new_branch => 'origin/master')
        gp.branches.include?('fb').should be_true

        gp.remove_feature_branch

        gp.branches.include?('fb').should be_false
        gp.branches.current.name.should == '_parking_'
      end
    end


    it "should raise an error when the local branch has not been merged into origin/master" do
      clone do |gp|
        gp.checkout('fb', :new_branch => 'origin/master')
        change_file_and_commit('a', '', gp)

        gp.branches.include?('fb').should be_true

        expect { gp.remove_feature_branch }.should raise_error GitProc::GitProcessError
      end
    end


    it "should delete the old remote branch" do
      change_file_and_commit('a', '')

      gitprocess.branch('fb', :base_branch => 'master')

      clone('fb') do |gp|
        gp.branches.include?('origin/fb').should be_true
        gp.remove_feature_branch
        gp.branches.include?('origin/fb').should be_false
        gitprocess.branches.include?('fb').should be_false
        gp.branches.current.name.should == '_parking_'
      end
    end

  end


  describe ":keep option" do

    it "should not try to close a pull request or remove remote branch" do
      gitprocess.branch('fb', :base_branch => 'master')

      rtm = GitProc::RebaseToMaster.new(clone('fb').workdir, {:log_level => log_level, :keep => true})
      rtm.should_receive(:fetch)
      rtm.should_receive(:push).with('origin', rtm.branches.current, 'master')
      rtm.should_not_receive(:push).with('origin', nil, nil, :delete => 'fb')
      rtm.runner
    end

  end


  describe ":interactive option" do

    it "should try to do an interactive rebase" do
      gitprocess.branch('fb', :base_branch => 'master')

      rtm = GitProc::RebaseToMaster.new(clone('fb').workdir, {:log_level => log_level, :interactive => true})
      rtm.should_receive(:fetch)
      rtm.should_receive(:rebase).with('origin/master', {})
      rtm.should_receive(:rebase).with('origin/master', :interactive => true)
      rtm.should_receive(:push).with('origin', rtm.branches.current, 'master')
      rtm.should_receive(:push).with('origin', nil, nil, :delete => 'fb')
      rtm.runner
    end

  end

end
