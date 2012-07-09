require 'git-process/rebase_to_master'
require 'GitRepoHelper'
require 'webmock/rspec'
require 'json'

describe GitProc::RebaseToMaster do
  include GitRepoHelper

  before(:each) do
    create_files(['.gitignore'])
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  def create_process(dir, opts)
    GitProc::RebaseToMaster.new(dir, opts)
  end


  describe "rebase to master" do

    def log_level
      Logger::ERROR
    end


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
        exp.resolved_files.should == ['a']
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

        expect {gitprocess.runner}.should raise_error GitProc::ParkedChangesError
      end
    end


    describe "closing the pull request" do

      def log_level
        Logger::ERROR
      end


      it "should work for an existing pull request" do
        gitprocess.branch('fb', :base_branch => 'master')
        clone('fb') do |gp|
          stub_request(:get, /test_repo\/pulls\?access_token=/).
            to_return(:status => 200, :body => JSON([{:number => 987, :state => 'open', :html_url => 'test_url', :head => {:ref => 'fb'}, :base => {:ref => 'master'}}]))
          stub_request(:patch, /test_repo\/pulls\/987\?access_token=/).
            with(:body => JSON({:state => 'closed'})).
            to_return(:status => 200, :body => JSON([{:number => 987, :state => 'closed', :html_url => 'test_url', :head => {:ref => 'fb'}, :base => {:ref => 'master'}}]))
          gp.config('gitProcess.github.authToken', 'test-token')
          gp.config('remote.origin.url', 'git@github.com:test_repo.git')
          gp.config('github.user', 'test_user')
          gp.stub(:fetch)
          gp.stub(:push)

          gp.runner
        end
      end


      it "should not try when there is no auth token" do
        gitprocess.branch('fb', :base_branch => 'master')
        clone('fb') do |gp|
          gp.config('gitProcess.github.authToken', '')
          gp.config('remote.origin.url', 'git@github.com:test_repo.git')
          gp.config('github.user', 'test_user')
          gp.stub(:fetch)
          gp.stub(:push)

          gp.runner
        end
      end


      it "should not try when there is a file:// origin url" do
        gitprocess.branch('fb', :base_branch => 'master')
        clone('fb') do |gp|
          gp.config('gitProcess.github.authToken', 'test-token')
          gp.config('github.user', 'test_user')
          gp.stub(:fetch)
          gp.stub(:push)

          gp.runner
        end
      end

    end

  end


  describe "custom integration branch" do

    def log_level
      Logger::ERROR
    end


    it "should use the 'gitProcess.integrationBranch' configuration" do
      gitprocess.checkout('int-br', :new_branch => 'master') do
        change_file_and_commit('a', '')
      end
      gitprocess.checkout('fb', :new_branch => 'master') do
        change_file_and_commit('b', '')
      end
      gitprocess.branches['master'].delete

      clone('int-br') do |gl|
        gl.config('gitProcess.integrationBranch', 'int-br')

        gl.checkout('ab', :new_branch => 'origin/int-br')

        branches = gl.branches
        branches.include?('origin/master').should be_false
        branches['ab'].sha.should == branches['origin/int-br'].sha

        gl.stub(:repo_name).and_return('test_repo')

        change_file_and_commit('c', '', gl)

        branches = gl.branches
        branches['ab'].sha.should_not == branches['origin/int-br'].sha

        gl.run

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

        expect {gp.remove_feature_branch}.should raise_error GitProc::GitProcessError
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

end
