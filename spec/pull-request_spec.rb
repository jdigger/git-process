require 'pull-request'
require 'webmock/rspec'
require 'json'
require 'octokit'

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


  describe "create_authorization" do

    before(:each) do
      @pr = Git::PullRequest.new(lib, :user => 'tu', :password => 'dfsdf')
    end


    it "should return an auth_token for a good request" do
      lib.should_receive(:config).with('gitProcess.github.authToken', anything).once

      stub_request(:post, /api.github.com\/authorizations/).
        to_return(:status => 200, :body => JSON({:token => test_token}))

      @pr.create_authorization().should == test_token
    end


    it "should 401 for bad password" do
      stub_request(:post, /api.github.com\/authorizations/).
        to_return(:status => 401)

      lambda { @pr.create_authorization() }.should raise_error Octokit::Unauthorized
    end

  end


  describe "pull_request" do

    before(:each) do
      @pr = Git::PullRequest.new(lib, :user => 'test_user')
      lib.stub(:config).with('gitProcess.github.authToken').and_return(test_token)
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


  describe "auth_token" do

    before(:each) do
      lib.stub(:config).with('github.user').and_return('test_user')
    end


    it "should get the token from config if it exists" do
      lib.stub(:config).with('gitProcess.github.authToken').and_return(test_token)

      pr = Git::PullRequest.new(lib)
      pr.auth_token.should == test_token
    end


    it "should get the token from the server if it does not exist in config" do
      lib.stub(:config).with('gitProcess.github.authToken').and_return('')
      lib.should_receive(:config).with('gitProcess.github.authToken', anything).once

      stub_request(:post, /api.github.com\/authorizations/).
        to_return(:status => 200, :body => JSON({:token => test_token}))

      pr = Git::PullRequest.new(lib, :password => 'dfsdf')
      pr.auth_token.should == test_token
    end

  end


  describe "user" do

    it "should get the value from config" do
      lib.stub(:config).with('github.user').and_return('test_user')

      pr = Git::PullRequest.new(lib, :password => 'dfsdf')
      pr.user.should == 'test_user'
    end


    it "should prompt the user and store it in the config" do
      lib.stub(:config).with('github.user').and_return('')
      lib.stub(:config).with('github.user', anything).once

      pr = Git::PullRequest.new(lib, :password => 'dfsdf')
      pr.stub(:ask).with(/username/).and_return('test_user')
      pr.user.should == 'test_user'
    end

  end

end
