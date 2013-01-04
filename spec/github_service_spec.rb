require 'git-process/github_service'
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

    def ghs
      unless @ghs
        @ghs = GHS.new('tu', 'dfsdf')
        @ghs.lib.stub(:config).with('remote.origin.url').and_return('git@github.com:jdigger/git-process.git')
      end
      @ghs
    end


    it "should return an auth_token for a good request" do
      ghs.lib.should_receive(:config).with('gitProcess.github.authToken', anything).once

      stub_request(:post, /api.github.com\/authorizations/).
          to_return(:status => 200, :body => JSON({:token => test_token}))

      ghs.create_authorization().should == test_token
    end


    it "should 401 for bad password" do
      stub_request(:post, /api.github.com\/authorizations/).
          to_return(:status => 401)

      lambda { ghs.create_authorization() }.should raise_error Octokit::Unauthorized
    end

  end


  describe "auth_token" do

    it "should get the token from config if it exists" do
      ghs = GHS.new
      ghs.lib.stub(:config).with('github.user').and_return('test_user')
      ghs.lib.stub(:config).with('remote.origin.url').and_return('git@github.com:jdigger/git-process.git')
      ghs.lib.stub(:config).with('gitProcess.github.authToken').and_return(test_token)

      ghs.auth_token.should == test_token
    end


    it "should get the token from the server if it does not exist in config" do
      ghs = GHS.new(nil, 'dfsdf')
      ghs.lib.stub(:config).with('github.user').and_return('test_user')
      ghs.lib.stub(:config).with('remote.origin.url').and_return('git@github.com:jdigger/git-process.git')
      ghs.lib.stub(:config).with('gitProcess.github.authToken').and_return('')
      ghs.lib.should_receive(:config).with('gitProcess.github.authToken', anything).once

      stub_request(:post, /api.github.com\/authorizations/).
          to_return(:status => 200, :body => JSON({:token => test_token}))

      ghs.auth_token.should == test_token
    end

  end


  describe "user" do

    it "should get the value from config" do
      ghs = GHS.new(nil, 'dfsdf')
      ghs.lib.stub(:config).with('github.user').and_return('test_user')

      ghs.user.should == 'test_user'
    end


    it "should prompt the user and store it in the config" do
      ghs = GHS.new(nil, 'dfsdf')
      ghs.lib.stub(:config).with('github.user').and_return('')
      ghs.lib.stub(:config).with('github.user', anything).once

      ghs.stub(:ask).with(/username/).and_return('test_user')
      ghs.user.should == 'test_user'
    end

  end


  describe "using GHE instead of GitHub.com" do

    def ghs
      @ghs ||= GHS.new('tu', 'dfsdf', nil)
    end


    it "should use the correct server and path for a non-GitHub.com site" do
      ghs.lib.stub(:config).with('remote.origin.url').and_return('git@myco.com:jdigger/git-process.git')
      ghs.lib.should_receive(:config).with('gitProcess.github.authToken', anything).once

      stub_request(:post, /myco.com\/api\/v3\/authorizations/).
          to_return(:status => 200, :body => JSON({:token => test_token}))

      ghs.create_authorization().should == test_token
    end


    it "site should work for git@... ssh address" do
      ghs.lib.stub(:config).with('remote.origin.url').and_return('git@myco.com:jdigger/git-process.git')

      ghs.site.should == 'https://myco.com'
    end


    it "site should work for https address" do
      ghs.lib.stub(:config).with('remote.origin.url').and_return('https://myco.com/jdigger/git-process.git')

      ghs.site.should == 'https://myco.com'
    end


    it "site should work for http address" do
      ghs.lib.stub(:config).with('remote.origin.url').and_return('http://jdigger@myco.com/jdigger/git-process.git')

      ghs.site.should == 'http://myco.com'
    end


    it "site should work for git://myco.com/ address" do
      ghs.lib.stub(:config).with('remote.origin.url').and_return('git://myco.com/jdigger/git-process.git')

      ghs.site.should == 'https://myco.com'
    end


    it "site should raise an error if remote.origin.url not set" do
      ghs.lib.stub(:config).with('remote.origin.url').and_return('')

      lambda { ghs.site }.should raise_error GitHubService::NoRemoteRepository
    end


    it "site should not work for a garbase url address" do
      ghs.lib.stub(:config).with('remote.origin.url').and_return('garbage')

      lambda { ghs.site }.should raise_error URI::InvalidURIError
    end


    def in_tempfile(content, &block)
      file = Tempfile.new('ssh_config')
      file.puts content
      file.flush

      begin
        block.call(file)
      ensure
        file.close
        file.unlink
      end
    end


    it "site should work for an ssh-configged url address" do
      ghs.lib.stub(:config).with('remote.origin.url').and_return('mygithub:jdigger/git-process.git')

      content = "\nHost mygithub\n"+
          "  User git\n"+
          "  HostName github.myco.com\n"

      in_tempfile(content) do |file|
        ghs.site(:ssh_config_file => file.path).should == 'https://github.myco.com'
      end
    end

  end

end
