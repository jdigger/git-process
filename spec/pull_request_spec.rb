require 'git-process/pull_request'
require 'github_test_helper'
require 'pull_request_helper'
require 'GitRepoHelper'
require 'sawyer'
require 'octokit'


describe GitProc::PullRequest do
  include GitRepoHelper
  include GitHubTestHelper

  before(:each) do
    create_files(%w(.gitignore))
    gitlib.commit('initial')
  end


  after(:each) do
    rm_rf(gitlib.workdir)
  end


  def log_level
    Logger::ERROR
  end


  describe 'with no parameters' do
    def create_process(dir, opts)
      GitProc::PullRequest.new(dir, opts)
    end


    it 'should push the branch and create a default pull request' do
      pr_client = double('pr_client')

      gitlib.config['gitProcess.integrationBranch'] = 'develop'
      gitlib.remote.add('origin', 'git@github.com:jdigger/git-process.git')

      GitProc::PullRequest.stub(:create_pull_request_client).and_return(pr_client)
      #PullRequest.stub(:create_pull_request_client).with(anything, 'origin', 'jdigger/git-process').and_return(pr_client)
      gitlib.should_receive(:push)
      agent = Sawyer::Agent.new(Octokit::Default::API_ENDPOINT, {})
      sawyer_resource = Sawyer::Resource.new(agent, {:html_url => 'http://test'})
      pr_client.should_receive(:create).with('develop', 'master', 'master', '').and_return(sawyer_resource)

      gitprocess.runner
    end


    it 'should fail if the base and head branch are the same' do
      gitlib.remote.add('origin', 'git@github.com:jdigger/git-process.git')

      expect {
        gitprocess.runner
      }.to raise_error GitProc::PullRequestError
    end

  end


  describe 'checkout pull request' do
    include PullRequestHelper

    before(:each) do
      gitlib.config['gitProcess.github.authToken'] = 'sdfsfsdf'
      gitlib.config['github.user'] = 'jdigger'
    end


    describe "with PR #" do

      def pull_request
        @pr ||= create_pull_request({})
      end


      def create_process(dir, opts)
        GitProc::PullRequest.new(dir, opts.merge({:prNumber => pull_request[:number]}))
      end


      it 'should checkout the branch for the pull request' do
        add_remote(:head)
        stub_fetch(:head)

        stub_get_pull_request(pull_request)

        expect_checkout_pr_head()
        expect_upstream_set()

        gitlib.stub(:branch).with(nil, :no_color => true, :all => true).and_return('')
        gitlib.stub(:branch).with(nil, :no_color => true, :remote => true).and_return('')
        gitlib.should_receive(:rebase).with('tester/test_repo/master', {})

        gitprocess.runner
      end

    end


    describe 'with repo name and PR #' do

      def pull_request
        @pr ||= create_pull_request(:base_remote => 'sourcerepo', :base_repo => 'source_repo')
      end


      def create_process(dir, opts)
        GitProc::PullRequest.new(dir, opts.merge({:prNumber => pull_request[:number],
                                                  :server => pull_request[:head][:remote]}))
      end


      it 'should checkout the branch for the pull request' do
        add_remote(:head)
        add_remote(:base)
        stub_fetch(:head)
        stub_fetch(:base)
        gitlib.config['gitProcess.remoteName'] = pull_request[:head][:repo][:name]

        stub_get_pull_request(pull_request)

        expect_checkout_pr_head()
        expect_upstream_set()

        gitlib.stub(:branch).with(nil, :no_color => true, :all => true).and_return('')
        gitlib.stub(:branch).with(nil, :no_color => true, :remote => true).and_return('')
        gitlib.should_receive(:rebase).with('tester/test_repo/master', {})

        gitprocess.runner
      end

    end

  end

end
