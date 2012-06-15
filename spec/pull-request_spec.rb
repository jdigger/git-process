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


  describe "create_authorization" do

    before(:each) do
      @pr = Git::PullRequest.new(lib, :user => 'tu', :password => 'dfsdf')
      lib.stub(:config).with('remote.origin.url').and_return('git@github.com:jdigger/git-process.git')
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


  describe "auth_token" do

    before(:each) do
      lib.stub(:config).with('github.user').and_return('test_user')
      lib.stub(:config).with('remote.origin.url').and_return('git@github.com:jdigger/git-process.git')
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


  describe "using GHE instead of GitHub.com" do

    before(:each) do
      @pr = Git::PullRequest.new(lib, :user => 'tu', :password => 'dfsdf', :site => 'http://myco.com')
    end


    it "should return an auth_token for a good request" do
      lib.stub(:config).with('remote.origin.url').and_return('git@myco.com:jdigger/git-process.git')
      lib.should_receive(:config).with('gitProcess.github.authToken', anything).once

      stub_request(:post, /myco.com\/api\/v3\/authorizations/).
        to_return(:status => 200, :body => JSON({:token => test_token}))

      @pr.create_authorization().should == test_token
    end


    it "site should work for git@... ssh address" do
      lib.stub(:config).with('remote.origin.url').and_return('git@myco.com:jdigger/git-process.git')

      @pr.site.should == 'http://myco.com'
    end


    it "site should work for https address" do
      lib.stub(:config).with('remote.origin.url').and_return('https://myco.com/jdigger/git-process.git')

      @pr.site.should == 'https://myco.com'
    end


    it "site should work for http address" do
      lib.stub(:config).with('remote.origin.url').and_return('http://jdigger@myco.com/jdigger/git-process.git')

      @pr.site.should == 'http://myco.com'
    end


    it "site should work for git://myco.com/ address" do
      lib.stub(:config).with('remote.origin.url').and_return('git://myco.com/jdigger/git-process.git')

      @pr.site.should == 'http://myco.com'
    end


    it "site should raise an error if remote.origin.url not set" do
      lib.stub(:config).with('remote.origin.url').and_return('')

      lambda {@pr.site}.should raise_error Git::PullRequest::NoRemoteRepository
    end


    it "site should not work for a garbase url address" do
      lib.stub(:config).with('remote.origin.url').and_return('garbage')

      lambda {@pr.site}.should raise_error URI::InvalidURIError
    end


    it "site should work for an ssh-configged url address" do
      lib.stub(:config).with('remote.origin.url').and_return('mygithub:jdigger/git-process.git')

      config_file = Tempfile.new('ssh_config')
      config_file.puts "\nHost mygithub\n"+
        "  User git\n"+
        "  HostName github.myco.com\n"
      config_file.flush

      begin
        @pr.site(:ssh_config_file => config_file.path).should == 'http://github.myco.com'
      ensure
        config_file.close
        config_file.unlink
      end
    end

  end

end
