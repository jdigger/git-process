require 'github-service'
require 'webmock/rspec'
require 'json'
require 'octokit'
require 'tempfile'
require 'rspec/mocks/methods'
require 'rspec/mocks/test_double'
require 'rspec/mocks/mock'


class GHS
  include GitHubService

  def initialize(user = nil, password = nil, site = nil)
    @user = user
    @password = password
    @site = site

    logger = RSpec::Mocks::Mock.new('logger')
    logger.stub(:debug)
    logger.stub(:info)

    @lib = RSpec::Mocks::Mock.new('lib')
    @lib.stub(:logger).and_return(logger)
  end

  def lib
    @lib
  end
end


describe GitHubService do

  def test_token
    'hfgkdjfgksjhdfkls'
  end


  describe "create_authorization" do

    before(:each) do
      @pr = GHS.new('tu', 'dfsdf')
      @pr.lib.stub(:config).with('remote.origin.url').and_return('git@github.com:jdigger/git-process.git')
    end


    it "should return an auth_token for a good request" do
      @pr.lib.should_receive(:config).with('gitProcess.github.authToken', anything).once

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


  describe "auth_token" do

    it "should get the token from config if it exists" do
      pr = GHS.new
      pr.lib.stub(:config).with('github.user').and_return('test_user')
      pr.lib.stub(:config).with('remote.origin.url').and_return('git@github.com:jdigger/git-process.git')
      pr.lib.stub(:config).with('gitProcess.github.authToken').and_return(test_token)

      pr.auth_token.should == test_token
    end


    it "should get the token from the server if it does not exist in config" do
      pr = GHS.new(nil, 'dfsdf')
      pr.lib.stub(:config).with('github.user').and_return('test_user')
      pr.lib.stub(:config).with('remote.origin.url').and_return('git@github.com:jdigger/git-process.git')
      pr.lib.stub(:config).with('gitProcess.github.authToken').and_return('')
      pr.lib.should_receive(:config).with('gitProcess.github.authToken', anything).once

      stub_request(:post, /api.github.com\/authorizations/).
        to_return(:status => 200, :body => JSON({:token => test_token}))

      pr.auth_token.should == test_token
    end

  end


  describe "user" do

    it "should get the value from config" do
      pr = GHS.new(nil, 'dfsdf')
      pr.lib.stub(:config).with('github.user').and_return('test_user')

      pr.user.should == 'test_user'
    end


    it "should prompt the user and store it in the config" do
      pr = GHS.new(nil, 'dfsdf')
      pr.lib.stub(:config).with('github.user').and_return('')
      pr.lib.stub(:config).with('github.user', anything).once

      pr.stub(:ask).with(/username/).and_return('test_user')
      pr.user.should == 'test_user'
    end

  end


  describe "using GHE instead of GitHub.com" do

    before(:each) do
      @pr = GHS.new('tu', 'dfsdf', nil)
    end


    it "should use the correct server and path for a non-GitHub.com site" do
      @pr.lib.stub(:config).with('remote.origin.url').and_return('git@myco.com:jdigger/git-process.git')
      @pr.lib.should_receive(:config).with('gitProcess.github.authToken', anything).once

      stub_request(:post, /myco.com\/api\/v3\/authorizations/).
        to_return(:status => 200, :body => JSON({:token => test_token}))

      @pr.create_authorization().should == test_token
    end


    it "site should work for git@... ssh address" do
      @pr.lib.stub(:config).with('remote.origin.url').and_return('git@myco.com:jdigger/git-process.git')

      @pr.site.should == 'http://myco.com'
    end


    it "site should work for https address" do
      @pr.lib.stub(:config).with('remote.origin.url').and_return('https://myco.com/jdigger/git-process.git')

      @pr.site.should == 'https://myco.com'
    end


    it "site should work for http address" do
      @pr.lib.stub(:config).with('remote.origin.url').and_return('http://jdigger@myco.com/jdigger/git-process.git')

      @pr.site.should == 'http://myco.com'
    end


    it "site should work for git://myco.com/ address" do
      @pr.lib.stub(:config).with('remote.origin.url').and_return('git://myco.com/jdigger/git-process.git')

      @pr.site.should == 'http://myco.com'
    end


    it "site should raise an error if remote.origin.url not set" do
      @pr.lib.stub(:config).with('remote.origin.url').and_return('')

      lambda {@pr.site}.should raise_error GitHubService::NoRemoteRepository
    end


    it "site should not work for a garbase url address" do
      @pr.lib.stub(:config).with('remote.origin.url').and_return('garbage')

      lambda {@pr.site}.should raise_error URI::InvalidURIError
    end


    it "site should work for an ssh-configged url address" do
      @pr.lib.stub(:config).with('remote.origin.url').and_return('mygithub:jdigger/git-process.git')

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
