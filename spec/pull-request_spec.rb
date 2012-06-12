require 'pull-request'
require 'webmock/rspec'
require 'json'
require 'octokit'
require 'tempfile'


describe Git::PullRequest do

  attr_reader :logger, :lib

  before(:each) do
    @logger = double('logger')
    @logger.stub(:debug)
    @logger.stub(:info)

    @lib = double('lib')
    @lib.stub(:logger).and_return(logger)
  end


  def test_token
    'hfgkdjfgksjhdfkls'
  end


  describe "pull_request" do

    before(:each) do
      @pr = Git::PullRequest.new(lib, :user => 'test_user')
      lib.stub(:config).with('gitProcess.github.authToken').and_return(test_token)
      lib.stub(:config).with('remote.origin.url').and_return('git@github.com:jdigger/git-process.git')
    end


    it "should return a pull request for a good request" do
      stub_request(:post, "https://api.github.com/repos/test_repo/pulls?access_token=#{test_token}").
        to_return(:status => 200, :body => JSON({:number => 1, :state => 'open'}))

      @pr.pull_request('test_repo', 'test_base', 'test_head', 'test title', 'test body')[:state].should == 'open'
    end


    it "should handle asking for a duplicate pull request" do
      stub_request(:post, "https://api.github.com/repos/test_repo/pulls?access_token=#{test_token}").
        to_return(:status => 422)

      stub_request(:get, /test_repo\/pulls\?access_token=/).
        to_return(:status => 200, :body => JSON([{:html_url => 'test_url', :head => {:ref => 'test_head'}, :base => {:ref => 'test_base'}}]))

      @logger.should_receive(:warn).once

      @pr.pull_request('test_repo', 'test_base', 'test_head', 'test title', 'test body')[:html_url].should == 'test_url'
    end

  end

end
