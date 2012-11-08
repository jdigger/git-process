require 'git-process/pull_request'
require 'github_test_helper'
require 'GitRepoHelper'

describe GitProc::PullRequest do
  include GitRepoHelper
  include GitHubTestHelper

  WebMock.reset!

  HEAD_REMOTE = 'testrepo'
  HEAD_REPO = 'test_repo'
  HEAD_BRANCH = 'test_branch'
  BASE_BRANCH = 'source_branch'
  HEAD_URL = "git@github.com:#{HEAD_REPO}.git"

  PR_NUMBER = '32'


  before(:each) do
    create_files(%w(.gitignore))
    gitprocess.commit('initial')
  end


  after(:each) do
    rm_rf(tmpdir)
  end


  def log_level
    Logger::ERROR
  end


  describe "with no parameters" do
    def create_process(dir, opts)
      GitProc::PullRequest.new(dir, opts)
    end


    it "should push the branch and create a default pull request" do
      pr_client = double('pr_client')

      gitprocess.config('gitProcess.integrationBranch', 'develop')
      gitprocess.add_remote('origin', 'git@github.com:jdigger/git-process.git')

      gitprocess.stub(:create_pull_request_client).with('origin', 'jdigger/git-process').and_return(pr_client)
      gitprocess.should_receive(:push)
      pr_client.should_receive(:create).with('develop', 'master', 'master', '')

      gitprocess.runner
    end


    it "should fail if the base and head branch are the same" do
      gitprocess.add_remote('origin', 'git@github.com:jdigger/git-process.git')

      expect {
        gitprocess.runner
      }.to raise_error GitProc::PullRequestError
    end

  end


  describe "with PR #" do
    def create_process(dir, opts)
      GitProc::PullRequest.new(dir, opts.merge({:prNumber => PR_NUMBER}))
    end


    it "should checkout the branch for the pull request" do
      gitprocess.config('gitProcess.github.authToken', 'sdfsfsdf')
      gitprocess.config('github.user', 'jdigger')
      gitprocess.stub(:fetch).with(HEAD_REMOTE)
      gitprocess.add_remote(HEAD_REMOTE, HEAD_URL)

      data = basic_pull_request_data()
      stub_get("https://api.github.com/repos/#{HEAD_REPO}/pulls/#{PR_NUMBER}", :body => data)

      # Tests that:
      #  * the branch is checked out from the HEAD branch of the pull
      #    request and created by the same name
      #  * the tracking for the new branch is set to the BASE branch
      #    of the pull request
      #
      gitprocess.should_receive(:checkout).with(HEAD_BRANCH, :new_branch => "#{HEAD_REMOTE}/#{HEAD_BRANCH}")
      gitprocess.should_receive(:branch).with(HEAD_BRANCH, :upstream => "#{HEAD_REMOTE}/#{BASE_BRANCH}")

      gitprocess.runner
    end

  end


  describe "with repo name and PR #" do
    def create_process(dir, opts)
      GitProc::PullRequest.new(dir, opts.merge({:prNumber => PR_NUMBER, :server => HEAD_REMOTE}))
    end


    it "should checkout the branch for the pull request" do
      BASE_REMOTE = 'sourcerepo'
      BASE_REPO = 'source_repo'
      BASE_URL = "git@github.com:#{BASE_REPO}.git"

      gitprocess.config('gitProcess.github.authToken', 'sdfsfsdf')
      gitprocess.config('github.user', 'jdigger')
      gitprocess.should_receive(:fetch).with(HEAD_REMOTE)
      gitprocess.should_receive(:fetch).with(BASE_REMOTE)

      gitprocess.add_remote(HEAD_REMOTE, HEAD_URL)
      gitprocess.add_remote(BASE_REMOTE, BASE_URL)

      data = basic_pull_request_data()
      data[:base][:repo][:ssh_url] = BASE_URL
      data[:base][:ref] = BASE_BRANCH

      stub_get("https://api.github.com/repos/#{HEAD_REPO}/pulls/#{PR_NUMBER}", :body => data)

      # Tests that:
      #  * the branch is checked out from the HEAD branch of the pull
      #    request and created by the same name
      #  * the tracking for the new branch is set to the BASE branch
      #    of the pull request
      #
      gitprocess.should_receive(:checkout).with(HEAD_BRANCH, :new_branch => "#{HEAD_REMOTE}/#{HEAD_BRANCH}")
      gitprocess.should_receive(:branch).with(HEAD_BRANCH, :upstream => "#{BASE_REMOTE}/#{BASE_BRANCH}")

      gitprocess.runner
    end

  end


  def basic_pull_request_data()
    {
        :number => PR_NUMBER,
        :state => 'open',
        :head => {
            :ref => HEAD_BRANCH,
            :repo => {
                :ssh_url => HEAD_URL,
            }
        },
        :base => {
            :ref => BASE_BRANCH,
            :repo => {
                :ssh_url => HEAD_URL,
            }
        }
    }
  end

end
