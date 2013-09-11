require 'git-process/rebase_to_master'
require 'GitRepoHelper'
require 'github_test_helper'
require 'pull_request_helper'
require 'webmock/rspec'
require 'json'
include GitProc

describe RebaseToMaster do
  include GitRepoHelper
  include GitHubTestHelper


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


  def create_process(base, opts = {})
    RebaseToMaster.new(base, opts)
  end


  describe 'rebase to master' do

    it 'should work easily for a simple rebase' do
      gitlib.checkout('fb', :new_branch => 'master')
      change_file_and_commit('a', '')

      commit_count.should == 2

      gitlib.checkout('master')
      change_file_and_commit('b', '')

      gitlib.checkout('fb')

      gitprocess.run

      commit_count.should == 3
    end


    describe 'when used on _parking_' do
      it 'should fail #rebase_to_master' do
        gitlib.checkout('_parking_', :new_branch => 'master')
        change_file_and_commit('a', '')

        expect { gitprocess.verify_preconditions }.to raise_error ParkedChangesError
      end
    end


    describe 'closing the pull request' do
      include PullRequestHelper


      def pull_request
        @pr ||= create_pull_request(:pr_number => '987', :head_branch => 'fb', :base_branch => 'master')
      end


      it 'should not try when there is no auth token' do
        gitlib.branch('fb', :base_branch => 'master')
        clone_repo('fb') do |gl|
          gl.config['gitProcess.github.authToken'] = ''
          gl.config['remote.origin.url'] = 'git@github.com:test_repo.git'
          gl.config['github.user'] = 'test_user'

          rtm = RebaseToMaster.new(gl, :log_level => log_level)
          rtm.gitlib.stub(:fetch)
          rtm.gitlib.stub(:push)
          rtm.runner
        end
      end

    end

  end


  describe 'custom integration branch' do

    it "should use the 'gitProcess.integrationBranch' configuration" do
      gitlib.checkout('int-br', :new_branch => 'master')
      change_file_and_commit('a', '')

      gitlib.checkout('fb', :new_branch => 'master')
      change_file_and_commit('b', '')

      gitlib.branches['master'].delete!

      clone_repo('int-br') do |gl|
        gl.config['gitProcess.integrationBranch'] = 'int-br'

        gl.checkout('ab', :new_branch => 'origin/int-br')

        my_branches = gl.branches
        my_branches.include?('origin/master').should be_false
        my_branches['ab'].sha.should == my_branches['origin/int-br'].sha

        gl.stub(:repo_name).and_return('test_repo')

        change_file_and_commit('c', '', gl)

        my_branches = gl.branches
        my_branches['ab'].sha.should_not == my_branches['origin/int-br'].sha

        RebaseToMaster.new(gl, :log_level => log_level).runner

        my_branches = gl.branches
        my_branches['HEAD'].sha.should == my_branches['origin/int-br'].sha
      end
    end

  end


  describe 'remove current feature branch' do

    describe 'when handling the parking branch' do

      it 'should create it based on origin/master' do
        gitlib.branch('fb', :base_branch => 'master')
        clone_repo('fb') do |gl|
          create_process(gl).remove_feature_branch
          gl.branches.current.name.should == '_parking_'
        end
      end


      it 'should move it to the new origin/master if it already exists and is clean' do
        clone_repo do |gl|
          gl.branch('_parking_', :base_branch => 'origin/master')
          change_file_and_commit('a', '', gl)

          gl.checkout('fb', :new_branch => 'origin/master')

          create_process(gl).remove_feature_branch

          gl.branches.current.name.should == '_parking_'
        end
      end


      it 'should move it to the new origin/master if it already exists and changes are part of the current branch' do
        gitlib.checkout('afb', :new_branch => 'master')
        clone_repo do |gl|
          gl.checkout('_parking_', :new_branch => 'origin/master') do
            change_file_and_commit('a', '', gl)
          end

          gl.checkout('fb', :new_branch => '_parking_')
          gl.push('origin', 'fb', 'master')

          create_process(gl).remove_feature_branch
          gl.branches.current.name.should == '_parking_'
        end
      end


      it 'should move it out of the way if it has unaccounted changes on it' do
        clone_repo do |gl|
          gl.checkout('_parking_', :new_branch => 'origin/master')
          change_file_and_commit('a', '', gl)
          gl.checkout('fb', :new_branch => 'origin/master')

          gl.branches.include?('_parking_OLD_').should be_false

          create_process(gl).remove_feature_branch

          gl.branches.include?('_parking_OLD_').should be_true
          gl.branches.current.name.should == '_parking_'
        end
      end

    end


    it 'should delete the old local branch when it has been merged into origin/master' do
      clone_repo do |gl|
        change_file_and_commit('a', '', gl)

        gl.checkout('fb', :new_branch => 'origin/master')
        gl.branches.include?('fb').should be_true

        create_process(gl).remove_feature_branch

        gl.branches.include?('fb').should be_false
        gl.branches.current.name.should == '_parking_'
      end
    end


    it 'should raise an error when the local branch has not been merged into origin/master' do
      clone_repo do |gl|
        gl.checkout('fb', :new_branch => 'origin/master')
        change_file_and_commit('a', '', gl)

        gl.branches.include?('fb').should be_true

        expect { create_process(gl).remove_feature_branch }.to raise_error GitProcessError
      end
    end


    it 'should delete the old remote branch' do
      change_file_and_commit('a', '')

      gitlib.branch('fb', :base_branch => 'master')

      clone_repo('fb') do |gl|
        gl.branches.include?('origin/fb').should be_true
        create_process(gl).remove_feature_branch
        gl.branches.include?('origin/fb').should be_false
        gitlib.branches.include?('fb').should be_false
        gl.branches.current.name.should == '_parking_'
      end
    end

  end


  describe ':keep option' do

    it 'should not try to close a pull request or remove remote branch' do
      gitlib.branch('fb', :base_branch => 'master')

      clone_repo('fb') do |gl|
        rtm = GitProc::RebaseToMaster.new(gl, :log_level => log_level, :keep => true)
        gl.should_receive(:fetch).at_least(1)
        gl.should_receive(:push).with('origin', gl.branches.current.name, 'master')
        gl.should_not_receive(:push).with('origin', nil, nil, :delete => 'fb')
        rtm.runner
      end
    end

  end


  describe 'to-master pull request' do
    include PullRequestHelper


    def pull_request_number
      pull_request[:number]
    end


    def head_repo_name
      pull_request[:head][:repo][:name]
    end


    def base_repo_name
      pull_request[:base][:repo][:name]
    end


    def base_branch_name
      pull_request[:base][:ref]
    end


    def head_branch_name
      pull_request[:head][:ref]
    end


    before(:each) do
      gitlib.branch(head_branch_name, :base_branch => 'master')
    end


    def configure(gl)
      gl.config['gitProcess.github.authToken'] = 'sdfsfsdf'
      gl.config["remote.#{head_repo_name}.url"] = "git@github.com:#{head_repo_name}.git"
      gl.config['github.user'] = 'jdigger'
      gl.config['gitProcess.remoteName'] = head_repo_name

      stub_fetch(:head, gl)
      stub_fetch(:base, gl)

      stub_get("https://api.github.com/repos/#{head_repo_name}/pulls/#{pull_request_number}", :body => pull_request)
      stub_patch("https://api.github.com/repos/#{head_repo_name}/pulls/#{pull_request_number}")
    end


    describe 'with PR #' do

      def pull_request
        @pr ||= create_pull_request({})
      end


      def create_process(dir, opts)
        RebaseToMaster.new(dir, opts.merge({:prNumber => pull_request_number}))
      end


      it 'should checkout the branch for the pull request' do
        clone_repo('master', head_repo_name) do |gl|
          gl.branch("#{base_repo_name}/#{base_branch_name}", :base_branch => "#{head_repo_name}/master")

          configure(gl)

          rtm = GitProc::RebaseToMaster.new(gl, :log_level => log_level, :prNumber => pull_request_number)

          gl.should_receive(:push).with(head_repo_name, head_branch_name, 'master')
          gl.should_receive(:push).with(head_repo_name, nil, nil, :delete => head_branch_name)

          rtm.runner
        end
      end

    end


    describe 'with repo name and PR #' do

      def pull_request
        @pr ||= create_pull_request(:base_remote => 'sourcerepo', :base_repo => 'source_repo')
      end


      def create_process(dir, opts = {})
        RebaseToMaster.new(dir, opts.merge({:prNumber => var,
                                            :server => pull_request[:head][:remote]}))
      end


      it 'should checkout the branch for the pull request' do
        clone_repo('master', head_repo_name) do |gl|
          add_remote(:base, gl)
          gl.branch("#{base_repo_name}/#{base_branch_name}", :base_branch => "#{head_repo_name}/master")

          configure(gl)

          rtm = GitProc::RebaseToMaster.new(gl, :log_level => log_level, :prNumber => pull_request_number)

          gl.should_receive(:push).with(head_repo_name, head_branch_name, 'master')
          gl.should_receive(:push).with(head_repo_name, nil, nil, :delete => head_branch_name)

          rtm.runner
        end
      end

    end

  end

end
