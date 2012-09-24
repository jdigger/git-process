require 'git-process/pull_request'
require 'GitRepoHelper'
require 'webmock/rspec'
require 'json'
require 'octokit'
require 'tempfile'


describe GitHub::PullRequest do
  include GitRepoHelper


  def lib
    unless @lib
      @lib = double('lib')
      @lib.stub(:logger).and_return(logger)
    end
    @lib
  end


  def test_token
    'hfgkdjfgksjhdfkls'
  end


  def pull_request
    @pr ||= GitHub::PullRequest.new(lib, 'test_repo', :user => 'test_user')
  end


  before(:each) do
    lib.stub(:config).with('gitProcess.github.authToken').and_return(test_token)
    lib.stub(:config).with('remote.origin.url').and_return('git@github.com:jdigger/git-process.git')
  end


  describe "#create" do

    it "should return a pull request for a good request" do
      stub_request(:post, "https://api.github.com/repos/test_repo/pulls?access_token=#{test_token}").
          to_return(:status => 200, :body => JSON({:number => 1, :state => 'open'}))

      pull_request.create('test_base', 'test_head', 'test title', 'test body')[:state].should == 'open'
    end


    it "should handle asking for a duplicate pull request" do
      # trying to create the request should return "HTTP 422: Unprocessable Entity" because it already exists
      stub_request(:post, "https://api.github.com/repos/test_repo/pulls?access_token=#{test_token}").
          to_return(:status => 422)

      # listing all existing pull requests should contain the current branch
      stub_request(:get, /test_repo\/pulls\?access_token=/).
          to_return(:status => 200, :body => JSON([{:html_url => 'test_url', :head => {:ref => 'test_head'}, :base => {:ref => 'test_base'}}]))

      pull_request.create('test_base', 'test_head', 'test title', 'test body')[:html_url].should == 'test_url'
    end

  end


  describe "#close" do

    it "should close a good current pull request" do
      stub_request(:get, /test_repo\/pulls\?access_token=/).
          to_return(:status => 200, :body => JSON([{:number => 1, :state => 'open', :html_url => 'test_url', :head => {:ref => 'test_head'}, :base => {:ref => 'test_base'}}]))
      stub_request(:patch, /test_repo\/pulls\/1\?access_token=/).with(:body => JSON({:state => 'closed'})).
          to_return(:status => 200, :body => JSON({:number => 1, :state => 'closed', :html_url => 'test_url', :head => {:ref => 'test_head'}, :base => {:ref => 'test_base'}}))

      pull_request.close('test_base', 'test_head')[:state].should == 'closed'
    end


    it "should close a good current pull request using the pull request number" do
      stub_request(:patch, /test_repo\/pulls\/1\?access_token=/).with(:body => JSON({:state => 'closed'})).
          to_return(:status => 200, :body => JSON({:number => 1, :state => 'closed', :html_url => 'test_url', :head => {:ref => 'test_head'}, :base => {:ref => 'test_base'}}))

      pull_request.close(1)[:state].should == 'closed'
    end


    it "should complain about a missing pull request" do
      stub_request(:get, /test_repo\/pulls\?access_token=/).
          to_return(:status => 200, :body => JSON([{:number => 1, :state => 'open', :html_url => 'test_url', :head => {:ref => 'test_head'}, :base => {:ref => 'test_base'}}]))

      expect { pull_request.close('test_base', 'missing_head') }.should raise_error GitHub::PullRequest::NotFoundError
    end

  end

end
